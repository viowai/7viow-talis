import AppKit
import TalisCore

private final class ClarificationChoiceButton: NSButton {
    let optionValue: String
    var onPress: (() -> Void)?

    private var isChoiceSelected = false
    private var isHovering = false
    private var hoverTrackingArea: NSTrackingArea?

    init(optionValue: String) {
        self.optionValue = optionValue
        super.init(frame: .zero)
        title = optionValue
        target = self
        action = #selector(pressed)
        isBordered = false
        alignment = .left
        imagePosition = .imageLeading
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        toolTip = "选择后点击下一题"
        setAccessibilityLabel(optionValue)
        updateAppearance()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTrackingArea {
            removeTrackingArea(hoverTrackingArea)
        }
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        hoverTrackingArea = trackingArea
    }

    override func mouseEntered(with event: NSEvent) {
        isHovering = true
        updateAppearance()
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
        updateAppearance()
    }

    func setChoiceSelected(_ selected: Bool) {
        isChoiceSelected = selected
        updateAppearance()
    }

    private func updateAppearance() {
        let emphasized = isChoiceSelected || isHovering
        let color: NSColor = emphasized ? .systemPurple : .secondaryLabelColor
        let font = isChoiceSelected ? AppTheme.medium(12) : AppTheme.regular(12)
        attributedTitle = NSAttributedString(
            string: optionValue,
            attributes: [.foregroundColor: color, .font: font]
        )
        image = NSImage(
            systemSymbolName: isChoiceSelected ? "checkmark.circle.fill" : "circle",
            accessibilityDescription: isChoiceSelected ? "已选择" : "未选择"
        )
        image?.isTemplate = true
        contentTintColor = color
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    @objc private func pressed() {
        onPress?()
    }
}

final class ClarificationPanelView: NSVisualEffectView, NSTextFieldDelegate {
    static let preferredHeight: CGFloat = 252

    var onSubmit: ((ClarificationAnswer) -> Void)?

    private let contentStack = NSStackView()
    private let metaLabel = NSTextField(labelWithString: "")
    private let skipButton = NSButton(title: "跳过", target: nil, action: nil)
    private let questionLabel = NSTextField(wrappingLabelWithString: "")
    private let optionsStack = NSStackView()
    private let customAnswerField = NSTextField()
    private let submitButton = NSButton(title: "下一题", target: nil, action: nil)
    private var optionButtons: [ClarificationChoiceButton] = []
    private var currentQuestion: ClarificationQuestion?
    private var selectedOption: String?
    private var roundNumber = 1
    private var questionNumber = 1
    private var totalQuestions = 1

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(
        question: ClarificationQuestion,
        round: Int,
        maximumRounds: Int,
        questionIndex: Int,
        totalQuestions: Int
    ) {
        currentQuestion = question
        selectedOption = nil
        roundNumber = round
        questionNumber = questionIndex + 1
        self.totalQuestions = totalQuestions
        metaLabel.stringValue = "第 \(round)/\(maximumRounds) 轮 · 问题 \(questionNumber)/\(totalQuestions)"
        questionLabel.stringValue = question.question
        customAnswerField.stringValue = ""
        customAnswerField.placeholderString = "或输入自定义回答"
        submitButton.title = questionNumber < totalQuestions ? "下一题" : "提交本轮"

        optionButtons.forEach { button in
            optionsStack.removeArrangedSubview(button)
            button.removeFromSuperview()
        }
        optionButtons = []

        for option in question.options.prefix(4) {
            let button = ClarificationChoiceButton(optionValue: option)
            button.onPress = { [weak self, weak button] in
                guard let self, let button else { return }
                self.selectOption(button.optionValue)
            }
            optionsStack.addArrangedSubview(button)
            button.widthAnchor.constraint(equalTo: optionsStack.widthAnchor).isActive = true
            button.heightAnchor.constraint(equalToConstant: 24).isActive = true
            optionButtons.append(button)
        }
        updateSubmitState()
        setLoading(false)
    }

    func setLoading(_ loading: Bool) {
        optionButtons.forEach { $0.isEnabled = !loading }
        customAnswerField.isEnabled = !loading
        submitButton.isEnabled = !loading && hasAnswer
        skipButton.isEnabled = !loading
        if loading {
            metaLabel.stringValue = "第 \(roundNumber)/\(ClarificationSession.maximumRounds) 轮 · 正在结合本轮回答…"
        }
    }

    func focusCustomAnswer() {
        window?.makeFirstResponder(customAnswerField)
    }

    func controlTextDidChange(_ obj: Notification) {
        guard obj.object as? NSTextField === customAnswerField else { return }
        if !customAnswerField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            selectedOption = nil
            optionButtons.forEach { $0.setChoiceSelected(false) }
        }
        updateSubmitState()
    }

    private var hasAnswer: Bool {
        selectedOption != nil
            || !customAnswerField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func configureUI() {
        translatesAutoresizingMaskIntoConstraints = false
        material = .hudWindow
        blendingMode = .withinWindow
        state = .active
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.borderColor = NSColor.systemPurple.withAlphaComponent(0.42).cgColor
        layer?.borderWidth = 1
        layer?.masksToBounds = true

        contentStack.orientation = .vertical
        contentStack.spacing = 7
        contentStack.alignment = .leading
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        metaLabel.font = AppTheme.medium(11)
        metaLabel.textColor = .systemPurple
        metaLabel.lineBreakMode = .byTruncatingTail

        skipButton.target = self
        skipButton.action = #selector(skipPressed)
        skipButton.isBordered = false
        skipButton.font = AppTheme.medium(11)
        skipButton.contentTintColor = .secondaryLabelColor
        skipButton.toolTip = "不回答当前问题"

        let headerSpacer = NSView()
        headerSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let header = NSStackView(views: [metaLabel, headerSpacer, skipButton])
        header.orientation = .horizontal
        header.spacing = 8
        header.alignment = .centerY
        header.translatesAutoresizingMaskIntoConstraints = false

        questionLabel.font = AppTheme.semibold(13)
        questionLabel.textColor = .labelColor
        questionLabel.maximumNumberOfLines = 3
        questionLabel.lineBreakMode = .byWordWrapping
        questionLabel.setContentCompressionResistancePriority(.required, for: .vertical)

        optionsStack.orientation = .vertical
        optionsStack.spacing = 2
        optionsStack.alignment = .leading
        optionsStack.translatesAutoresizingMaskIntoConstraints = false

        customAnswerField.font = AppTheme.regular(12)
        customAnswerField.controlSize = .regular
        customAnswerField.bezelStyle = .roundedBezel
        customAnswerField.delegate = self
        customAnswerField.target = self
        customAnswerField.action = #selector(submitCurrentAnswer)

        submitButton.target = self
        submitButton.action = #selector(submitCurrentAnswer)
        submitButton.bezelStyle = .rounded
        submitButton.controlSize = .regular
        submitButton.font = AppTheme.medium(12)

        let customRow = NSStackView(views: [customAnswerField, submitButton])
        customRow.orientation = .horizontal
        customRow.spacing = 8
        customRow.alignment = .centerY
        customRow.translatesAutoresizingMaskIntoConstraints = false

        contentStack.addArrangedSubview(header)
        contentStack.addArrangedSubview(questionLabel)
        contentStack.addArrangedSubview(optionsStack)
        contentStack.addArrangedSubview(customRow)
        addSubview(contentStack)

        NSLayoutConstraint.activate([
            contentStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            contentStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            contentStack.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            contentStack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -10),
            header.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            questionLabel.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            optionsStack.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            customRow.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            customAnswerField.heightAnchor.constraint(equalToConstant: 28),
            submitButton.heightAnchor.constraint(equalToConstant: 28),
            submitButton.widthAnchor.constraint(equalToConstant: 88)
        ])
    }

    private func selectOption(_ option: String) {
        selectedOption = option
        customAnswerField.stringValue = ""
        optionButtons.forEach { button in
            button.setChoiceSelected(button.optionValue == option)
        }
        updateSubmitState()
    }

    private func updateSubmitState() {
        submitButton.isEnabled = hasAnswer
    }

    @objc private func submitCurrentAnswer() {
        guard let currentQuestion else { return }
        let customAnswer = customAnswerField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let answer = customAnswer.isEmpty ? selectedOption : customAnswer
        guard let answer, !answer.isEmpty else {
            NSSound.beep()
            focusCustomAnswer()
            return
        }
        onSubmit?(ClarificationAnswer(question: currentQuestion.question, answer: answer))
    }

    @objc private func skipPressed() {
        guard let currentQuestion else { return }
        onSubmit?(ClarificationAnswer(question: currentQuestion.question, answer: "（用户跳过）", skipped: true))
    }
}
