import Foundation
import TalisCore

enum TestFailure: Error { case injected }
final class MemorySecrets: CredentialStorage {
    var values: [String: String] = [:]
    var failWrite = false, failRead = false, failDelete = false, corruptWrite = false
    func read(account: String) throws -> String? {
        if failRead { throw TestFailure.injected }; return values[account]
    }
    func write(_ value: String, account: String) throws {
        if failWrite { throw TestFailure.injected }
        values[account] = corruptWrite ? "wrong" : value
    }
    func delete(account: String) throws {
        if failDelete { throw TestFailure.injected }; values.removeValue(forKey: account)
    }
}
final class Legacy: LegacyCredentialSource {
    var migrationComplete = false
    var ownerProvider = "deepseek"
    let sourceNames = ["defaults", "config0", "config1", "config2", "keychain"]
    var old: [LegacyCredential] = []
    var cleanupFailed = false, cleared = false
    func candidates() throws -> [LegacyCredential] { old }
    func clearPlaintext() throws {
        if cleanupFailed { throw TestFailure.injected }
        cleared = true; old = []
    }
    func markMigrationComplete() { migrationComplete = true }
}
var count = 0
func check(_ value: @autoclosure () throws -> Bool, _ label: String) throws {
    guard try value() else { fatalError(label) }; count += 1
}
func mustThrow(_ label: String, _ body: () throws -> Void) {
    do { try body(); fatalError(label) } catch { count += 1 }
}

let storage = MemorySecrets(), legacy = Legacy()
legacy.old = [LegacyCredential(source: "defaults", provider: "deepseek", value: "effective-old"),
              LegacyCredential(source: "config0", provider: "deepseek", value: "different-old-config"),
              LegacyCredential(source: "config1", provider: "kimi", value: "kimi-old")]
let vault = CredentialVault(storage: storage, legacy: legacy)
try check(vault.read(provider: "deepseek") == "effective-old", "old priority retained")
try check(storage.values["legacy.config0.deepseek"] == "different-old-config", "different old key preserved securely")
try check(vault.read(provider: "kimi") == "kimi-old", "config provider retained")
try check(vault.read(provider: "openai") == nil, "no cross-provider fallback")
try check(legacy.cleared && legacy.migrationComplete, "clear only after successful writes")
try vault.save(" new-key ", provider: "openai")
try check(vault.read(provider: "openai") == "new-key", "save trims key")
try check(vault.read(provider: "deepseek") == "effective-old", "saving one provider preserves another")
storage.failWrite = true
mustThrow("write error surfaced") { try vault.save("replacement", provider: "openai") }
storage.failWrite = false
try check(vault.read(provider: "openai") == "new-key", "failed update preserves previous key")
storage.failRead = true; mustThrow("read error surfaced") { _ = try vault.read(provider: "openai") };storage.failRead = false
storage.failDelete = true;mustThrow("delete error surfaced") { try vault.delete(provider: "openai") };storage.failDelete = false
try check(vault.read(provider: "openai") == "new-key", "failed delete preserves previous key")
try vault.delete(provider: "deepseek")
try check(vault.read(provider: "deepseek") == nil, "deleted key never resurrects")
try check(storage.values["legacy.config0.deepseek"] == nil, "provider recovery items removed too")
try check(vault.read(provider: "kimi") == "kimi-old", "delete preserves other provider")
mustThrow("empty input rejected") { try vault.save("  ", provider: "openai") }

for mode in ["write", "verification", "cleanup"] {
    let s = MemorySecrets(), l = Legacy()
    l.old = [LegacyCredential(source: "defaults", provider: "deepseek", value: "old-key")]
    s.failWrite = mode == "write";s.corruptWrite = mode == "verification";l.cleanupFailed = mode == "cleanup"
    let v = CredentialVault(storage: s, legacy: l)
    mustThrow("migration failure \(mode) surfaced") { try v.migrate() }
    try check(!l.cleared && !l.migrationComplete && !l.old.isEmpty, "migration failure preserves plaintext input")
    s.failWrite = false;s.corruptWrite = false;l.cleanupFailed = false
    if mode == "verification" { s.values = [:] }
    try v.migrate()
    try check(l.migrationComplete && v.read(provider: "deepseek") == "old-key", "migration retry succeeds")
}
let newer = MemorySecrets(), old = Legacy()
newer.values["provider.deepseek"] = "already-saved-new"
old.old = [LegacyCredential(source:"defaults",provider:"deepseek",value:"older")]
try CredentialVault(storage:newer,legacy:old).migrate()
try check(newer.values["provider.deepseek"] == "already-saved-new" && newer.values["legacy.defaults.deepseek"] == "older", "existing provider key never overwritten by migration")

let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
defer { try? FileManager.default.removeItem(at:directory) }
let config = directory.appendingPathComponent("config.yaml")
try "# keep comment\nmodel: deepseek\napi_key: 'fixture-key'\nother: keep\n".write(to:config,atomically:true,encoding:.utf8)
try check(AppConfigFile.apiKey(at:config) == "fixture-key", "quoted old config read")
try AppConfigFile.removeAPIKey(at:config)
let clean = try String(contentsOf:config,encoding:.utf8)
try check(!clean.contains("fixture-key") && clean.contains("model: deepseek") && clean.contains("other: keep") && clean.contains("# keep comment"), "config cleanup preserves nonsecret content")

// Real Keychain test uses disposable fake values and an isolated service only.
let real = SystemKeychainStorage(service:"local.talis.credential-tests.\(UUID().uuidString)")
defer { try? real.delete(account:"provider.deepseek");try? real.delete(account:"provider.openai") }
try real.write("fake-key-a",account:"provider.deepseek")
try real.write("fake-key-b",account:"provider.openai")
try check(real.read(account:"provider.deepseek") == "fake-key-a" && real.read(account:"provider.openai") == "fake-key-b", "real keychain provider isolation")
try real.write("fake-key-a2",account:"provider.deepseek")
try check(real.read(account:"provider.deepseek") == "fake-key-a2", "real keychain in-place update")
try real.delete(account:"provider.deepseek")
try check(real.read(account:"provider.deepseek") == nil && real.read(account:"provider.openai") == "fake-key-b", "real keychain scoped deletion")
print("PASS: \(count) credential checks including real isolated Keychain CRUD; no real keys logged")
