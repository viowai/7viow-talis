import AppKit

enum AppSettings {
    private static let modelKey = "ai.model"

    static var modelID: String {
        get {
            let saved = UserDefaults.standard.string(forKey: modelKey) ?? ""
            if !saved.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return saved
            }
            if let configModelID = AppConfigFile.modelID, !configModelID.isEmpty {
                return configModelID
            }
            return OpenAIClient.defaultModelID
        }
        set {
            UserDefaults.standard.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: modelKey)
        }
    }

    static var modelOption: OpenAIClient.ModelOption {
        OpenAIClient.modelOption(for: modelID)
    }
}

final class SettingsWindowController: NSWindowController {
    private let apiKeyField = NSSecureTextField()
    private let modelPopup = NSPopUpButton()
    private let statusLabel = NSTextField(wrappingLabelWithString: "")

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "\(AppIdentity.current.displayName) · AI 模型与 API Key"
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        super.init(window: window)
        configureWindow()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        refresh()
        NSApp.activate(ignoringOtherApps: true)
        NSApp.unhide(nil)
        window?.center()
        window?.deminiaturize(nil)
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
        window?.makeFirstResponder(apiKeyField)
    }

    private func configureWindow() {
        guard let contentView = window?.contentView else { return }

        let rootView = NSVisualEffectView()
        rootView.material = .underWindowBackground
        rootView.blendingMode = .behindWindow
        rootView.state = .active
        rootView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(rootView)

        let title = NSTextField(labelWithString: "AI 模型与 API Key")
        title.font = AppTheme.semibold(18)

        let intro = NSTextField(wrappingLabelWithString: "每个供应商的 API Key 分别保存在 macOS Keychain。已有密钥不回显；留空保存会保留该供应商的密钥。")
        intro.font = AppTheme.regular(12)
        intro.textColor = .secondaryLabelColor

        apiKeyField.placeholderString = "输入新的 API Key；留空保留已有密钥"
        apiKeyField.font = AppTheme.regular(13)
        apiKeyField.controlSize = .regular

        modelPopup.controlSize = .regular
        modelPopup.font = AppTheme.medium(13)
        modelPopup.target = self
        modelPopup.action = #selector(modelSelectionChanged)
        modelPopup.removeAllItems()
        OpenAIClient.modelOptions.forEach { option in
            modelPopup.addItem(withTitle: option.title)
            modelPopup.lastItem?.representedObject = option.id
        }

        statusLabel.font = AppTheme.regular(12)
        statusLabel.textColor = .secondaryLabelColor

        let saveButton = NSButton(title: "保存修改", target: self, action: #selector(saveSettings))
        saveButton.bezelStyle = .rounded
        saveButton.font = AppTheme.medium(12)

        let clearButton = NSButton(title: "移除 API Key", target: self, action: #selector(clearAPIKey))
        clearButton.bezelStyle = .rounded
        clearButton.font = AppTheme.medium(12)

        let buttonStack = NSStackView(views: [clearButton, saveButton])
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 8
        buttonStack.alignment = .centerY

        let form = NSGridView(views: [
            [makeLabel("API Key"), apiKeyField],
            [makeLabel("模型"), modelPopup]
        ])
        form.column(at: 0).xPlacement = .trailing
        form.column(at: 1).width = 360
        form.rowSpacing = 10
        form.columnSpacing = 10

        let stack = NSStackView(views: [title, intro, form, statusLabel, buttonStack])
        stack.orientation = .vertical
        stack.spacing = 14
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        rootView.addSubview(stack)

        NSLayoutConstraint.activate([
            rootView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            rootView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            rootView.topAnchor.constraint(equalTo: contentView.topAnchor),
            rootView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            stack.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: rootView.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: rootView.topAnchor, constant: 24),
            intro.widthAnchor.constraint(equalToConstant: 452),
            statusLabel.widthAnchor.constraint(equalToConstant: 452)
        ])
    }

    private func makeLabel(_ value: String) -> NSTextField {
        let label = NSTextField(labelWithString: value)
        label.font = AppTheme.medium(12)
        label.textColor = .secondaryLabelColor
        return label
    }

    private func refresh() {
        selectCurrentModel()
        modelSelectionChanged()
    }

    private var selectedProvider: String {
        (modelPopup.selectedItem?.representedObject as? String) ?? OpenAIClient.defaultModelID
    }

    @objc private func modelSelectionChanged() {
        apiKeyField.stringValue = ""
        do {
            let exists = try KeychainStore.readAPIKey(provider: selectedProvider) != nil
            statusLabel.textColor = .secondaryLabelColor
            statusLabel.stringValue = exists ? "此供应商已有密钥。输入新密钥可替换，留空则保留。" : "此供应商尚未配置密钥。"
        } catch {
            statusLabel.textColor = .systemRed
            statusLabel.stringValue = error.localizedDescription
        }
    }

    private func selectCurrentModel() {
        let currentID = AppSettings.modelID
        let index = OpenAIClient.modelOptions.firstIndex { $0.id == currentID } ?? 0
        modelPopup.selectItem(at: index)
    }

    @objc private func saveSettings() {
        do {
            let selectedID = selectedProvider
            try KeychainStore.migrateLegacyIfNeeded()
            let trimmedAPIKey = apiKeyField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedAPIKey.isEmpty {
                try KeychainStore.saveAPIKey(trimmedAPIKey, provider: selectedID)
            }
            AppSettings.modelID = selectedID
            apiKeyField.stringValue = ""
            selectCurrentModel()
            statusLabel.textColor = .secondaryLabelColor
            statusLabel.stringValue = trimmedAPIKey.isEmpty
                ? "模型设置已保存。"
                : "API Key 与模型设置已保存。"
        } catch {
            statusLabel.textColor = .systemRed
            statusLabel.stringValue = error.localizedDescription
        }
    }

    @objc private func clearAPIKey() {
        do {
            try KeychainStore.deleteAPIKey(provider: selectedProvider)
            modelSelectionChanged()
            statusLabel.textColor = .secondaryLabelColor
            statusLabel.stringValue = "已移除此供应商的密钥及旧恢复项，其他供应商保持不变。"
        } catch {
            statusLabel.textColor = .systemRed
            statusLabel.stringValue = error.localizedDescription
        }
    }
}
