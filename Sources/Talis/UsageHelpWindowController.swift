import AppKit

final class UsageHelpWindowController: NSWindowController {
    private let scrollView = NSScrollView()
    private let documentStack = TopAlignedStackView()

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 620),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = L("使用说明")
        window.minSize = NSSize(width: 540, height: 440)
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        window.isRestorable = false
        AppTheme.configureWindow(window)
        super.init(window: window)
        configure()
        refreshLocalization()
        AppLocalization.observe(self, selector: #selector(refreshLocalization))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show(relativeTo parent: NSWindow? = nil) {
        if let window { AppTheme.center(window, on: parent?.screen ?? window.screen ?? NSScreen.main) }
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
    }

    static func plainText() -> String {
        helpSections().map { heading, lines in
            ([heading] + lines).joined(separator: "\n")
        }.joined(separator: "\n\n")
    }

    private static func helpSections() -> [(String, [String])] {
        let shortcut = AppIdentity.current.shortcutLabel
        return [
            (L("打开与编辑"), [
                shortcut + L("：唤起输入框"),
                L("⌘K：打开模板选择；空输入时也可按 /"),
                L("Tab：跳到下一处占位符（有占位符时）"),
                L("⌘↵：复制 Prompt"),
                L("Esc：结束当前快速会话并收起；下次唤起为空白"),
                L("⌘N：保存当前会话到“上次草稿”，开始新 Prompt"),
                L("恢复上次草稿：存在可恢复内容时，从主界面、Prompt 菜单或状态栏菜单恢复最近一次正文与修改记录"),
                L("⌘Z：撤销，包括撤销清空"),
                L("⌘D：快速浮窗与独立工作窗口切换，正文与修改记录保留")
            ]),
            (L("菜单栏"), [
                L("单击 T：打开或收起 Talis"),
                L("右击 T：新建 Prompt、恢复上次草稿、修改记录、模板、设置与退出")
            ]),
            (L("模板选择"), [
                L("↑↓：选择模板"),
                L("↵：插入模板"),
                L("Tab：切换模板来源"),
                L("Esc：收起模板选择")
            ]),
            (L("AI 操作（按所选服务）"), [
                L("微调：保留原意与结构，调整表达"),
                L("重构：按当前需求重新组织内容"),
                L("追问：先补充关键信息，再生成Prompt"),
                L("停止或 ⌘.：停止等待，保留原文")
            ]),
            (L("内容操作"), [
                L("从“模板”菜单打开“模板中心”"),
                L("存为新模板：提取模板，预览后保存"),
                L("覆盖原模板：确认后写回来源模板"),
                L("清空当前内容：清空正文和修改记录，可撤销")
            ]),
            (L("修改记录"), [
                L("修改记录保留本次编辑的全部轮次，模型仅参考最近 3 轮。")
            ])
        ]
    }

    private func configure() {
        guard let content = window?.contentView else { return }
        let root = WindowContentView()
        root.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(root)

        documentStack.orientation = .vertical
        documentStack.alignment = .leading
        documentStack.spacing = 12
        documentStack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        documentStack.translatesAutoresizingMaskIntoConstraints = false

        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = false
        scrollView.borderType = .noBorder
        scrollView.documentView = documentStack
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.setAccessibilityLabel(L("使用说明"))

        let stack = NSStackView(views: [scrollView])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(stack)
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            root.topAnchor.constraint(equalTo: content.topAnchor),
            root.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: AppTheme.Spacing.window),
            stack.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -AppTheme.Spacing.window),
            stack.topAnchor.constraint(equalTo: root.topAnchor, constant: AppTheme.Spacing.window),
            stack.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -AppTheme.Spacing.window),
            scrollView.widthAnchor.constraint(equalTo: stack.widthAnchor),
            documentStack.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            documentStack.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            documentStack.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            documentStack.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor)
        ])
        rebuildDocument()
    }

    @objc private func refreshLocalization() {
        window?.title = L("使用说明")
        rebuildDocument()
    }

    private func rebuildDocument() {
        for view in documentStack.arrangedSubviews {
            documentStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        for (heading, lines) in Self.helpSections() {
            let card = ThemedSurfaceView()
            card.fillColor = AppTheme.contentColor.withAlphaComponent(0.72)
            card.borderColor = AppTheme.borderColor.withAlphaComponent(0.72)
            card.translatesAutoresizingMaskIntoConstraints = false

            let headingLabel = NSTextField(labelWithString: heading)
            headingLabel.font = AppTheme.semibold(15)
            headingLabel.textColor = .labelColor
            headingLabel.translatesAutoresizingMaskIntoConstraints = false
            let linesStack = NSStackView()
            linesStack.orientation = .vertical
            linesStack.alignment = .leading
            linesStack.spacing = 5
            linesStack.translatesAutoresizingMaskIntoConstraints = false
            for line in lines {
                let label = NSTextField(wrappingLabelWithString: "• " + line)
                label.font = AppTheme.regular(13)
                label.textColor = .labelColor
                label.setContentCompressionResistancePriority(.required, for: .vertical)
                linesStack.addArrangedSubview(label)
                label.widthAnchor.constraint(equalTo: linesStack.widthAnchor).isActive = true
            }
            card.addSubview(headingLabel)
            card.addSubview(linesStack)
            NSLayoutConstraint.activate([
                headingLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
                headingLabel.trailingAnchor.constraint(lessThanOrEqualTo: card.trailingAnchor, constant: -14),
                headingLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
                linesStack.leadingAnchor.constraint(equalTo: headingLabel.leadingAnchor),
                linesStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
                linesStack.topAnchor.constraint(equalTo: headingLabel.bottomAnchor, constant: 7),
                linesStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12)
            ])
            documentStack.addArrangedSubview(card)
            card.widthAnchor.constraint(equalTo: documentStack.widthAnchor, constant: -40).isActive = true
        }
        documentStack.layoutSubtreeIfNeeded()
        documentStack.window?.contentView?.layoutSubtreeIfNeeded()
    }
}
