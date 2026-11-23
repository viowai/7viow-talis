import Foundation
import Carbon

let standard = AppIdentity(bundleIdentifier: "ai.viow.talis")
let preview = AppIdentity(bundleIdentifier: "ai.viow.talis.preview")
let commandLine = AppIdentity(bundleIdentifier: nil)

precondition(standard.preferenceDomain == "local.prompt-library.overlay")
precondition(preview.preferenceDomain == "local.prompt-library.overlay.preview")
precondition(commandLine.preferenceDomain == nil)
precondition(standard.dataDirectoryName == "Talis")
precondition(standard.keychainService == "local.prompt-library.overlay.openai")
precondition(standard.hotKeyModifiers == UInt32(optionKey))
precondition(commandLine.dataDirectoryName == standard.dataDirectoryName)
precondition(preview.dataDirectoryName != standard.dataDirectoryName)
precondition(preview.keychainService != standard.keychainService)
precondition(preview.hotKeyModifiers == UInt32(optionKey | shiftKey))
precondition(preview.shortcutLabel == "⌥⇧Space")
precondition(preview.displayName == "Talis")
precondition(preview.dataDirectoryName == "Talis Preview")
precondition(!standard.isPreview)
print("PASS: preview storage, keychain, identity and shortcut remain separate; standard identity preserved")
