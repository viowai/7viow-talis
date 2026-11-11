import AppKit
import TalisCore

private final class ClarificationSheetWindow: NSWindow {
    var onCancel: (() -> Void)?
    override func cancelOperation(_ sender: Any?) { onCancel?() }

    private static let minimumContentWidth: CGFloat = 580
    private static let maximumContentWidth: CGFloat = 680

    override func setContentSize(_ size: NSSize) {
        let width = min(Self.maximumContentWidth, max(Self.minimumContentWidth, size.width))
        super.setContentSize(NSSize(width: width, height: size.height))
    }

    override func setFrame(_ frameRect: NSRect, display flag: Bool) {
        var constrained = frameRect
        let maximumWidth = Self.maximumContentWidth
        constrained.size.width = min(maximumWidth, max(Self.minimumContentWidth, constrained.width))
        super.setFrame(constrained, display: flag)
    }
}

final class ClarificationWindowController: NSWindowController, NSWindowDelegate {
    private static let preferredSize = NSSize(width: 620, height: 460)

    let panel = ClarificationPanelView()
    private weak var parentWindow: NSWindow?
    private(set) var isPresented = false

    var onSubmit: ((ClarificationAnswer) -> Void)? {
        didSet { panel.onSubmit = onSubmit }
    }
    var onUseGeneratedResult: (() -> Void)? {
        didSet { panel.onUseGeneratedResult = onUseGeneratedResult }
    }
    var onEnd: (() -> Void)? {
        didSet { panel.onEnd = onEnd }
    }
    var onDismiss: (() -> Void)? {
        didSet { panel.onDismiss = onDismiss }
    }

    init() {
        let window = ClarificationSheetWindow(
            contentRect: NSRect(origin: .zero, size: Self.preferredSize),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = L("追问")
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.contentMinSize = NSSize(width: 580, height: 400)
        window.contentMaxSize = NSSize(width: 620, height: 720)
        window.minSize = NSSize(width: 580, height: 400)
        window.maxSize = NSSize(width: 620, height: 760)
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        AppTheme.configureWindow(window)
        super.init(window: window)
        window.onCancel = { [weak self] in self?.onDismiss?() }
        window.delegate = self
        installPanel()
        panel.onPreferredHeightChanged = { [weak self] in
            self?.resizeForCurrentContent(minimum: 440, maximum: 720)
        }
        AppLocalization.observe(self, selector: #selector(refreshLocalization))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present(relativeTo parent: NSWindow?) {
        guard let window, let parent else {
            showWindow(nil)
            isPresented = true
            return
        }
        guard !isPresented else {
            window.makeKeyAndOrderFront(nil)
            return
        }
        parentWindow = parent
        let visible = parent.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let width = min(Self.preferredSize.width, max(580, visible.width - 96))
        let height = min(Self.preferredSize.height, max(420, visible.height - 140))
        window.setContentSize(NSSize(width: width, height: height))
        parent.beginSheet(window)
        isPresented = true
    }

    func configureLoading() {
        panel.configureLoading()
        resizeForCurrentContent(minimum: 440, maximum: 500)
    }

    func configureNoQuestions() {
        panel.configureNoQuestions()
        resizeForCurrentContent(minimum: 240, maximum: 280)
    }

    func configure(question: ClarificationQuestion, round: Int, maximumRounds: Int,
                   questionIndex: Int, totalQuestions: Int) {
        panel.configure(
            question: question,
            round: round,
            maximumRounds: maximumRounds,
            questionIndex: questionIndex,
            totalQuestions: totalQuestions
        )
        resizeForCurrentContent(minimum: 440, maximum: 620)
    }

    func restoreAnswer(_ answer: ClarificationAnswer) {
        panel.restoreAnswer(answer)
    }

    func setLoading(_ loading: Bool) {
        panel.setLoading(loading)
    }

    func showError(title: String, message: String, retryTitle: String = L("重试"), retry: @escaping () -> Void) {
        panel.showError(title: title, message: message, retryTitle: retryTitle, retry: retry)
        resizeForCurrentContent(minimum: 250, maximum: 350)
    }

    func focusAnswer() {
        panel.focusAnswer()
    }

    func dismissSheet() {
        guard let window else { return }
        if let parent = window.sheetParent {
            parent.endSheet(window)
        } else {
            window.orderOut(nil)
        }
        isPresented = false
        parentWindow = nil
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        onDismiss?()
        return false
    }

    private func installPanel() {
        guard let contentView = window?.contentView else { return }
        let root = WindowContentView(frame: .zero)
        root.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(root)
        panel.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(panel)
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            root.topAnchor.constraint(equalTo: contentView.topAnchor),
            root.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            panel.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: AppTheme.Spacing.window),
            panel.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -AppTheme.Spacing.window),
            panel.topAnchor.constraint(equalTo: root.topAnchor, constant: AppTheme.Spacing.window),
            panel.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -AppTheme.Spacing.window)
        ])
    }

    @objc private func refreshLocalization() {
        if let content = window?.contentView { AppLocalization.refresh(content) }
        panel.refreshLocalization()
        window?.title = L("追问")
    }

    private func resizeForCurrentContent(minimum: CGFloat, maximum: CGFloat) {
        guard let window else { return }
        panel.layoutSubtreeIfNeeded()
        let target = min(maximum, max(minimum, panel.preferredContentHeight + 88))
        var frame = window.frame
        frame.origin.y += frame.height - target
        frame.size.width = min(620, max(580, frame.width))
        frame.size.height = target
        window.setFrame(frame, display: true)
    }
}
