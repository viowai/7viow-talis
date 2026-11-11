import AppKit

/// A shared action button with one stable icon and label. Pointer and press
/// states change only the button surface so the control stays calm and native.
class TalisActionButton: NSButton {
    enum Emphasis {
        case neutral
        case primary
    }

    enum Surface {
        case glass
        case push
    }

    private(set) var isHovering = false
    private var hoverTrackingArea: NSTrackingArea?
    private var windowObservers: [NSObjectProtocol] = []
    private var windowActiveOverride: Bool?

    var emphasis: Emphasis = .neutral {
        didSet { refreshAppearance() }
    }
    var keepsPrimaryWhenInactive = false {
        didSet { refreshAppearance() }
    }
    var emphasisColorOverride: NSColor? {
        didSet { refreshAppearance() }
    }
    var surface: Surface = .glass {
        didSet { refreshAppearance() }
    }

    init(title: String, target: AnyObject?, action: Selector?,
         surface: Surface = .glass, emphasis: Emphasis = .neutral) {
        self.surface = surface
        self.emphasis = emphasis
        super.init(frame: .zero)
        self.title = title
        self.target = target
        self.action = action
        wantsLayer = true
        layer?.masksToBounds = true
        font = AppTheme.medium(14)
        imageHugsTitle = true
        configureNativeSurface()
        refreshAppearance()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        windowObservers.forEach(NotificationCenter.default.removeObserver)
    }

    override var isEnabled: Bool {
        didSet {
            if !isEnabled { isHovering = false }
            refreshAppearance()
        }
    }

    override var isHighlighted: Bool {
        didSet { refreshAppearance() }
    }

    override func layout() {
        super.layout()
        guard let layer else { return }
        layer.cornerRadius = bounds.height / 2
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        windowObservers.forEach(NotificationCenter.default.removeObserver)
        windowObservers.removeAll()
        guard let window else {
            refreshAppearance()
            return
        }
        windowObservers.append(NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in self?.refreshAppearance() })
        windowObservers.append(NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in self?.refreshAppearance() })
        refreshAppearance()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTrackingArea { removeTrackingArea(hoverTrackingArea) }
        let area = NSTrackingArea(
            rect: .zero,
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
        setHovering(true)
    }

    override func mouseExited(with event: NSEvent) {
        setHovering(false)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        isEnabled
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        refreshAppearance()
    }

    func setHovering(_ hovering: Bool) {
        let next = hovering && isEnabled
        guard next != isHovering else { return }
        isHovering = next
        refreshAppearance()
    }

    func setEmphasis(_ emphasis: Emphasis) {
        guard self.emphasis != emphasis else { return }
        self.emphasis = emphasis
    }

    func setWindowActive(_ active: Bool) {
        windowActiveOverride = active
        refreshAppearance()
    }

    func refreshAppearance() {
        let enabled = isEnabled
        let windowActive = windowActiveOverride ?? window?.isKeyWindow ?? true
        let primary = enabled && emphasis == .primary && (windowActive || keepsPrimaryWhenInactive)
        let hovered = enabled && isHovering
        let customPrimarySurface = primary && surface == .push
        let emphasisColor = emphasisColorOverride ?? AppTheme.primaryActionColor
        configureNativeSurface()

        isBordered = !customPrimarySurface
        if customPrimarySurface {
            effectiveAppearance.performAsCurrentDrawingAppearance {
                let background = isHighlighted
                    ? emphasisColor.blended(withFraction: 0.12, of: .black)!
                    : hovered
                        ? emphasisColor.blended(withFraction: 0.08, of: .black)!
                        : emphasisColor
                layer?.backgroundColor = background.cgColor
                layer?.borderWidth = 1
                layer?.borderColor = emphasisColor.withAlphaComponent(0.72).cgColor
                layer?.cornerRadius = bounds.height / 2
            }
            bezelColor = isHighlighted
                ? emphasisColor.blended(withFraction: 0.12, of: .black)!
                : hovered
                    ? emphasisColor.blended(withFraction: 0.08, of: .black)!
                    : emphasisColor
            contentTintColor = AppTheme.primaryActionTextColor
        } else if primary {
            layer?.backgroundColor = NSColor.clear.cgColor
            layer?.borderWidth = 0
            bezelColor = hovered
                ? (emphasisColorOverride ?? AppTheme.primaryActionColor).blended(withFraction: 0.08, of: .black)!
                : (surface == .glass ? (emphasisColorOverride ?? AppTheme.accentColor) : emphasisColor)
            contentTintColor = surface == .glass ? AppTheme.primaryTextColor : AppTheme.primaryActionTextColor
        } else if hovered {
            effectiveAppearance.performAsCurrentDrawingAppearance {
                layer?.backgroundColor = NSColor.clear.cgColor
                layer?.borderWidth = 0
                layer?.borderColor = NSColor.clear.cgColor
            }
            bezelColor = isHighlighted ? AppTheme.actionHoverEnd : AppTheme.actionHoverStart
            contentTintColor = enabled ? .labelColor : .disabledControlTextColor
        } else {
            layer?.backgroundColor = NSColor.clear.cgColor
            layer?.borderWidth = 0
            bezelColor = nil
            contentTintColor = enabled ? .labelColor : .disabledControlTextColor
        }

        if #available(macOS 26.0, *) {
            tintProminence = primary ? .primary : .none
        }
        let foreground = contentTintColor ?? NSColor.labelColor
        image?.isTemplate = true
        attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .font: font ?? AppTheme.medium(14),
                .foregroundColor: enabled ? foreground : NSColor.disabledControlTextColor
            ]
        )
        invalidateIntrinsicContentSize()
        superview?.needsLayout = true
        layer?.transform = CATransform3DIdentity
        needsDisplay = true
        window?.invalidateCursorRects(for: self)
    }

    private func configureNativeSurface() {
        controlSize = .large
        if #available(macOS 26.0, *) {
            bezelStyle = surface == .glass ? .glass : .push
            borderShape = .capsule
        } else {
            bezelStyle = .push
        }
        isBordered = true
        setContentCompressionResistancePriority(.required, for: .horizontal)
    }

}

final class ModeHoverButton: TalisActionButton {
    init(title: String, target: AnyObject?, action: Selector?) {
        super.init(title: title, target: target, action: action, surface: .glass, emphasis: .neutral)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
