import Foundation
import Security
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
                return "已取消 Keychain 授权，原密钥仍保留。需要时可以重新尝试。"
            }
            let description = SecCopyErrorMessageString(status, nil) as String? ?? "未知错误"
            return "无法访问 macOS Keychain（\(status)）：\(description)。请解锁登录钥匙串，并在系统提示中允许 Talis 访问后重试。"
        }
    }
}
