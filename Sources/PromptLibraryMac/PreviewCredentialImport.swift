import Foundation
import TalisCore

/// Explicit local setup copies provider keys without changing either app's
/// ordinary vault behavior. Values stay in this process and the Keychain.
enum PreviewCredentialImport {
    static func copy(providers: [String], from source: CredentialStorage, to target: CredentialStorage) throws -> Int {
        var copied = 0
        for provider in providers {
            let account = "provider.\(provider)"
            guard try target.read(account: account) == nil,
                  let value = try source.read(account: account) else { continue }
            try target.write(value, account: account)
            guard try target.read(account: account) == value else {
                throw CredentialVaultError.verificationFailed
            }
            copied += 1
        }
        return copied
    }
}
