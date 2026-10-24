import Foundation
import TalisCore

final class AppLegacyCredentials: LegacyCredentialSource {
    private let defaults = UserDefaults.standard
    private let keychain: SystemKeychainStorage
    private let completionKey = "ai.credentials-migrated.v1"
    private let ownerKey = "ai.legacy-key-provider"
    let ownerProvider: String
    let sourceNames = ["defaults", "config0", "config1", "config2", "keychain"]

    init(keychain: SystemKeychainStorage) {
        self.keychain = keychain
        ownerProvider = defaults.string(forKey: ownerKey) ?? AppSettings.modelOption.id
        defaults.set(ownerProvider, forKey: ownerKey)
    }

    var migrationComplete: Bool { defaults.bool(forKey: completionKey) }

    func candidates() throws -> [LegacyCredential] {
        var values: [LegacyCredential] = []
        if let value = defaults.string(forKey: "ai.api-key.local"), !value.isEmpty {
            values.append(LegacyCredential(source: "defaults", provider: ownerProvider, value: value))
        }
        for (index, url) in AppConfigFile.legacyConfigURLs.enumerated() {
            if let value = AppConfigFile.apiKey(at: url) {
                let provider = OpenAIClient.modelOption(for: AppConfigFile.modelID(at: url) ?? ownerProvider).id
                values.append(LegacyCredential(source: "config\(index)", provider: provider, value: value))
            }
        }
        if values.isEmpty, let value = try keychain.read(account: "api-key") {
            values.append(LegacyCredential(source: "keychain", provider: ownerProvider, value: value))
        }
        return values
    }

    func clearPlaintext() throws {
        for url in AppConfigFile.legacyConfigURLs { try AppConfigFile.removeAPIKey(at: url) }
        defaults.removeObject(forKey: "ai.api-key.local")
        defaults.synchronize()
    }

    func markMigrationComplete() {
        defaults.set(true, forKey: completionKey)
        defaults.synchronize()
    }
}

enum KeychainStore {
    private static let storage = SystemKeychainStorage(service: AppIdentity.current.keychainService)
    private static let vault = CredentialVault(storage: storage, legacy: AppLegacyCredentials(keychain: storage))

    static func migrateLegacyIfNeeded() throws { try vault.migrate() }
    static func readAPIKey(provider: String = AppSettings.modelOption.id) throws -> String? {
        try vault.read(provider: provider)
    }
    static func saveAPIKey(_ value: String, provider: String = AppSettings.modelOption.id) throws {
        try vault.save(value, provider: provider)
    }
    static func deleteAPIKey(provider: String = AppSettings.modelOption.id) throws {
        try vault.delete(provider: provider)
    }
}

