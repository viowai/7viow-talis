import AppKit

final class TemplatePreviewWindowController: NSWindowController {
    private let titleField = NSTextField()
    private let detailField = NSTextField()
    private let bodyScrollView = NSScrollView()
    private let bodyTextView = NSTextView()
    private let statusLabel = NSTextField(labelWithString: "")
    var onSave: ((UserPromptTemplate) -> Void)?

    init(draft: TemplateDraft) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 560),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "保存为我的模板"
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        super.init(window: window)
        configureUI()
        load(draft)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
        window?.makeFirstResponder(titleField)
    }

    private func configureUI() {
        guard let contentView = window?.contentView else { return }

        let rootView = NSVisualEffectView()
        rootView.material = .underWindowBackground
        rootView.blendingMode = .behindWindow
        rootView.state = .active
        rootView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(rootView)

        let titleLabel = NSTextField(labelWithString: "预览并确认模板")
        titleLabel.font = AppTheme.semibold(18)

        let introLabel = NSTextField(labelWithString: "AI 已将当前 Prompt 抽象为可复用模板。确认后保存到「我的模板」。")
        introLabel.font = AppTheme.regular(12)
        introLabel.textColor = .secondaryLabelColor

        titleField.font = AppTheme.regular(13)
        titleField.placeholderString = "模板名称"

        detailField.font = AppTheme.regular(13)
        detailField.placeholderString = "模板说明"

        bodyScrollView.translatesAutoresizingMaskIntoConstraints = false
        bodyScrollView.borderType = .bezelBorder
        bodyScrollView.hasVerticalScroller = true
        bodyScrollView.autohidesScrollers = true
        bodyScrollView.drawsBackground = true
        bodyScrollView.backgroundColor = NSColor.textBackgroundColor.withAlphaComponent(0.82)

        bodyTextView.font = AppTheme.regular(13)
        bodyTextView.frame = NSRect(x: 0, y: 0, width: 560, height: 360)
        bodyTextView.autoresizingMask = [.width]
        bodyTextView.drawsBackground = true
        bodyTextView.backgroundColor = NSColor.textBackgroundColor.withAlphaComponent(0.82)
        bodyTextView.textColor = .labelColor
        bodyTextView.insertionPointColor = .controlAccentColor
        bodyTextView.isRichText = false
        bodyTextView.isAutomaticQuoteSubstitutionEnabled = false
        bodyTextView.isAutomaticDashSubstitutionEnabled = false
        bodyTextView.textContainerInset = NSSize(width: 8, height: 8)
        bodyTextView.minSize = NSSize(width: 0, height: 360)
        bodyTextView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        bodyTextView.isVerticallyResizable = true
        bodyTextView.isHorizontallyResizable = false
        bodyTextView.textContainer?.widthTracksTextView = true
        bodyTextView.textContainer?.containerSize = NSSize(width: 560, height: CGFloat.greatestFiniteMagnitude)
        bodyScrollView.documentView = bodyTextView

        statusLabel.font = AppTheme.regular(12)
        statusLabel.textColor = .secondaryLabelColor

        let cancelButton = NSButton(title: "取消", target: self, action: #selector(cancel))
        cancelButton.bezelStyle = .rounded
        cancelButton.font = AppTheme.medium(12)

        let saveButton = NSButton(title: "保存", target: self, action: #selector(save))
        saveButton.bezelStyle = .rounded
        saveButton.font = AppTheme.medium(12)

        let buttonStack = NSStackView(views: [cancelButton, saveButton])
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 8
        buttonStack.alignment = .centerY

        let form = NSGridView(views: [
            [makeLabel("名称"), titleField],
            [makeLabel("说明"), detailField]
        ])
        form.column(at: 0).xPlacement = .trailing
        form.column(at: 1).width = 520
        form.rowSpacing = 8
        form.columnSpacing = 10

        let stack = NSStackView(views: [titleLabel, introLabel, form, bodyScrollView, statusLabel, buttonStack])
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

            stack.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 22),
            stack.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -22),
            stack.topAnchor.constraint(equalTo: rootView.topAnchor, constant: 22),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: rootView.bottomAnchor, constant: -18),

            bodyScrollView.widthAnchor.constraint(equalTo: stack.widthAnchor),
            bodyScrollView.heightAnchor.constraint(equalToConstant: 330)
        ])
    }

    private func load(_ draft: TemplateDraft) {
        titleField.stringValue = draft.title
        detailField.stringValue = draft.detail
        bodyTextView.string = draft.body
        bodyTextView.scrollRangeToVisible(NSRange(location: 0, length: 0))
        bodyTextView.needsDisplay = true
    }

    private func makeLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = AppTheme.medium(12)
        label.textColor = .secondaryLabelColor
        return label
    }

    @objc private func save() {
        let title = titleField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = bodyTextView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, !body.isEmpty else {
            statusLabel.textColor = .systemRed
            statusLabel.stringValue = "名称和内容不能为空。"
            return
        }
        do {
            let template = try UserTemplateStore.add(TemplateDraft(title: title, detail: detailField.stringValue, body: body))
            statusLabel.textColor = .secondaryLabelColor
            statusLabel.stringValue = "已保存到我的模板。"
            onSave?(template)
            window?.orderOut(nil)
        } catch {
            statusLabel.textColor = .systemRed
            statusLabel.stringValue = error.localizedDescription
        }
    }

    @objc private func cancel() {
        window?.orderOut(nil)
    }
}
