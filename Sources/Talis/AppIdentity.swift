import Foundation
import Carbon

/// A separate local preview keeps the existing Talis installation's state intact.
struct AppIdentity {
    static let current = AppIdentity(bundleIdentifier: Bundle.main.bundleIdentifier)

    // Existing preferences and Keychain items have storage names independent of the app name.
    let preferenceDomain: String?
    static let preferences = current.preferenceDomain.flatMap { UserDefaults(suiteName: $0) } ?? .standard

    let isPreview: Bool

    init(bundleIdentifier: String?) {
        let bundleID = "ai.viow.talis"
        let storageID = "local.prompt-library.overlay"
        if let identifier = bundleIdentifier,
           identifier == bundleID || identifier.hasPrefix(bundleID + ".") {
            preferenceDomain = storageID + identifier.dropFirst(bundleID.count)
        } else {
            preferenceDomain = nil
        }
        isPreview = bundleIdentifier == bundleID + ".preview"
    }

    var displayName: String { "Talis" }
    // Display names can change without switching the user to a different data store.
    var dataDirectoryName: String { isPreview ? "Talis Preview" : "Talis" }
    var keychainService: String {
        isPreview ? "local.prompt-library.overlay.preview.openai" : "local.prompt-library.overlay.openai"
    }
    var hotKeyModifiers: UInt32 {
        isPreview ? UInt32(optionKey | shiftKey) : UInt32(optionKey)
    }
    var shortcutLabel: String { isPreview ? "⌥⇧Space" : "⌥Space" }
}
