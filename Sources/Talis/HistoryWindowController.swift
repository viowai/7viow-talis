import AppKit
import TalisCore

/// Session history is a reading window, independent of the prompt editor's height.
final class HistoryWindowController: NSWindowController, NSWindowDelegate {
    struct Entry: Equatable {
        let round: Int
        let action: String
        let date: Date
        let input: String
        let output: String
        let clarificationRounds: [ClarificationRoundRecord]
        let originalQuery: String?

        init(round: Int, action: String, date: Date, input: String, output: String,
             clarificationRounds: [ClarificationRoundRecord] = [], originalQuery: String? = nil) {
            self.round = round
            self.action = action
            self.date = date
            self.input = input
            self.output = output
            self.clarificationRounds = clarificationRounds
            self.originalQuery = originalQuery
        }

        var title: String {
            let timestamp = DateFormatter.localizedString(from: date, dateStyle: .none, timeStyle: .medium)
            return AppLocalization.format("第 %@ 轮 · %@ · %@", round, AppLocalization.redisplay(action), timestamp)
        }
    }
    private let picker = NSPopUpButton()
    private let detail = NSTextView()
    private let scroll = HistoryScrollView()
    private let readingSurface = ThemedSurfaceView()
    private let previous = NSButton(title: L("上一轮"), target: nil, action: nil)
    private let next = NSButton(title: L("下一轮"), target: nil, action: nil)
    private var entries: [Entry] = []
    var onClose: (() -> Void)?

    init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 780, height: 600),
                              styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.title = L("修改记录")
        window.minSize = NSSize(width: 560, height: 380)
        AppTheme.configureWindow(window)
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        window.isRestorable = false
        super.init(window: window)
        window.delegate = self
        AppLocalization.observe(self, selector: #selector(refreshLocalization))
        let root = WindowContentView(frame: .zero)
        window.contentView = root
        picker.target = self; picker.action = #selector(selectionChanged)
        picker.setAccessibilityLabel(L("选择修改轮次"))
        previous.target = self; previous.action = #selector(previousPressed)
        next.target = self; next.action = #selector(nextPressed)
        let back = NSButton(title: L("返回编辑"), target: self, action: #selector(returnPressed))
        for button in [previous, next, back] { AppTheme.styleButton(button) }
        back.keyEquivalent = "\u{1b}"
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let toolbar = NSStackView(views: [picker, previous, next, spacer, back])
        toolbar.orientation = .horizontal; toolbar.spacing = 8; toolbar.alignment = .centerY
        for view in [toolbar, readingSurface] { view.translatesAutoresizingMaskIntoConstraints = false; root.addSubview(view) }
        scroll.translatesAutoresizingMaskIntoConstraints = false
        readingSurface.addSubview(scroll)
        detail.configureHistoryWrapping()
        detail.isEditable = false; detail.isSelectable = true; detail.drawsBackground = false
        detail.font = AppTheme.regular(15)
        detail.textColor = .labelColor
        AppTheme.styleEditor(detail)
        detail.textContainerInset = NSSize(width: 18, height: 16)
        detail.setAccessibilityLabel(L("本轮输入与结果"))
        scroll.hasVerticalScroller = true; scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        AppTheme.configureContentScrollView(scroll)
        scroll.documentView = detail
        NSLayoutConstraint.activate([
            toolbar.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: AppTheme.Spacing.window),
            toolbar.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -AppTheme.Spacing.window),
            toolbar.topAnchor.constraint(equalTo: root.topAnchor, constant: AppTheme.Spacing.window),
            toolbar.heightAnchor.constraint(equalToConstant: 32),
            picker.widthAnchor.constraint(greaterThanOrEqualToConstant: 220),
            readingSurface.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: AppTheme.Spacing.window),
            readingSurface.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -AppTheme.Spacing.window),
            readingSurface.topAnchor.constraint(equalTo: toolbar.bottomAnchor, constant: AppTheme.Spacing.section),
            readingSurface.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -AppTheme.Spacing.window),
            scroll.leadingAnchor.constraint(equalTo: readingSurface.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: readingSurface.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: readingSurface.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: readingSurface.bottomAnchor)
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(_ entries: [Entry]) {
        guard self.entries != entries else { return }
        let selection = picker.indexOfSelectedItem
        self.entries = entries
        picker.removeAllItems()
        picker.addItems(withTitles: entries.map(\.title))
        if !entries.isEmpty { picker.selectItem(at: min(max(0, selection), entries.count - 1)) }
        render()
    }
    func showLatest(relativeTo editor: NSWindow?) {
        guard !entries.isEmpty, let window else { return }
        picker.selectItem(at: entries.count - 1)
        render()
        window.appearance = editor?.appearance
        let targetScreen = editor?.screen ?? NSScreen.main
        if !window.isVisible || window.screen !== targetScreen {
            AppTheme.center(window, on: targetScreen)
        }
        window.makeKeyAndOrderFront(nil)
    }
    private func render() {
        let index = picker.indexOfSelectedItem
        guard entries.indices.contains(index) else { detail.string = ""; return }
        picker.item(at: index)?.title = entries[index].title
        let entry = entries[index]
        var input = entry.input
        if let originalQuery = entry.originalQuery, !entry.clarificationRounds.isEmpty {
            // Transcript chrome is application copy; the question and answer
            // text remains unchanged and the model request keeps its source format.
            let transcript = entry.clarificationRounds.enumerated().map { index, round in
                let answers = round.answers.map { answer in
                    "- \(answer.question) → \(answer.skipped ? L("跳过") : answer.answer)"
                }.joined(separator: "\n")
                return AppLocalization.format("第 %@ 轮", index + 1) + "\n" + answers
            }.joined(separator: "\n")
            input = originalQuery + "\n\n" + L("追问记录：") + "\n" + transcript
        }
        let content = NSMutableAttributedString(string: "")
        let paragraph = NSMutableParagraphStyle()
        paragraph.paragraphSpacing = 8
        for (heading, body) in [(L("输入"), input), (L("结果"), entry.output)] {
            content.append(NSAttributedString(string: heading + "\n", attributes: [.font: AppTheme.semibold(17), .foregroundColor: NSColor.labelColor, .paragraphStyle: paragraph]))
            content.append(NSAttributedString(string: body + "\n\n", attributes: [.font: AppTheme.regular(15), .foregroundColor: NSColor.labelColor, .paragraphStyle: paragraph]))
        }
        detail.textStorage?.setAttributedString(content)
        previous.isEnabled = index > 0
        next.isEnabled = index < entries.count - 1
        scroll.needsLayout = true
        scroll.layoutSubtreeIfNeeded()
        detail.scrollRangeToVisible(NSRange(location: 0, length: 0))
    }
    @objc private func refreshLocalization() {
        if let content = window?.contentView { AppLocalization.refresh(content) }
        window?.title = L("修改记录")
        let selection = picker.indexOfSelectedItem
        picker.removeAllItems()
        picker.addItems(withTitles: entries.map(\.title))
        if entries.indices.contains(selection) { picker.selectItem(at: selection) }
        render()
    }
    @objc private func selectionChanged() { render() }
    @objc private func previousPressed() { picker.selectItem(at: picker.indexOfSelectedItem - 1); render() }
    @objc private func nextPressed() { picker.selectItem(at: picker.indexOfSelectedItem + 1); render() }
    @objc private func returnPressed() { close() }
    func windowWillClose(_ notification: Notification) { onClose?() }
}
