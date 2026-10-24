import Foundation
import Carbon

/// A separate local preview keeps the existing Talis installation's state intact.
struct AppIdentity {
    static let current = AppIdentity(bundleIdentifier: Bundle.main.bundleIdentifier)

    let isPreview: Bool

    init(bundleIdentifier: String?) {
        isPreview = bundleIdentifier == "local.prompt-library.overlay.preview"
    }

    var displayName: String { isPreview ? "Talis Preview" : "Talis" }
    var dataDirectoryName: String { displayName }
    var keychainService: String {
        isPreview ? "local.prompt-library.overlay.preview.openai" : "local.prompt-library.overlay.openai"
    }
    var hotKeyModifiers: UInt32 {
        isPreview ? UInt32(optionKey | shiftKey) : UInt32(optionKey)
    }
    var shortcutLabel: String { isPreview ? "⌥⇧Space" : "⌥Space" }
}
