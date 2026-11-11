import AppKit
import TalisCore

private final class ClarificationRadioButton: NSButton {
    var onFocusChanged: ((Bool) -> Void)?

    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted { onFocusChanged?(true) }
        return accepted
    }

    override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        if resigned { onFocusChanged?(false) }
        return resigned
    }
}

final class ClarificationChoiceButton: ThemedSurfaceView {
    let optionValue: String
    var onPress: (() -> Void)?
    private let radio = ClarificationRadioButton()
    private var choiceSelected = false
    private var keyboardFocused = false
    private var hovering = false
    private var hoverTrackingArea: NSTrackingArea?
    var isEnabled: Bool {
        get { radio.isEnabled }
        set {
            radio.isEnabled = newValue
            updateStyle()
        }
    }

    init(optionValue: String) {
        self.optionValue = optionValue
        super.init(frame: .zero)
        radio.title = optionValue
        radio.setButtonType(.radio)
        radio.isBordered = false
        radio.font = AppTheme.regular(13)
        radio.alignment = .left
        radio.cell?.wraps = true
        radio.cell?.usesSingleLineMode = false
        radio.cell?.lineBreakMode = .byWordWrapping
        radio.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        radio.target = self
        radio.action = #selector(pressed)
        radio.focusRingType = .none
        radio.onFocusChanged = { [weak self] focused in
            self?.keyboardFocused = focused
            self?.updateStyle()
        }
        radio.setAccessibilityLabel(optionValue)
        radio.toolTip = optionValue
        radio.translatesAutoresizingMaskIntoConstraints = false
        addSubview(radio)
        NSLayoutConstraint.activate([
            radio.leadingAnchor.constraint(equalTo: leadingAnchor, constant: AppTheme.Spacing.control),
            radio.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -AppTheme.Spacing.control),
            radio.topAnchor.constraint(equalTo: topAnchor, constant: AppTheme.Spacing.inline),
            radio.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -AppTheme.Spacing.inline)
        ])
        setChoiceSelected(false)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func setChoiceSelected(_ selected: Bool) {
        choiceSelected = selected
        radio.state = selected ? .on : .off
        updateStyle()
    }
    func focus() { window?.makeFirstResponder(radio) }
    func height(for width: CGFloat) -> CGFloat {
        let size = (optionValue as NSString).boundingRect(
            with: NSSize(width: max(120, width - 48), height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [.font: AppTheme.regular(13)]
        ).height
        return max(40, ceil(size) + 20)
    }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTrackingArea { removeTrackingArea(hoverTrackingArea) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        hoverTrackingArea = area
    }
    override func resetCursorRects() {
        super.resetCursorRects()
        if isEnabled { addCursorRect(bounds, cursor: .pointingHand) }
    }
    override func mouseEntered(with event: NSEvent) {
        hovering = true
        updateStyle()
    }
    override func mouseExited(with event: NSEvent) {
        hovering = false
        updateStyle()
    }
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateStyle()
    }
    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }
        onPress?()
    }
    @objc private func pressed() { onPress?() }

    private func updateStyle() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            let enabled = isEnabled
            fillColor = AppTheme.contentColor
            radio.contentTintColor = enabled
                ? (choiceSelected ? AppTheme.accentColor : .secondaryLabelColor)
                : .disabledControlTextColor
            let titleColor: NSColor = enabled ? .labelColor : .disabledControlTextColor
            radio.attributedTitle = NSAttributedString(
                string: optionValue,
                attributes: [.font: AppTheme.regular(13), .foregroundColor: titleColor]
            )
            if !enabled {
                gradientColorsProvider = nil
                borderColor = AppTheme.borderColor.withAlphaComponent(0.48)
            } else if choiceSelected {
                gradientColorsProvider = {
                    [AppTheme.accentColor.blended(withFraction: 0.84, of: AppTheme.contentColor)!,
                     AppTheme.accentColor.blended(withFraction: 0.92, of: AppTheme.contentColor)!]
                }
                borderColor = AppTheme.accentColor.withAlphaComponent(0.82)
            } else if keyboardFocused {
                gradientColorsProvider = nil
                borderColor = AppTheme.accentColor.withAlphaComponent(0.58)
            } else if hovering {
                gradientColorsProvider = {
                    [AppTheme.accentColor.withAlphaComponent(0.075),
                     AppTheme.accentColor.withAlphaComponent(0.025)]
                }
                borderColor = AppTheme.accentColor.withAlphaComponent(0.36)
            } else {
                gradientColorsProvider = nil
                borderColor = AppTheme.borderColor
            }
        }
        needsDisplay = true
        window?.invalidateCursorRects(for: self)
    }
}

final class GrowingClarificationAnswerField: ThemedSurfaceView, NSTextViewDelegate {
    var onChange: ((String) -> Void)?
    var onSubmit: (() -> Void)?
    var onCancel: (() -> Void)?

    private let scrollView = NSScrollView()
    private let textView = NSTextView()
    private let placeholderLabel = NSTextField(labelWithString: L("或输入自定义回答"))
    private var heightConstraint: NSLayoutConstraint!

    var stringValue: String {
        get { textView.string }
        set {
            let previous = textView.string
            textView.string = newValue
            refreshTextState()
            if previous != newValue { onChange?(newValue) }
        }
    }

    var isEditable: Bool {
        get { textView.isEditable }
        set {
            textView.isEditable = newValue
            textView.isSelectable = newValue
            scrollView.hasVerticalScroller = false
            refreshAppearance()
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        fillColor = AppTheme.contentColor
        borderColor = AppTheme.borderColor
        layer?.cornerRadius = 8

        textView.isRichText = false
        textView.drawsBackground = false
        textView.font = AppTheme.regular(13)
        textView.textColor = .labelColor
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainerInset = NSSize(width: 10, height: 8)
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.delegate = self
        textView.setAccessibilityLabel(L("自定义回答"))

        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.documentView = textView
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)

        placeholderLabel.font = AppTheme.regular(13)
        placeholderLabel.textColor = .placeholderTextColor
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        placeholderLabel.setAccessibilityElement(false)
        addSubview(placeholderLabel)

        heightConstraint = heightAnchor.constraint(equalToConstant: 44)
        heightConstraint.priority = .required
        NSLayoutConstraint.activate([
            heightConstraint,
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            placeholderLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            placeholderLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -10),
            placeholderLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12)
        ])
        refreshTextState()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func focus() { window?.makeFirstResponder(textView) }

    func textDidChange(_ notification: Notification) {
        refreshTextState()
        onChange?(textView.string)
    }

    func textDidBeginEditing(_ notification: Notification) {
        borderColor = AppTheme.accentColor.withAlphaComponent(0.58)
    }

    func textDidEndEditing(_ notification: Notification) {
        borderColor = AppTheme.borderColor
    }

    func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            onCancel?()
            return true
        }
        if commandSelector == #selector(NSResponder.insertNewline(_:)),
           NSEvent.modifierFlags.contains(.command) {
            onSubmit?()
            return true
        }
        return false
    }

    private func refreshTextState() {
        placeholderLabel.isHidden = !textView.string.isEmpty
        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }
        layoutManager.ensureLayout(for: textContainer)
        let used = layoutManager.usedRect(for: textContainer).height
        let target = min(132, max(44, ceil(used + textView.textContainerInset.height * 2 + 6)))
        if abs(heightConstraint.constant - target) > 0.5 {
            heightConstraint.constant = target
            superview?.layoutSubtreeIfNeeded()
        }
        scrollView.hasVerticalScroller = target >= 132
        textView.frame = NSRect(
            x: 0,
            y: 0,
            width: max(1, scrollView.contentSize.width),
            height: max(scrollView.contentSize.height, used + textView.textContainerInset.height * 2)
        )
    }

    private func refreshAppearance() {
        let enabled = textView.isEditable
        fillColor = enabled ? AppTheme.contentColor : AppTheme.contentColor.withAlphaComponent(0.65)
        borderColor = enabled ? AppTheme.borderColor : AppTheme.borderColor.withAlphaComponent(0.48)
        placeholderLabel.textColor = enabled ? .placeholderTextColor : .disabledControlTextColor
        needsDisplay = true
    }
}

final class ClarificationPanelView: ThemedSurfaceView {
    static let preferredHeight: CGFloat = 340
    var onSubmit: ((ClarificationAnswer) -> Void)?
    var onUseGeneratedResult: (() -> Void)?
    var onEnd: (() -> Void)?
    var onDismiss: (() -> Void)?
    var onPreferredHeightChanged: (() -> Void)?

    private let contentStack = TopAlignedStackView()
    private let contentScrollView = NSScrollView()
    private let activityIndicator = NSProgressIndicator()
    private let metaLabel = NSTextField(labelWithString: "")
    private let endButton = TalisActionButton(
        title: L("结束追问"), target: nil, action: nil,
        surface: .push, emphasis: .neutral
    )
    private let skipButton = TalisActionButton(
        title: L("跳过"), target: nil, action: nil,
        surface: .push, emphasis: .neutral
    )
    private let questionLabel = NSTextField(wrappingLabelWithString: "")
    private let optionsStack = NSStackView()
    private let answerSeparator = NSBox()
    private let customAnswerField = GrowingClarificationAnswerField()
    private let submitButton = TalisActionButton(
        title: L("下一题"), target: nil, action: nil,
        surface: .push, emphasis: .primary
    )
    private var submitMinimumWidthConstraint: NSLayoutConstraint!
    private let answerActions = NSStackView()
    private let errorContainer = ThemedSurfaceView()
    private let failureBottomSpacer = NSView()
    private let errorContentStack = NSStackView()
    private let errorTextStack = NSStackView()
    private let errorSymbol = NSImageView()
    private let errorTitle = NSTextField(wrappingLabelWithString: "")
    private let errorMessage = NSTextField(wrappingLabelWithString: "")
    private let errorSupportLabel = NSTextField(wrappingLabelWithString: "")
    private var failureTitleSource = ""
    private let errorRetryButton = TalisActionButton(
        title: L("重试"), target: nil, action: nil,
        surface: .push, emphasis: .primary
    )
    private var optionButtons: [ClarificationChoiceButton] = []
    private var currentQuestion: ClarificationQuestion?
    private var selectedOption: String?
    private var roundNumber = 1
    private var questionNumber = 1
    private var totalQuestions = 1
    private var isLoading = false
    private var isShowingNoQuestions = false
    private var restoredSkippedAnswer: ClarificationAnswer?
    private var retryAction: (() -> Void)?

    var preferredContentHeight: CGFloat {
        if !errorContainer.isHidden { return 184 }
        if isShowingNoQuestions { return 166 }
        let width = bounds.width > 0 ? bounds.width - 44 : 628
        let questionHeight = (questionLabel.stringValue as NSString).boundingRect(
            with: NSSize(width: width, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [.font: AppTheme.semibold(15)]
        ).height
        let optionsHeight = optionButtons.reduce(CGFloat(0)) { $0 + $1.height(for: width) }
        let answerGrowth = max(0, customAnswerField.frame.height - 44)
        return min(620, max(230, 184 + ceil(questionHeight) + optionsHeight
            + CGFloat(max(0, optionButtons.count - 1)) * 8 + answerGrowth))
    }
    var panelErrorIsVisibleForTesting: Bool { !errorContainer.isHidden }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureUI()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(question: ClarificationQuestion, round: Int, maximumRounds: Int, questionIndex: Int, totalQuestions: Int) {
        isShowingNoQuestions = false
        clearError()
        optionsStack.isHidden = false
        customAnswerField.isHidden = false
        answerSeparator.isHidden = false
        answerActions.isHidden = false
        contentScrollView.isHidden = false
        questionLabel.isHidden = false
        skipButton.isHidden = false
        submitButton.isHidden = false
        currentQuestion = question
        selectedOption = nil
        restoredSkippedAnswer = nil
        roundNumber = round
        questionNumber = questionIndex + 1
        self.totalQuestions = totalQuestions
        metaLabel.stringValue = totalQuestions > 1
            ? AppLocalization.format("追问 · 第 %@ 轮 · 问题 %@/%@", round, questionNumber, totalQuestions)
            : AppLocalization.format("追问 · 第 %@ 轮", round)
        metaLabel.toolTip = metaLabel.stringValue
        questionLabel.stringValue = question.question
        questionLabel.preferredMaxLayoutWidth = bounds.width > 0 ? bounds.width - 44 : 628
        customAnswerField.stringValue = ""
        submitButton.title = questionNumber < totalQuestions ? L("下一题") : L("提交本轮")
        submitMinimumWidthConstraint.constant = 112
        submitButton.setAccessibilityLabel(submitButton.title)
        submitButton.setEmphasis(.primary)
        submitButton.refreshAppearance()
        for button in optionButtons { optionsStack.removeArrangedSubview(button); button.removeFromSuperview() }
        optionButtons = []
        let width = bounds.width > 0 ? bounds.width - 44 : 628
        for option in question.options.prefix(4) {
            let button = ClarificationChoiceButton(optionValue: option)
            button.onPress = { [weak self] in self?.selectOption(option) }
            optionsStack.addArrangedSubview(button)
            button.widthAnchor.constraint(equalTo: optionsStack.widthAnchor).isActive = true
            button.heightAnchor.constraint(equalToConstant: button.height(for: width)).isActive = true
            optionButtons.append(button)
        }
        setLoading(false)
        AppTheme.announce(question.question, from: self)
    }

    func configureLoading() {
        isShowingNoQuestions = false
        clearError()
        currentQuestion = nil
        selectedOption = nil
        restoredSkippedAnswer = nil
        metaLabel.stringValue = L("追问 · 正在整理…")
        metaLabel.toolTip = metaLabel.stringValue
        questionLabel.stringValue = L("正在分析当前 Prompt，请稍候。")
        optionsStack.isHidden = true
        customAnswerField.isHidden = true
        answerSeparator.isHidden = true
        answerActions.isHidden = true
        contentScrollView.isHidden = false
        questionLabel.isHidden = false
        skipButton.isHidden = true
        submitButton.isHidden = true
        setLoading(true)
    }

    func configureNoQuestions() {
        isShowingNoQuestions = true
        currentQuestion = nil
        selectedOption = nil
        restoredSkippedAnswer = nil
        clearError()
        metaLabel.stringValue = L("追问 · 无需补充")
        metaLabel.toolTip = metaLabel.stringValue
        questionLabel.stringValue = L("当前 Prompt 信息已经足够明确。\n\n没有发现会显著影响执行的问题。可以直接使用整理后的版本，或返回原文。")
        optionsStack.isHidden = true
        customAnswerField.isHidden = true
        answerSeparator.isHidden = true
        answerActions.isHidden = false
        contentScrollView.isHidden = false
        questionLabel.isHidden = false
        skipButton.isHidden = true
        submitButton.isHidden = false
        submitButton.title = L("使用整理后的 Prompt")
        submitMinimumWidthConstraint.constant = 208
        submitButton.setAccessibilityLabel(submitButton.title)
        submitButton.isEnabled = true
        submitButton.setEmphasis(.primary)
        submitButton.refreshAppearance()
        setLoading(false)
        endButton.title = L("返回原文")
        endButton.setAccessibilityLabel(endButton.title)
        endButton.toolTip = L("关闭追问并保留原文")
        endButton.setEmphasis(.neutral)
        endButton.refreshAppearance()
        submitButton.isEnabled = true
        AppTheme.announce(L("当前 Prompt 信息已经足够明确，无需补充。"), from: self)
    }

    func setLoading(_ loading: Bool) {
        isLoading = loading
        if loading { clearError() }
        activityIndicator.isHidden = !loading
        if loading { activityIndicator.startAnimation(nil) } else { activityIndicator.stopAnimation(nil) }
        optionButtons.forEach { $0.isEnabled = !loading }
        customAnswerField.isEditable = !loading
        submitButton.isEnabled = !loading && hasAnswer
        skipButton.isEnabled = !loading
        endButton.isEnabled = true
        endButton.title = loading ? L("停止") : L("结束追问")
        endButton.surface = .push
        endButton.keepsPrimaryWhenInactive = true
        endButton.setAccessibilityLabel(endButton.title)
        endButton.toolTip = loading ? L("停止请求，保留当前回答") : L("结束追问并回到原文")
        endButton.image = loading ? AppTheme.primaryActionSymbol(named: "stop.fill") : nil
        endButton.imagePosition = loading ? .imageLeading : .noImage
        endButton.imageHugsTitle = true
        endButton.setEmphasis(loading ? .primary : .neutral)
        endButton.refreshAppearance()
        submitButton.setEmphasis(.primary)
        submitButton.refreshAppearance()
    }

    func showError(title: String, message: String, retryTitle: String, retry: @escaping () -> Void) {
        isShowingNoQuestions = false
        setLoading(false)
        metaLabel.stringValue = L("追问")
        metaLabel.toolTip = L("追问请求未完成")
        retryAction = retry
        errorTitle.stringValue = title
        failureTitleSource = AppLocalization.original(title)
        errorMessage.stringValue = message
        errorSupportLabel.stringValue = L("原文和本轮回答已保留。")
        errorRetryButton.title = retryTitle
        errorRetryButton.setAccessibilityLabel(retryTitle)
        errorRetryButton.refreshAppearance()
        // The symbol conveys the error; the content surface stays neutral so
        // the message and recovery action remain readable in every appearance.
        errorContainer.gradientColorsProvider = nil
        errorContainer.fillColor = AppTheme.contentColor
        errorContainer.borderColor = AppTheme.borderColor
        errorContainer.isHidden = false
        failureBottomSpacer.isHidden = false
        contentScrollView.isHidden = true
        answerSeparator.isHidden = true
        customAnswerField.isHidden = true
        answerActions.isHidden = true
        errorContainer.setAccessibilityLabel(AppLocalization.format("%@，%@原文和本轮回答已保留。", title, message))
        let separator = AppLocalization.isEnglish ? ": " : "，"
        let ending = AppLocalization.isEnglish ? " " + L("原文和本轮回答已保留。") : "，" + L("原文和本轮回答已保留。")
        AppTheme.announce(title + separator + message + ending, from: self)
    }

    func clearError() {
        retryAction = nil
        errorContainer.isHidden = true
        errorTitle.stringValue = ""
        errorMessage.stringValue = ""
        errorSupportLabel.stringValue = ""
        errorContainer.gradientColorsProvider = nil
        errorContainer.setAccessibilityLabel(nil)
        failureBottomSpacer.isHidden = true
    }
    func submitRestoredAnswer() {
        if let answer = restoredSkippedAnswer, !hasAnswer { onSubmit?(answer) }
        else { submitCurrentAnswer() }
    }
    func restoreAnswer(_ answer: ClarificationAnswer) {
        restoredSkippedAnswer = answer.skipped ? answer : nil
        if optionButtons.contains(where: { $0.optionValue == answer.answer }) { selectOption(answer.answer) }
        else if !answer.skipped { customAnswerField.stringValue = answer.answer }
        submitButton.isEnabled = !isLoading && hasAnswer
        AppTheme.styleButtonTitle(submitButton, primary: true)
    }
    func focusCustomAnswer() {
        layoutSubtreeIfNeeded()
        let top = contentStack.isFlipped ? 0 : max(0, contentStack.frame.height - contentScrollView.contentView.bounds.height)
        contentScrollView.contentView.scroll(to: NSPoint(x: 0, y: top))
        contentScrollView.reflectScrolledClipView(contentScrollView.contentView)
        customAnswerField.focus()
    }
    func focusAnswer() {
        layoutSubtreeIfNeeded()
        contentScrollView.contentView.scroll(to: .zero)
        contentScrollView.reflectScrolledClipView(contentScrollView.contentView)
        if isShowingNoQuestions {
            window?.makeFirstResponder(submitButton)
        } else if !customAnswerField.stringValue.isEmpty {
            customAnswerField.focus()
        } else {
            (optionButtons.first { $0.optionValue == selectedOption } ?? optionButtons.first)?.focus()
        }
    }
    private var hasAnswer: Bool {
        selectedOption != nil || !customAnswerField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    private func configureUI() {
        translatesAutoresizingMaskIntoConstraints = false
        fillColor = AppTheme.contentColor
        contentStack.orientation = .vertical
        contentStack.spacing = AppTheme.Spacing.section
        contentStack.alignment = .leading
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        metaLabel.font = AppTheme.medium(12)
        metaLabel.textColor = AppTheme.secondaryTextColor
        activityIndicator.style = .spinning
        activityIndicator.controlSize = .regular
        activityIndicator.isDisplayedWhenStopped = false
        activityIndicator.isHidden = true
        activityIndicator.setAccessibilityLabel(L("追问处理中"))
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.widthAnchor.constraint(equalToConstant: 18).isActive = true
        activityIndicator.heightAnchor.constraint(equalToConstant: 18).isActive = true
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        endButton.target = self
        endButton.action = #selector(endPressed)
        endButton.keepsPrimaryWhenInactive = true
        endButton.setEmphasis(.neutral)
        endButton.refreshAppearance()
        endButton.toolTip = L("结束追问并回到原文")
        endButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 118).isActive = true
        endButton.heightAnchor.constraint(equalToConstant: 36).isActive = true
        let header = NSStackView(views: [activityIndicator, metaLabel, spacer, endButton])
        header.spacing = 8
        header.alignment = .centerY
        questionLabel.font = AppTheme.semibold(15)
        questionLabel.textColor = .labelColor
        questionLabel.maximumNumberOfLines = 0
        questionLabel.lineBreakMode = .byWordWrapping
        questionLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        questionLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        optionsStack.orientation = .vertical
        optionsStack.spacing = AppTheme.Spacing.inline
        optionsStack.alignment = .leading
        optionsStack.translatesAutoresizingMaskIntoConstraints = false
        answerSeparator.boxType = .separator
        answerSeparator.translatesAutoresizingMaskIntoConstraints = false
        customAnswerField.onChange = { [weak self] _ in
            guard let self else { return }
            self.restoredSkippedAnswer = nil
            if !self.customAnswerField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                self.selectedOption = nil
                self.optionButtons.forEach { $0.setChoiceSelected(false) }
            }
            self.submitButton.isEnabled = !self.isLoading && self.hasAnswer
            AppTheme.styleButtonTitle(self.submitButton, primary: true)
            self.onPreferredHeightChanged?()
        }
        customAnswerField.onSubmit = { [weak self] in self?.submitCurrentAnswer() }
        customAnswerField.onCancel = { [weak self] in self?.onDismiss?() }
        submitButton.target = self
        submitButton.action = #selector(submitCurrentAnswer)
        submitButton.keepsPrimaryWhenInactive = true
        submitButton.setEmphasis(.primary)
        submitButton.refreshAppearance()
        skipButton.target = self
        skipButton.action = #selector(skipPressed)
        skipButton.toolTip = L("跳过这一题，保留为未知信息")
        skipButton.setEmphasis(.neutral)
        skipButton.refreshAppearance()
        skipButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 88).isActive = true
        skipButton.heightAnchor.constraint(equalToConstant: 36).isActive = true
        submitMinimumWidthConstraint = submitButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 112)
        submitMinimumWidthConstraint.isActive = true
        submitButton.setContentHuggingPriority(.required, for: .horizontal)
        submitButton.heightAnchor.constraint(equalToConstant: 36).isActive = true
        errorContainer.translatesAutoresizingMaskIntoConstraints = false
        errorContainer.drawsBorder = true
        errorContainer.layer?.cornerRadius = 14
        errorContainer.setContentHuggingPriority(.required, for: .vertical)
        errorContainer.setContentCompressionResistancePriority(.required, for: .vertical)
        errorContainer.gradientColorsProvider = nil
        errorContainer.borderColor = AppTheme.borderColor
        errorContainer.isHidden = true
        errorContainer.setAccessibilityElement(true)
        errorContainer.setAccessibilityRole(.group)
        errorSymbol.image = NSImage(
            systemSymbolName: "exclamationmark.triangle.fill",
            accessibilityDescription: nil
        )
        errorSymbol.image?.isTemplate = true
        errorSymbol.contentTintColor = AppTheme.errorTextColor
        errorSymbol.imageScaling = .scaleProportionallyDown
        errorSymbol.translatesAutoresizingMaskIntoConstraints = false
        errorSymbol.widthAnchor.constraint(equalToConstant: 20).isActive = true
        errorSymbol.heightAnchor.constraint(equalToConstant: 20).isActive = true
        errorSymbol.setAccessibilityElement(false)
        errorTitle.font = AppTheme.semibold(14)
        errorTitle.textColor = .labelColor
        errorTitle.maximumNumberOfLines = 0
        errorTitle.lineBreakMode = .byWordWrapping
        errorTitle.setContentCompressionResistancePriority(.required, for: .vertical)
        errorMessage.font = AppTheme.regular(13)
        errorMessage.textColor = .labelColor
        errorMessage.lineBreakMode = .byWordWrapping
        errorMessage.maximumNumberOfLines = 0
        errorMessage.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        errorSupportLabel.font = AppTheme.regular(12)
        errorSupportLabel.textColor = AppTheme.secondaryTextColor
        errorSupportLabel.lineBreakMode = .byWordWrapping
        errorSupportLabel.maximumNumberOfLines = 0
        errorSupportLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        errorRetryButton.target = self
        errorRetryButton.action = #selector(retryPressed)
        errorRetryButton.keepsPrimaryWhenInactive = true
        errorRetryButton.setEmphasis(.primary)
        errorRetryButton.refreshAppearance()
        errorRetryButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 94).isActive = true
        errorRetryButton.heightAnchor.constraint(equalToConstant: 36).isActive = true
        errorTextStack.orientation = .vertical
        errorTextStack.alignment = .leading
        errorTextStack.spacing = 5
        for view in [errorTitle, errorMessage, errorSupportLabel] {
            errorTextStack.addArrangedSubview(view)
        }
        errorTextStack.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        errorContentStack.orientation = .horizontal
        errorContentStack.alignment = .top
        errorContentStack.spacing = 12
        errorContentStack.addArrangedSubview(errorSymbol)
        errorContentStack.addArrangedSubview(errorTextStack)
        let errorActionSpacer = NSView()
        errorActionSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let errorActionRow = NSStackView(views: [errorActionSpacer, errorRetryButton])
        errorActionRow.orientation = .horizontal
        errorActionRow.alignment = .centerY
        let errorStack = NSStackView(views: [errorContentStack, errorActionRow])
        errorStack.orientation = .vertical
        errorStack.alignment = .leading
        errorStack.spacing = 14
        errorStack.translatesAutoresizingMaskIntoConstraints = false
        errorContentStack.widthAnchor.constraint(equalTo: errorStack.widthAnchor).isActive = true
        errorActionRow.widthAnchor.constraint(equalTo: errorStack.widthAnchor).isActive = true
        errorContainer.addSubview(errorStack)
        NSLayoutConstraint.activate([
            errorStack.leadingAnchor.constraint(equalTo: errorContainer.leadingAnchor, constant: 16),
            errorStack.trailingAnchor.constraint(equalTo: errorContainer.trailingAnchor, constant: -16),
            errorStack.topAnchor.constraint(equalTo: errorContainer.topAnchor, constant: 14),
            errorStack.bottomAnchor.constraint(equalTo: errorContainer.bottomAnchor, constant: -14)
        ])
        answerActions.orientation = .horizontal
        answerActions.alignment = .centerY
        answerActions.heightAnchor.constraint(equalToConstant: 36).isActive = true
        let bottomSpacer = NSView()
        bottomSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        for view in [skipButton, bottomSpacer, submitButton] {
            answerActions.addArrangedSubview(view)
        }
        failureBottomSpacer.setContentHuggingPriority(.defaultLow, for: .vertical)
        failureBottomSpacer.isHidden = true
        // Questions can be arbitrarily long; keep exit and answer actions outside the scroll area.
        contentScrollView.translatesAutoresizingMaskIntoConstraints = false
        contentScrollView.hasVerticalScroller = true
        contentScrollView.hasHorizontalScroller = false
        contentScrollView.autohidesScrollers = true
        contentScrollView.drawsBackground = false
        contentScrollView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        contentStack.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        for view in [questionLabel, optionsStack] {
            contentStack.addArrangedSubview(view)
            view.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true
        }
        contentScrollView.documentView = contentStack
        let layoutStack = NSStackView(views: [header, errorContainer, failureBottomSpacer, contentScrollView, answerSeparator, customAnswerField, answerActions])
        layoutStack.orientation = .vertical
        layoutStack.alignment = .leading
        layoutStack.spacing = 12
        layoutStack.detachesHiddenViews = true
        layoutStack.translatesAutoresizingMaskIntoConstraints = false
        for view in [header, errorContainer, failureBottomSpacer, contentScrollView, answerSeparator, customAnswerField, answerActions] {
            view.widthAnchor.constraint(equalTo: layoutStack.widthAnchor).isActive = true
        }
        addSubview(layoutStack)
        NSLayoutConstraint.activate([
            layoutStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            layoutStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            layoutStack.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            layoutStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),
            contentStack.widthAnchor.constraint(equalTo: contentScrollView.contentView.widthAnchor, constant: -12),
            contentScrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 64)
        ])
    }

    @objc func refreshLocalization() {
        let message = errorMessage.stringValue
        AppLocalization.refresh(self)
        errorMessage.stringValue = message
        errorTitle.stringValue = L(failureTitleSource)
        endButton.title = L(isLoading ? "停止" : "结束追问")
        endButton.toolTip = L(isLoading ? "停止请求，保留当前回答" : "结束追问并回到原文")
        skipButton.title = L("跳过")
        errorSupportLabel.stringValue = L("原文和本轮回答已保留。")
        errorRetryButton.title = AppLocalization.redisplay(errorRetryButton.title)
        metaLabel.stringValue = AppLocalization.redisplay(metaLabel.stringValue)
        questionLabel.stringValue = AppLocalization.redisplay(questionLabel.stringValue)
        if isShowingNoQuestions {
            submitButton.title = L("使用整理后的 Prompt")
            submitMinimumWidthConstraint.constant = 208
            endButton.title = L("返回原文")
            endButton.toolTip = L("关闭追问并保留原文")
        } else if currentQuestion != nil {
            submitButton.title = L(questionNumber < totalQuestions ? "下一题" : "提交本轮")
            submitMinimumWidthConstraint.constant = 112
            metaLabel.stringValue = totalQuestions > 1
                ? AppLocalization.format("追问 · 第 %@ 轮 · 问题 %@/%@", roundNumber, questionNumber, totalQuestions)
                : AppLocalization.format("追问 · 第 %@ 轮", roundNumber)
        }
        metaLabel.toolTip = errorContainer.isHidden ? metaLabel.stringValue : L("追问请求未完成")
        endButton.setAccessibilityLabel(endButton.title)
        submitButton.setAccessibilityLabel(submitButton.title)
        endButton.refreshAppearance()
        submitButton.refreshAppearance()
        errorRetryButton.refreshAppearance()
    }

    override func layout() {
        super.layout()
        let textWidth = max(120, bounds.width - 44)
        questionLabel.preferredMaxLayoutWidth = textWidth
    }
    private func selectOption(_ option: String) {
        selectedOption = option
        restoredSkippedAnswer = nil
        customAnswerField.stringValue = ""
        optionButtons.forEach { $0.setChoiceSelected($0.optionValue == option) }
        optionButtons.first { $0.optionValue == option }?.focus()
        submitButton.isEnabled = !isLoading && hasAnswer
        AppTheme.styleButtonTitle(submitButton, primary: true)
    }
    @objc private func submitCurrentAnswer() {
        if isShowingNoQuestions {
            onUseGeneratedResult?()
            return
        }
        guard !isLoading, let currentQuestion else { return }
        let custom = customAnswerField.stringValue
        guard let answer = custom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? selectedOption : custom, !answer.isEmpty else { focusCustomAnswer(); return }
        onSubmit?(ClarificationAnswer(question: currentQuestion.question, answer: answer))
    }
    @objc private func skipPressed() {
        guard !isLoading, let currentQuestion else { return }
        onSubmit?(ClarificationAnswer(question: currentQuestion.question, answer: "（用户跳过）", skipped: true))
    }
    @objc private func endPressed() { onEnd?() }
    @objc private func retryPressed() { retryAction?() }
}
