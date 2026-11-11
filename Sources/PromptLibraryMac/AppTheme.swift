import AppKit
import CoreText

enum AppTheme {
    static let editorFontSize: CGFloat = 16
    static let bodyFontSize: CGFloat = 13
    static let titleFontSize: CGFloat = 15

    static func registerBundledFonts() {
        let fileManager = FileManager.default
        let candidateURLs: [URL?] = [
            Bundle.main.url(forResource: "Montserrat", withExtension: "ttf", subdirectory: "Fonts"),
            Bundle.main.resourceURL?.appendingPathComponent("Fonts/Montserrat.ttf"),
            URL(fileURLWithPath: fileManager.currentDirectoryPath).appendingPathComponent("Resources/Fonts/Montserrat.ttf")
        ]

        for url in candidateURLs.compactMap({ $0 }) where fileManager.fileExists(atPath: url.path) {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    static let contentInset: CGFloat = 20
    static let cornerRadius: CGFloat = 10
    static let controlHeight: CGFloat = 32
    enum Spacing {
        static let small: CGFloat = 4
        static let inline: CGFloat = 8
        static let control: CGFloat = 12
        static let section: CGFloat = 16
        static let window: CGFloat = 20
    }
    static let editorToolbarHeight: CGFloat = 50
    static let editorFooterHeight: CGFloat = editorToolbarHeight + 37

    private static func adaptive(_ name: String, light: UInt32, dark: UInt32) -> NSColor {
        NSColor(name: name) { appearance in
            let value = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: CGFloat((value >> 16) & 255) / 255,
                           green: CGFloat((value >> 8) & 255) / 255,
                           blue: CGFloat(value & 255) / 255, alpha: 1)
        }
    }
    static let accentColor = adaptive("TalisViolet", light: 0x7137ED, dark: 0xB89AFF)
    static let accentTextColor = adaptive("TalisVioletText", light: 0x6031AF, dark: 0xD1BAFF)
    static let primaryTextColor = adaptive("TalisPrimaryText", light: 0xFFFFFF, dark: 0x241331)
    static let primaryActionColor = adaptive("TalisPrimaryAction", light: 0x7137ED, dark: 0x7A45E6)
    static let primaryActionTextColor = adaptive("TalisPrimaryActionText", light: 0xFFFFFF, dark: 0xFFFFFF)
    static let windowColor = adaptive("TalisPearlWindow", light: 0xF4F4F6, dark: 0x202023)
    static let contentColor = adaptive("TalisPearlContent", light: 0xFFFFFF, dark: 0x27272A)
    static let borderColor = adaptive("TalisLilacBorder", light: 0xDDDCE0, dark: 0x504D55)
    static let selectionColor = adaptive("TalisLilacSelection", light: 0xE8DCF9, dark: 0x49365F)
    static let modeButtonFill = adaptive("TalisModeButtonFill", light: 0xFCFCFD, dark: 0x323235)
    static let modeButtonHoverStart = adaptive("TalisModeButtonHoverStart", light: 0xF7F3FD, dark: 0x43394F)
    static let modeButtonHoverEnd = adaptive("TalisModeButtonHoverEnd", light: 0xEDE5F9, dark: 0x38313F)
    static let actionHoverStart = adaptive("TalisActionHoverStart", light: 0xEEEEF0, dark: 0x29292C)
    static let actionHoverEnd = adaptive("TalisActionHoverEnd", light: 0xE3E3E6, dark: 0x222225)

    static func regular(_ size: CGFloat) -> NSFont { .systemFont(ofSize: size) }
    static func medium(_ size: CGFloat) -> NSFont { .systemFont(ofSize: size, weight: .medium) }
    static func semibold(_ size: CGFloat) -> NSFont { .systemFont(ofSize: size, weight: .semibold) }

    // Keep supporting text readable on both system text and window surfaces.
    static let secondaryTextColor = NSColor(name: "TalisSecondaryText") { appearance in
        var color = NSColor.labelColor
        appearance.performAsCurrentDrawingAppearance {
            color = NSColor.labelColor.usingColorSpace(.sRGB)!.withAlphaComponent(0.72)
        }
        return color
    }

    static let errorTextColor = NSColor(name: "TalisErrorText") { appearance in
        var color = NSColor.systemRed
        appearance.performAsCurrentDrawingAppearance {
            color = NSColor.systemRed.blended(withFraction: 0.3, of: .labelColor) ?? .labelColor
        }
        return color
    }

    static func readableAccent(_ accent: NSColor) -> NSColor {
        NSColor(name: nil) { appearance in
            var color = accent
            appearance.performAsCurrentDrawingAppearance {
                color = accent.blended(withFraction: 0.35, of: .labelColor) ?? .labelColor
            }
            return color
        }
    }
    static let placeholderTextColor = accentTextColor
    static let placeholderFillColor = NSColor(name: "TalisPlaceholderFill") { appearance in
        var color = NSColor.clear
        appearance.performAsCurrentDrawingAppearance {
            color = accentColor.withAlphaComponent(0.028)
        }
        return color
    }
    static let placeholderActiveFillColor = NSColor(name: "TalisPlaceholderActiveFill") { appearance in
        var color = NSColor.clear
        appearance.performAsCurrentDrawingAppearance {
            color = accentColor.withAlphaComponent(0.075)
        }
        return color
    }

    static var reducesMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    static func configureWindow(_ window: NSWindow) {
        let isOverlay = window is NSPanel
        window.isOpaque = !isOverlay
        window.backgroundColor = isOverlay ? .clear : windowColor
        window.hasShadow = true
    }

    static func center(_ window: NSWindow, on screen: NSScreen?) {
        guard let screen = screen ?? NSScreen.main else {
            window.center()
            return
        }
        let visible = screen.visibleFrame
        let size = window.frame.size
        let origin = NSPoint(
            x: visible.midX - size.width / 2,
            y: visible.midY - size.height / 2
        )
        window.setFrameOrigin(origin)
    }

    static func styleTextField(_ field: NSTextField) {
        field.font = regular(13)
        field.controlSize = .regular
        field.bezelStyle = .roundedBezel
        field.isBezeled = true
        field.backgroundColor = contentColor
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }

    static func alignForm(_ form: NSGridView, labelWidth: CGFloat, spacing: CGFloat = 14) {
        form.column(at: 0).width = labelWidth
        form.column(at: 0).xPlacement = .trailing
        form.column(at: 1).xPlacement = .fill
        form.rowAlignment = .firstBaseline
        form.yPlacement = .center
        form.rowSpacing = spacing
        form.columnSpacing = 14
    }

    static func styleButton(_ button: NSButton, primary: Bool = false, glass: Bool = false) {
        if #available(macOS 26.0, *), glass {
            button.bezelStyle = .glass
        } else {
            button.bezelStyle = .push
        }
        button.controlSize = .regular
        button.font = medium(13)
        button.imageHugsTitle = true
        if #available(macOS 26.0, *), glass {
            button.borderShape = .capsule
        }
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: controlHeight).isActive = true
        button.bezelColor = primary ? (glass ? accentColor : primaryActionColor) : nil
        button.contentTintColor = primary ? (glass ? primaryTextColor : primaryActionTextColor) : .labelColor
        if #available(macOS 26.0, *) {
            button.tintProminence = primary ? .primary : .none
        }
        styleButtonTitle(button, primary: primary)
    }

    static func styleButtonTitle(_ button: NSButton, primary: Bool) {
        if primary {
            let usesGlass = if #available(macOS 26.0, *) { button.bezelStyle == .glass } else { false }
            button.bezelColor = button.isEnabled ? (usesGlass ? accentColor : primaryActionColor) : nil
            button.contentTintColor = button.isEnabled
                ? (usesGlass ? primaryTextColor : primaryActionTextColor)
                : .disabledControlTextColor
            if #available(macOS 26.0, *) { button.tintProminence = button.isEnabled ? .primary : .none }
        }
        guard button.imagePosition != .imageOnly else { return }
        let accessibilityLabel = button.accessibilityLabel()
        let usesAccentGlass: Bool
        if #available(macOS 26.0, *) {
            usesAccentGlass = button.bezelStyle == .glass && button.bezelColor != nil && button.isEnabled
        } else {
            usesAccentGlass = false
        }
        let isFilledPush = primary && !usesAccentGlass
        let color: NSColor = button.isEnabled
            ? ((primary || usesAccentGlass) ? (isFilledPush ? primaryActionTextColor : primaryTextColor) : (button.contentTintColor ?? .labelColor))
            : .disabledControlTextColor
        // Glass can ignore contentTintColor for text when a custom bezel color is used.
        button.attributedTitle = NSAttributedString(string: button.title, attributes: [
            .foregroundColor: color,
            .font: button.font ?? medium(13)
        ])
        if let accessibilityLabel { button.setAccessibilityLabel(accessibilityLabel) }
    }

    static func modeIcon(named name: String) -> NSImage? {
        let symbolNames = [
            "refine": "slider.horizontal.3",
            "regenerate": "arrow.triangle.2.circlepath",
            "clarify": "bubble.left.and.bubble.right"
        ]
        guard let symbolName = symbolNames[name],
              let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) else { return nil }
        image.isTemplate = true
        image.size = NSSize(width: 16, height: 16)
        return image
    }

    static func primarySymbol(named name: String) -> NSImage? {
        filledSymbol(named: name, color: primaryTextColor)
    }

    static func primaryActionSymbol(named name: String) -> NSImage? {
        filledSymbol(named: name, color: primaryActionTextColor)
    }

    /// Menu bar extras use a monochrome template image so macOS can tint it for
    /// light, dark, inactive, and increased-contrast menu bars.
    static func statusBarIcon() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSColor.black.setFill()
            NSBezierPath(
                roundedRect: NSRect(x: 3.25, y: 12.25, width: 11.5, height: 2.5),
                xRadius: 1.25,
                yRadius: 1.25
            ).fill()
            NSBezierPath(
                roundedRect: NSRect(x: 7.65, y: 3.0, width: 2.7, height: 11.75),
                xRadius: 1.2,
                yRadius: 1.2
            ).fill()
            return true
        }
        image.isTemplate = true
        return image
    }

    private static func filledSymbol(named name: String, color: NSColor) -> NSImage? {
        guard let base = NSImage(systemSymbolName: name, accessibilityDescription: nil) else { return nil }
        let image = base.copy() as! NSImage
        image.isTemplate = false
        let rect = NSRect(origin: .zero, size: base.size)
        image.lockFocus()
        base.draw(in: rect)
        color.set()
        rect.fill(using: .sourceAtop)
        image.unlockFocus()
        return image
    }

    static func configureContentScrollView(_ scrollView: NSScrollView) {
        // The opaque semantic content surface supplies the background. A separate
        // AppKit clip background can introduce desktop tint in dark appearance.
        scrollView.drawsBackground = false
        scrollView.contentView.drawsBackground = false
    }

    static func styleEditor(_ editor: NSTextView) {
        editor.insertionPointColor = accentColor
        editor.selectedTextAttributes = [.backgroundColor: selectionColor, .foregroundColor: NSColor.labelColor]
    }

    static func announce(_ message: String, from view: NSView) {
        NSAccessibility.post(element: view, notification: .announcementRequested, userInfo: [
            .announcement: message, .priority: NSAccessibilityPriorityLevel.medium.rawValue
        ])
    }

    static func attributedString(
        _ string: String,
        size: CGFloat,
        weight: NSFont.Weight = .regular,
        color: NSColor = .labelColor,
        alignment: NSTextAlignment = .left
    ) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment
        paragraphStyle.lineBreakMode = .byTruncatingTail

        let attributed = NSMutableAttributedString(
            string: string,
            attributes: [
                .font: baseFont(size: size, weight: weight),
                .foregroundColor: color,
                .paragraphStyle: paragraphStyle
            ]
        )
        attributed.addAttribute(.font, value: fallbackFont(size: size, weight: weight), range: NSRange(location: 0, length: attributed.length))
        applyLatinFont(to: attributed, size: size, weight: weight)
        return attributed
    }

    static func applyTextStyle(
        to label: NSTextField,
        text: String,
        size: CGFloat,
        weight: NSFont.Weight = .regular,
        color: NSColor = .labelColor,
        alignment: NSTextAlignment = .left
    ) {
        label.stringValue = text
        label.attributedStringValue = attributedString(text, size: size, weight: weight, color: color, alignment: alignment)
        label.invalidateIntrinsicContentSize()
    }

    private static func baseFont(size: CGFloat, weight: NSFont.Weight) -> NSFont {
        switch weight {
        case .semibold, .bold, .heavy, .black:
            return semibold(size)
        case .medium:
            return medium(size)
        default:
            return regular(size)
        }
    }

    private static func fallbackFont(size: CGFloat, weight: NSFont.Weight) -> NSFont {
        .systemFont(ofSize: size, weight: weight)
    }

    private static func applyLatinFont(to attributed: NSMutableAttributedString, size: CGFloat, weight: NSFont.Weight) {
        let latinFont = baseFont(size: size, weight: weight)
        let nsString = attributed.string as NSString
        let pattern = "[A-Za-z0-9_./:+\\-]+"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        regex.matches(in: attributed.string, range: NSRange(location: 0, length: nsString.length)).forEach { match in
            attributed.addAttribute(.font, value: latinFont, range: match.range)
        }
    }
}

/// A standard macOS material for the window background, below the controls.
/// AppKit supplies vibrancy, wallpaper blending and Reduce Transparency behavior.
final class WindowBackdropView: NSVisualEffectView {
    init(material: NSVisualEffectView.Material) {
        super.init(frame: .zero)
        self.material = material
        blendingMode = .behindWindow
        state = .followsWindowActiveState
        translatesAutoresizingMaskIntoConstraints = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

final class TopAlignedStackView: NSStackView {
    override var isFlipped: Bool { true }
}

/// Glass belongs to the small navigation/control layer, not the editor's text.
final class GlassToolGroup: NSView {
    init(content: NSView) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        let surface: NSView
        if #available(macOS 26.0, *) {
            let glass = NSGlassEffectView()
            glass.style = .regular
            glass.cornerRadius = 16
            if #available(macOS 27.0, *) {
                glass.effectIsInteractive = true
            }
            glass.contentView = content
            surface = glass
        } else {
            let material = NSVisualEffectView()
            material.material = .popover
            material.blendingMode = .withinWindow
            material.wantsLayer = true
            material.layer?.cornerRadius = 12
            material.addSubview(content)
            surface = material
        }
        surface.translatesAutoresizingMaskIntoConstraints = false
        addSubview(surface)
        var constraints = [
            surface.leadingAnchor.constraint(equalTo: leadingAnchor),
            surface.trailingAnchor.constraint(equalTo: trailingAnchor),
            surface.topAnchor.constraint(equalTo: topAnchor),
            surface.bottomAnchor.constraint(equalTo: bottomAnchor)
        ]
        if #unavailable(macOS 26.0) {
            constraints.append(contentsOf: [
                content.leadingAnchor.constraint(equalTo: surface.leadingAnchor, constant: 6),
                content.trailingAnchor.constraint(equalTo: surface.trailingAnchor, constant: -6),
                content.topAnchor.constraint(equalTo: surface.topAnchor, constant: 4),
                content.bottomAnchor.constraint(equalTo: surface.bottomAnchor, constant: -4)
            ])
        }
        NSLayoutConstraint.activate(constraints)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

}

/// Opaque content surfaces re-resolve semantic layer colors when appearance changes.
class ThemedSurfaceView: NSView {
    var fillColor: NSColor = AppTheme.contentColor { didSet { needsDisplay = true } }
    var gradientColorsProvider: (() -> [NSColor])? { didSet { needsDisplay = true } }
    var borderColor: NSColor = AppTheme.borderColor { didSet { needsDisplay = true } }
    var drawsBorder = true { didSet { needsDisplay = true } }
    private let fillGradient = CAGradientLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureSurface()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureSurface()
    }

    override var wantsUpdateLayer: Bool { true }

    private func configureSurface() {
        wantsLayer = true
        layer?.cornerRadius = AppTheme.cornerRadius
        layer?.masksToBounds = true
        fillGradient.cornerRadius = AppTheme.cornerRadius
        fillGradient.masksToBounds = true
        fillGradient.isHidden = true
        layer?.insertSublayer(fillGradient, at: 0)
    }

    override func layout() {
        super.layout()
        CATransaction.begin(); CATransaction.setDisableActions(true)
        fillGradient.frame = bounds
        CATransaction.commit()
    }

    override func updateLayer() {
        super.updateLayer()
        effectiveAppearance.performAsCurrentDrawingAppearance {
            if let colors = gradientColorsProvider?() {
                layer?.backgroundColor = NSColor.clear.cgColor
                fillGradient.colors = colors.map(\.cgColor)
                fillGradient.isHidden = false
            } else {
                fillGradient.isHidden = true
                layer?.backgroundColor = fillColor.cgColor
            }
            layer?.borderColor = borderColor.cgColor
            layer?.borderWidth = drawsBorder ? 1 : 0
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
}

/// Ordinary document/settings windows use the semantic window color. This keeps
/// desktop tint out of dense forms while the floating editor remains translucent.
final class WindowContentView: ThemedSurfaceView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        fillColor = AppTheme.windowColor
        drawsBorder = false
        layer?.cornerRadius = 0
        translatesAutoresizingMaskIntoConstraints = false
        let accent = GuidedAccentView(frame: .zero)
        accent.translatesAutoresizingMaskIntoConstraints = false
        addSubview(accent)
        NSLayoutConstraint.activate([
            accent.leadingAnchor.constraint(equalTo: leadingAnchor),
            accent.trailingAnchor.constraint(equalTo: trailingAnchor),
            accent.topAnchor.constraint(equalTo: topAnchor),
            accent.heightAnchor.constraint(equalToConstant: 150)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

/// One visible feedback channel for running, failure and interruption states.
final class FeedbackStackView: NSStackView {
    enum Tone { case working, error, neutral }
    var tone: Tone = .neutral { didSet { needsDisplay = true } }
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = 12
        edgeInsets = NSEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func updateLayer() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            let color: NSColor = tone == .working ? AppTheme.accentColor : tone == .error ? .systemRed : .labelColor
            layer?.backgroundColor = color.withAlphaComponent(tone == .neutral ? 0.035 : 0.12).cgColor
            layer?.borderWidth = tone == .neutral ? 0 : 1
            layer?.borderColor = color.withAlphaComponent(tone == .working ? 0.48 : 0.32).cgColor
        }
    }
    override func viewDidChangeEffectiveAppearance() { super.viewDidChangeEffectiveAppearance(); needsDisplay = true }
}
