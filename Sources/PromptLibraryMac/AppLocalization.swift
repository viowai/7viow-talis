import AppKit
import ObjectiveC

enum AppLanguage: String, CaseIterable {
    case system
    case simplifiedChinese = "zh-Hans"
    case english = "en"

    var title: String {
        switch self {
        case .system: return L("跟随系统")
        case .simplifiedChinese: return "简体中文"
        case .english: return "English"
        }
    }
}

enum AppLocalization {
    static let didChangeNotification = Notification.Name("TalisAppLanguageDidChange")
    private static let preferenceKey = "app.language"
    private static var cachedLanguage = ""
    private static var cachedTranslations: [String: String] = [:]
    private static var sourceByDisplayedText: [String: String] = [:]

    static var preference: AppLanguage {
        get {
            AppLanguage(rawValue: UserDefaults.standard.string(forKey: preferenceKey) ?? "") ?? .system
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: preferenceKey)
            NotificationCenter.default.post(name: didChangeNotification, object: nil)
        }
    }

    static var isEnglish: Bool {
        switch preference {
        case .english: return true
        case .simplifiedChinese: return false
        case .system:
            return Locale.preferredLanguages.first?.hasPrefix("zh") != true
        }
    }

    static func text(_ source: String) -> String {
        guard isEnglish else { return source }
        if cachedLanguage != "en" {
            cachedLanguage = "en"
            cachedTranslations = (NSDictionary(contentsOf: translationURL) as? [String: String]) ?? [:]
        }
        let displayed = cachedTranslations[source] ?? source
        sourceByDisplayedText[source] = source
        sourceByDisplayedText[displayed] = source
        return displayed
    }

    private static var translationURL: URL {
        if let url = Bundle.main.url(forResource: "Localizable", withExtension: "strings", subdirectory: nil, localization: "en") {
            return url
        }
        return Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/en.lproj/Localizable.strings")
    }

    static func format(_ source: String, _ arguments: Any...) -> String {
        var arguments = arguments.makeIterator()
        return text(source).components(separatedBy: "%@").reduce("") { result, component in
            result + component + (arguments.next().map { String(describing: $0) } ?? "")
        }
    }

    // Only call this for app-generated copy. User text is not a translation key.
    static func redisplay(_ value: String) -> String {
        L(original(value))
    }

    static func original(_ value: String) -> String {
        sourceByDisplayedText[value] ?? value
    }

    static var newTemplateBody: String {
        isEnglish ? """
        # Role
        You are [role].

        # Task
        Use [input] to complete [task].

        # Output
        - ...
        """ : """
        # 角色
        你是【角色】。

        # 任务
        请根据【输入内容】完成【目标任务】。

        # 输出格式
        - ...
        """
    }

    static func observe(_ observer: Any, selector: Selector) {
        NotificationCenter.default.removeObserver(observer, name: didChangeNotification, object: nil)
        NotificationCenter.default.addObserver(observer, selector: selector, name: didChangeNotification, object: nil)
    }

    static func bind(_ root: NSView) {
        for view in [root] + root.subviews.flatMap(allViews) {
            if let field = view as? NSTextField, !field.isEditable {
                _ = localizedOriginal(field, &localizationTitleKey, field.stringValue)
            } else if let button = view as? NSButton, !(view is NSPopUpButton) {
                _ = localizedOriginal(button, &localizationTitleKey, button.title)
            }
            if let field = view as? NSTextField {
                _ = localizedOriginal(field, &localizationPlaceholderKey, field.placeholderString)
            }
        }
    }
}

func L(_ source: String) -> String { AppLocalization.text(source) }

private var localizationTitleKey: UInt8 = 0
private var localizationTooltipKey: UInt8 = 0
private var localizationAccessibilityLabelKey: UInt8 = 0
private var localizationAccessibilityHelpKey: UInt8 = 0
private var localizationPlaceholderKey: UInt8 = 0
private var localizationSegmentsKey: UInt8 = 0

private func localizedOriginal(_ object: NSObject, _ key: UnsafeRawPointer, _ current: String?) -> String? {
    if let stored = objc_getAssociatedObject(object, key) as? String { return stored }
    guard let current, !current.isEmpty else { return nil }
    let original = AppLocalization.original(current)
    objc_setAssociatedObject(object, key, original, .OBJC_ASSOCIATION_COPY_NONATOMIC)
    return original
}

extension AppLocalization {
    // Keep each view's source text so switching back never translates an
    // already-translated string or changes editable user content.
    static func refresh(_ root: NSView) {
        for view in [root] + root.subviews.flatMap(allViews) {
            if let field = view as? NSTextField, !(field is NSSearchField), !field.isEditable,
               field.accessibilityIdentifier() != "settings-status" {
                if let original = localizedOriginal(field, &localizationTitleKey, field.stringValue) {
                    field.stringValue = original.isEmpty ? "" : L(original)
                }
            } else if let button = view as? NSButton, !(view is NSPopUpButton) {
                if let original = localizedOriginal(button, &localizationTitleKey, button.title) {
                    button.title = original.isEmpty ? "" : L(original)
                }
            }
            if let field = view as? NSTextField,
               let original = localizedOriginal(field, &localizationPlaceholderKey, field.placeholderString) {
                field.placeholderString = L(original)
            }
            if let popup = view as? NSPopUpButton { refresh(popup.menu) }
            if let segmented = view as? NSSegmentedControl {
                var originals = (objc_getAssociatedObject(segmented, &localizationSegmentsKey) as? [String]) ?? []
                for index in 0..<segmented.segmentCount {
                    let current = segmented.label(forSegment: index) ?? ""
                    let original = originals.indices.contains(index) ? originals[index] : current
                    segmented.setLabel(L(original), forSegment: index)
                    if originals.count < segmented.segmentCount { originals.append(current) }
                }
                objc_setAssociatedObject(segmented, &localizationSegmentsKey, originals, .OBJC_ASSOCIATION_COPY_NONATOMIC)
            }
            if let original = localizedOriginal(view, &localizationTooltipKey, view.toolTip) {
                view.toolTip = L(original)
            }
            if let original = localizedOriginal(view, &localizationAccessibilityLabelKey, view.accessibilityLabel()) {
                view.setAccessibilityLabel(L(original))
            }
            if let original = localizedOriginal(view, &localizationAccessibilityHelpKey, view.accessibilityHelp()) {
                view.setAccessibilityHelp(L(original))
            }
        }
    }

    static func refresh(_ menu: NSMenu?) {
        guard let menu else { return }
        if let original = localizedOriginal(menu, &localizationTitleKey, menu.title) { menu.title = L(original) }
        for item in menu.items {
            if let original = localizedOriginal(item, &localizationTitleKey, item.title) { item.title = L(original) }
            if let original = localizedOriginal(item, &localizationTooltipKey, item.toolTip) { item.toolTip = L(original) }
            refresh(item.submenu)
        }
    }

    private static func allViews(_ view: NSView) -> [NSView] {
        // NSSearchField owns private text-rendering subviews. Translating those
        // implementation details can duplicate or clip the public placeholder.
        if view is NSSearchField { return [view] }
        return [view] + view.subviews.flatMap(allViews)
    }
}
