import AppKit

final class TemplateManagerRowView: NSControl {
    private let titleLabel = NSTextField(labelWithString: "")
    private let detailLabel = NSTextField(labelWithString: "")
    private let badgeLabel = NSTextField(labelWithString: "我的")
    var onSelect: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureLayout()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureLayout()
    }

    func configure(with template: UserPromptTemplate, selected: Bool) {
        AppTheme.applyTextStyle(to: titleLabel, text: template.title, size: 12, weight: .medium)
        AppTheme.applyTextStyle(to: detailLabel, text: template.detail.isEmpty ? "我的专属 Prompt 模板" : template.detail, size: 11, color: .secondaryLabelColor)
        setSelected(selected)
        toolTip = template.title
    }

    func setSelected(_ selected: Bool) {
        layer?.backgroundColor = selected
            ? NSColor.controlAccentColor.withAlphaComponent(0.22).cgColor
            : NSColor.clear.cgColor
        layer?.borderColor = selected
            ? NSColor.controlAccentColor.withAlphaComponent(0.3).cgColor
            : NSColor.clear.cgColor
    }

    override func mouseDown(with event: NSEvent) {
        onSelect?()
    }

    private func configureLayout() {
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.borderWidth = 1

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.drawsBackground = false

        detailLabel.translatesAutoresizingMaskIntoConstraints = false
        detailLabel.lineBreakMode = .byTruncatingTail
        detailLabel.drawsBackground = false

        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        badgeLabel.font = AppTheme.medium(10)
        badgeLabel.textColor = .secondaryLabelColor
        badgeLabel.alignment = .right
        badgeLabel.drawsBackground = false

        addSubview(titleLabel)
        addSubview(detailLabel)
        addSubview(badgeLabel)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 52),

            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(equalTo: badgeLabel.leadingAnchor, constant: -8),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            titleLabel.heightAnchor.constraint(equalToConstant: 17),

            detailLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            detailLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            detailLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 3),
            detailLabel.heightAnchor.constraint(equalToConstant: 15),

            badgeLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            badgeLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            badgeLabel.widthAnchor.constraint(equalToConstant: 38)
        ])
    }
}

final class TemplateManagerWindowController: NSWindowController, NSTextFieldDelegate, NSSearchFieldDelegate {
    private let searchField = NSSearchField()
    private let listScrollView = NSScrollView()
    private let listStack = NSStackView()
    private let emptyLabel = NSTextField(labelWithString: "暂无模板")
    private let nameField = NSTextField()
    private let detailField = NSTextField()
    private let bodyScrollView = NSScrollView()
    private let bodyTextView = NSTextView()
    private let statusLabel = NSTextField(labelWithString: "")

    private var templates: [UserPromptTemplate] = []
    private var rowViews: [TemplateManagerRowView] = []
    private var selectedTemplateID: UUID?
    var onChange: (() -> Void)?

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 860, height: 560),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "我的模板库"
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        super.init(window: window)
        configureUI()
        reload()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        reload()
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
        window?.makeFirstResponder(searchField)
    }

    private func configureUI() {
        guard let contentView = window?.contentView else { return }

        let rootView = NSVisualEffectView()
        rootView.material = .underWindowBackground
        rootView.blendingMode = .behindWindow
        rootView.state = .active
        rootView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(rootView)

        let titleLabel = NSTextField(labelWithString: "我的模板库")
        titleLabel.font = AppTheme.semibold(18)

        searchField.placeholderString = "搜索名称、说明或模板内容"
        searchField.delegate = self
        searchField.target = self
        searchField.action = #selector(searchChanged)
        searchField.translatesAutoresizingMaskIntoConstraints = false

        listStack.orientation = .vertical
        listStack.spacing = 4
        listStack.alignment = .leading
        listStack.edgeInsets = NSEdgeInsets(top: 6, left: 6, bottom: 6, right: 6)
        listStack.translatesAutoresizingMaskIntoConstraints = false

        listScrollView.borderType = .bezelBorder
        listScrollView.hasVerticalScroller = true
        listScrollView.documentView = listStack
        listScrollView.translatesAutoresizingMaskIntoConstraints = false

        emptyLabel.font = AppTheme.regular(12)
        emptyLabel.textColor = .secondaryLabelColor
        emptyLabel.isHidden = true

        let newButton = NSButton(title: "新增模板", target: self, action: #selector(newTemplate))
        newButton.bezelStyle = .rounded
        newButton.font = AppTheme.medium(12)

        let deleteButton = NSButton(title: "删除模板", target: self, action: #selector(deleteTemplate))
        deleteButton.bezelStyle = .rounded
        deleteButton.font = AppTheme.medium(12)

        let saveButton = NSButton(title: "保存修改", target: self, action: #selector(saveTemplate))
        saveButton.bezelStyle = .rounded
        saveButton.font = AppTheme.medium(12)

        let leftButtonStack = NSStackView(views: [newButton, deleteButton])
        leftButtonStack.orientation = .horizontal
        leftButtonStack.spacing = 8
        leftButtonStack.alignment = .centerY

        nameField.placeholderString = "模板名称"
        nameField.font = AppTheme.regular(13)

        detailField.placeholderString = "模板说明"
        detailField.font = AppTheme.regular(13)

        bodyScrollView.borderType = .bezelBorder
        bodyScrollView.hasVerticalScroller = true
        bodyScrollView.drawsBackground = true
        bodyScrollView.backgroundColor = NSColor.textBackgroundColor.withAlphaComponent(0.82)
        bodyScrollView.translatesAutoresizingMaskIntoConstraints = false

        bodyTextView.font = AppTheme.regular(13)
        bodyTextView.frame = NSRect(x: 0, y: 0, width: 500, height: 360)
        bodyTextView.autoresizingMask = [.width]
        bodyTextView.drawsBackground = true
        bodyTextView.backgroundColor = NSColor.textBackgroundColor.withAlphaComponent(0.82)
        bodyTextView.textColor = .labelColor
        bodyTextView.insertionPointColor = .controlAccentColor
        bodyTextView.isRichText = false
        bodyTextView.isAutomaticQuoteSubstitutionEnabled = false
        bodyTextView.isAutomaticDashSubstitutionEnabled = false
        bodyTextView.textContainerInset = NSSize(width: 8, height: 8)
        bodyTextView.minSize = NSSize(width: 0, height: 320)
        bodyTextView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        bodyTextView.isVerticallyResizable = true
        bodyTextView.isHorizontallyResizable = false
        bodyTextView.textContainer?.widthTracksTextView = true
        bodyTextView.textContainer?.containerSize = NSSize(width: 500, height: CGFloat.greatestFiniteMagnitude)
        bodyScrollView.documentView = bodyTextView

        statusLabel.font = AppTheme.regular(12)
        statusLabel.textColor = .secondaryLabelColor

        let editorForm = NSGridView(views: [
            [makeLabel("名称"), nameField],
            [makeLabel("说明"), detailField]
        ])
        editorForm.column(at: 0).xPlacement = .trailing
        editorForm.column(at: 1).width = 430
        editorForm.rowSpacing = 8
        editorForm.columnSpacing = 10

        let editorHeader = NSStackView(views: [editorForm, saveButton])
        editorHeader.orientation = .horizontal
        editorHeader.spacing = 12
        editorHeader.alignment = .bottom

        let leftStack = NSStackView(views: [titleLabel, searchField, listScrollView, emptyLabel, leftButtonStack])
        leftStack.orientation = .vertical
        leftStack.spacing = 10
        leftStack.alignment = .leading
        leftStack.translatesAutoresizingMaskIntoConstraints = false

        let rightTitle = NSTextField(labelWithString: "模板内容")
        rightTitle.font = AppTheme.semibold(14)

        let rightStack = NSStackView(views: [editorHeader, rightTitle, bodyScrollView, statusLabel])
        rightStack.orientation = .vertical
        rightStack.spacing = 10
        rightStack.alignment = .leading
        rightStack.translatesAutoresizingMaskIntoConstraints = false

        rootView.addSubview(leftStack)
        rootView.addSubview(rightStack)

        NSLayoutConstraint.activate([
            rootView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            rootView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            rootView.topAnchor.constraint(equalTo: contentView.topAnchor),
            rootView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            leftStack.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 20),
            leftStack.topAnchor.constraint(equalTo: rootView.topAnchor, constant: 20),
            leftStack.bottomAnchor.constraint(equalTo: rootView.bottomAnchor, constant: -18),
            leftStack.widthAnchor.constraint(equalToConstant: 300),

            searchField.widthAnchor.constraint(equalTo: leftStack.widthAnchor),
            listScrollView.widthAnchor.constraint(equalTo: leftStack.widthAnchor),
            listScrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 380),
            listStack.widthAnchor.constraint(equalTo: listScrollView.contentView.widthAnchor),

            rightStack.leadingAnchor.constraint(equalTo: leftStack.trailingAnchor, constant: 20),
            rightStack.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -20),
            rightStack.topAnchor.constraint(equalTo: rootView.topAnchor, constant: 24),
            rightStack.bottomAnchor.constraint(lessThanOrEqualTo: rootView.bottomAnchor, constant: -18),

            bodyScrollView.widthAnchor.constraint(equalTo: rightStack.widthAnchor),
            bodyScrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 360)
        ])
    }

    private func makeLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = AppTheme.medium(12)
        label.textColor = .secondaryLabelColor
        return label
    }

    private func reload() {
        templates = UserTemplateStore.search(searchField.stringValue)
        rebuildRows()
        if let selectedTemplateID, let template = templates.first(where: { $0.id == selectedTemplateID }) {
            load(template)
        } else if let first = templates.first {
            selectedTemplateID = first.id
            load(first)
        } else {
            selectedTemplateID = nil
            clearEditor()
        }
        refreshSelection()
    }

    private func rebuildRows() {
        rowViews.forEach { row in
            listStack.removeArrangedSubview(row)
            row.removeFromSuperview()
        }
        rowViews = []
        emptyLabel.isHidden = !templates.isEmpty

        for template in templates {
            let row = TemplateManagerRowView()
            row.configure(with: template, selected: template.id == selectedTemplateID)
            row.onSelect = { [weak self] in
                self?.selectedTemplateID = template.id
                self?.load(template)
                self?.refreshSelection()
            }
            listStack.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: listStack.widthAnchor, constant: -12).isActive = true
            rowViews.append(row)
        }
    }

    private func refreshSelection() {
        for (index, row) in rowViews.enumerated() {
            row.setSelected(templates.indices.contains(index) && templates[index].id == selectedTemplateID)
        }
    }

    private func load(_ template: UserPromptTemplate) {
        selectedTemplateID = template.id
        nameField.stringValue = template.title
        detailField.stringValue = template.detail
        bodyTextView.string = template.body
        bodyTextView.scrollRangeToVisible(NSRange(location: 0, length: 0))
        bodyTextView.needsDisplay = true
        statusLabel.stringValue = ""
    }

    private func clearEditor() {
        nameField.stringValue = ""
        detailField.stringValue = ""
        bodyTextView.string = ""
        statusLabel.stringValue = ""
    }

    @objc private func searchChanged() {
        reload()
    }

    func controlTextDidChange(_ obj: Notification) {
        reload()
    }

    @objc private func newTemplate() {
        selectedTemplateID = nil
        refreshSelection()
        nameField.stringValue = "新模板"
        detailField.stringValue = ""
        bodyTextView.string = """
        # 角色
        你是【角色】。

        # 任务
        请根据【输入内容】完成【目标任务】。

        # 输出格式
        - ...
        """
        bodyTextView.scrollRangeToVisible(NSRange(location: 0, length: 0))
        bodyTextView.needsDisplay = true
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.stringValue = "正在新建模板，编辑后点击保存。"
        window?.makeFirstResponder(nameField)
    }

    @objc private func saveTemplate() {
        let title = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = bodyTextView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, !body.isEmpty else {
            statusLabel.textColor = .systemRed
            statusLabel.stringValue = "名称和内容不能为空。"
            return
        }
        do {
            if let selectedTemplateID, let existing = templates.first(where: { $0.id == selectedTemplateID }) {
                var updated = existing
                updated.title = title
                updated.detail = detailField.stringValue
                updated.body = body
                try UserTemplateStore.update(updated)
            } else {
                let template = try UserTemplateStore.add(TemplateDraft(title: title, detail: detailField.stringValue, body: body))
                selectedTemplateID = template.id
            }
            statusLabel.textColor = .secondaryLabelColor
            statusLabel.stringValue = "已保存。"
            onChange?()
            reload()
        } catch {
            statusLabel.textColor = .systemRed
            statusLabel.stringValue = error.localizedDescription
        }
    }

    @objc private func deleteTemplate() {
        guard let selectedTemplateID, let template = templates.first(where: { $0.id == selectedTemplateID }) else {
            NSSound.beep()
            return
        }
        let alert = NSAlert()
        alert.messageText = "删除模板？"
        alert.informativeText = "将删除「\(template.title)」，此操作不可撤销。"
        alert.addButton(withTitle: "删除")
        alert.addButton(withTitle: "取消")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        do {
            try UserTemplateStore.delete(id: selectedTemplateID)
            self.selectedTemplateID = nil
            statusLabel.textColor = .secondaryLabelColor
            statusLabel.stringValue = "已删除。"
            onChange?()
            reload()
        } catch {
            statusLabel.textColor = .systemRed
            statusLabel.stringValue = error.localizedDescription
        }
    }
}
