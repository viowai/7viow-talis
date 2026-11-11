import Foundation
import Security
import LocalAuthentication
import TalisCore

struct SystemKeychainStorage: CredentialStorage {
    let service: String

    private func query(_ account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service, kSecAttrAccount as String: account]
    }

    func read(account: String) throws -> String? {
        var request = query(account)
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        let status = SecItemCopyMatching(request as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KeychainError.unhandledStatus(status) }
        guard let data = result as? Data, let value = String(data: data, encoding: .utf8) else {
            throw CredentialVaultError.verificationFailed
        }
        return value
    }

    func contains(account: String) throws -> Bool {
        var request = query(account)
        request[kSecReturnAttributes as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        let context = LAContext()
        context.interactionNotAllowed = true
        request[kSecUseAuthenticationContext as String] = context
        let status = SecItemCopyMatching(request as CFDictionary, nil)
        if status == errSecItemNotFound { return false }
        guard status == errSecSuccess else { throw KeychainError.unhandledStatus(status) }
        return true
    }

    func write(_ value: String, account: String) throws {
        var request = query(account)
        let data = Data(value.utf8)
        var status = SecItemUpdate(request as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            request[kSecValueData as String] = data
            request[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            status = SecItemAdd(request as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw KeychainError.unhandledStatus(status) }
    }

    func delete(account: String) throws {
        let status = SecItemDelete(query(account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledStatus(status)
        }
    }
}

enum KeychainError: LocalizedError {
    case unhandledStatus(OSStatus)
    var errorDescription: String? {
        switch self {
        case .unhandledStatus(let status):
            if status == errSecUserCanceled {
                return L("已取消钥匙串授权，原密钥仍保留。需要时可以重新尝试。")
            }
            let description = SecCopyErrorMessageString(status, nil) as String? ?? L("未知错误")
            return AppLocalization.format("无法访问 macOS 钥匙串（%@）：%@。请解锁登录钥匙串，并在系统提示中允许 Talis 访问后重试。", status, description)
        }
    }
}
