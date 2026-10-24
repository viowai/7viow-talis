import Foundation

public protocol CredentialStorage {
    func read(account: String) throws -> String?
    func write(_ value: String, account: String) throws
    func delete(account: String) throws
}

public struct LegacyCredential {
    public let source: String
    public let provider: String
    public let value: String
    public init(source: String, provider: String, value: String) {
        self.source = source; self.provider = provider; self.value = value
    }
}

public protocol LegacyCredentialSource {
    var migrationComplete: Bool { get }
    var ownerProvider: String { get }
    var sourceNames: [String] { get }
    func candidates() throws -> [LegacyCredential]
    func clearPlaintext() throws
    func markMigrationComplete()
}

public enum CredentialVaultError: Error, LocalizedError {
    case emptyKey
    case missingKey
    case verificationFailed
    public var errorDescription: String? {
        switch self {
        case .emptyKey: return "请输入有效的 API Key。"
        case .missingKey: return "当前模型供应商尚未配置 API Key，请先打开设置。"
        case .verificationFailed: return "密钥写入后未能正确读回，原配置已保留。"
        }
    }
}

public final class CredentialVault {
    private let storage: CredentialStorage
    private let legacy: LegacyCredentialSource

    public init(storage: CredentialStorage, legacy: LegacyCredentialSource) {
        self.storage = storage; self.legacy = legacy
    }

    public func migrate() throws {
        guard !legacy.migrationComplete else { return }
        // Candidates arrive in the old application's actual priority order.
        for candidate in try legacy.candidates() {
            let value = candidate.value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else { continue }
            let account = "provider.\(candidate.provider)"
            if let current = try storage.read(account: account) {
                if current != value {
                    try writeVerified(value, account: "legacy.\(candidate.source).\(candidate.provider)")
                }
            } else {
                try writeVerified(value, account: account)
            }
        }
        try legacy.clearPlaintext()
        legacy.markMigrationComplete()
    }

    public func read(provider: String) throws -> String? {
        try migrate()
        return try storage.read(account: "provider.\(provider)")
    }

    public func save(_ value: String, provider: String) throws {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw CredentialVaultError.emptyKey }
        try migrate()
        try writeVerified(trimmed, account: "provider.\(provider)")
    }

    public func delete(provider: String) throws {
        try migrate()
        try storage.delete(account: "provider.\(provider)")
        for source in legacy.sourceNames {
            try storage.delete(account: "legacy.\(source).\(provider)")
        }
        if provider == legacy.ownerProvider { try storage.delete(account: "api-key") }
    }

    private func writeVerified(_ value: String, account: String) throws {
        try storage.write(value, account: account)
        guard try storage.read(account: account) == value else {
            throw CredentialVaultError.verificationFailed
        }
    }
}
