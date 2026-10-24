import AppKit
import CoreText

enum AppTheme {
    static let editorFontSize: CGFloat = 15
    static let bodyFontSize: CGFloat = 12
    static let titleFontSize: CGFloat = 13

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

    static func regular(_ size: CGFloat) -> NSFont {
        NSFont(name: "Montserrat-Regular", size: size)
            ?? NSFont(name: "Montserrat", size: size)
            ?? .systemFont(ofSize: size)
    }

    static func medium(_ size: CGFloat) -> NSFont {
        NSFont(name: "Montserrat-Medium", size: size)
            ?? NSFont(name: "Montserrat", size: size)
            ?? .systemFont(ofSize: size, weight: .medium)
    }

    static func semibold(_ size: CGFloat) -> NSFont {
        NSFont(name: "Montserrat-SemiBold", size: size)
            ?? NSFont(name: "Montserrat", size: size)
            ?? .systemFont(ofSize: size, weight: .semibold)
    }

    static func configureGlassWindow(_ window: NSWindow) {
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
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
