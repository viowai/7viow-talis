import AppKit

final class TemplatePreviewWindowController: NSWindowController, NSWindowDelegate {
    private let titleField = NSTextField()
    private let detailField = NSTextField()
    private let bodyScrollView = HistoryScrollView()
    private let bodyTextView = NSTextView()
    private var formGrid: NSGridView?
    private let statusLabel = NSTextField(labelWithString: "")
    private var loadedDraft: TemplateDraft?
    private let persistDraft: (TemplateDraft) throws -> UserPromptTemplate
    var onSave: ((UserPromptTemplate) -> Void)?

    init(draft: TemplateDraft, persistDraft: @escaping (TemplateDraft) throws -> UserPromptTemplate = UserTemplateStore.add) {
        self.persistDraft = persistDraft
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 560),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = L("保存模板")
        window.minSize = NSSize(width: 600, height: 540)
        AppTheme.configureWindow(window)
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        window.isRestorable = false
        super.init(window: window)
        window.delegate = self
        configureUI()
        load(draft)
        AppLocalization.observe(self, selector: #selector(refreshLocalization))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(relativeTo parent: NSWindow? = nil) {
        NSApp.activate(ignoringOtherApps: true)
        if let window { AppTheme.center(window, on: parent?.screen ?? window.screen ?? NSScreen.main) }
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
        window?.makeFirstResponder(titleField)
    }

    private func configureUI() {
        guard let contentView = window?.contentView else { return }

        let rootView = WindowContentView()
        rootView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(rootView)

        let titleLabel = NSTextField(labelWithString: L("保存模板"))
        titleLabel.font = AppTheme.semibold(18)

        titleField.font = AppTheme.regular(13)
        titleField.placeholderString = L("名称")
        titleField.setAccessibilityLabel(L("模板名称"))

        detailField.font = AppTheme.regular(13)
        detailField.placeholderString = L("说明")
        detailField.setAccessibilityLabel(L("模板说明"))

        bodyScrollView.translatesAutoresizingMaskIntoConstraints = false
        bodyScrollView.borderType = .bezelBorder
        bodyScrollView.hasVerticalScroller = true
        bodyScrollView.autohidesScrollers = true
        AppTheme.configureContentScrollView(bodyScrollView)

        bodyTextView.configureHistoryWrapping()
        bodyTextView.font = AppTheme.regular(14)
        bodyTextView.frame = NSRect(x: 0, y: 0, width: 560, height: 360)
        bodyTextView.autoresizingMask = [.width]
        bodyTextView.drawsBackground = false
        bodyTextView.textColor = .labelColor
        AppTheme.styleEditor(bodyTextView)
        bodyTextView.isRichText = false
        bodyTextView.isAutomaticQuoteSubstitutionEnabled = false
        bodyTextView.isAutomaticDashSubstitutionEnabled = false
        bodyTextView.textContainerInset = NSSize(width: 12, height: 12)
        bodyTextView.setAccessibilityLabel(L("模板正文"))
        bodyTextView.allowsUndo = true
        bodyTextView.minSize = NSSize(width: 0, height: 360)
        bodyTextView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        bodyTextView.isVerticallyResizable = true
        bodyTextView.isHorizontallyResizable = false
        bodyTextView.textContainer?.widthTracksTextView = true
        bodyTextView.textContainer?.containerSize = NSSize(width: 560, height: CGFloat.greatestFiniteMagnitude)
        bodyScrollView.documentView = bodyTextView

        statusLabel.font = AppTheme.regular(12)
        statusLabel.textColor = AppTheme.secondaryTextColor

        let cancelButton = NSButton(title: L("取消"), target: self, action: #selector(cancel))
        cancelButton.bezelStyle = .rounded
        AppTheme.styleButton(cancelButton)
        cancelButton.keyEquivalent = "\u{1b}"

        let saveButton = NSButton(title: L("保存"), target: self, action: #selector(save))
        saveButton.bezelStyle = .rounded
        AppTheme.styleButton(saveButton, primary: true)
        saveButton.keyEquivalent = "s"
        saveButton.keyEquivalentModifierMask = .command

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let buttonStack = NSStackView(views: [spacer, cancelButton, saveButton])
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 8
        buttonStack.alignment = .centerY
        let footerSeparator = NSBox()
        footerSeparator.boxType = .separator

        let form = NSGridView(views: [
            [makeLabel(L("名称")), titleField],
            [makeLabel(L("说明")), detailField]
        ])
        AppTheme.alignForm(form, labelWidth: AppLocalization.isEnglish ? 72 : 40, spacing: 8)
        formGrid = form
        for field in [titleField, detailField] {
            AppTheme.styleTextField(field)
        }

        let stack = NSStackView(views: [titleLabel, form, bodyScrollView, statusLabel, footerSeparator, buttonStack])
        stack.orientation = .vertical
        stack.spacing = 12
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        rootView.addSubview(stack)

        NSLayoutConstraint.activate([
            rootView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            rootView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            rootView.topAnchor.constraint(equalTo: contentView.topAnchor),
            rootView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            stack.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: AppTheme.Spacing.window),
            stack.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -AppTheme.Spacing.window),
            stack.topAnchor.constraint(equalTo: rootView.topAnchor, constant: AppTheme.Spacing.window),
            stack.bottomAnchor.constraint(equalTo: rootView.bottomAnchor, constant: -AppTheme.Spacing.window),
            form.widthAnchor.constraint(equalTo: stack.widthAnchor),
            statusLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            footerSeparator.widthAnchor.constraint(equalTo: stack.widthAnchor),
            buttonStack.widthAnchor.constraint(equalTo: stack.widthAnchor),

            bodyScrollView.widthAnchor.constraint(equalTo: stack.widthAnchor),
            bodyScrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 260)
        ])
    }

    private func load(_ draft: TemplateDraft) {
        titleField.stringValue = draft.title
        detailField.stringValue = draft.detail
        bodyTextView.string = draft.body
        bodyTextView.scrollRangeToVisible(NSRange(location: 0, length: 0))
        bodyTextView.needsDisplay = true
        loadedDraft = draft
    }

    var hasUnsavedChanges: Bool {
        loadedDraft != TemplateDraft(title: titleField.stringValue, detail: detailField.stringValue, body: bodyTextView.string)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard hasUnsavedChanges else { return true }
        let alert = NSAlert()
        alert.messageText = L("放弃未保存的修改？")
        alert.informativeText = L("模板内容尚未保存。可以继续编辑，或放弃这次修改。")
        alert.addButton(withTitle: L("继续编辑"))
        alert.addButton(withTitle: L("放弃修改"))
        alert.buttons.last?.contentTintColor = .systemRed
        return alert.runModal() == .alertSecondButtonReturn
    }

    private func makeLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = AppTheme.regular(13)
        label.textColor = AppTheme.secondaryTextColor
        return label
    }

    @objc private func refreshLocalization() {
        guard let content = window?.contentView else { return }
        AppLocalization.refresh(content)
        formGrid?.column(at: 0).width = AppLocalization.isEnglish ? 72 : 40
        window?.title = L("保存模板")
        content.layoutSubtreeIfNeeded()
    }

    @objc private func save() {
        let title = titleField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = bodyTextView.string
        guard !title.isEmpty, !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            statusLabel.textColor = AppTheme.errorTextColor
            statusLabel.stringValue = L("请填写模板名称和内容。")
            return
        }
        do {
            let template = try persistDraft(TemplateDraft(title: title, detail: detailField.stringValue, body: body))
            statusLabel.textColor = AppTheme.secondaryTextColor
            statusLabel.stringValue = L("已保存")
            onSave?(template)
            window?.orderOut(nil)
        } catch {
            statusLabel.textColor = AppTheme.errorTextColor
            statusLabel.stringValue = error.localizedDescription
        }
    }

    @objc private func cancel() {
        window?.performClose(nil)
    }
}
