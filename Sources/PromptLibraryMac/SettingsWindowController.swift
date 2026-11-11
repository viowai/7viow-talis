import AppKit

enum AppSettings {
    private static let modelKey = "ai.model"

    static var modelID: String {
        get {
            let saved = UserDefaults.standard.string(forKey: modelKey) ?? ""
            if !saved.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return saved }
            if let configured = AppConfigFile.modelID, !configured.isEmpty { return configured }
            return OpenAIClient.defaultModelID
        }
        set { UserDefaults.standard.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: modelKey) }
    }

    static func endpoint(for provider: AIProvider) -> URL {
        if let saved = UserDefaults.standard.string(forKey: "ai.endpoint.\(provider.id)"),
           let url = URL(string: saved),
           (url.scheme == "https" && url.host != nil)
            || (!provider.requiresAPIKey && url.scheme == "http" && ["127.0.0.1", "localhost", "::1"].contains(url.host ?? "")) {
            return url
        }
        return provider.endpoints[0].url
    }

    static func setEndpoint(_ url: URL, providerID: String) {
        UserDefaults.standard.set(url.absoluteString, forKey: "ai.endpoint.\(providerID)")
    }

    static var modelOption: OpenAIClient.ModelOption {
        let id = modelID
        if let provider = AIProvider.find(id) {
            return OpenAIClient.ModelOption(
                id: provider.id,
                title: provider.nameKey,
                model: provider.initialModel,
                baseURL: endpoint(for: provider)
            )
        }
        return OpenAIClient.modelOption(for: id)
    }
}

final class SettingsWindowController: NSWindowController, NSTextFieldDelegate {
    private let apiKeyField = NSSecureTextField()
    private let authModeControl = NSSegmentedControl(
        labels: ["API Key", L("订阅共享")],
        trackingMode: .selectOne,
        target: nil,
        action: nil
    )
    private let providerPopup = NSPopUpButton()
    private let languagePopup = NSPopUpButton()
    private let endpointPopup = NSPopUpButton()
    private let customURLField = NSTextField()
    private let keyLink = NSButton(title: L("获取 API Key ↗"), target: nil, action: nil)
    private let removeKeyButton = NSButton(title: L("移除 API Key…"), target: nil, action: nil)
    private let statusLabel = NSTextField(wrappingLabelWithString: "")
    private let saveButton = NSButton(title: L("保存服务设置"), target: nil, action: nil)
    private let keyPresence: @MainActor (String) async throws -> Bool
    private var keyStatusTask: Task<Void, Never>?
    private var subscriptionDiscoveryTask: Task<Void, Never>?
    private var form: NSGridView!
    private var visibleProviders: [AIProvider] = []
    private var savedKeyPresence: Bool?
    private var savedConfigurationSignature = ""

    private enum AuthenticationMethod: Int {
        case apiKey
        case subscription

        var requiresAPIKey: Bool { self == .apiKey }
    }

    init(keyPresence: @escaping @MainActor (String) async throws -> Bool = { try await KeychainStore.hasAPIKey(provider: $0) }) {
        self.keyPresence = keyPresence
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 680, height: 620),
                              styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.title = AppIdentity.current.displayName
        window.minSize = NSSize(width: 640, height: 520)
        AppTheme.configureWindow(window)
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        window.isRestorable = false
        super.init(window: window)
        configureWindow()
        AppLocalization.bind(window.contentView ?? NSView())
        refreshLocalization()
        AppLocalization.observe(self, selector: #selector(refreshLocalization))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show(relativeTo parent: NSWindow? = nil) {
        let preferredProviderID = AppSettings.modelID
        synchronizeSelectionWithSavedProvider()
        captureSavedConfiguration()
        updateSaveButtonState()
        NSApp.activate(ignoringOtherApps: true)
        NSApp.unhide(nil)
        if let window { AppTheme.center(window, on: parent?.screen ?? window.screen ?? NSScreen.main) }
        window?.deminiaturize(nil)
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
        if selectedProvider.requiresAPIKey {
            window?.makeFirstResponder(apiKeyField)
        } else {
            window?.makeFirstResponder(providerPopup)
            refreshLocalSubscriptions(preferredProviderID: preferredProviderID)
        }
    }

    private var selectedAuthenticationMethod: AuthenticationMethod {
        AuthenticationMethod(rawValue: authModeControl.selectedSegment) ?? .apiKey
    }

    private var selectedProvider: AIProvider {
        let index = providerPopup.indexOfSelectedItem
        guard visibleProviders.indices.contains(index) else { return visibleProviders.first ?? AIProvider.all[0] }
        return visibleProviders[index]
    }

    private func providers(for method: AuthenticationMethod) -> [AIProvider] {
        method.requiresAPIKey
            ? AIProvider.all.filter(\.requiresAPIKey)
            : AILocalSubscriptionCatalog.providers()
    }

    private func synchronizeSelectionWithSavedProvider(checkKeyStatus: Bool = true) {
        let provider = AIProvider.find(AppSettings.modelID) ?? AIProvider.all[0]
        authModeControl.selectedSegment = provider.requiresAPIKey
            ? AuthenticationMethod.apiKey.rawValue
            : AuthenticationMethod.subscription.rawValue
        reloadProviderChoices(selecting: provider.id, checkKeyStatus: checkKeyStatus)
    }

    @objc private func authModeChanged() {
        reloadProviderChoices(selecting: nil)
        updateSaveButtonState()
        if selectedAuthenticationMethod == .subscription {
            refreshLocalSubscriptions(preferredProviderID: AppSettings.modelID)
        }
    }

    private func refreshLocalSubscriptions(preferredProviderID: String) {
        subscriptionDiscoveryTask?.cancel()
        subscriptionDiscoveryTask = Task { @MainActor [weak self] in
            guard await AILocalSubscriptionCatalog.discover() != nil,
                  !Task.isCancelled, let self, self.selectedAuthenticationMethod == .subscription else { return }
            self.reloadProviderChoices(selecting: preferredProviderID)
            self.updateSaveButtonState()
        }
    }

    private func reloadProviderChoices(selecting providerID: String?, checkKeyStatus: Bool = true) {
        visibleProviders = providers(for: selectedAuthenticationMethod)
        providerPopup.removeAllItems()
        for provider in visibleProviders {
            providerPopup.addItem(withTitle: provider.name)
        }
        let selectedIndex = providerID.flatMap { id in
            visibleProviders.firstIndex { $0.id == id }
        } ?? (visibleProviders.isEmpty ? -1 : 0)
        if selectedIndex >= 0 {
            providerPopup.selectItem(at: selectedIndex)
        }
        providerPopup.synchronizeTitleAndSelectedItem()
        configureSelectedProvider(checkKeyStatus: checkKeyStatus)
    }

    private func configureWindow() {
        guard let content = window?.contentView else { return }
        let root = WindowContentView()
        root.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(root)

        let title = NSTextField(labelWithString: L("设置"))
        title.font = AppTheme.semibold(20)
        let generalTitle = sectionTitle(L("通用"))
        let serviceTitle = sectionTitle(L("AI 服务"))
        let languageHint = NSTextField(
            wrappingLabelWithString: L("语言修改立即生效；macOS 提供的系统菜单仍跟随系统语言。")
        )
        languageHint.font = AppTheme.regular(12)
        languageHint.textColor = AppTheme.secondaryTextColor
        let intro = NSTextField(
            wrappingLabelWithString: L("选择连接方式。API Key 按厂商存入 macOS 钥匙串；订阅用本机账号。")
        )
        intro.font = AppTheme.regular(13)
        intro.textColor = AppTheme.secondaryTextColor
        let privacy = NSTextField(
            wrappingLabelWithString: L("Talis 不显示已保存密钥，也不复制订阅登录凭据。")
        )
        privacy.font = AppTheme.regular(12)
        privacy.textColor = AppTheme.secondaryTextColor

        for popup in [providerPopup, endpointPopup, languagePopup] {
            popup.controlSize = .regular
            popup.font = AppTheme.regular(13)
            popup.target = self
        }
        for language in AppLanguage.allCases { languagePopup.addItem(withTitle: language.title) }
        languagePopup.selectItem(at: AppLanguage.allCases.firstIndex(of: AppLocalization.preference) ?? 0)
        languagePopup.action = #selector(languageChanged)
        languagePopup.setAccessibilityLabel(L("应用语言"))

        authModeControl.controlSize = .regular
        authModeControl.font = AppTheme.regular(13)
        authModeControl.segmentStyle = .rounded
        authModeControl.target = self
        authModeControl.action = #selector(authModeChanged)
        authModeControl.setAccessibilityLabel(L("认证方式"))
        providerPopup.setAccessibilityLabel(L("服务"))
        endpointPopup.setAccessibilityLabel(L("服务区域"))
        apiKeyField.setAccessibilityLabel("API Key")
        customURLField.setAccessibilityLabel(L("HTTPS 接口基础地址"))
        providerPopup.action = #selector(providerSelectionChanged)
        endpointPopup.action = #selector(endpointSelectionChanged)
        apiKeyField.placeholderString = L("输入新 API Key；留空保留已有密钥")
        apiKeyField.font = AppTheme.regular(13)
        apiKeyField.delegate = self
        customURLField.placeholderString = L("控制台提供的 HTTPS 基础地址")
        customURLField.font = AppTheme.regular(13)
        customURLField.delegate = self
        for field in [apiKeyField as NSTextField, customURLField] {
            AppTheme.styleTextField(field)
        }

        let generalForm = NSGridView(views: [
            [makeLabel(L("应用语言")), languagePopup]
        ])
        AppTheme.alignForm(generalForm, labelWidth: 100)

        let aiForm = NSGridView(views: [
            [makeLabel(L("认证方式")), authModeControl],
            [makeLabel(L("服务")), providerPopup],
            [makeLabel(L("服务区域")), endpointPopup],
            [makeLabel(L("接口地址")), customURLField],
            [makeLabel("API Key"), apiKeyField]
        ])
        AppTheme.alignForm(aiForm, labelWidth: 100)
        self.form = aiForm
        aiForm.row(at: 3).isHidden = true
        synchronizeSelectionWithSavedProvider(checkKeyStatus: false)

        keyLink.target = self
        keyLink.action = #selector(openKeyPage)
        keyLink.isBordered = false
        keyLink.alignment = .left
        keyLink.contentTintColor = AppTheme.accentTextColor
        keyLink.font = AppTheme.medium(13)
        AppTheme.styleButtonTitle(keyLink, primary: false)
        statusLabel.font = AppTheme.regular(13)
        statusLabel.textColor = AppTheme.secondaryTextColor
        statusLabel.setAccessibilityIdentifier("settings-status")
        statusLabel.setAccessibilityLabel(L("设置状态"))

        saveButton.target = self
        saveButton.action = #selector(saveSettings)
        AppTheme.styleButton(saveButton, primary: true)
        saveButton.keyEquivalent = "s"
        saveButton.keyEquivalentModifierMask = .command
        saveButton.isEnabled = false
        AppTheme.styleButtonTitle(saveButton, primary: true)

        removeKeyButton.target = self
        removeKeyButton.action = #selector(clearAPIKey)
        removeKeyButton.contentTintColor = .systemRed
        AppTheme.styleButton(removeKeyButton)
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let buttons = NSStackView(views: [removeKeyButton, spacer, saveButton])
        buttons.spacing = 8
        buttons.alignment = .centerY

        let keyInfo = NSStackView(views: [statusLabel, keyLink, privacy])
        keyInfo.orientation = .vertical
        keyInfo.alignment = .leading
        keyInfo.spacing = 8
        keyInfo.translatesAutoresizingMaskIntoConstraints = false
        for label in [privacy, statusLabel] {
            label.widthAnchor.constraint(equalTo: keyInfo.widthAnchor).isActive = true
            label.setContentCompressionResistancePriority(.required, for: .vertical)
        }

        let sectionSeparator = NSBox()
        sectionSeparator.boxType = .separator
        let footerSeparator = NSBox()
        footerSeparator.boxType = .separator
        footerSeparator.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView(views: [
            title, generalTitle, generalForm, languageHint, sectionSeparator,
            serviceTitle, intro, aiForm, keyInfo
        ])
        stack.orientation = .vertical
        stack.spacing = 14
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(stack)
        buttons.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(buttons)
        root.addSubview(footerSeparator)
        for view in [generalForm, languageHint, sectionSeparator, intro, aiForm] {
            view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            root.topAnchor.constraint(equalTo: content.topAnchor),
            root.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: AppTheme.Spacing.window),
            stack.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -AppTheme.Spacing.window),
            stack.topAnchor.constraint(equalTo: root.topAnchor, constant: AppTheme.Spacing.window),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: footerSeparator.topAnchor, constant: -16),
            keyInfo.leadingAnchor.constraint(equalTo: apiKeyField.leadingAnchor),
            keyInfo.trailingAnchor.constraint(equalTo: stack.trailingAnchor),
            buttons.leadingAnchor.constraint(equalTo: stack.leadingAnchor),
            buttons.trailingAnchor.constraint(equalTo: stack.trailingAnchor),
            buttons.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -AppTheme.Spacing.window),
            buttons.heightAnchor.constraint(equalToConstant: 32),
            footerSeparator.leadingAnchor.constraint(equalTo: stack.leadingAnchor),
            footerSeparator.trailingAnchor.constraint(equalTo: stack.trailingAnchor),
            footerSeparator.bottomAnchor.constraint(equalTo: buttons.topAnchor, constant: -12)
        ])
        captureSavedConfiguration()
        updateSaveButtonState()
    }

    private func sectionTitle(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = AppTheme.semibold(14)
        label.textColor = .labelColor
        return label
    }

    private func makeLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = AppTheme.regular(13)
        label.textColor = AppTheme.secondaryTextColor
        return label
    }

    @objc private func providerSelectionChanged() {
        configureSelectedProvider(checkKeyStatus: true)
    }

    private func configureSelectedProvider(checkKeyStatus: Bool) {
        keyStatusTask?.cancel()
        apiKeyField.stringValue = ""
        let provider = selectedProvider
        endpointPopup.removeAllItems()
        provider.endpoints.forEach { endpointPopup.addItem(withTitle: $0.name) }
        if provider.requiresAPIKey {
            endpointPopup.addItem(withTitle: L("自定义接口…"))
        }
        let configured = AppSettings.endpoint(for: provider)
        let selectedEndpointIndex = provider.endpoints.firstIndex { $0.url == configured }
            ?? (provider.requiresAPIKey ? provider.endpoints.count : 0)
        endpointPopup.selectItem(at: selectedEndpointIndex)
        customURLField.stringValue = configured.absoluteString
        updateEndpointRows()
        removeKeyButton.isEnabled = false
        form.row(at: 4).isHidden = !provider.requiresAPIKey
        apiKeyField.isEnabled = provider.requiresAPIKey
        keyLink.isHidden = !provider.requiresAPIKey
        removeKeyButton.isHidden = !provider.requiresAPIKey
        updateSaveButtonState()
        guard provider.requiresAPIKey else {
            statusLabel.textColor = AppTheme.secondaryTextColor
            statusLabel.stringValue = AppLocalization.format(
                "无需 API Key。Talis 会使用本机共享的 %@ 服务。",
                provider.name
            )
            return
        }
        statusLabel.textColor = AppTheme.secondaryTextColor
        statusLabel.stringValue = L("正在检查密钥状态…")
        savedKeyPresence = nil
        guard checkKeyStatus else { return }
        let presence = keyPresence
        keyStatusTask = Task { @MainActor [weak self] in
            do {
                let exists = try await presence(provider.id)
                guard !Task.isCancelled, let self, self.selectedProvider.id == provider.id else { return }
                self.removeKeyButton.isEnabled = exists
                self.savedKeyPresence = exists
                self.statusLabel.textColor = AppTheme.secondaryTextColor
                self.statusLabel.stringValue = exists
                    ? L("此厂商已保存 API Key。")
                    : L("此厂商尚未保存 API Key。")
            } catch {
                guard !Task.isCancelled, let self, self.selectedProvider.id == provider.id else { return }
                self.statusLabel.textColor = AppTheme.errorTextColor
                self.statusLabel.stringValue = error.localizedDescription
            }
        }
    }

    @objc private func endpointSelectionChanged() {
        updateEndpointRows()
        updateSaveButtonState()
    }

    @objc private func languageChanged() {
        let index = languagePopup.indexOfSelectedItem
        guard AppLanguage.allCases.indices.contains(index) else { return }
        AppLocalization.preference = AppLanguage.allCases[index]
    }

    func controlTextDidChange(_ notification: Notification) {
        guard notification.object as? NSTextField === apiKeyField
                || notification.object as? NSTextField === customURLField else { return }
        updateSaveButtonState()
    }

    private func updateEndpointRows() {
        let provider = selectedProvider
        let endpointIndex = endpointPopup.indexOfSelectedItem
        let custom = provider.requiresAPIKey && endpointIndex >= provider.endpoints.count
        form.row(at: 2).isHidden = provider.endpoints.count <= 1 && !custom
        form.row(at: 3).isHidden = !custom
    }

    private func currentEndpointSignature() -> String {
        let provider = selectedProvider
        let index = endpointPopup.indexOfSelectedItem
        if provider.endpoints.indices.contains(index) {
            return provider.endpoints[index].url.absoluteString
        }
        return customURLField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func currentConfigurationSignature() -> String {
        let newKeyState = apiKeyField.stringValue.isEmpty ? "existing" : "new"
        return [
            String(selectedAuthenticationMethod.rawValue),
            selectedProvider.id,
            currentEndpointSignature(),
            newKeyState
        ].joined(separator: "|")
    }

    private func captureSavedConfiguration() {
        savedConfigurationSignature = currentConfigurationSignature()
        updateSaveButtonState()
    }

    private func updateSaveButtonState() {
        guard !savedConfigurationSignature.isEmpty else { return }
        let dirty = currentConfigurationSignature() != savedConfigurationSignature
        saveButton.isEnabled = dirty
        AppTheme.styleButtonTitle(saveButton, primary: true)
    }

    @objc private func refreshLocalization() {
        guard let content = window?.contentView else { return }
        let endpoint = customURLField.stringValue
        let secret = apiKeyField.stringValue
        let endpointIndex = endpointPopup.indexOfSelectedItem
        statusLabel.stringValue = AppLocalization.redisplay(statusLabel.stringValue)
        AppLocalization.refresh(content)
        AppLocalization.refresh(languagePopup.menu)
        authModeControl.setLabel("API Key", forSegment: 0)
        authModeControl.setLabel(L("订阅共享"), forSegment: 1)
        let endpoints = selectedProvider.endpoints.map(\.name)
            + (selectedProvider.requiresAPIKey ? [L("自定义接口…")] : [])
        if endpointPopup.itemTitles != endpoints {
            endpointPopup.removeAllItems()
            endpointPopup.addItems(withTitles: endpoints)
        }
        if endpoints.indices.contains(endpointIndex) { endpointPopup.selectItem(at: endpointIndex) }
        endpointPopup.title = endpoints.indices.contains(endpointIndex) ? endpoints[endpointIndex] : ""
        AppTheme.alignForm(form, labelWidth: 92)
        window?.title = AppIdentity.current.displayName
        customURLField.stringValue = endpoint
        apiKeyField.stringValue = secret
        if let savedKeyPresence {
            statusLabel.stringValue = savedKeyPresence
                ? L("此厂商已保存 API Key。")
                : L("此厂商尚未保存 API Key。")
        }
        content.layoutSubtreeIfNeeded()
    }

    @objc private func openKeyPage() {
        let provider = selectedProvider
        var url = provider.keyURL
        if provider.id == "kimi", endpointPopup.indexOfSelectedItem == 1 { url = URL(string: "https://platform.moonshot.cn/console/api-keys")! }
        if provider.id == "minimax", endpointPopup.indexOfSelectedItem == 1 { url = URL(string: "https://platform.minimax.io/user-center/basic-information/interface-key")! }
        if provider.id == "zhipu", endpointPopup.indexOfSelectedItem == 1 { url = URL(string: "https://z.ai/manage-apikey/apikey-list")! }
        if provider.id == "alibaba", endpointPopup.indexOfSelectedItem == 1 { url = URL(string: "https://modelstudio.console.alibabacloud.com/")! }
        NSWorkspace.shared.open(url)
    }

    @objc private func saveSettings() {
        defer { AppTheme.announce(statusLabel.stringValue, from: statusLabel) }
        let provider = selectedProvider
        let index = endpointPopup.indexOfSelectedItem
        let endpoint: URL
        if index < provider.endpoints.count {
            endpoint = provider.endpoints[index].url
        } else {
            let value = customURLField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            guard let url = URL(string: value), url.scheme == "https", url.host != nil, url.user == nil,
                  url.password == nil, url.query == nil, url.fragment == nil else {
                statusLabel.textColor = AppTheme.errorTextColor
                statusLabel.stringValue = L("请填写控制台提供的完整 HTTPS 基础地址，不要包含 API Key。")
                return
            }
            endpoint = url
        }
        do {
            let newKey = apiKeyField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if provider.requiresAPIKey {
                try KeychainStore.migrateLegacyIfNeeded()
                if !newKey.isEmpty {
                    try KeychainStore.saveAPIKey(newKey, provider: provider.id)
                    keyStatusTask?.cancel()
                    removeKeyButton.isEnabled = true
                }
            }
            AppSettings.setEndpoint(endpoint, providerID: provider.id)
            AppSettings.modelID = provider.id
            apiKeyField.stringValue = ""
            Task { await ModelResolver.shared.invalidate(providerID: provider.id) }
            statusLabel.textColor = AppTheme.secondaryTextColor
            if provider.requiresAPIKey {
                statusLabel.stringValue = newKey.isEmpty ? L("厂商设置已保存。") : L("厂商设置与 API Key 已保存。")
            } else {
                statusLabel.stringValue = L("订阅设置已保存。")
            }
            captureSavedConfiguration()
        } catch {
            statusLabel.textColor = AppTheme.errorTextColor
            statusLabel.stringValue = error.localizedDescription
        }
    }

    @objc private func clearAPIKey() {
        let provider = selectedProvider
        let alert = NSAlert()
        alert.messageText = AppLocalization.format("移除 %@ 的 API Key？", provider.name)
        alert.informativeText = L("移除后，此厂商的 AI 功能将无法使用。其他厂商的密钥不变，需要时可重新填写。")
        alert.addButton(withTitle: L("取消"))
        alert.addButton(withTitle: L("移除"))
        alert.buttons.last?.contentTintColor = .systemRed
        guard alert.runModal() == .alertSecondButtonReturn else { return }
        do {
            try KeychainStore.deleteAPIKey(provider: selectedProvider.id)
            Task { await ModelResolver.shared.invalidate(providerID: selectedProvider.id) }
            providerSelectionChanged()
            statusLabel.stringValue = L("已移除此厂商的密钥。")
        } catch {
            statusLabel.textColor = AppTheme.errorTextColor
            statusLabel.stringValue = error.localizedDescription
        }
    }
}
