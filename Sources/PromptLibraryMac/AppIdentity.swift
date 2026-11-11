import Foundation
import Carbon

/// A separate local preview keeps the existing Talis installation's state intact.
struct AppIdentity {
    static let current = AppIdentity(bundleIdentifier: Bundle.main.bundleIdentifier)

    let isPreview: Bool
    let isV1Preview: Bool

    init(bundleIdentifier: String?) {
        isV1Preview = bundleIdentifier == "local.prompt-library.overlay.v1-preview"
        isPreview = isV1Preview || bundleIdentifier == "local.prompt-library.overlay.preview"
    }

    var displayName: String { "Talis" }
    // Display names can change without switching the user to a different data store.
    var dataDirectoryName: String { isV1Preview ? "Talis v1 Preview" : isPreview ? "Talis Preview" : "Talis" }
    var keychainService: String {
        isV1Preview ? "local.prompt-library.overlay.v1-preview.openai" :
            isPreview ? "local.prompt-library.overlay.preview.openai" : "local.prompt-library.overlay.openai"
    }
    var hotKeyModifiers: UInt32 {
        isPreview ? UInt32(optionKey | shiftKey) : UInt32(optionKey)
    }
    var shortcutLabel: String { isPreview ? "⌥⇧Space" : "⌥Space" }
}
