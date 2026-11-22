import AppKit

final class TemplateManagerWindowController: NSWindowController, NSTextFieldDelegate, NSSearchFieldDelegate, NSTextViewDelegate, NSWindowDelegate {
    private let searchField = TalisSearchField()
    private let listScrollView = NSScrollView()
    private let listStack = TopAlignedStackView()
    private let emptyLabel = NSTextField(wrappingLabelWithString: "")
    private let nameField = NSTextField()
    private let detailField = NSTextField()
    private let bodyScrollView = HistoryScrollView()
    private let bodyTextView = NSTextView()
    private var formGrid: NSGridView?
    private let statusLabel = NSTextField(labelWithString: "")
    private let saveButton = NSButton(title: L("保存"), target: nil, action: nil)
    private let deleteButton = NSButton(title: L("删除"), target: nil, action: nil)
    private var templates: [UserPromptTemplate] = []
    private var rowViews: [CommandRowView] = []
    private var selectedTemplateID: UUID?
    private var loadedDraft = TemplateDraft(title: "", detail: "", body: "")
    private var lastSearch = ""
    private let discardDecision: (() -> Bool)?
    private let templatesProvider: () -> [UserPromptTemplate]
    private let addTemplate: (TemplateDraft) throws -> UserPromptTemplate
    private let updateTemplate: (UserPromptTemplate) throws -> Void
    private let removeTemplate: (UUID) throws -> Void
    private var hoverResetObserver: NSObjectProtocol?
    var onChange: (() -> Void)?

    var hasUnsavedChanges: Bool { currentDraft != loadedDraft }
    private var currentDraft: TemplateDraft {
        TemplateDraft(title: nameField.stringValue, detail: detailField.stringValue, body: bodyTextView.string)
    }

    init(discardDecision: (() -> Bool)? = nil,
         templatesProvider: @escaping () -> [UserPromptTemplate] = UserTemplateStore.all,
         addTemplate: @escaping (TemplateDraft) throws -> UserPromptTemplate = UserTemplateStore.add,
         updateTemplate: @escaping (UserPromptTemplate) throws -> Void = UserTemplateStore.update,
         removeTemplate: @escaping (UUID) throws -> Void = UserTemplateStore.delete) {
        self.discardDecision = discardDecision
        self.templatesProvider = templatesProvider
        self.addTemplate = addTemplate
        self.updateTemplate = updateTemplate
        self.removeTemplate = removeTemplate
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 960, height: 640),
                              styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.title = AppIdentity.current.displayName
        window.minSize = NSSize(width: 820, height: 520)
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        window.isRestorable = false
        AppTheme.configureWindow(window)
        super.init(window: window)
        window.delegate = self
        configureUI()
        reload()
        AppLocalization.observe(self, selector: #selector(refreshLocalization))
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit {
        if let hoverResetObserver {
            NotificationCenter.default.removeObserver(hoverResetObserver)
        }
    }

    func show(relativeTo parent: NSWindow? = nil) {
        if window?.isVisible != true && !hasUnsavedChanges { reload() }
        CommandRowView.clearAllHover()
        NSApp.activate(ignoringOtherApps: true)
        if let window { AppTheme.center(window, on: parent?.screen ?? window.screen ?? NSScreen.main) }
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(searchField)
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard mayDiscardEdits() else { return false }
        CommandRowView.clearAllHover()
        loadedDraft = currentDraft
        return true
    }
    func windowDidResignKey(_ notification: Notification) {
        CommandRowView.clearAllHover()
    }

    private func configureUI() {
        guard let contentView = window?.contentView else { return }
        let root = WindowContentView()
        root.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(root)
        let title = NSTextField(labelWithString: L("我的"))
        title.font = AppTheme.semibold(20)
        searchField.preparePlaceholder(L("搜索"))
        searchField.setAccessibilityLabel(L("搜索模板"))
        searchField.delegate = self
        searchField.sendsSearchStringImmediately = true
        searchField.target = self
        searchField.action = #selector(searchChanged)
        listStack.orientation = .vertical
        listStack.spacing = 4
        listStack.alignment = .leading
        listStack.edgeInsets = NSEdgeInsets(top: 6, left: 6, bottom: 6, right: 6)
        listStack.translatesAutoresizingMaskIntoConstraints = false
        AppTheme.configureContentScrollView(listScrollView)
        listScrollView.borderType = .bezelBorder
        listScrollView.hasVerticalScroller = true
        listScrollView.hasHorizontalScroller = false
        listScrollView.autohidesScrollers = true
        listScrollView.documentView = listStack
        listScrollView.contentView.postsBoundsChangedNotifications = true
        hoverResetObserver = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: listScrollView.contentView,
            queue: .main
        ) { _ in
            CommandRowView.clearAllHover()
        }
        emptyLabel.font = AppTheme.regular(13)
        emptyLabel.textColor = AppTheme.secondaryTextColor
        emptyLabel.isHidden = true
        let newButton = NSButton(title: L("新增"), target: self, action: #selector(newTemplate))
        AppTheme.styleButton(newButton)
        deleteButton.target = self
        deleteButton.action = #selector(deleteTemplate)
        AppTheme.styleButton(deleteButton)
        deleteButton.contentTintColor = .systemRed
        AppTheme.styleButtonTitle(deleteButton, primary: false)
        saveButton.target = self
        saveButton.action = #selector(saveTemplate)
        saveButton.keyEquivalent = "s"
        saveButton.keyEquivalentModifierMask = .command
        AppTheme.styleButton(saveButton, primary: true)
        for (field, label) in [(nameField, L("名称")), (detailField, L("说明"))] {
            AppTheme.styleTextField(field)
            field.placeholderString = label
            field.setAccessibilityLabel(field === nameField ? L("模板名称") : L("模板说明"))
            field.delegate = self
            field.setContentHuggingPriority(.defaultLow, for: .horizontal)
            field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        }
        bodyScrollView.borderType = .bezelBorder
        bodyScrollView.hasVerticalScroller = true
        bodyScrollView.hasHorizontalScroller = false
        bodyScrollView.autohidesScrollers = true
        AppTheme.configureContentScrollView(bodyScrollView)
        bodyTextView.configureHistoryWrapping()
        bodyTextView.font = AppTheme.regular(14)
        bodyTextView.frame = NSRect(x: 0, y: 0, width: 560, height: 400)
        bodyTextView.autoresizingMask = [.width]
        bodyTextView.drawsBackground = false
        AppTheme.styleEditor(bodyTextView)
        bodyTextView.textColor = .labelColor
        bodyTextView.isRichText = false
        bodyTextView.allowsUndo = true
        bodyTextView.isAutomaticQuoteSubstitutionEnabled = false
        bodyTextView.isAutomaticDashSubstitutionEnabled = false
        bodyTextView.textContainerInset = NSSize(width: 12, height: 12)
        bodyTextView.isVerticallyResizable = true
        bodyTextView.isHorizontallyResizable = false
        bodyTextView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        bodyTextView.textContainer?.widthTracksTextView = true
        bodyTextView.textContainer?.containerSize = NSSize(width: 560, height: CGFloat.greatestFiniteMagnitude)
        bodyTextView.delegate = self
        bodyTextView.setAccessibilityLabel(L("模板正文"))
        bodyScrollView.documentView = bodyTextView
        statusLabel.font = AppTheme.regular(12)
        statusLabel.textColor = AppTheme.secondaryTextColor
        statusLabel.lineBreakMode = .byTruncatingTail
        let form = NSGridView(views: [[makeLabel(L("名称")), nameField], [makeLabel(L("说明")), detailField]])
        AppTheme.alignForm(form, labelWidth: AppLocalization.isEnglish ? 72 : 40, spacing: 12)
        formGrid = form
        let bodyTitle = NSTextField(labelWithString: L("正文"))
        bodyTitle.font = AppTheme.semibold(14)
        let left = NSStackView(views: [title, searchField, listScrollView, emptyLabel])
        let right = NSStackView(views: [form, bodyTitle, bodyScrollView, statusLabel])
        for stack in [left, right] {
            stack.orientation = .vertical
            stack.alignment = .leading
            stack.spacing = 12
            stack.detachesHiddenViews = true
            stack.translatesAutoresizingMaskIntoConstraints = false
            root.addSubview(stack)
        }
        let footerSeparator = NSBox()
        footerSeparator.boxType = .separator
        footerSeparator.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(footerSeparator)
        let footerSpacer = NSView()
        footerSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let footer = NSStackView(views: [newButton, footerSpacer, deleteButton, saveButton])
        footer.orientation = .horizontal
        footer.spacing = 8
        footer.alignment = .centerY
        footer.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(footer)
        for view in [searchField, listScrollView, emptyLabel] { view.widthAnchor.constraint(equalTo: left.widthAnchor).isActive = true }
        for view in [form, bodyScrollView, statusLabel] { view.widthAnchor.constraint(equalTo: right.widthAnchor).isActive = true }
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: contentView.leadingAnchor), root.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            root.topAnchor.constraint(equalTo: contentView.topAnchor), root.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            left.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 20), left.widthAnchor.constraint(equalToConstant: 240),
            left.topAnchor.constraint(equalTo: root.topAnchor, constant: 20), left.bottomAnchor.constraint(equalTo: footerSeparator.topAnchor, constant: -16),
            right.leadingAnchor.constraint(equalTo: left.trailingAnchor, constant: 20), right.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -20),
            right.topAnchor.constraint(equalTo: root.topAnchor, constant: 20), right.bottomAnchor.constraint(equalTo: footerSeparator.topAnchor, constant: -16),
            listScrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 180), listStack.widthAnchor.constraint(equalTo: listScrollView.contentView.widthAnchor),
            bodyScrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 160),
            searchField.heightAnchor.constraint(equalToConstant: 32), statusLabel.heightAnchor.constraint(equalToConstant: 18),
            footerSeparator.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 20),
            footerSeparator.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -20),
            footerSeparator.bottomAnchor.constraint(equalTo: footer.topAnchor, constant: -12),
            footer.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 20),
            footer.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -20),
            footer.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -20),
            footer.heightAnchor.constraint(equalToConstant: 32),
            newButton.widthAnchor.constraint(equalToConstant: 128)
        ])
    }
    private func makeLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = AppTheme.medium(13)
        label.textColor = AppTheme.secondaryTextColor
        return label
    }
    @objc private func refreshLocalization() {
        guard let content = window?.contentView else { return }
        AppLocalization.refresh(content)
        formGrid?.column(at: 0).width = AppLocalization.isEnglish ? 72 : 40
        rebuildRows()
        content.layoutSubtreeIfNeeded()
    }
    private func reload() {
        let query = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        templates = templatesProvider().filter { item in
            query.isEmpty || [item.title, item.detail, item.body].contains { $0.localizedStandardContains(query) }
        }
        rebuildRows()
        if let id = selectedTemplateID, let selected = templates.first(where: { $0.id == id }) { load(selected) }
        else if let first = templates.first { load(first) }
        else { selectedTemplateID = nil; clearEditor() }
        refreshSelection()
        updateDirtyState()
    }
    private func rebuildRows() {
        CommandRowView.clearAllHover()
        for row in rowViews { listStack.removeArrangedSubview(row); row.removeFromSuperview() }
        rowViews = []
        emptyLabel.isHidden = !templates.isEmpty
        emptyLabel.stringValue = searchField.stringValue.isEmpty ? L("暂无模板") : L("无匹配")
        for template in templates {
            let row = CommandRowView()
            row.configure(with: template.libraryItem, isSelected: template.id == selectedTemplateID, allowsApply: false)
            row.onChoose = { [weak self] in
                guard let self, self.selectedTemplateID != template.id, self.mayDiscardEdits() else { return }
                self.load(template)
                self.refreshSelection()
            }
            listStack.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: listStack.widthAnchor, constant: -12).isActive = true
            rowViews.append(row)
        }
        AppLocalization.refresh(listStack)
    }
    private func refreshSelection() {
        for (index, row) in rowViews.enumerated() { row.setSelected(templates.indices.contains(index) && templates[index].id == selectedTemplateID) }
        deleteButton.isEnabled = selectedTemplateID != nil
    }
    private func load(_ template: UserPromptTemplate) {
        selectedTemplateID = template.id
        nameField.stringValue = template.title
        detailField.stringValue = template.detail
        bodyTextView.string = template.body
        bodyTextView.scrollRangeToVisible(NSRange(location: 0, length: 0))
        loadedDraft = currentDraft
        statusLabel.stringValue = ""
        statusLabel.setAccessibilityHelp(nil)
        updateDirtyState()
    }
    private func clearEditor() {
        nameField.stringValue = ""
        detailField.stringValue = ""
        bodyTextView.string = ""
        loadedDraft = currentDraft
        statusLabel.stringValue = ""
        statusLabel.setAccessibilityHelp(nil)
        updateDirtyState()
    }
    private func updateDirtyState() {
        window?.isDocumentEdited = hasUnsavedChanges
        saveButton.isEnabled = !nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !bodyTextView.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (hasUnsavedChanges || selectedTemplateID == nil)
        AppTheme.styleButtonTitle(saveButton, primary: true)
        if hasUnsavedChanges { statusLabel.textColor = AppTheme.secondaryTextColor; statusLabel.stringValue = L("未保存") }
    }
    func confirmDiscardIfNeeded() -> Bool { mayDiscardEdits() }
    private func mayDiscardEdits() -> Bool {
        guard hasUnsavedChanges else { return true }
        if let discardDecision { return discardDecision() }
        let alert = NSAlert()
        alert.messageText = L("放弃未保存的修改？")
        alert.informativeText = L("当前模板还没有保存。可以继续编辑，或放弃这次修改。")
        alert.addButton(withTitle: L("继续编辑"))
        alert.addButton(withTitle: L("放弃修改"))
        alert.buttons.last?.contentTintColor = .systemRed
        return alert.runModal() == .alertSecondButtonReturn
    }
    @objc private func searchChanged() {
        guard searchField.stringValue != lastSearch else { return }
        guard mayDiscardEdits() else { searchField.stringValue = lastSearch; return }
        lastSearch = searchField.stringValue
        reload()
    }
    func controlTextDidChange(_ notification: Notification) {
        if notification.object as? NSSearchField === searchField { searchChanged() }
        else { updateDirtyState() }
    }
    func textDidChange(_ notification: Notification) { updateDirtyState() }
    @objc private func newTemplate() {
        guard mayDiscardEdits() else { return }
        selectedTemplateID = nil
        nameField.stringValue = L("未命名")
        detailField.stringValue = ""
        bodyTextView.string = AppLocalization.newTemplateBody
        loadedDraft = currentDraft
        bodyTextView.scrollRangeToVisible(NSRange(location: 0, length: 0))
        refreshSelection()
        updateDirtyState()
        statusLabel.textColor = AppTheme.secondaryTextColor
        statusLabel.stringValue = ""
        statusLabel.setAccessibilityHelp(nil)
        window?.makeFirstResponder(nameField)
    }
    @objc private func saveTemplate() {
        let title = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = bodyTextView.string
        guard !title.isEmpty, !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { statusLabel.textColor = AppTheme.errorTextColor; statusLabel.stringValue = L("请填写模板名称和内容。"); return }
        do {
            if let id = selectedTemplateID, var existing = templatesProvider().first(where: { $0.id == id }) {
                existing.title = title; existing.detail = detailField.stringValue; existing.body = body
                try updateTemplate(existing)
            } else {
                selectedTemplateID = try addTemplate(TemplateDraft(title: title, detail: detailField.stringValue, body: body)).id
            }
            loadedDraft = currentDraft
            searchField.stringValue = ""
            lastSearch = ""
            reload()
            statusLabel.textColor = AppTheme.secondaryTextColor
            statusLabel.stringValue = L("已保存")
            AppTheme.announce(L("模板已保存"), from: statusLabel)
            onChange?()
        } catch { statusLabel.textColor = AppTheme.errorTextColor; statusLabel.stringValue = error.localizedDescription }
    }
    @objc private func deleteTemplate() {
        guard let id = selectedTemplateID, let template = templates.first(where: { $0.id == id }) else { return }
        let alert = NSAlert()
        alert.messageText = L("删除模板？")
        alert.informativeText = AppLocalization.format("将删除「%@」，此操作不可撤销。", template.title) + (hasUnsavedChanges ? L("未保存的修改也会丢失。") : "")
        alert.addButton(withTitle: L("取消"))
        alert.addButton(withTitle: L("删除"))
        alert.buttons.last?.contentTintColor = .systemRed
        guard alert.runModal() == .alertSecondButtonReturn else { return }
        do {
            try removeTemplate(id)
            selectedTemplateID = nil
            reload()
            statusLabel.stringValue = L("已删除")
            onChange?()
        } catch { statusLabel.textColor = AppTheme.errorTextColor; statusLabel.stringValue = error.localizedDescription }
    }
}
