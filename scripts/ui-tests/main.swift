import AppKit
import Carbon
import ScreenCaptureKit
import TalisCore

setbuf(stdout, nil)
let originalAppLanguage = UserDefaults.standard.string(forKey: "app.language")
UserDefaults.standard.set("zh-Hans", forKey: "app.language")

let clipboardSnapshot = NSPasteboard.general.pasteboardItems?.map { item in
    Dictionary(uniqueKeysWithValues: item.types.compactMap { type in item.data(forType: type).map { (type, $0) } })
} ?? []
func restoreClipboard() {
    if let originalAppLanguage {
        UserDefaults.standard.set(originalAppLanguage, forKey: "app.language")
    } else {
        UserDefaults.standard.removeObject(forKey: "app.language")
    }
    let items = clipboardSnapshot.map { values -> NSPasteboardItem in
        let item = NSPasteboardItem()
        values.forEach { item.setData($0.value, forType: $0.key) }
        return item
    }
    NSPasteboard.general.clearContents()
    NSPasteboard.general.writeObjects(items)
}

var checks = 0
func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { restoreClipboard(); fputs("FAIL: \(message)\n", stderr); exit(1) }
    checks += 1
}
func views(_ root: NSView) -> [NSView] { [root] + root.subviews.flatMap(views) }
func transientTemplate(_ draft: TemplateDraft) -> UserPromptTemplate {
    UserPromptTemplate(id: UUID(), title: draft.title, detail: draft.detail, body: draft.body, createdAt: Date(), updatedAt: Date())
}
func button(_ title: String, in root: NSView) -> NSButton {
    guard let result = views(root).compactMap({ $0 as? NSButton }).first(where: { $0.title == title }) else {
        fputs("FAIL: button not found: \(title)\n", stderr); exit(1)
    }
    return result
}
func clarificationAskResponse(question: String, options: [String]) -> String {
    let object: [String: Any] = [
        "status": "ask",
        "questions": [["question": question, "options": options]]
    ]
    return String(data: try! JSONSerialization.data(withJSONObject: object), encoding: .utf8)!
}
func clarificationFinalResponse(_ prompt: String) -> String {
    let object: [String: Any] = ["status": "final", "prompt": prompt]
    return String(data: try! JSONSerialization.data(withJSONObject: object), encoding: .utf8)!
}
func activate(_ button: NSButton) {
    guard button.isEnabled, let action = button.action else { fputs("FAIL: cannot activate \(button.title)\n", stderr); exit(1) }
    NSApp.sendAction(action, to: button.target, from: button)
}
func triggerAction(_ control: NSControl) {
    guard let action = control.action else { fputs("FAIL: control has no action\n", stderr); exit(1) }
    NSApp.sendAction(action, to: control.target, from: control)
}
func menuItem(_ title: String, in root: NSView) -> NSMenuItem {
    let items = views(root).compactMap { $0 as? NSPopUpButton }.flatMap { $0.menu?.items ?? [] }
    guard let item = items.first(where: { $0.title == title }) else {
        fputs("FAIL: menu item not found: \(title)\n", stderr); exit(1)
    }
    return item
}
func activate(_ item: NSMenuItem) {
    guard item.isEnabled, let action = item.action else { fputs("FAIL: cannot activate \(item.title)\n", stderr); exit(1) }
    NSApp.sendAction(action, to: item.target, from: item)
}
func pump(until condition: () -> Bool, seconds: TimeInterval = 2) {
    let deadline = Date().addingTimeInterval(seconds)
    while !condition() && Date() < deadline { RunLoop.current.run(until: Date().addingTimeInterval(0.01)) }
}
func key(_ text: String, code: UInt16, flags: NSEvent.ModifierFlags = []) -> NSEvent {
    NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0,
                    windowNumber: 0, context: nil, characters: text, charactersIgnoringModifiers: text,
                    isARepeat: false, keyCode: code)!
}
func contrast(_ foreground: NSColor, _ background: NSColor, appearance: NSAppearance.Name) -> Double {
    var fg: NSColor!, bg: NSColor!
    NSAppearance(named: appearance)!.performAsCurrentDrawingAppearance {
        fg = foreground.usingColorSpace(.sRGB)!
        bg = background.usingColorSpace(.sRGB)!
    }
    let alpha = fg.alphaComponent
    let rgb = [fg.redComponent, fg.greenComponent, fg.blueComponent]
    let base = [bg.redComponent, bg.greenComponent, bg.blueComponent]
    func luminance(_ color: [CGFloat]) -> Double {
        zip(color, [0.2126, 0.7152, 0.0722]).reduce(0) { sum, item in
            let c = Double(item.0)
            return sum + (c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)) * item.1
        }
    }
    let front = zip(rgb, base).map { $0.0 * alpha + $0.1 * (1 - alpha) }
    let a = luminance(front), b = luminance(base)
    return (max(a, b) + 0.05) / (min(a, b) + 0.05)
}
func colorsMatch(_ lhs: NSColor, _ rhs: NSColor, appearance: NSAppearance.Name = .aqua) -> Bool {
    var left: NSColor!
    var right: NSColor!
    NSAppearance(named: appearance)!.performAsCurrentDrawingAppearance {
        left = lhs.usingColorSpace(.sRGB)
        right = rhs.usingColorSpace(.sRGB)
    }
    return left == right
}

final class FixtureProtocol: URLProtocol {
    static var delay: TimeInterval = 0.08
    static var started = 0
    static var stopped = 0
    static var lastSystem = ""
    static var lastMessages: [[String: String]] = []
    static var status = 200
    static var content = "结果【待填事项】："
    static var contentQueue: [String] = []
    static var transportError: URLError?
    static var rawBody: Data?
    private var responseWork: DispatchWorkItem?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.started += 1
        var data = request.httpBody ?? Data()
        if data.isEmpty, let stream = request.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count <= 0 { break }
                data.append(buffer, count: count)
            }
        }
        if let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let messages = payload["messages"] as? [[String: String]] {
            Self.lastSystem = messages.first?["content"] ?? ""
            Self.lastMessages = messages
        }
        let responseError = Self.transportError
        let rawResponse = Self.rawBody
        let responseContent = responseError == nil
            ? (Self.contentQueue.isEmpty ? Self.content : Self.contentQueue.removeFirst())
            : nil
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            if let error = responseError { self.client?.urlProtocol(self, didFailWithError: error); return }
            let data = rawResponse ?? (try! JSONSerialization.data(withJSONObject: ["choices": [["message": ["content": responseContent ?? Self.content]]]]))
            self.client?.urlProtocol(self, didReceive: HTTPURLResponse(url: self.request.url!, statusCode: Self.status, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
            self.client?.urlProtocol(self, didLoad: data)
            self.client?.urlProtocolDidFinishLoading(self)
        }
        responseWork = work
        DispatchQueue.global().asyncAfter(deadline: .now() + Self.delay, execute: work)
    }
    override func stopLoading() { Self.stopped += 1; responseWork?.cancel() }
}

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
let isUIReview = Bundle.main.object(forInfoDictionaryKey: "TalisUIReview") as? Bool == true
expect(AppIdentity.current.isPreview, "UI checks use the isolated Preview identity")
var shortcutRegistrationAttempts = 0
let shortcutConflict = OSStatus(eventHotKeyExistsErr)
let failedShortcut = GlobalHotKey(registerShortcut: { _ in
    shortcutRegistrationAttempts += 1
    return shortcutConflict
}, onPressed: {})
expect(failedShortcut.register() == shortcutConflict && shortcutRegistrationAttempts == 1, "shortcut conflict is reported to the caller instead of silently succeeding")
expect(failedShortcut.register() == shortcutConflict && shortcutRegistrationAttempts == 2, "failed shortcut registration removes its handler and can be retried")
let configuration = URLSessionConfiguration.ephemeral
configuration.protocolClasses = [FixtureProtocol.self]
let session = URLSession(configuration: configuration)
let client = OpenAIClient(apiKey: "fictional-ui-key", modelOption: OpenAIClient.modelOption(for: "deepseek"),
                          urlSession: session, modelResolver: ModelResolver(defaults: nil))
if !isUIReview {
let announcementTarget = NSTextField(labelWithString: "当前服务状态")
AppTheme.announce("订阅设置已保存。", from: announcementTarget)
expect(announcementTarget.accessibilityHelp() == nil && announcementTarget.stringValue == "当前服务状态",
       "a transient announcement does not become stale persistent accessibility help")
announcementTarget.setAccessibilityHelp("选择要使用的服务")
AppTheme.announce("临时操作反馈", from: announcementTarget)
expect(announcementTarget.accessibilityHelp() == "选择要使用的服务",
       "a transient announcement preserves the control's existing help")
var operationClient = client
let controller = PromptWindowController(clientFactory: { operationClient }, motionPreference: { true }, templatePreviewFactory: { TemplatePreviewWindowController(draft: $0, persistDraft: transientTemplate) })
let root = controller.window!.contentView!
let editor = views(root).compactMap { $0 as? PromptTextView }.first!
func edit(_ text: String) {
    editor.string = text
    editor.setSelectedRange(NSRange(location: (text as NSString).length, length: 0))
    controller.textDidChange(Notification(name: NSText.didChangeNotification, object: editor))
}
root.layoutSubtreeIfNeeded()
let identity = views(root).compactMap { $0 as? GuidedIdentityView }.first!
let identitySymbols = views(identity).compactMap { $0 as? NSImageView }
expect(identitySymbols.count == 1 && identitySymbols[0].image != nil && identitySymbols[0].bounds.width >= 24, "identity uses a real available system symbol with dedicated bounds")
func inspectGuideLayout(_ guide: ShortcutGuideView) {
    root.layoutSubtreeIfNeeded()
    guide.layoutSubtreeIfNeeded()
    expect(guide.arrangedSubviews.count == guide.entries.count, "each shortcut has its own native row")
    var lastFrame: NSRect?
    for row in guide.arrangedSubviews {
        expect(row.frame.height >= 19, "shortcut rows retain readable line height")
        if let previous = lastFrame { expect(abs(previous.midY - row.frame.midY) >= 23, "independent shortcut actions never share a baseline") }
        lastFrame = row.frame
        let fields = row.subviews.compactMap { $0 as? NSTextField }
        let keys = row.subviews.compactMap { $0 as? ShortcutKeyView }
        expect(fields.count == 1 && keys.count == 1, "each shortcut uses a keycap column and one action column")
        let keyColumn = keys[0].alignmentRect(forFrame: keys[0].frame)
        expect(abs(keyColumn.width - 60) < 0.5, "shortcut key columns align")
        expect(fields[0].frame.height >= fields[0].intrinsicContentSize.height - 0.5, "shortcut action text is not vertically clipped")
        for image in views(keys[0]).compactMap({ $0 as? NSImageView }) {
            expect(image.image != nil && image.bounds.height >= 14 && image.bounds.width >= 16, "Return uses a visible system glyph with dedicated bounds")
        }
    }
}
let suggestion = TemplateSuggestionView()
let suggestionItem = PromptStore.items(for: .prompt).first { $0.title == "文稿润色模板" }!
suggestion.configure(with: PromptTemplateMatch(item: suggestionItem, mode: .prompt, score: 8, matchedKeywords: ["润色", "文案"]))
suggestion.frame = NSRect(x: 0, y: 0, width: 680, height: TemplateSuggestionView.height)
suggestion.layoutSubtreeIfNeeded()
let suggestionMenu = views(suggestion).compactMap { $0 as? NSPopUpButton }.first!
expect(suggestionMenu.title.contains("文稿润色模板"), "matching template has a recognizable object-bound entry")
expect(suggestionMenu.toolTip?.contains(suggestionItem.detail) == true, "suggestion retains its complete explanation")
expect(suggestion.gradientColorsProvider?().count == 2 && suggestion.borderColor != .clear, "template suggestion reads as a discreet interactive surface")
var suggestionApplied = false, suggestionIgnored = false
suggestion.onApply = { suggestionApplied = true }; suggestion.onIgnore = { suggestionIgnored = true }
activate(menuItem("套用此模板", in: suggestion))
activate(menuItem("忽略本次建议", in: suggestion))
expect(suggestionApplied && suggestionIgnored, "both suggested-template actions remain reachable through the real native menu")
let shortcutGuides = views(root).compactMap { $0 as? ShortcutGuideView }
expect(shortcutGuides.isEmpty, "the template list does not reserve permanent height for shortcut rows")
let shortcutHelpButton = controller.shortcutHelpButtonForTesting
expect(shortcutHelpButton.accessibilityLabel() == "模板快捷键"
       && shortcutHelpButton.accessibilityIdentifier() == "template-shortcuts"
       && shortcutHelpButton.toolTip == "查看模板快捷键",
       "template shortcuts are exposed through one named on-demand control")
expect(!controller.window!.isOpaque, "window allows the standard system material to blend behind it")
let windowBackdrops = views(root).compactMap { $0 as? WindowBackdropView }
expect(windowBackdrops.count == 1 && windowBackdrops[0].blendingMode == .behindWindow && windowBackdrops[0].material == .popover, "floating editor has the native standard popover material")
let guidedAccent = views(root).compactMap { $0 as? GuidedAccentView }.first!
guidedAccent.updateLayer()
let guidedLayers = guidedAccent.layer!.sublayers!
expect(!guidedLayers.contains { $0 is CAShapeLayer }, "shared background removes every lacquer wave contour")
expect(guidedLayers.filter { ($0 as? CAGradientLayer) == nil }.count == 3, "shared background uses three radial halo layers")
expect(guidedLayers.filter { $0.contents != nil }.count == 3, "each halo has a rendered radial light image")
var motionReduced = false
let motionProbe = GuidedAccentView(frame: NSRect(x: 0, y: 0, width: 320, height: 120), motionPreference: { motionReduced })
let motionWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 320, height: 120), styleMask: [.titled], backing: .buffered, defer: false)
motionWindow.contentView!.addSubview(motionProbe)
motionProbe.updateLayer()
NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil)
expect(motionProbe.layer!.sublayers!.contains { $0.animationKeys()?.isEmpty == false }, "normal motion starts slow halo animation when the display option notification arrives")
motionReduced = true
NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil)
expect(motionProbe.layer!.sublayers!.allSatisfy { $0.animationKeys()?.isEmpty != false }, "turning on reduced motion stops the existing halo through the workspace notification center")
motionReduced = false
NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil)
expect(motionProbe.layer!.sublayers!.contains { $0.animationKeys()?.isEmpty == false }, "turning off reduced motion resumes the existing halo")
motionWindow.close()
let visibleCopy = views(root).compactMap { $0 as? NSTextField }.map(\.stringValue)
expect(!visibleCopy.contains(where: { $0.contains("写下重点") || $0.contains("把想法写成") || $0.contains("提示词已准备好") }), "idle editor has no redundant title or instruction")
expect(controller.window!.frame.height < 340, "empty editor remains compact with the two-line footer spacing")
if #available(macOS 26.0, *) {
    let glasses = views(root).compactMap { $0 as? NSGlassEffectView }
    expect(glasses.count == 2 && glasses.allSatisfy { $0.style == .regular && $0.tintColor == nil }, "template and settings each use their own neutral system glass group")
    if #available(macOS 27.0, *) {
        expect(glasses.allSatisfy(\.effectIsInteractive), "both navigation glass groups enable the system interactive response")
    }
}
let contentSurfaces = views(root).filter { $0 is ThemedSurfaceView }
expect(contentSurfaces.allSatisfy { !($0 is NSVisualEffectView) }, "content must not blend the old visual effect material over semantic backgrounds")
expect(views(root).compactMap { $0 as? NSScrollView }.allSatisfy { !$0.drawsBackground && !$0.contentView.drawsBackground }, "main scroll content inherits the neutral semantic surface")
if #available(macOS 26.0, *) {
    let tools = views(root).compactMap { $0 as? NSButton }.filter { $0.accessibilityLabel() == "设置" || $0.accessibilityLabel() == "模板菜单" }
    expect(tools.count == 2 && tools.allSatisfy { $0.bezelStyle == .toolbar && !$0.isBordered }, "top-level tools use native toolbar controls inside native glass groups")
    expect(tools.allSatisfy { $0.bezelColor == nil }, "native glass has no app-specific tint")
    let settingsTool = tools.first { $0.accessibilityLabel() == "设置" }!
    expect(settingsTool.imagePosition == .imageOnly && settingsTool.title.isEmpty, "brand title styling cannot expose the default Button text on the settings icon")
}
let toolGroups = views(root).compactMap { $0 as? GlassToolGroup }
let templateToolGroup = toolGroups.first { views($0).contains { ($0 as? NSButton)?.accessibilityLabel() == "模板菜单" } }!
let settingsToolGroup = toolGroups.first { views($0).contains { ($0 as? NSButton)?.accessibilityLabel() == "设置" } }!
let templateGroupFrame = templateToolGroup.convert(templateToolGroup.bounds, to: root)
let settingsGroupFrame = settingsToolGroup.convert(settingsToolGroup.bounds, to: root)
expect(toolGroups.count == 2, "template and settings use two separate navigation groups")
expect(settingsGroupFrame.minX - templateGroupFrame.maxX >= AppTheme.Spacing.control - 0.5,
       "settings stays visibly separated from the template-and-arrow group")
let templateMenu = views(root).compactMap { $0 as? NSButton }.first { $0.accessibilityLabel() == "模板菜单" }!
expect(templateMenu.title == "模板" && templateMenu.font!.pointSize >= 13 && templateMenu.bounds.width >= 88 && templateMenu.bounds.width <= 120, "template text and disclosure arrow form one compact button; actual=\(templateMenu.bounds.width)")
expect(templateMenu.alignment == .center, "template label sits close to its disclosure arrow")
expect(templateMenu.imagePosition == .imageTrailing && templateMenu.image != nil, "template menu uses one trailing disclosure chevron")
expect(templateMenu.isEnabled && templateMenu.action != nil, "empty content still permits opening the template center directly")
expect(editor.font!.pointSize == 16, "editor has a legible system text size")
expect(!button("复制 Prompt  ⌘↵", in: root).isEnabled, "empty input cannot be copied")
expect(!button("重构", in: root).isEnabled, "empty input cannot invoke AI")
expect(!button("复制 Prompt  ⌘↵", in: root).isHidden, "the stable copy slot remains present but disabled for an empty draft")
edit("草稿保留测试")
root.layoutSubtreeIfNeeded()
expect(!button("复制 Prompt  ⌘↵", in: root).isHidden && button("复制 Prompt  ⌘↵", in: root).isEnabled,
       "an editable draft uses the same copy action name before generation")
let inputCopy = button("复制 Prompt  ⌘↵", in: root) as! TalisActionButton
expect(inputCopy.emphasis == .neutral && inputCopy.bezelColor == nil,
       "an editable draft keeps the copy slot in the neutral component variant")
inputCopy.setHovering(true)
expect(inputCopy.isHovering
       && inputCopy.bezelColor.map { colorsMatch($0, AppTheme.actionHoverStart) } == true
       && inputCopy.contentTintColor.map { colorsMatch($0, NSColor.labelColor) } == true,
       "copy hover deepens only its surface and keeps the label color stable")
if #available(macOS 26.0, *) {
    expect(inputCopy.bezelStyle == .glass && (inputCopy.layer?.borderWidth ?? 0) == 0,
           "copy hover keeps the native glass capsule and changes only its surface")
}
inputCopy.setHovering(false)
expect(!inputCopy.isHovering && inputCopy.bezelColor == nil,
       "copy hover restores the shared neutral component")
let animatedComponent = TalisActionButton(
    title: "测试",
    target: nil,
    action: nil,
    surface: .glass,
    emphasis: .neutral
)
animatedComponent.isEnabled = true
animatedComponent.setHovering(true)
expect(animatedComponent.layer?.animation(forKey: "hoverMotion") == nil,
       "the shared action component changes color without moving the control")
let staticComponent = TalisActionButton(
    title: "测试",
    target: nil,
    action: nil,
    surface: .glass,
    emphasis: .neutral
)
staticComponent.isEnabled = true
staticComponent.setHovering(true)
expect(staticComponent.layer?.animation(forKey: "hoverMotion") == nil,
       "the shared action component removes motion while preserving hover color")
for title in ["微调", "重构", "追问"] {
    let mode = button(title, in: root)
    expect(mode.image != nil && mode.imagePosition == .imageLeading, "\(title) has its branded icon in the leading position")
}
if #available(macOS 26.0, *) {
    for title in ["微调", "重构", "追问"] {
        let mode = button(title, in: root)
        expect(mode.bezelStyle == .glass && mode.borderShape == .capsule, "\(title) uses the real native glass capsule")
        expect(mode.bezelColor == nil && mode.tintProminence == .none, "\(title) preserves the selected neutral resting appearance")
    }
    let hoverMode = button("微调", in: root) as! ModeHoverButton
    let restingImage = hoverMode.image
    let restingTitleColor = hoverMode.attributedTitle.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
    hoverMode.setHovering(true)
    expect(hoverMode.isHovering
           && hoverMode.bezelColor.map { colorsMatch($0, AppTheme.actionHoverStart) } == true
           && hoverMode.tintProminence == .none
           && hoverMode.bezelStyle == .glass
           && (hoverMode.layer?.borderWidth ?? 0) == 0,
           "mode hover deepens only the native glass surface")
    let hoverForeground = hoverMode.attributedTitle.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
    expect(hoverForeground.map { colorsMatch($0, restingTitleColor ?? .labelColor) } == true
           && hoverMode.contentTintColor.map { colorsMatch($0, NSColor.labelColor) } == true
           && hoverMode.image === restingImage,
           "mode hover keeps the icon and title unchanged")
    expect(hoverMode.acceptsFirstMouse(for: nil),
           "an enabled mode action can handle the first click after the window loses focus")
    hoverMode.setHovering(false)
    expect(!hoverMode.isHovering && hoverMode.bezelColor == nil, "leaving a mode restores the neutral native glass")
    hoverMode.setHovering(true)
    hoverMode.isEnabled = false
    expect(!hoverMode.isHovering && hoverMode.bezelColor == nil, "disabled mode cannot retain a hover surface")
    hoverMode.isEnabled = true
    let modeContainers = views(root).compactMap { $0 as? NSGlassEffectContainerView }
    expect(modeContainers.count == 1 && modeContainers[0].contentView is NSStackView, "one native container groups the three adjacent glass modes")
}
editor.keyDown(with: key("\u{1b}", code: 53))
expect(controller.window?.isVisible == false && controller.canRestoreLastDraft,
       "Escape ends the current quick session and keeps one in-memory recovery draft")
controller.show()
let hiddenHistory = views(root).compactMap { $0 as? NSButton }.first {
    ($0.accessibilityLabel() ?? "").hasPrefix("修改记录")
}!
expect(editor.string.isEmpty && hiddenHistory.isHiddenOrHasHiddenAncestor,
       "the next invocation starts with an empty prompt and history")
let visibleRestore = button("恢复上次草稿", in: root)
expect(!visibleRestore.isHiddenOrHasHiddenAncestor,
       "the main window exposes draft recovery once a dismissed draft exists")
expect(visibleRestore.image != nil
       && visibleRestore.accessibilityLabel() == "恢复上次草稿",
       "main-window draft recovery keeps a meaningful icon and accessible name")
activate(visibleRestore)
expect(editor.string == "草稿保留测试"
       && button("恢复上次草稿", in: root).isHiddenOrHasHiddenAncestor,
       "the main-window recovery action restores the dismissed session and then disappears")
controller.performNewPrompt()
expect(editor.string.isEmpty && controller.canRestoreLastDraft,
       "New Prompt captures the current session and opens a blank document")
let previousRestore = button("恢复上次草稿", in: root)
expect(!previousRestore.isHiddenOrHasHiddenAncestor,
       "New Prompt exposes the previous draft in the main window")
activate(previousRestore)
expect(editor.string == "草稿保留测试",
       "restore remains available after an explicit new prompt")
let processFreshController = PromptWindowController(clientFactory: { client })
processFreshController.show()
let processFreshRoot = processFreshController.window!.contentView!
let processFreshEditor = views(processFreshRoot).compactMap { $0 as? PromptTextView }.first!
expect(processFreshEditor.string.isEmpty,
       "a new controller, representing a new process, never restores the ordinary prior session")
processFreshController.window?.orderOut(nil)
edit("https:")
controller.window?.makeFirstResponder(editor)
editor.keyDown(with: key("/", code: 44))
expect(editor.string == "https:/", "slash inside text is literal")
controller.performShowTemplates()
expect(views(controller.templatePickerViewForTesting!).compactMap { $0 as? NSSearchField }.first!.isHidden == false,
       "search control is present inside the separate template picker")
controller.promptTextViewDidRequestClose(editor)
edit("请帮我润色文案，调整语气，让表达更清晰。")
let editorHeightBeforeTemplates = editor.enclosingScrollView!.frame.height
let actionsBeforeTemplates = button("微调", in: root).isHidden
controller.performShowTemplates()
expect(abs(editor.enclosingScrollView!.frame.height - editorHeightBeforeTemplates) < 1
       && button("微调", in: root).isHidden == actionsBeforeTemplates,
       "opening Template Center never compresses the editor or hides the main AI actions")
expect(controller.templatePickerWindowForTesting !== controller.window
       && controller.templatePickerWindowForTesting?.parent === controller.window,
       "Template Center is a separate child window rather than part of the editor stack")
let pickerWindow = controller.templatePickerWindowForTesting!
expect(pickerWindow.isOpaque
       && !pickerWindow.titlebarAppearsTransparent
       && pickerWindow.titleVisibility == .visible
       && pickerWindow.level == .floating
       && pickerWindow.contentView !== controller.window?.contentView,
       "Template Center uses an opaque normal title-bar window with no editor-surface bleed; opaque=\(pickerWindow.isOpaque), transparent=\(pickerWindow.titlebarAppearsTransparent), titleVisibility=\(pickerWindow.titleVisibility.rawValue), level=\(pickerWindow.level.rawValue), separate=\(pickerWindow.contentView !== controller.window?.contentView)")
let pickerRoot = controller.templatePickerViewForTesting!
let recommendation = views(pickerRoot).compactMap { $0 as? TemplateRecommendationView }.first!
expect(!recommendation.isHidden, "a matching draft exposes one recommendation notice inside the template center")
let recommendationButtons = views(recommendation).compactMap { $0 as? NSButton }
expect(recommendationButtons.map(\.title) == ["忽略"],
       "recommendation does not duplicate the template row's explicit apply action")
let recommendationCopy = views(recommendation).compactMap { $0 as? NSTextField }.map(\.stringValue)
expect(recommendationCopy.contains("建议")
       && recommendationCopy.contains("已选中下方项")
       && !recommendationCopy.contains(where: { $0.contains("文稿润色模板") || $0.contains("补齐目标、上下文、约束、输出格式和自检规则") }),
       "recommendation points to the selected row without repeating its title or description")
let ignoreRecommendationButton = button("忽略", in: recommendation)
expect(ignoreRecommendationButton.frame.height >= 31.5,
       "recommendation ignore action keeps the shared 32pt minimum instead of an impossible 28pt constraint")
let unselectedTemplateRow = views(pickerRoot).compactMap { $0 as? CommandRowView }.first {
    !$0.selectionButton.isAccessibilitySelected()
}!
unselectedTemplateRow.setHovering(true)
expect(unselectedTemplateRow.gradientColorsProvider?().count == 2 && unselectedTemplateRow.borderColor != .clear,
       "unselected template row exposes a visible pointer hover before selection")
unselectedTemplateRow.setHovering(false)
expect(unselectedTemplateRow.gradientColorsProvider == nil && unselectedTemplateRow.borderColor == .clear,
       "leaving an unselected template row restores its plain surface")
let otherUnselectedTemplateRow = views(pickerRoot).compactMap { $0 as? CommandRowView }.first {
    $0 !== unselectedTemplateRow && !$0.selectionButton.isAccessibilitySelected()
}!
unselectedTemplateRow.setHovering(true)
otherUnselectedTemplateRow.setHovering(true)
expect(unselectedTemplateRow.gradientColorsProvider == nil
       && otherUnselectedTemplateRow.gradientColorsProvider?().count == 2,
       "only one template row can own hover at a time")
let pickerListScroll = views(pickerRoot).compactMap { $0 as? NSScrollView }.first { $0.documentView is NSStackView }!
NotificationCenter.default.post(name: NSView.boundsDidChangeNotification, object: pickerListScroll.contentView)
expect(otherUnselectedTemplateRow.gradientColorsProvider == nil,
       "scrolling clears hover so moved rows cannot retain a colored surface")
otherUnselectedTemplateRow.setHovering(true)
controller.windowDidResignKey(Notification(name: NSWindow.didResignKeyNotification, object: pickerWindow))
expect(otherUnselectedTemplateRow.gradientColorsProvider == nil,
       "window focus loss clears every template-row hover state")
let selectedSuggestedRows = views(pickerRoot).compactMap { $0 as? CommandRowView }.filter {
    $0.selectionButton.isAccessibilitySelected()
}
expect(selectedSuggestedRows.count == 1
       && selectedSuggestedRows[0].selectionButton.accessibilityLabel() == "文稿润色模板"
       && !selectedSuggestedRows[0].applyButton.isHidden,
       "opening a recommendation selects the corresponding row and keeps apply there")
pickerRoot.layoutSubtreeIfNeeded()
let selectedApplyFrame = selectedSuggestedRows[0].applyButton.convert(
    selectedSuggestedRows[0].applyButton.bounds,
    to: pickerRoot
)
expect(selectedApplyFrame.maxX <= pickerRoot.bounds.maxX - 8
       && selectedApplyFrame.maxY <= pickerRoot.bounds.maxY - 8,
       "the selected template action stays fully inside the standalone picker")
activate(selectedSuggestedRows[0].applyButton)
expect(editor.string.contains("请帮我润色文案，调整语气，让表达更清晰。"),
       "applying the recommended row reuses the draft in the matched template")
edit("")
editor.keyDown(with: key("/", code: 44))
let search = views(pickerRoot).compactMap { $0 as? NSSearchField }.first!
expect(search.accessibilityLabel() == "搜索模板", "picker search exposes its name")
expect(search.placeholderString == "搜索"
       && search.cell?.title == "",
       "picker search uses one visible text layer and no native cell title")
let searchInternalBefore = views(search).dropFirst().map { ($0 as? NSTextField)?.stringValue ?? "" }
AppLocalization.refresh(pickerRoot)
let searchInternalAfter = views(search).dropFirst().map { ($0 as? NSTextField)?.stringValue ?? "" }
expect(searchInternalAfter == searchInternalBefore,
       "localization never rewrites private search-field text views")
let shortcutView = controller.templateShortcutPopoverViewForTesting()
let shortcutGuide = views(shortcutView).compactMap { $0 as? ShortcutGuideView }.first!
expect(shortcutGuide.entries.map(\.action) == ["选择", "应用", "来源", "收起"],
       "shortcut popover keeps one complete action per row")
inspectGuideLayout(shortcutGuide)
expect(controller.control(search, textView: NSTextView(), doCommandBy: #selector(NSResponder.insertTab(_:))), "search field handles Tab itself")
expect(views(pickerRoot).compactMap { $0 as? NSSegmentedControl }.first!.selectedSegment == 1, "Tab from search switches to personal templates")
expect(!button("管理", in: pickerRoot).isHidden, "personal tab exposes the real manager entry")
expect(!button("存为新", in: pickerRoot).isHidden, "template center keeps save-as as an explicit visible action")
_ = controller.control(search, textView: NSTextView(), doCommandBy: #selector(NSResponder.insertBacktab(_:)))
expect(views(pickerRoot).compactMap { $0 as? NSSegmentedControl }.first!.selectedSegment == 0, "back Tab switches source from search")
search.stringValue = "准备会前材料"
controller.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: search))
let rows = views(pickerRoot).compactMap { $0 as? CommandRowView }
expect(rows.count == 1, "picker filters actual production template items")
expect(rows[0].selectionButton.accessibilityLabel() == "准备会前材料", "template title is an accessible button name")
expect(rows[0].selectionButton.accessibilityRole() == .button, "template row is a native accessible button")
    expect(views(rows[0]).compactMap { $0 as? NSImageView }.isEmpty, "template rows no longer carry generic per-row glyphs")
expect(rows[0].selectionButton.isAccessibilitySelected(), "selected template is exposed to accessibility")
expect(rows[0].gradientColorsProvider?().count == 2, "selected template uses a shallow gradient inside its accent outline")
activate(rows[0].selectionButton)
expect(editor.string.isEmpty, "clicking the selected row does not apply its template")
expect(!rows[0].applyButton.isHidden && rows[0].applyButton.title == "应用", "empty draft exposes an explicit apply button only for the selected row")
activate(rows[0].applyButton)
expect(editor.string.contains("会议主题：【会议主题】"), "filtered selection inserts preserved template body")
controller.performShowTemplates()
expect(!button("更新", in: controller.templatePickerViewForTesting!).isHidden,
       "template origin survives filtered insertion")
controller.promptTextViewDidRequestClose(editor)
edit("原始请求")
controller.show()
controller.window?.makeKey()
FixtureProtocol.delay = 0.25
activate(button("微调", in: root))
pump(until: { FixtureProtocol.started > 0 })
expect(!editor.isEditable, "in-flight request cannot overwrite simultaneous edits")
let clipboardChangeCount = NSPasteboard.general.changeCount
editor.keyDown(with: key("\r", code: 36, flags: [.command]))
expect(NSPasteboard.general.changeCount == clipboardChangeCount, "busy keyboard copy obeys the same disabled state as the visible control")
let stopControl = button("停止", in: root) as! TalisActionButton
stopControl.setWindowActive(false)
expect(stopControl.bezelColor == AppTheme.primaryActionColor,
       "the stop action keeps its semantic primary surface even if the window loses key status")
stopControl.setWindowActive(true)
expect(!button("停止", in: root).isHidden, "in-flight operation has a visible stop action")
expect(button("停止", in: root).bezelColor == AppTheme.primaryActionColor && button("停止", in: root).bounds.width >= 96,
       "in-flight stop has a visible native tinted capsule and adequate click target")
expect(button("停止", in: root).bounds.width == inputCopy.bounds.width,
       "the copy and stop actions occupy the same right-edge action slot")
expect(button("停止", in: root).contentTintColor == AppTheme.primaryActionTextColor,
       "in-flight stop keeps its symbol and label in the explicit primary foreground")
expect(button("停止", in: root).attributedTitle.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor == AppTheme.primaryActionTextColor,
       "in-flight stop keeps a primary attributed title after state refreshes")
if #available(macOS 26.0, *) {
    expect(button("停止", in: root).bezelStyle == .push && button("停止", in: root).tintProminence == .primary,
           "in-flight stop uses a deterministic promoted native push surface")
}
root.layoutSubtreeIfNeeded()
let workingLabels = views(root).compactMap { $0 as? NSTextField }.filter { $0.stringValue.contains("正在微调") && !$0.isHiddenOrHasHiddenAncestor }
expect(!workingLabels.isEmpty, "running feedback has a visible operation title")
let workingLabel = workingLabels[0]
expect(workingLabel.frame.width >= workingLabel.intrinsicContentSize.width - 1 && workingLabel.frame.height >= 14,
       "working status has visible text bounds: label=\(workingLabel.frame), group=\(workingLabel.superview!.frame)")
let workingSpinner = views(root).compactMap { $0 as? NSProgressIndicator }.first { !$0.isHidden }!
let initialSpinnerFrame = workingSpinner.convert(workingSpinner.bounds, to: root)
let initialTitleFrame = workingLabel.convert(workingLabel.bounds, to: root)
expect(abs(initialSpinnerFrame.midY - initialTitleFrame.midY) <= 1,
       "the running spinner is vertically centered on the title line")
let feedbackDetail = views(root).compactMap { $0 as? NSTextField }.first { $0.accessibilityLabel() == "状态说明" }!
feedbackDetail.stringValue = "等待 AI 响应…"
feedbackDetail.isHidden = false
root.layoutSubtreeIfNeeded()
let waitingSpinnerFrame = workingSpinner.convert(workingSpinner.bounds, to: root)
let waitingTitleFrame = workingLabel.convert(workingLabel.bounds, to: root)
expect(abs(waitingSpinnerFrame.midY - waitingTitleFrame.midY) <= 1,
       "adding a second status line never pulls the spinner away from the title")
activate(button("停止", in: root))
expect(editor.isEditable, "stop restores editing")
expect(editor.string == "原始请求", "stop retains original input")
edit("停止后新写的内容")
pump(until: { FixtureProtocol.stopped > 0 })
let until = Date().addingTimeInterval(0.35)
while Date() < until { RunLoop.current.run(until: Date().addingTimeInterval(0.01)) }
expect(editor.string == "停止后新写的内容", "late request completion cannot replace subsequent edits")
FixtureProtocol.delay = 0.03
activate(button("微调", in: root))
pump(until: { editor.isEditable })
expect(editor.string == "结果【待填事项】：", "normal completion still updates the editor")
    expect(!views(root).compactMap { $0 as? NSTextField }.contains { $0.stringValue == "微调已完成" && !$0.isHidden }, "result does not duplicate operation status beside clear or under the title")
expect(FixtureProtocol.lastSystem == AIAction.refine.instruction + "\n\n" + ClarificationPromptBuilder.contentLanguageInstruction(.simplifiedChinese),
       "UI redesign preserves the model instruction and appends the app-language rule")
expect(!button("重构", in: root).isHidden, "completed result keeps all three modes available")
let resultCopy = button("复制 Prompt  ⌘↵", in: root)
if let actionCopy = resultCopy as? TalisActionButton {
    actionCopy.setWindowActive(false)
    expect(actionCopy.bezelColor == nil
           && actionCopy.contentTintColor.map { colorsMatch($0, NSColor.labelColor) } == true,
           "an inactive window uses a legible neutral surface instead of white text on dim glass")
    actionCopy.setWindowActive(true)
}
expect(resultCopy is TalisActionButton && (resultCopy as! TalisActionButton).emphasis == .primary,
       "result copy promotes the same component instead of switching to another button type")
expect((resultCopy as! TalisActionButton).surface == .push,
       "result copy uses the solid primary surface so its text stays visible over the light editor")
expect(resultCopy.image == nil && resultCopy.imagePosition == .noImage, "copy has no redundant left icon")
expect(!resultCopy.isHidden && resultCopy.isEnabled, "result promotes copy at the same action edge")
expect(resultCopy.keyEquivalent == "\r" && resultCopy.keyEquivalentModifierMask == .command, "copy shortcut keeps its effect across stages")
if #available(macOS 26.0, *) { expect(resultCopy.tintProminence == .primary, "result copy requests the native primary tint role") }
expect(["微调", "重构", "追问"].allSatisfy { !button($0, in: root).isHidden && button($0, in: root).isEnabled }, "three modes stay visible and enabled after generation")
let resultCopyFrame = resultCopy.frame
controller.performPasteBack()
let copiedControl = views(root).compactMap { $0 as? TalisActionButton }.first { $0.title == "已复制" }!
expect(copiedControl.emphasis == .primary && copiedControl.frame == resultCopyFrame && copiedControl.image == nil,
       "copy completion uses the same primary component and geometry")
let copiedResetDate = Date().addingTimeInterval(1.55)
while Date() < copiedResetDate { RunLoop.current.run(until: Date().addingTimeInterval(0.01)) }
expect(button("复制 Prompt  ⌘↵", in: root).frame == resultCopyFrame,
       "copy completion returns to the same stable result control")
let savedResult = editor.string
edit(savedResult + "\n手动补充")
expect(!resultCopy.isHidden && resultCopy.title == "复制 Prompt  ⌘↵", "editing a prepared result keeps the review-and-copy stage")
edit(savedResult)

expect(!controller.canCancelAI, "completed operation releases stop state")
activate(button("清空", in: root))
expect(editor.string.isEmpty, "explicit clear remains available")
controller.promptTextViewDidRequestUndo(editor)
expect(editor.string == "结果【待填事项】：", "explicit clear is undoable")
let contextButtons = views(root).compactMap { $0 as? NSButton }
expect(contextButtons.contains(where: { $0.title.contains("修改记录") && !$0.isHidden }), "undo clear also restores recent context")
let completedResult = editor.string
controller.hide()
expect(controller.canRestoreLastDraft && controller.window?.isVisible == false,
       "dismissing a completed session records its complete history for explicit recovery")
controller.show()
expect(editor.string.isEmpty && !controller.hasConversationHistory,
       "the next completed session also starts blank with no inherited rounds")
controller.restoreLastDraft()
controller.performShowTemplates()
expect(editor.string == completedResult
       && !button("修改记录 · 1 轮", in: root).isHidden
       && !button("更新", in: controller.templatePickerViewForTesting!).isHidden,
       "recovering the dismissed completed session restores its text, template source and history together")
controller.promptTextViewDidRequestClose(editor)

FixtureProtocol.status = 503
let beforeError = editor.string
activate(button("微调", in: root))
pump(until: { editor.isEditable })
expect(editor.string == beforeError, "HTTP failure retains the input")
    expect(!button("详情", in: root).isHidden && !button("重试", in: root).isHidden, "HTTP failure exposes grouped retry and detail controls")
    expect(views(root).compactMap { $0 as? NSTextField }.contains { !$0.isHidden && $0.stringValue == "微调失败" }, "failure title is separated from its diagnosis")
    let retry = button("重试", in: root)
    let details = button("详情", in: root)
    expect(retry.frame.height >= 31.5 && details.frame.height >= 31.5, "recovery actions retain a deliberate 32pt click target")
    if #available(macOS 26.0, *) {
        expect(retry.bezelStyle == .push && details.bezelStyle == .glass,
               "retry stays the filled primary while details uses a readable neutral glass surface")
    }
expect(NSApp.modalWindow == nil, "ordinary HTTP failure does not open a modal alert")
    FixtureProtocol.status = 200
    FixtureProtocol.transportError = URLError(.secureConnectionFailed)
    let requestsBeforeTLSFailure = FixtureProtocol.started
    controller.performRegenerate()
    pump(until: { !button("重试", in: root).isHidden && editor.isEditable })
    expect(views(root).compactMap { $0 as? NSTextField }.contains { !$0.isHidden && $0.stringValue == "TLS 安全连接未能建立，请重试。" }, "one-time TLS handshake failure is named without inventing a specific network node")
    expect(FixtureProtocol.started == requestsBeforeTLSFailure + 1, "TLS failure is not automatically retried as a paid request")
    FixtureProtocol.transportError = nil
    let modelBeforeSubscriptionFailure = AppSettings.modelID
    AppSettings.modelID = AIProvider.codexSubscriptionID
    FixtureProtocol.transportError = URLError(.cannotConnectToHost)
    controller.performRegenerate()
    pump(until: { editor.isEditable })
    expect(views(root).compactMap { $0 as? NSTextField }.contains {
        !$0.isHidden && $0.stringValue == "无法连接 AI 服务，请稍后重试。"
    }, "an API request failure is not attributed to a newly selected subscription")
    operationClient = OpenAIClient(apiKey: "", modelOption: OpenAIClient.modelOption(for: AIProvider.codexSubscriptionID),
                                   urlSession: session, modelResolver: ModelResolver(defaults: nil))
    controller.performRegenerate()
    AppSettings.modelID = "deepseek"
    pump(until: { editor.isEditable && views(root).compactMap { $0 as? NSTextField }.contains { !$0.isHidden && $0.stringValue.contains("Codex 订阅当前不可用") } })
    expect(views(root).compactMap { $0 as? NSTextField }.contains {
        !$0.isHidden && $0.stringValue == "Codex 订阅当前不可用。请确认已登录 Codex 订阅。"
    }, "Codex subscription failure gives a product-level recovery instruction")
    FixtureProtocol.transportError = nil
    AppSettings.modelID = modelBeforeSubscriptionFailure
    operationClient = client
FixtureProtocol.status = 200

// An interrupted subscription stream must preserve the editor and history;
// only the user's retry with a completed response may commit a new result.
let streamClient = OpenAIClient(apiKey: "", modelOption: OpenAIClient.modelOption(for: AIProvider.codexSubscriptionID),
                                urlSession: session, modelResolver: ModelResolver(defaults: nil))
let streamController = PromptWindowController(clientFactory: { streamClient }, motionPreference: { true })
streamController.show()
let oldStreamEditor = views(streamController.window!.contentView!).compactMap { $0 as? PromptTextView }.first!
oldStreamEditor.string = "上次收起的草稿"
streamController.textDidChange(Notification(name: NSText.didChangeNotification, object: oldStreamEditor))
streamController.hide()
streamController.toggleWorkspaceMode()
let streamRoot = streamController.window!.contentView!
let streamEditor = views(streamRoot).compactMap { $0 as? PromptTextView }.first!
expect(streamEditor.string.isEmpty && streamController.canRestoreLastDraft,
       "opening workspace after ending a quick session starts fresh while retaining the recoverable draft")
streamEditor.string = "订阅中断时必须保留的原文"
streamController.textDidChange(Notification(name: NSText.didChangeNotification, object: streamEditor))
FixtureProtocol.rawBody = Data("data: {\"type\":\"response.output_text.delta\",\"delta\":\"残缺结果\"}\n\ndata: [DONE]\n\n".utf8)
streamController.performRegenerate()
pump(until: { streamEditor.isEditable && !button("重试", in: streamRoot).isHidden })
expect(streamEditor.string == "订阅中断时必须保留的原文" && !streamController.canShowHistory,
       "a truncated subscription stream does not replace the editor or append history; text=\(streamEditor.string), history=\(streamController.canShowHistory)")
expect(views(streamRoot).compactMap { $0 as? NSTextField }.contains { $0.stringValue.contains("未完整返回") },
       "a truncated stream exposes its actual failure with a retry action")
FixtureProtocol.rawBody = Data("data: {\"type\":\"response.completed\",\"response\":{\"output_text\":\"完整订阅结果\"}}\n\n".utf8)
activate(button("重试", in: streamRoot))
pump(until: { streamEditor.isEditable && streamEditor.string == "完整订阅结果" })
expect(streamEditor.string == "完整订阅结果" && streamController.canShowHistory,
       "manual retry commits a completed subscription response")
expect(button("修改记录 · 1 轮", in: streamRoot).isEnabled && button("重试", in: streamRoot).isHidden,
       "only the completed retry creates one history turn and clears the old error")
streamController.hide()
FixtureProtocol.rawBody = nil

// A model may decide immediately that no clarification question is needed.
// That decision must stay visible and require an explicit choice instead of
// silently closing the sheet and replacing the draft.
let noQuestionController = PromptWindowController(clientFactory: { client })
let noQuestionRoot = noQuestionController.window!.contentView!
let noQuestionEditor = views(noQuestionRoot).compactMap { $0 as? PromptTextView }.first!
noQuestionController.show()
noQuestionEditor.string = "原始 Prompt"
noQuestionController.textDidChange(Notification(name: NSText.didChangeNotification, object: noQuestionEditor))
FixtureProtocol.content = clarificationFinalResponse("整理后的 Prompt")
FixtureProtocol.delay = 0.03
noQuestionController.performClarification()
pump(until: {
    views(noQuestionController.clarificationPanelForTesting ?? NSView()).compactMap { $0 as? NSTextField }
        .contains { $0.stringValue == "追问 · 无需补充" }
})
let noQuestionPanel = noQuestionController.clarificationPanelForTesting!
expect(noQuestionController.clarificationSheetWindowForTesting?.isVisible == true
       && noQuestionEditor.string == "原始 Prompt"
       && noQuestionEditor.isEditable == false,
       "an immediate final response keeps the sheet visible and does not silently replace the original")
expect((noQuestionController.clarificationSheetWindowForTesting?.frame.height ?? 9999) <= 280.5,
       "the no-question state uses a compact sheet instead of a large empty modal")
expect(views(noQuestionPanel).compactMap { $0 as? NSTextField }.contains {
    $0.stringValue.contains("当前 Prompt 信息已经足够明确")
}, "the no-question state explains why the clarification sheet did not ask anything")
expect(button("使用整理后的 Prompt", in: noQuestionPanel).isEnabled
       && button("返回原文", in: noQuestionPanel).isEnabled,
       "the no-question state gives separate use-result and return actions")
let noQuestionUseButton = button("使用整理后的 Prompt", in: noQuestionPanel)
noQuestionPanel.layoutSubtreeIfNeeded()
expect(noQuestionUseButton.frame.width >= 200,
       "the no-question action reserves enough width for its full title")
activate(button("返回原文", in: noQuestionPanel))
expect(noQuestionEditor.string == "原始 Prompt"
       && !noQuestionController.hasConversationHistory,
       "returning from no-question state preserves the original and does not record a turn")

noQuestionController.performClarification()
pump(until: {
    views(noQuestionController.clarificationPanelForTesting ?? NSView()).compactMap { $0 as? NSTextField }
        .contains { $0.stringValue == "追问 · 无需补充" }
})
let noQuestionApplyPanel = noQuestionController.clarificationPanelForTesting!
activate(button("使用整理后的 Prompt", in: noQuestionApplyPanel))
pump(until: { noQuestionEditor.isEditable && noQuestionController.clarificationSheetWindowForTesting == nil })
expect(noQuestionEditor.string == "整理后的 Prompt"
       && button("修改记录 · 1 轮", in: noQuestionRoot).isHidden == false,
       "using the generated result applies it and records one explicit clarification turn")
noQuestionController.window?.orderOut(nil)

FixtureProtocol.content = "{\"status\":\"ask\",\"questions\":[{\"question\":\"用于什么场景？\",\"options\":[\"个人使用\",\"团队协作\"]}]}"
FixtureProtocol.delay = 0.15
let editorHeightBeforeClarification = editor.enclosingScrollView!.frame.height
let hostFrameBeforeClarification = controller.window!.frame
let requestsBeforeClarification = FixtureProtocol.started
controller.performClarification()
let pendingPanel = controller.clarificationPanelForTesting!
expect(controller.clarificationIsActiveForTesting && !controller.canRunAI && !controller.canChooseTemplate,
       "clarification state is committed before the sheet enters its presentation loop")
expect(["微调", "重构", "追问", "复制 Prompt  ⌘↵"].allSatisfy { !button($0, in: root).isEnabled },
       "clarification immediately disables every competing primary action")
expect(views(root).compactMap { $0 as? NSButton }
    .filter { $0.title == "停止" && !$0.isHiddenOrHasHiddenAncestor }.isEmpty,
       "the sheet owns the only visible stop action; the dimmed main window does not duplicate it")
controller.performRefine()
controller.performRegenerate()
expect(controller.clarificationSheetWindowForTesting?.sheetParent === controller.window,
       "clarification is attached as a window-modal sheet rather than inserted into the editor")
expect((controller.clarificationSheetWindowForTesting?.frame.width ?? 0) <= 680.5,
       "clarification sheet respects its native width instead of expanding to long option text")
expect(controller.window!.frame.width >= 760 && controller.window!.frame.height >= 680,
       "the prompt window expands into a container before presenting the clarification sheet: \(controller.window!.frame)")
let pendingStatus = views(pendingPanel).compactMap { $0 as? NSTextField }.first { $0.stringValue == "追问 · 正在整理…" }!
expect(pendingStatus.toolTip == pendingStatus.stringValue && !(pendingStatus.toolTip?.contains("503") ?? false), "starting a new action replaces the old error tooltip")
pump(until: { views(pendingPanel).compactMap { $0 as? NSTextField }.contains { $0.stringValue == "用于什么场景？" } })
expect(FixtureProtocol.started == requestsBeforeClarification + 1,
       "refine and regenerate cannot start a second request while clarification is active")
let clarificationPanel = controller.clarificationPanelForTesting!
expect(controller.canCancelAI && !editor.isEditable, "clarification answer state locks original text and remains cancellable")
expect(views(root).compactMap { $0 as? ClarificationPanelView }.isEmpty,
       "the main editor no longer contains an inline clarification panel")
root.layoutSubtreeIfNeeded()
expect(!editor.isEditable
       && abs(editor.enclosingScrollView!.frame.height - editorHeightBeforeClarification) < 1,
       "clarification locks the original text without resizing the editor")
expect((button("提交本轮", in: clarificationPanel).attributedTitle.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor) == NSColor.disabledControlTextColor, "unanswered clarification uses neutral disabled foreground")
expect(button("提交本轮", in: clarificationPanel).accessibilityLabel() == "提交本轮", "clarification accessibility uses the visible final-question action")
let currentQuestionLabel = views(clarificationPanel).compactMap { $0 as? NSTextField }.first { $0.stringValue == "用于什么场景？" }!
let questionClip = currentQuestionLabel.enclosingScrollView!.contentView
clarificationPanel.layoutSubtreeIfNeeded()
let questionFrame = currentQuestionLabel.convert(currentQuestionLabel.bounds, to: questionClip)
expect(abs(questionFrame.minY - questionClip.bounds.minY) <= 3,
       "short clarification content begins at the top of its scrolling area: \(questionFrame), \(questionClip.bounds)")
let focusedChoice = views(clarificationPanel).compactMap { $0 as? ClarificationChoiceButton }.first!
let secondChoice = views(clarificationPanel).compactMap { $0 as? ClarificationChoiceButton }.first {
    $0.optionValue == "团队协作"
}!
focusedChoice.focus()
pump(until: { focusedChoice.window?.firstResponder is NSButton })
expect(focusedChoice.gradientColorsProvider == nil && focusedChoice.borderColor != .clear,
       "keyboard focus uses an outline only and cannot be mistaken for a selected answer")
let secondChoiceRadio = button("团队协作", in: clarificationPanel)
activate(secondChoiceRadio)
expect(focusedChoice.gradientColorsProvider == nil
       && secondChoice.gradientColorsProvider?().count == 2
       && secondChoiceRadio.state == .on
       && clarificationPanel.window?.firstResponder === secondChoiceRadio,
       "selecting a later answer moves focus and leaves only that answer emphasized")
activate(button("结束追问", in: clarificationPanel))
expect(controller.clarificationSheetWindowForTesting == nil, "ending clarification closes the sheet")
expect(editor.isEditable && !controller.canCancelAI && editor.string == beforeError, "ending clarification restores the original draft")
pump(until: {
    abs(controller.window!.frame.width - hostFrameBeforeClarification.width) < 1
        && controller.window!.frame.height < 500
})
expect(abs(controller.window!.frame.width - hostFrameBeforeClarification.width) < 1
       && controller.window!.frame.height < 500,
       "ending clarification returns the host width and compact content height: \(controller.window!.frame) vs \(hostFrameBeforeClarification)")
FixtureProtocol.content = "结果【待填事项】："

// Failure recovery retains each answer and never retries billable inference automatically.
FixtureProtocol.content = "{\"status\":\"ask\",\"questions\":[{\"question\":\"用于什么场景？\",\"options\":[\"个人使用\",\"团队协作\"]}]}"
FixtureProtocol.delay = 0.03
controller.performClarification()
pump(until: { views(controller.clarificationPanelForTesting!).compactMap { $0 as? NSTextField }.contains { $0.stringValue == "用于什么场景？" } })
let failurePanel = controller.clarificationPanelForTesting!
activate(button("团队协作", in: failurePanel))
FixtureProtocol.transportError = URLError(.networkConnectionLost)
let requestsBeforeFailure = FixtureProtocol.started
activate(button("提交本轮", in: failurePanel))
pump(until: { views(controller.clarificationPanelForTesting!).compactMap { $0 as? NSTextField }.contains { $0.stringValue == "网络连接中断，请重试。" } })
expect(!button("重试", in: controller.clarificationPanelForTesting!).isHidden,
       "transport failure stays actionable inside the modal sheet")
expect(button("团队协作", in: failurePanel).state == .on && button("提交本轮", in: failurePanel).isEnabled, "failed round restores the chosen answer and enabled submit")
expect(FixtureProtocol.started == requestsBeforeFailure + 1, "transport failure does not automatically repeat inference")
let visibleFailureText = views(failurePanel).compactMap { $0 as? NSTextField }
    .filter { !$0.isHiddenOrHasHiddenAncestor }
    .map(\.stringValue)
expect(visibleFailureText.contains("追问")
       && visibleFailureText.contains("原文和本轮回答已保留。")
       && !visibleFailureText.contains(where: { $0.contains("正在整理") || $0.contains("正在分析当前 Prompt") }),
       "failure replaces stale loading and analysis copy with one explicit recovery state")
expect((controller.clarificationSheetWindowForTesting?.frame.height ?? 999) <= 350,
       "failure uses a compact sheet instead of leaving a large empty body")
let failureRetry = button("重试", in: failurePanel) as! TalisActionButton
expect(failureRetry.frame.height >= 31.5,
       "failure retry keeps a deliberate click target")
failureRetry.setWindowActive(false)
expect(failureRetry.bezelColor.map { colorsMatch($0, AppTheme.primaryActionColor) } == true
       && failureRetry.contentTintColor.map { colorsMatch($0, AppTheme.primaryActionTextColor) } == true,
       "failure retry keeps a legible primary foreground when the sheet is not key")
failureRetry.setWindowActive(true)
let failureCard = views(failurePanel).compactMap { $0 as? ThemedSurfaceView }.first {
    ($0.accessibilityLabel() ?? "").hasPrefix("追问失败")
}
expect(failureCard != nil
       && failureCard?.gradientColorsProvider == nil,
       "failure uses a neutral content surface with no red background gradient")
for appearance in [NSAppearance.Name.aqua, .darkAqua] {
    failurePanel.appearance = NSAppearance(named: appearance)
    failureCard!.updateLayer()
    let renderedBackground = NSColor(cgColor: failureCard!.layer!.backgroundColor!)!
    expect(colorsMatch(renderedBackground, AppTheme.contentColor, appearance: appearance),
           "rendered failure layer stays neutral in \(appearance.rawValue)")
    expect(contrast(.labelColor, renderedBackground, appearance: appearance) >= 4.5
           && contrast(AppTheme.secondaryTextColor, renderedBackground, appearance: appearance) >= 4.5,
           "failure message and preserved-answer note stay readable on the actual layer")
    expect(contrast(AppTheme.errorTextColor, renderedBackground, appearance: appearance) >= 3,
           "warning symbol stays distinguishable on the actual failure surface")
    for active in [true, false] {
        failureRetry.setWindowActive(active)
        let textColor = failureRetry.attributedTitle.attribute(.foregroundColor, at: 0, effectiveRange: nil) as! NSColor
        expect(failureRetry.surface == .push
               && contrast(textColor, AppTheme.primaryActionColor, appearance: appearance) >= 4.5,
               "retry text stays readable in \(appearance.rawValue), active=\(active)")
    }
}
failurePanel.appearance = nil
failureRetry.setWindowActive(true)
FixtureProtocol.transportError = nil
FixtureProtocol.content = "{\"status\":\"final\",\"prompt\":\"已恢复的 Prompt\"}"
activate(button("重试", in: failurePanel))
pump(until: { editor.isEditable })
expect(editor.string == "已恢复的 Prompt",
       "explicit retry writes the returned final without forcing a removed placeholder back")
expect(FixtureProtocol.lastMessages.last?["content"]?.components(separatedBy: "团队协作").count == 2, "retry appends the answer exactly once")

// Clarification accepts a structurally valid repair after exactly one
// corrective request when a model tries to flatten a structured Prompt.
let structuredController = PromptWindowController(clientFactory: { client })
let structuredRoot = structuredController.window!.contentView!
let structuredEditor = views(structuredRoot).compactMap { $0 as? PromptTextView }.first!
let originalStructure = """
# 项目简报

## 输入
- 【项目名称】：
- 【目标受众】：

## 输出
1. 总结【核心进展】：
2. 列出风险
"""
let repairedStructure = """
# 项目简报

## 输入
- 【项目名称】：
- 【目标受众】：

## 输出
1. 总结【核心进展】：
2. 列出风险、负责人和截止日期
"""
structuredController.show()
structuredEditor.string = originalStructure
structuredController.textDidChange(Notification(name: NSText.didChangeNotification, object: structuredEditor))
FixtureProtocol.delay = 0.03
FixtureProtocol.contentQueue = [
    clarificationAskResponse(question: "简报面向谁？", options: ["项目组", "管理层"]),
    clarificationFinalResponse("请根据【项目名称】、【目标受众】和【核心进展】整理项目简报。"),
    clarificationFinalResponse(repairedStructure)
]
structuredController.performClarification()
pump(until: {
    guard let panel = structuredController.clarificationPanelForTesting else { return false }
    return views(panel).compactMap { $0 as? NSTextField }.contains { $0.stringValue == "简报面向谁？" }
})
let structurePanel = structuredController.clarificationPanelForTesting!
activate(button("项目组", in: structurePanel))
let requestsBeforeStructureRepair = FixtureProtocol.started
activate(button("提交本轮", in: structurePanel))
pump(until: { structuredEditor.isEditable && structuredController.clarificationSheetWindowForTesting == nil })
expect(FixtureProtocol.started == requestsBeforeStructureRepair + 2,
       "a flattened final Prompt triggers exactly one structure repair request")
expect(structuredEditor.string == repairedStructure,
       "the repaired final Prompt preserves the complete heading, list and placeholder structure")
expect(FixtureProtocol.lastSystem.contains("结构修复")
       && FixtureProtocol.lastMessages.last?["content"]?.contains("<rejected_final_prompt>") == true
       && FixtureProtocol.lastMessages.last?["content"]?.contains("整理项目简报") == true,
       "the one repair request contains both the rejected candidate and an explicit structure-repair instruction")
expect(!button("修改记录 · 1 轮", in: structuredRoot).isHidden,
       "successful structure repair records one complete clarification turn")
structuredController.window?.orderOut(nil)

// Two structurally invalid finals fail closed: the original text and history
// remain unchanged, the sheet stays open, and the user can explicitly retry.
let structureFailureController = PromptWindowController(clientFactory: { client })
let structureFailureRoot = structureFailureController.window!.contentView!
let structureFailureEditor = views(structureFailureRoot).compactMap { $0 as? PromptTextView }.first!
let failureStructure = "# 方案\n- 【受众】：\n1. 【目标】："
structureFailureController.show()
structureFailureEditor.string = failureStructure
structureFailureController.textDidChange(Notification(name: NSText.didChangeNotification, object: structureFailureEditor))
FixtureProtocol.contentQueue = [
    clarificationAskResponse(question: "方案给谁看？", options: ["团队", "客户"]),
    clarificationFinalResponse("请写一个给团队看的方案。"),
    clarificationFinalResponse("请写一个给团队看、保留目标说明的方案。")
]
structureFailureController.performClarification()
pump(until: {
    guard let panel = structureFailureController.clarificationPanelForTesting else { return false }
    return views(panel).compactMap { $0 as? NSTextField }.contains { $0.stringValue == "方案给谁看？" }
})
let structureFailurePanel = structureFailureController.clarificationPanelForTesting!
activate(button("团队", in: structureFailurePanel))
let requestsBeforeFailureRepair = FixtureProtocol.started
activate(button("提交本轮", in: structureFailurePanel))
pump(until: { structureFailurePanel.panelErrorIsVisibleForTesting })
expect(FixtureProtocol.started == requestsBeforeFailureRepair + 2,
       "the client performs one repair and then fails closed instead of looping inference")
expect(structureFailureEditor.string == failureStructure
       && !structureFailureController.hasConversationHistory,
       "two invalid finals preserve the original text and complete history")
expect(structureFailureController.clarificationSheetWindowForTesting?.isVisible == true
       && !button("重试", in: structureFailurePanel).isHidden,
       "invalid structure keeps the clarification sheet and exposes explicit retry")
expect(views(structureFailurePanel).compactMap { $0 as? NSTextField }.contains {
    $0.stringValue.contains("没有保留原有标题或列表结构")
}, "the failure explains the concrete structural contract that was not met")
activate(button("结束追问", in: structureFailurePanel))
structureFailureController.window?.orderOut(nil)
FixtureProtocol.contentQueue.removeAll()
FixtureProtocol.content = "结果【待填事项】："

FixtureProtocol.content = "{\"status\":\"ask\",\"questions\":[{\"question\":\"停止后保留哪项决定？\",\"options\":[\"保留我的回答\",\"重新开始\"]}]}"
controller.performClarification()
pump(until: { views(controller.clarificationPanelForTesting!).compactMap { $0 as? NSTextField }.contains { $0.stringValue == "停止后保留哪项决定？" } })
let stopPanel = controller.clarificationPanelForTesting!
activate(button("保留我的回答", in: stopPanel))
FixtureProtocol.delay = 0.3
let startedBeforeAnswer = FixtureProtocol.started
activate(button("提交本轮", in: stopPanel))
pump(until: { FixtureProtocol.started > startedBeforeAnswer })
let visibleStops = views(stopPanel).compactMap { $0 as? NSButton }.filter { $0.title == "停止" && !$0.isHiddenOrHasHiddenAncestor }
expect(visibleStops.count == 1, "clarification request exposes a single stop action")
if let sheetStop = visibleStops.first as? TalisActionButton { sheetStop.setWindowActive(true) }
expect(visibleStops[0].bezelColor == AppTheme.primaryActionColor
       && visibleStops[0].contentTintColor == AppTheme.primaryActionTextColor
       && visibleStops[0].attributedTitle.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor == AppTheme.primaryActionTextColor,
       "clarification stop uses the same readable filled primary action as the main window")
expect(visibleStops[0].frame.width >= 107 && visibleStops[0].image != nil
       && visibleStops[0].imagePosition == .imageLeading,
       "clarification stop owns a stable capsule width with its icon and title centered")
if #available(macOS 26.0, *) {
    expect(visibleStops[0].bezelStyle == .push && visibleStops[0].tintProminence == .primary,
           "clarification stop uses a deterministic native promotional surface")
}
activate(visibleStops[0])
expect(button("保留我的回答", in: stopPanel).state == .on && button("提交本轮", in: stopPanel).isEnabled,
       "stopping a submitted clarification restores the answer for continued editing")
expect(controller.canCancelAI && !editor.isEditable, "stopping a clarification request stays in the question workflow")
expect(controller.clarificationSheetWindowForTesting?.isVisible == true,
       "stopping a submitted answer preserves the question sheet for continued editing")
FixtureProtocol.delay = 0.03
FixtureProtocol.content = "{\"status\":\"final\",\"prompt\":\"停止后继续生成\"}"
activate(button("提交本轮", in: stopPanel))
pump(until: { editor.isEditable })
expect(editor.string == "停止后继续生成",
       "a stopped clarification can resume and reach a structurally safe result")
expect(FixtureProtocol.lastMessages.last?["content"]?.components(separatedBy: "保留我的回答").count == 2,
       "resuming after stop includes the answer once")

// The operation deadline cancels a request that never yields a response.
let boundedClient = OpenAIClient(apiKey: "fictional-ui-key", modelOption: OpenAIClient.modelOption(for: "deepseek"), urlSession: session, modelResolver: ModelResolver(defaults: nil), operationTimeout: 0.12)
let bounded = PromptWindowController(clientFactory: { boundedClient })
let boundedRoot = bounded.window!.contentView!
let boundedEditor = views(boundedRoot).compactMap { $0 as? PromptTextView }.first!
bounded.show()
boundedEditor.string = "不能在超时后丢失的原文"
bounded.textDidChange(Notification(name: NSText.didChangeNotification, object: boundedEditor))
FixtureProtocol.delay = 0.6
let stopsBeforeDeadline = FixtureProtocol.stopped
bounded.performClarification()
pump(until: { bounded.clarificationPanelForTesting?.panelErrorIsVisibleForTesting == true }, seconds: 2)
let timeoutPanel = bounded.clarificationPanelForTesting!
expect(!boundedEditor.isEditable && bounded.canCancelAI && boundedEditor.string == "不能在超时后丢失的原文",
       "deadline ends the request, keeps the original text locked, and preserves the sheet until recovery")
expect(views(timeoutPanel).compactMap { $0 as? NSTextField }.contains { $0.stringValue.contains("等待超时") }
       && !button("重试", in: timeoutPanel).isHidden,
       "deadline visibly fails inside the sheet rather than leaving a spinner")
expect(FixtureProtocol.stopped > stopsBeforeDeadline, "deadline cancels the underlying URLSession request")
FixtureProtocol.delay = 0.03
FixtureProtocol.content = "{\"status\":\"final\",\"prompt\":\"超时后恢复\"}"
activate(button("重试", in: timeoutPanel))
pump(until: {
    views(bounded.clarificationPanelForTesting ?? NSView()).compactMap { $0 as? NSTextField }
        .contains { $0.stringValue == "追问 · 无需补充" }
})
let timeoutNoQuestionPanel = bounded.clarificationPanelForTesting!
expect(boundedEditor.string == "不能在超时后丢失的原文",
       "timeout retry first explains that no clarification question is needed")
activate(button("使用整理后的 Prompt", in: timeoutNoQuestionPanel))
pump(until: { boundedEditor.isEditable })
expect(boundedEditor.string.hasPrefix("超时后恢复"),
       "using the no-question result starts a fresh successful operation")
bounded.window?.orderOut(nil)
FixtureProtocol.content = "结果【待填事项】："

// Long clarification copy must wrap within the fixed sheet instead of widening the modal.
let longPhrase = "请说明这份材料的主要使用场景和需要作出的决定。"
let longQuestion = String(repeating: longPhrase, count: 18)
let longOptions = [
    String(repeating: "整理团队周会后行动项与待确认问题。", count: 18),
    "项目启动前准备讨论材料",
    "向负责人汇报进展",
    "个人梳理下一步"
]
FixtureProtocol.content = String(
    data: try! JSONSerialization.data(withJSONObject: [
        "status": "ask",
        "questions": [["question": longQuestion, "options": longOptions]]
    ]),
    encoding: .utf8
)!
FixtureProtocol.delay = 0.03
let longHostBefore = controller.window!.frame
controller.performClarification()
pump(until: {
    views(controller.clarificationPanelForTesting!).compactMap { $0 as? NSTextField }
        .contains { $0.stringValue.hasPrefix("请说明这份材料") }
})
let longPanel = controller.clarificationPanelForTesting!
let longSheet = controller.clarificationSheetWindowForTesting!
longSheet.contentView?.layoutSubtreeIfNeeded()
longPanel.layoutSubtreeIfNeeded()
let longQuestionField = views(longPanel).compactMap { $0 as? NSTextField }
    .first { $0.stringValue.hasPrefix("请说明这份材料") }!
expect(longSheet.frame.width <= 620.5,
       "arbitrarily long questions and options cannot widen the clarification sheet")
expect(longQuestionField.frame.width <= longPanel.bounds.width - 30,
       "long clarification copy wraps within the panel instead of increasing its horizontal content width")
expect(controller.window!.frame.width >= 760,
       "the host remains the larger container while a long clarification is visible: host=\(controller.window!.frame), sheet=\(longSheet.frame)")
activate(button("结束追问", in: longPanel))
expect(abs(controller.window!.frame.width - longHostBefore.width) < 1
       && controller.window!.frame.height < 500,
       "closing a long clarification returns to the compact host layout")

// Exercise the selected entry action and actual motion policy using intercepted HTTP.
for reduced in [false, true] {
    let guided = PromptWindowController(clientFactory: { client }, motionPreference: { reduced })
    let guidedRoot = guided.window!.contentView!
    let guidedEditor = views(guidedRoot).compactMap { $0 as? PromptTextView }.first!
    guidedEditor.string = "请整理产品评审纪要"
    guided.textDidChange(Notification(name: NSText.didChangeNotification, object: guidedEditor))
    let generation = button("重构", in: guidedRoot)
    expect(!generation.isHidden && generation.isEnabled, "input stage exposes the selected generation action")
    expect(["微调", "重构", "追问"].allSatisfy { !button($0, in: guidedRoot).isHidden }, "input exposes all three parallel modes")
    guidedRoot.layoutSubtreeIfNeeded()
    let generationFrame = generation.convert(generation.bounds, to: guidedRoot)
    activate(generation)
    expect(!button("停止", in: guidedRoot).isHidden, "generation keeps cancel at the action edge")
    pump(until: { guidedEditor.isEditable })
    expect(FixtureProtocol.lastSystem == AIAction.regenerate.instruction + "\n\n" + ClarificationPromptBuilder.contentLanguageInstruction(.simplifiedChinese),
           "the selected primary action preserves the regeneration protocol and adds the app-language rule")
    expect(guidedEditor.string == FixtureProtocol.content, "generation and reduced motion produce the same result")
    expect(!button("复制 Prompt  ⌘↵", in: guidedRoot).isHidden, "successful generation advances to the copy stage")
    guidedRoot.layoutSubtreeIfNeeded()
    let copyControl = button("复制 Prompt  ⌘↵", in: guidedRoot)
    let copyFrame = copyControl.convert(copyControl.bounds, to: guidedRoot)
    expect(copyFrame.minX > generationFrame.maxX && copyFrame.width >= 170, "result copy is separated from the continuing mode controls")
    let hasArrival = views(guidedRoot).contains { $0.layer?.animation(forKey: "resultArrival") != nil }
    expect(hasArrival != reduced, "reduced motion removes travel/fade while preserving the result")
    guided.window?.orderOut(nil)
}

// Regression: rows only select; applying is explicit and reversible with a populated editor.
activate(button("清空", in: root))
edit("不能被点选覆盖的草稿")
controller.performShowTemplates()
let populatedRoot = controller.templatePickerViewForTesting!
let populatedRows = views(populatedRoot).compactMap { $0 as? CommandRowView }
activate(populatedRows[1].selectionButton)
expect(editor.string == "不能被点选覆盖的草稿", "clicking another row only changes selection")
expect(!populatedRows[1].applyButton.isHidden && populatedRows[0].applyButton.isHidden, "apply button follows the selected row")
expect(populatedRows[1].applyButton.title == "替换", "populated editor explicitly names the replacement consequence")
activate(populatedRows[1].applyButton)
expect(editor.string.contains("【会议主题】"), "explicit replacement inserts the selected template")
controller.promptTextViewDidRequestUndo(editor)
expect(editor.string == "不能被点选覆盖的草稿", "template replacement restores previous draft on undo")

// Every marker symbol is ordinary editable text, across all native delete paths.
for symbol in ["【", "】", ":", "："] {
    for deletionMode in ["backward", "forward", "selection", "cut"] {
        let source = "前【事项:】::：后"
        edit(source)
        let target = (source as NSString).range(of: symbol, options: .backwards)
        let expected = (source as NSString).replacingCharacters(in: target, with: "")
        switch deletionMode {
        case "backward":
            editor.setSelectedRange(NSRange(location: NSMaxRange(target), length: 0)); editor.deleteBackward(nil)
        case "forward":
            editor.setSelectedRange(NSRange(location: target.location, length: 0)); editor.deleteForward(nil)
        case "cut":
            editor.setSelectedRange(target); editor.cut(nil)
            expect(NSPasteboard.general.string(forType: .string) == symbol, "cut copies the exact removed marker symbol")
        default:
            editor.setSelectedRange(target); editor.deleteBackward(nil)
        }
        pump(until: { false }, seconds: 0.02)
        expect(editor.string == expected, "\(deletionMode) deletes \(symbol) without restoring or redirecting it")
        controller.promptTextViewDidRequestUndo(editor)
        expect(editor.string == source, "undo restores the original \(symbol) edit")
        controller.promptTextViewDidRequestRedo(editor)
        expect(editor.string == expected, "redo preserves deliberate \(symbol) deletion")
    }
}
for literal in ["【字段】", "【字段】：", "【目:标：】::：", "【】", "【未闭合", "没有占位符的正文", "\n  【名字 】 \t\n", "  "] {
    edit(literal)
    expect(editor.string == literal, "setting or pasting literal text never normalizes marker punctuation")
    let tokens = PlaceholderNavigator().tokens(in: editor.string)
    if let token = tokens.first {
        controller.promptTextView(editor, focusPlaceholder: token.range)
        expect(editor.string == literal, "active placeholder navigation never inserts punctuation")
        editor.insertTab(nil); editor.insertBacktab(nil)
        expect(editor.string == literal, "Tab and Shift-Tab do not mutate literal text")
    }
    controller.performPasteBack()
    expect(NSPasteboard.general.string(forType: .string) == literal, "copy Prompt keeps punctuation and outer whitespace exactly")
    edit("前后")
    editor.setSelectedRange(NSRange(location: 1, length: 0))
    NSPasteboard.general.clearContents(); NSPasteboard.general.setString(literal, forType: .string)
    editor.paste(nil)
    expect(editor.string == "前" + literal + "后", "native paste does not add markers, colons or whitespace cleanup")
    controller.promptTextViewDidRequestUndo(editor)
    expect(editor.string == "前后", "paste undo retains native text semantics")
}
edit("【其他你自行补充】：")
editor.setSelectedRange(NSRange(location: (editor.string as NSString).length - 1, length: 0))
editor.insertText("-", replacementRange: editor.selectedRange())
expect(editor.string == "【其他你自行补充】-：", "typing before a delimiter inserts at that exact caret instead of redirecting")
editor.setSelectedRange(NSRange(location: 0, length: (editor.string as NSString).length))
editor.insertText("无标记正文", replacementRange: editor.selectedRange())
expect(editor.string == "无标记正文" && PlaceholderNavigator().tokens(in: editor.string).isEmpty,
       "all placeholders and their punctuation may be replaced or removed")

// A placeholder is ordinary text: deleting its colon must stay deleted.
edit("【其他你自行补充】：")
editor.setSelectedRange(NSRange(location: (editor.string as NSString).length, length: 0))
editor.deleteBackward(nil)
expect(editor.string == "【其他你自行补充】", "deleting a placeholder colon must not add it back")

// Regression: a freshly typed label must remain editable, including the user's inline q field.
edit("【计划公开渠道】：GitHub、viow.ai、【q】：\n【拟公开时间】：")
let inlineQ = (editor.string as NSString).range(of: "q")
editor.setSelectedRange(NSRange(location: NSMaxRange(inlineQ), length: 0))
editor.insertText("uery", replacementRange: editor.selectedRange())
expect(editor.string.contains("【query】："), "typing at the user's q caret continues the label instead of silently blocking")

let inlineAfterTyping = editor.string
controller.promptTextViewDidRequestUndo(editor)
expect(editor.string == "【计划公开渠道】：GitHub、viow.ai、【q】：\n【拟公开时间】：", "q typing undo restores the exact preceding text")
controller.promptTextViewDidRequestRedo(editor)
expect(editor.string == inlineAfterTyping, "q typing redo restores the complete edit")
let queryName = (editor.string as NSString).range(of: "query")
editor.setSelectedRange(queryName)
editor.insertText("其他渠道", replacementRange: editor.selectedRange())
expect(editor.string.contains("【其他渠道】："), "a selected label accepts direct replacement with Chinese text")
controller.promptTextViewDidRequestUndo(editor)
expect(editor.string == inlineAfterTyping && editor.selectedRange() == queryName, "undo restores the label and selected range")
let secondInlineToken = PlaceholderNavigator().tokens(in: editor.string)[1]
controller.promptTextView(editor, focusPlaceholder: secondInlineToken.range)
editor.insertText("公众号", replacementRange: editor.selectedRange())
expect(editor.string.contains("GitHub、viow.ai、【query】：公众号"), "second inline field fills without altering the first field's value")
editor.insertTab(nil)
expect(editor.selectedRange().location == PlaceholderNavigator().tokens(in: editor.string)[2].insertionLocation, "Tab advances from the second inline value to the next field")
editor.insertBacktab(nil)
expect(editor.selectedRange().location == PlaceholderNavigator().tokens(in: editor.string)[1].insertionLocation, "Shift-Tab returns to the second inline field")
editor.setSelectedRange(NSRange(location: 0, length: 0))
editor.insertText("发布：", replacementRange: editor.selectedRange())
expect(editor.string.hasPrefix("发布：【计划公开渠道】"), "typing before a leading placeholder is not silently blocked")

edit("【】：\n【负责人】：小李")
editor.setSelectedRange(NSRange(location: 1, length: 0))
for part in ["q", "uery", " ", "name"] { editor.insertText(part, replacementRange: editor.selectedRange()) }
expect(editor.string == "【query name】：\n【负责人】：小李", "an empty label accepts continuous typing including a multiword name")
let emptyCreated = editor.string
editor.moveLeft(nil)
editor.insertText("X", replacementRange: editor.selectedRange())
expect(editor.string.contains("【query namXe】："), "arrow movement within a label retains native editing semantics")
controller.promptTextViewDidRequestUndo(editor)
expect(editor.string == emptyCreated, "undo restores a name after an arrow-positioned edit")

edit("【q】：")
editor.setSelectedRange(NSRange(location: 2, length: 0))
editor.insertText(" ", replacementRange: editor.selectedRange())
let unfinishedName = editor.string
let unfinishedNameSelection = NSRange(location: 1, length: 2)
editor.setSelectedRange(unfinishedNameSelection)
pump(until: { false }, seconds: 0.05)
expect(editor.string == unfinishedName && editor.selectedRange() == unfinishedNameSelection,
       "selecting an unfinished label does not trim its text or collapse the native selection")
editor.insertText("项目", replacementRange: editor.selectedRange())
controller.promptTextViewDidRequestUndo(editor)
pump(until: { false }, seconds: 0.05)
expect(editor.string == unfinishedName && editor.selectedRange() == unfinishedNameSelection,
       "queued normalization cannot rewrite a restored in-progress label selection")

edit("【渠道】：A 【负责人】：小李")
let beforeNextField = (editor.string as NSString).range(of: "【负责人】").location
editor.setSelectedRange(NSRange(location: beforeNextField, length: 0))
editor.insertText("【", replacementRange: editor.selectedRange())
editor.insertText("q", replacementRange: editor.selectedRange())
expect(PlaceholderNavigator().tokens(in: editor.string).count == 2, "an unfinished opening bracket cannot swallow the following inline field")
expect((editor.string as NSString).substring(with: PlaceholderNavigator().tokens(in: editor.string)[1].range) == "【负责人】", "an unfinished outer label leaves the following marker independently recognizable")
editor.insertText("】", replacementRange: editor.selectedRange())
expect(editor.string == "【渠道】：A 【q】【负责人】：小李", "closing a newly typed marker creates its own field without changing the following one")
editor.insertText("内容", replacementRange: editor.selectedRange())
expect(editor.string == "【渠道】：A 【q】内容【负责人】：小李", "typing immediately after closing a new marker fills its value")
controller.promptTextViewDidRequestUndo(editor)
controller.promptTextViewDidRequestUndo(editor)
expect(editor.string == "【渠道】：A 【q【负责人】：小李", "undo restores the exact unfinished marker rather than canonicalizing it")
controller.promptTextViewDidRequestRedo(editor)
expect(editor.string == "【渠道】：A 【q】【负责人】：小李", "redo restores the marker close as a single edit")

edit("【计划公开渠道】：GitHub、viow.ai、【q】：\n【时间】：")
let composedLabelRange = (editor.string as NSString).range(of: "q")
editor.setSelectedRange(composedLabelRange)
let labelCompositionBefore = editor.string
editor.setMarkedText("xiang", selectedRange: NSRange(location: 5, length: 0), replacementRange: editor.selectedRange())
expect(editor.hasMarkedText(), "composition can start inside a selected label")
editor.setMarkedText("xiangmu", selectedRange: NSRange(location: 7, length: 0), replacementRange: editor.markedRange())
editor.insertText("项目", replacementRange: editor.markedRange())
expect(editor.string.contains("【项目】：") && !editor.hasMarkedText(), "Chinese composition commits inside a label without losing delimiters")
let labelCompositionAfter = editor.string
controller.promptTextViewDidRequestUndo(editor)
expect(editor.string == labelCompositionBefore && editor.selectedRange() == composedLabelRange, "one undo restores all text and selection before a label composition")
controller.promptTextViewDidRequestRedo(editor)
expect(editor.string == labelCompositionAfter, "redo restores the committed Chinese label")
let compositionValueToken = PlaceholderNavigator().tokens(in: editor.string)[1]
controller.promptTextView(editor, focusPlaceholder: compositionValueToken.range)
editor.setMarkedText("neirong", selectedRange: NSRange(location: 7, length: 0), replacementRange: NSRange(location: NSNotFound, length: 0))
editor.insertText("中文值", replacementRange: editor.markedRange())
expect(editor.string.contains("【项目】：中文值"), "the second inline field still accepts composed value input")
controller.promptTextViewDidRequestUndo(editor)
expect(editor.string == labelCompositionAfter, "value composition is also undone as one complete edit")

edit("【渠道】：GitHub 【负责人】：小李")
let pasteName = (editor.string as NSString).range(of: "负责人")
editor.setSelectedRange(pasteName)
NSPasteboard.general.clearContents(); NSPasteboard.general.setString("审核人", forType: .string)
editor.paste(nil)
expect(editor.string == "【渠道】：GitHub 【审核人】：小李", "native paste can replace a selected label")
controller.promptTextViewDidRequestUndo(editor)
expect(editor.string == "【渠道】：GitHub 【负责人】：小李", "label paste undo restores the full original")
let crossStart = (editor.string as NSString).range(of: "GitHub").location
let crossEnd = (editor.string as NSString).range(of: "小李").location
let crossSelection = NSRange(location: crossStart, length: crossEnd - crossStart)
editor.setSelectedRange(crossSelection)
editor.insertText("公开审核：", replacementRange: crossSelection)
expect(editor.string == "【渠道】：公开审核：小李", "an explicit selection across a value and another label keeps native replacement semantics")
controller.promptTextViewDidRequestUndo(editor)
expect(editor.string == "【渠道】：GitHub 【负责人】：小李" && editor.selectedRange() == crossSelection, "cross-field replacement undo restores text and selection exactly")
editor.setSelectedRange(PlaceholderNavigator().tokens(in: editor.string)[1].markerRange)
editor.insertText("审核人：", replacementRange: editor.selectedRange())
expect(editor.string == "【渠道】：GitHub 审核人：小李", "explicit replacement of a complete field is honored instead of redirecting the inserted text")
controller.promptTextViewDidRequestUndo(editor)
expect(editor.string == "【渠道】：GitHub 【负责人】：小李", "whole-field replacement undo restores its structure")

// Placeholder rendering must never alter text or clipboard data.
edit("开头【会议主题】；随后【截止日期】")
let hint = views(root).compactMap { $0 as? NSTextField }.first { $0.stringValue.hasPrefix("【】标记和正文均可编辑") }!
let hintContainer = hint.superview!
expect(!hintContainer.isHidden
       && hintContainer.superview === button("清空", in: root).superview,
       "placeholder hint is conditional and inside the editor toolbar")
expect(hint.stringValue == "【】标记和正文均可编辑\n按 Tab 跳到下一处", "placeholder structure and navigation remain two explicit lines")
let hintMarkerRange = (hint.attributedStringValue.string as NSString).range(of: "【】")
expect(hint.attributedStringValue.attribute(.backgroundColor, at: hintMarkerRange.location, effectiveRange: nil) != nil,
       "the 【】 sample carries the same local marker fill used in the editor")
root.layoutSubtreeIfNeeded()
let footer = hintContainer.superview!
expect(footer.frame.minX >= 16 && footer.frame.minY >= 12 && footer.bounds.height >= 32, "editor footer maintains specified horizontal and bottom padding")
let footerSeparator = views(root).compactMap { $0 as? NSBox }.first { $0.boxType == .separator }!
let editorViewport = editor.enclosingScrollView!
let separatorRect = footerSeparator.convert(footerSeparator.bounds.insetBy(dx: 0, dy: footerSeparator.alignmentRectInsets.top), to: root)
let editorRect = editorViewport.convert(editorViewport.bounds, to: root)
expect(editorRect.minY - separatorRect.maxY >= 12, "scrolled text has a visible breathing gap before the footer divider")
let marker = PlaceholderNavigator().ranges(in: editor.string).first!
let decoration = editor.layoutManager!.temporaryAttributes(atCharacterIndex: marker.location, effectiveRange: nil)
expect(decoration[.foregroundColor] != nil && decoration[.backgroundColor] == nil, "placeholder uses production drawing for its row instead of mutating rich text")
expect(editor.textStorage!.attributes(at: marker.location, effectiveRange: nil)[.backgroundColor] == nil, "placeholder color is not written into the content")
edit("【目标:】：\n\n【受众：】:\n")
expect(editor.string == "【目标:】：\n\n【受众：】:\n",
       "placeholder recognition never relocates or normalizes punctuation")
editor.frame.size.width = 620
root.layoutSubtreeIfNeeded()
let placeholderRows = editor.placeholderVisualRows()
expect(placeholderRows.count == 2, "each placeholder line exposes one production background row")
expect(placeholderRows.allSatisfy { $0.height >= 18 && $0.width > 8 && $0.maxX <= editor.bounds.width - 4 },
       "placeholder highlights wrap only the marker text instead of a full editor row: \(placeholderRows), editor=\(editor.bounds)")
expect(placeholderRows[0].maxY + 1 < placeholderRows[1].minY,
       "adjacent wrapped placeholder surfaces never overlap")
edit("开头【会议主题】；随后【截止日期】")
let canonicalMarker = PlaceholderNavigator().ranges(in: editor.string).first!
let canonicalDecoration = editor.layoutManager!.temporaryAttributes(atCharacterIndex: canonicalMarker.location, effectiveRange: nil)
expect(canonicalDecoration[.foregroundColor] != nil && editor.textStorage!.attributes(at: canonicalMarker.location, effectiveRange: nil)[.backgroundColor] == nil, "placeholder uses production drawing for its row instead of mutating rich text")
expect(editor.textStorage!.attributes(at: canonicalMarker.location, effectiveRange: nil)[.backgroundColor] == nil, "placeholder color is not written into the content")
editor.setSelectedRange(NSRange(location: 0, length: 0))
editor.keyDown(with: key("\t", code: 48))
let firstToken = PlaceholderNavigator().tokens(in: editor.string).first!
expect(editor.selectedRange() == NSRange(location: firstToken.insertionLocation, length: 0), "Tab lands after the protected placeholder structure")
controller.promptTextView(editor, focusPlaceholder: firstToken.range)
editor.insertText("会议资料", replacementRange: editor.selectedRange())
expect(editor.string.hasPrefix("开头【会议主题】会议资料"), "click/Tab filling continues after the actual colon")
let deletableLabelToken = PlaceholderNavigator().tokens(in: editor.string).first!
let selectedLabelCharacter = NSRange(location: deletableLabelToken.range.location + 1, length: 1)
editor.setSelectedRange(selectedLabelCharacter)
editor.deleteBackward(nil)
expect(editor.string.hasPrefix("开头【议主题】会议资料"), "a selected character inside placeholder label is deletable")
controller.promptTextViewDidRequestUndo(editor)
expect(editor.string.hasPrefix("开头【会议主题】会议资料"), "undo restores placeholder label text deleted from a selection")
let deletableWholeToken = PlaceholderNavigator().tokens(in: editor.string).first!
editor.setSelectedRange(deletableWholeToken.markerRange)
editor.deleteBackward(nil)
expect(editor.string == "开头会议资料；随后【截止日期】", "selecting the whole placeholder structure permits explicit deletion: \(editor.string.debugDescription)")
controller.promptTextViewDidRequestUndo(editor)
expect(editor.string.hasPrefix("开头【会议主题】会议资料"), "undo also restores deletion of a whole selected placeholder")
edit("开头【会议主题】\n随后【截止日期】")
editor.setSelectedRange(NSRange(location: 0, length: 0))
controller.performPasteBack()
expect(NSPasteboard.general.string(forType: .string) == "开头【会议主题】\n随后【截止日期】", "copy preserves the actual placeholder punctuation")

let longPlaceholderText = (1...42).map { "第 \($0) 行：用于检查长内容和占位符定位。" }.joined(separator: "\n") + "\n请处理【最后事项】"
edit(longPlaceholderText)
root.layoutSubtreeIfNeeded()
let minimap = views(root).compactMap { $0 as? PlaceholderMinimapView }.first!
expect(!minimap.isHidden, "long placeholder content exposes a clickable full-text minimap (doc=\(editor.bounds.height), viewport=\(editor.enclosingScrollView?.documentVisibleRect.height ?? -1), tokens=\(PlaceholderNavigator().tokens(in: editor.string).count))")
expect(minimap.accessibilityValue() as? String == "1 个占位符", "full-text minimap names its placeholder count")
expect(minimap.frame.width >= 30 && minimap.frame.height >= 104, "full-text minimap has a readable document-card footprint")
let minimapFrame = minimap.convert(minimap.bounds, to: root)
let documentFrame = editor.enclosingScrollView!.convert(editor.enclosingScrollView!.bounds, to: root)
expect(minimapFrame.minX - documentFrame.maxX >= 4, "the minimap occupies a separate gutter and never covers editable text")
expect(editor.enclosingScrollView!.hasVerticalScroller, "long content retains normal document scrolling beside placeholder navigation")
let lastToken = PlaceholderNavigator().tokens(in: editor.string).last!
minimap.onJump?(lastToken.range)
expect(editor.selectedRange().location == PlaceholderNavigator().tokens(in: editor.string).last!.insertionLocation,
       "minimap jump lands after the actual colon at the placeholder fill point")
let topButton = views(root).compactMap { $0 as? NSButton }.first { $0.accessibilityLabel() == "回到正文顶部" }!
editor.scrollRangeToVisible(lastToken.markerRange)
pump(until: { !topButton.isHidden })
expect(!topButton.isHidden, "return-to-top appears near the bottom of long content")
activate(topButton)
pump(until: { editor.enclosingScrollView!.documentVisibleRect.minY <= 1 })
expect(editor.enclosingScrollView!.documentVisibleRect.minY <= 1 && editor.selectedRange().location == 0, "return-to-top restores the start of the editor and focus")
edit("现在没有待填写信息")
expect(hintContainer.isHidden, "placeholder explanation disappears when there are no markers")

edit("【项目名称】\n【负责人】：小李\n【截止日期】：")
controller.promptTextView(editor, focusPlaceholder: PlaceholderNavigator().ranges(in: editor.string).first!)
let inputToken = PlaceholderNavigator().tokens(in: editor.string).first!
expect(!inputToken.hasTerminator && editor.selectedRange().location == inputToken.insertionLocation,
       "focusing a marker without a colon does not add punctuation")
editor.setMarkedText("xiangmu", selectedRange: NSRange(location: 7, length: 0),
                     replacementRange: NSRange(location: NSNotFound, length: 0))
expect(editor.hasMarkedText(), "placeholder filling preserves input-method composition")
editor.setMarkedText("xinxiangmu", selectedRange: NSRange(location: 10, length: 0), replacementRange: editor.markedRange())
editor.insertText("新项目", replacementRange: editor.markedRange())
expect(editor.string.hasPrefix("【项目名称】新项目\n"), "committing composed input fills after the protected colon once")
let composedResult = editor.string
controller.promptTextViewDidRequestUndo(editor)
expect(editor.string.hasPrefix("【项目名称】\n"), "undo removes an entire input-method composition instead of restoring intermediate spelling")
controller.promptTextViewDidRequestRedo(editor)
expect(editor.string == composedResult, "redo restores the committed composed value")
let filledTokens = PlaceholderNavigator().tokens(in: editor.string)
expect(filledTokens[0].isFilled && filledTokens[1].isFilled && !filledTokens[2].isFilled,
       "placeholder state distinguishes filled values from the remaining empty field")
let nameValue = filledTokens[0].valueRange
editor.setSelectedRange(NSRange(location: nameValue.location + 1, length: 1))
editor.insertText("版", replacementRange: editor.selectedRange())
expect(editor.string.hasPrefix("【项目名称】新版目"), "an existing placeholder value remains editable")
editor.keyDown(with: key("\t", code: 48))
expect(editor.selectedRange().location == PlaceholderNavigator().tokens(in: editor.string)[1].insertionLocation,
       "Tab advances from an edited value to the next field")
editor.keyDown(with: key("\t", code: 48, flags: .shift))
expect(editor.selectedRange().location == PlaceholderNavigator().tokens(in: editor.string)[0].insertionLocation,
       "Shift-Tab returns to the preceding field")
let colonToken = PlaceholderNavigator().tokens(in: editor.string)[0]
let formBeforeDelete = editor.string
editor.setSelectedRange(NSRange(location: colonToken.insertionLocation, length: 0))
editor.deleteBackward(nil)
let removedBoundary = NSMutableString(string: formBeforeDelete)
removedBoundary.deleteCharacters(in: NSRange(location: colonToken.insertionLocation - 1, length: 1))
expect(editor.string == removedBoundary as String, "backspace can remove a marker delimiter at its boundary")
controller.promptTextViewDidRequestUndo(editor)
expect(editor.string == formBeforeDelete, "undo restores a deliberately deleted delimiter")
editor.insertText("一次全新请求", replacementRange: NSRange(location: 0, length: (editor.string as NSString).length))
expect(editor.string == "一次全新请求", "deliberate whole-document replacement does not trap the user in protected fields")
controller.promptTextViewDidRequestUndo(editor)
expect(editor.string == formBeforeDelete, "whole-document replacement preserves a complete undo snapshot")

// Mixed operations keep all history while the model receives only the recent three turns.
activate(button("清空", in: root))
for index in 1...6 {
    edit("独立输入-\(index)")
    let result = "本轮结果-\(index)\n" + String(repeating: "长正文完整可读。\n", count: 35)
    if index == 3 {
        FixtureProtocol.content = String(data: try! JSONSerialization.data(withJSONObject: ["status": "final", "prompt": result]), encoding: .utf8)!
        activate(button("追问", in: root))
        pump(until: {
            views(controller.clarificationPanelForTesting ?? NSView()).compactMap { $0 as? NSTextField }
                .contains { $0.stringValue == "追问 · 无需补充" }
        })
        activate(button("使用整理后的 Prompt", in: controller.clarificationPanelForTesting!))
    } else {
        FixtureProtocol.content = result
        activate(button(index.isMultiple(of: 2) ? "重构" : "微调", in: root))
    }
    pump(until: { editor.isEditable })
    expect(editor.string == result, "mixed mode round \(index) refreshes the same editor")
    expect(["微调", "重构", "追问"].allSatisfy { button($0, in: root).isEnabled }, "each result permits another mode selection")
}
let sent = FixtureProtocol.lastMessages.last?["content"] ?? ""
expect(!sent.contains("独立输入-1") && !sent.contains("独立输入-2") && sent.contains("独立输入-3") && sent.contains("独立输入-5"), "request context contains exactly the recent three previous rounds")
let historyEntry = button("修改记录 · 6 轮", in: root)
let mainSize = controller.window!.frame.size
activate(historyEntry)
let historyWindow = NSApp.windows.first { $0.title == "修改记录" && $0.isVisible }!
expect(historyWindow.collectionBehavior.contains(.moveToActiveSpace)
       && !historyWindow.collectionBehavior.contains(.canJoinAllSpaces)
       && !historyWindow.isRestorable,
       "history window follows the editor's current Space")
let historyRoot = historyWindow.contentView!
historyRoot.layoutSubtreeIfNeeded()
let historyPicker = views(historyRoot).compactMap { $0 as? NSPopUpButton }.first!
let historyText = views(historyRoot).compactMap { $0 as? NSTextView }.first!
expect(historyPicker.numberOfItems == 6 && historyPicker.indexOfSelectedItem == 5, "history window retains and opens the latest of all six rounds")
expect(mainSize == controller.window!.frame.size, "opening history does not shrink or resize the editor")
let historyScroll = historyText.enclosingScrollView!
expect(historyScroll.frame.height > 400 && historyText.frame.height > historyScroll.contentSize.height, "long history has a large independently scrolling viewport")
for _ in 0..<5 { activate(button("上一轮", in: historyRoot)) }
expect(historyText.string.contains("独立输入-1") && historyText.string.contains("本轮结果-1"), "the first round is still fully readable after six generations")
historyWindow.setContentSize(NSSize(width: 560, height: 380)); historyRoot.layoutSubtreeIfNeeded()
expect(historyScroll.contentView.bounds.origin.x == 0 && abs(historyText.frame.width - historyScroll.contentSize.width) < 1, "history wraps without clipping at the supported minimum width")
activate(button("返回编辑", in: historyRoot))
expect(!historyWindow.isVisible && controller.window!.firstResponder === editor, "closing history returns focus to the original editor")
activate(button("清空", in: root))
controller.promptTextViewDidRequestUndo(editor)
expect(!button("修改记录 · 6 轮", in: root).isHidden, "undo clear restores every recorded round")
FixtureProtocol.content = "结果【待填事项】："

for appearance in [NSAppearance.Name.aqua, .darkAqua] {
    expect(contrast(AppTheme.placeholderTextColor, AppTheme.contentColor, appearance: appearance) >= 4.5, "placeholder help is readable in \(appearance.rawValue)")
    var markerBackground = AppTheme.contentColor
    NSAppearance(named: appearance)!.performAsCurrentDrawingAppearance {
        markerBackground = AppTheme.accentColor.blended(withFraction: 0.87, of: AppTheme.contentColor)!
    }
    expect(contrast(AppTheme.placeholderTextColor, markerBackground, appearance: appearance) >= 4.5, "highlighted placeholder text is readable in \(appearance.rawValue)")
    var pendingAlpha: CGFloat = 1
    var activeAlpha: CGFloat = 1
    NSAppearance(named: appearance)!.performAsCurrentDrawingAppearance {
        pendingAlpha = AppTheme.placeholderFillColor.usingColorSpace(.sRGB)?.alphaComponent ?? 1
        activeAlpha = AppTheme.placeholderActiveFillColor.usingColorSpace(.sRGB)?.alphaComponent ?? 1
    }
    expect(pendingAlpha <= 0.04 && activeAlpha <= 0.08,
           "placeholder fields stay subordinate to body copy instead of painting a full-strength highlight")
}

let fixture = UserPromptTemplate(id: UUID(), title: "测试模板", detail: "测试说明", body: "正文【输入】", createdAt: Date(), updatedAt: Date())
let recencyNow = Date()
let recentNew = UserPromptTemplate(id: UUID(), title: "新建", detail: "", body: "", createdAt: recencyNow.addingTimeInterval(-86400), updatedAt: recencyNow.addingTimeInterval(-86400))
let recentUpdate = UserPromptTemplate(id: UUID(), title: "更新", detail: "", body: "", createdAt: recencyNow.addingTimeInterval(-30 * 86400), updatedAt: recencyNow.addingTimeInterval(-86400))
let oldTemplate = UserPromptTemplate(id: UUID(), title: "旧模板", detail: "", body: "", createdAt: recencyNow.addingTimeInterval(-30 * 86400), updatedAt: recencyNow.addingTimeInterval(-8 * 86400))
expect(recentNew.recency(asOf: recencyNow) == .new && recentNew.libraryItem.recency?.title == "New", "an unmodified seven-day personal template is honestly marked New")
expect(recentUpdate.recency(asOf: recencyNow) == .updated
       && recentUpdate.libraryItem.recency?.title == "更新"
       && recentUpdate.libraryItem.recency?.explanation.contains("修改") == true,
       "a recently modified older template is marked updated rather than new")
expect(oldTemplate.recency(asOf: recencyNow) == nil, "templates outside the seven-day window have no recency badge")
let badgeProbeHost = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 64))
let badgeProbe = CommandRowView()
badgeProbe.configure(with: recentUpdate.libraryItem, isSelected: true, allowsApply: false)
badgeProbeHost.addSubview(badgeProbe)
NSLayoutConstraint.activate([
    badgeProbe.leadingAnchor.constraint(equalTo: badgeProbeHost.leadingAnchor),
    badgeProbe.trailingAnchor.constraint(equalTo: badgeProbeHost.trailingAnchor),
    badgeProbe.topAnchor.constraint(equalTo: badgeProbeHost.topAnchor)
])
badgeProbeHost.layoutSubtreeIfNeeded()
expect(badgeProbe.recencyUsesTitleBaselineForTesting && badgeProbe.recencyBadgeWidthForTesting >= 34,
       "the recency capsule keeps a stable minimum and aligns to the title baseline")
let manager = TemplateManagerWindowController(discardDecision: { false }, templatesProvider: { [fixture] })
expect(manager.window!.title == AppIdentity.current.displayName,
       "template manager uses the product identity in chrome and keeps its page title in content")
expect(manager.window!.collectionBehavior.contains(.moveToActiveSpace)
       && !manager.window!.collectionBehavior.contains(.canJoinAllSpaces)
       && !manager.window!.isRestorable,
       "template manager follows the active Space")
manager.window!.contentView!.layoutSubtreeIfNeeded()
let managerViews = views(manager.window!.contentView!)
let listScroll = managerViews.compactMap { $0 as? NSScrollView }.first { $0.documentView is NSStackView }!
let firstManagerRow = views(listScroll.documentView!).compactMap { $0 as? CommandRowView }.first!
expect(views(firstManagerRow).compactMap { $0 as? NSTextField }.contains { $0.stringValue == "New" }, "personal template inner page exposes its recent-change badge")
let recencyLabel = views(firstManagerRow).compactMap { $0 as? NSTextField }.first { $0.stringValue == "New" }!
expect((NSColor(cgColor: recencyLabel.layer!.backgroundColor!)?.alphaComponent ?? 1) < 0.3, "recent template badge stays secondary to the template name")
expect(firstManagerRow.applyButton.isHidden, "template management has no inert apply action")
let managerTitle = views(firstManagerRow).compactMap { $0 as? NSTextField }.first { $0.stringValue == fixture.title }!
expect(managerTitle.frame.width >= managerTitle.intrinsicContentSize.width, "short personal template names fit the sidebar without a reserved action column")
expect(button("保存", in: manager.window!.contentView!).bezelColor == nil, "unchanged template has a neutral disabled save action")
let managerActionButtons = [
    button("新增", in: manager.window!.contentView!),
    button("删除", in: manager.window!.contentView!),
    button("保存", in: manager.window!.contentView!)
]
let managerActionCenters = managerActionButtons.map { $0.convert($0.bounds, to: manager.window!.contentView!).midY }
expect((managerActionCenters.max() ?? 0) - (managerActionCenters.min() ?? 0) < 1, "template creation, deletion and saving share one footer action line")
let rowInClip = firstManagerRow.convert(firstManagerRow.bounds, to: listScroll.contentView)
let topDistance = listScroll.contentView.isFlipped ? rowInClip.minY - listScroll.contentView.bounds.minY : listScroll.contentView.bounds.maxY - rowInClip.maxY
expect(abs(topDistance) <= 8, "one personal template starts at the top of the list")
let name = managerViews.compactMap { $0 as? NSTextField }.first { $0.accessibilityLabel() == "模板名称" }!
expect(!manager.hasUnsavedChanges, "loaded personal template starts clean")
name.stringValue = "未保存名称"
manager.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: name))
expect(manager.hasUnsavedChanges, "personal template edits are tracked")
expect(!manager.windowShouldClose(manager.window!), "closing can preserve unsaved edits")
activate(button("新增", in: manager.window!.contentView!))
expect(name.stringValue == "未保存名称", "rejecting discard retains the edited template")
let managerSearch = managerViews.compactMap { $0 as? NSSearchField }.first!
expect(managerSearch.placeholderString == "搜索"
       && managerSearch.cell?.title == "",
       "template manager search has one visible text layer")
managerSearch.stringValue = "不匹配"
manager.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: managerSearch))
expect(managerSearch.stringValue.isEmpty && name.stringValue == "未保存名称", "search cannot silently discard current edits")
manager.window!.setContentSize(NSSize(width: 820, height: 520))
manager.window!.contentView!.layoutSubtreeIfNeeded()
expect(name.frame.width >= 400, "template name field fills the editor at minimum width")
let bodyScroll = views(manager.window!.contentView!).compactMap { $0 as? NSScrollView }.first { $0.documentView is NSTextView }!
expect(abs(bodyScroll.documentView!.frame.width - bodyScroll.contentSize.width) < 1, "template body width tracks the resized viewport")
expect(bodyScroll.contentView.bounds.origin.x == 0, "template load cannot clip the start of a line by horizontal scrolling")
let managerSaveButton = button("保存", in: manager.window!.contentView!)
expect(managerSaveButton.frame.width >= managerSaveButton.fittingSize.width - 1,
       "the compact template save label remains fully visible at minimum window width")
expect(managerViews.compactMap { $0 as? NSScrollView }.allSatisfy { !$0.drawsBackground && !$0.contentView.drawsBackground }, "template manager scroll content inherits the neutral surface")
expect(!(bodyScroll.documentView as! NSTextView).drawsBackground, "template body does not add a separately tinted text background")
let managerStoreBefore = UserTemplateStore.all()
var inMemoryTemplates = [fixture]
var changedTemplateLibrary = false
let editingManager = TemplateManagerWindowController(
    templatesProvider: { inMemoryTemplates },
    addTemplate: { draft in let saved = transientTemplate(draft); inMemoryTemplates.append(saved); return saved },
    updateTemplate: { item in
        if let index = inMemoryTemplates.firstIndex(where: { $0.id == item.id }) {
            var saved = item; saved.updatedAt = Date(); inMemoryTemplates[index] = saved
        }
    },
    removeTemplate: { id in inMemoryTemplates.removeAll { $0.id == id } }
)
editingManager.onChange = { changedTemplateLibrary = true }
let editingRoot = editingManager.window!.contentView!
let editingName = views(editingRoot).compactMap { $0 as? NSTextField }.first { $0.accessibilityLabel() == "模板名称" }!
let editingBody = views(editingRoot).compactMap { $0 as? NSTextView }.first!
editingName.stringValue = "更新后的周会模板"
editingManager.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: editingName))
activate(button("保存", in: editingRoot))
expect(inMemoryTemplates.count == 1 && inMemoryTemplates[0].id == fixture.id
       && inMemoryTemplates[0].title == "更新后的周会模板", "template update preserves identity and updates the selected object")
expect(!editingManager.hasUnsavedChanges && changedTemplateLibrary, "saved template leaves the dirty state and notifies the library")
activate(button("新增", in: editingRoot))
expect(views(editingRoot).compactMap { $0 as? NSTextField }.contains { $0.stringValue.isEmpty && $0.accessibilityHelp() == nil },
       "new-template editing clears the previous saved announcement")
editingName.stringValue = "新增周报模板"
editingBody.string = "  【项目】::\n【进展】\n "
editingManager.textDidChange(Notification(name: NSText.didChangeNotification, object: editingBody))
activate(button("保存", in: editingRoot))
expect(inMemoryTemplates.count == 2 && inMemoryTemplates.last!.title == "新增周报模板",
       "new-template save creates a separate selectable record")
expect(inMemoryTemplates.last!.body == "  【项目】::\n【进展】\n ", "template manager preserves body punctuation and outer whitespace")
expect(UserTemplateStore.all() == managerStoreBefore, "template management exercises save and update without persistent fixture writes")
editingManager.close()
let previewDraft = TemplateDraft(title: "外观检查", detail: "虚构模板", body: "  正文【输入】::\n\t")
let previewStoreBefore = UserTemplateStore.all()
var capturedPreviewDraft: TemplateDraft?
var previewSaveCallback = false
let templatePreview = TemplatePreviewWindowController(draft: previewDraft, persistDraft: { draft in
    capturedPreviewDraft = draft
    return transientTemplate(draft)
})
expect(templatePreview.window!.collectionBehavior.contains(.moveToActiveSpace)
       && !templatePreview.window!.collectionBehavior.contains(.canJoinAllSpaces)
       && !templatePreview.window!.isRestorable,
       "template preview follows the active Space")
templatePreview.onSave = { _ in previewSaveCallback = true }
expect(views(templatePreview.window!.contentView!).compactMap { $0 as? NSScrollView }.allSatisfy { !$0.drawsBackground && !$0.contentView.drawsBackground }, "template preview inherits the neutral surface")
activate(button("保存", in: templatePreview.window!.contentView!))
expect(capturedPreviewDraft == previewDraft && previewSaveCallback, "preview save hands the exact draft to its persistence action and callback")
expect(UserTemplateStore.all() == previewStoreBefore, "fictional preview save never changes the persistent Preview template store")
let previewWriteError = CocoaError(.fileWriteNoPermission)
let failedPreview = TemplatePreviewWindowController(draft: previewDraft, persistDraft: { _ in throw previewWriteError })
activate(button("保存", in: failedPreview.window!.contentView!))
expect(views(failedPreview.window!.contentView!).compactMap { $0 as? NSTextField }.contains { $0.stringValue == previewWriteError.localizedDescription }, "preview save failure remains visible instead of claiming success")

let panel = ClarificationPanelView(frame: NSRect(x: 0, y: 0, width: 680, height: 500))
var answer: ClarificationAnswer?
var ended = false
panel.onSubmit = { answer = $0 }
panel.onEnd = { ended = true }
panel.configure(question: ClarificationQuestion(question: "希望给谁使用？", options: ["初次使用者", "已有使用者"]), round: 1, maximumRounds: 5, questionIndex: 0, totalQuestions: 2)
expect(!button("下一题", in: panel).isEnabled, "clarification requires an answer before advancing")
expect(button("下一题", in: panel).bezelColor == nil, "disabled submit has no purple primary fill")
expect(views(panel).compactMap { $0 as? NSBox }.filter { $0.boxType == .separator }.count == 1, "custom clarification answers are separated from the option list")
panel.layoutSubtreeIfNeeded()
let paddedRadio = button("初次使用者", in: panel)
expect(paddedRadio.frame.minX >= 12 && paddedRadio.frame.minY >= 8, "radio content is inset from its option surface")
let hoverChoice = views(panel).compactMap { $0 as? ClarificationChoiceButton }.first!
hoverChoice.mouseEntered(with: NSEvent())
expect(hoverChoice.gradientColorsProvider != nil, "clarification option exposes a visible hover surface before selection")
hoverChoice.mouseExited(with: NSEvent())
activate(button("初次使用者", in: panel))
expect(button("初次使用者", in: panel).state == .on, "clarification selection uses native radio state")
let selectedChoice = views(panel).compactMap { $0 as? ThemedSurfaceView }.first { $0.gradientColorsProvider != nil }!
for appearance in [NSAppearance.Name.aqua, .darkAqua, .aqua] {
    selectedChoice.appearance = NSAppearance(named: appearance)
    selectedChoice.updateLayer()
    let gradient = selectedChoice.layer!.sublayers!.compactMap { $0 as? CAGradientLayer }.first!
    let colors = gradient.colors as! [CGColor]
    for cgColor in colors {
        let background = NSColor(cgColor: cgColor)!.usingColorSpace(.sRGB)!
        expect(appearance == .darkAqua ? background.brightnessComponent < 0.5 : background.brightnessComponent > 0.7,
               "selected clarification gradient follows appearance changes without reselecting")
        expect(contrast(.labelColor, background, appearance: appearance) >= 4.5,
               "selected option text remains readable on every gradient endpoint")
    }
}
selectedChoice.appearance = nil
activate(button("下一题", in: panel))
expect(answer?.answer == "初次使用者", "clarification sends the chosen value")
panel.configure(question: ClarificationQuestion(question: "希望给谁使用？", options: ["初次使用者", "已有使用者"]), round: 1, maximumRounds: 5, questionIndex: 0, totalQuestions: 2)
let literalAnswerField = views(panel).compactMap { $0 as? GrowingClarificationAnswerField }.first!
literalAnswerField.stringValue = "  【回答】::  "
expect(literalAnswerField.frame.height >= 44, "custom answer starts at the shared minimum control height")
activate(button("下一题", in: panel))
expect(answer?.answer == "  【回答】::  ", "custom answer submission preserves literal symbols and whitespace")
panel.configure(question: ClarificationQuestion(question: "希望给谁使用？", options: ["初次使用者", "已有使用者"]), round: 1, maximumRounds: 5, questionIndex: 0, totalQuestions: 2)
literalAnswerField.stringValue = "第一行\n第二行\n第三行\n第四行"
panel.layoutSubtreeIfNeeded()
expect(literalAnswerField.frame.height > 44 && literalAnswerField.frame.height <= 132,
       "custom answer grows for multiline input and stops at the configured maximum")
let endButton = button("结束追问", in: panel)
let skipButton = button("跳过", in: panel)
let nextButton = button("下一题", in: panel)
expect(endButton.frame.height >= 35.5 && skipButton.frame.height >= 35.5 && nextButton.frame.height >= 35.5,
       "Grill-me actions share the same readable 36pt target height")
expect((endButton as! TalisActionButton).surface == .push
       && (skipButton as! TalisActionButton).surface == .push
       && (nextButton as! TalisActionButton).surface == .push,
       "Grill-me secondary and primary actions share the same native push control family")
activate(button("结束追问", in: panel))
expect(ended, "clarification has an explicit end action")
panel.configure(question: ClarificationQuestion(question: "希望给谁使用？", options: ["初次使用者", "已有使用者"]), round: 1, maximumRounds: 5, questionIndex: 0, totalQuestions: 2)
panel.restoreAnswer(ClarificationAnswer(question: "希望给谁使用？", answer: "（用户跳过）", skipped: true))
panel.submitRestoredAnswer()
expect(answer?.skipped == true, "retry also preserves a deliberately skipped answer")
let shortHeight = panel.preferredContentHeight
panel.configure(question: ClarificationQuestion(question: String(repeating: "这是一条用于检查长问题换行的文字。", count: 8), options: [String(repeating: "这是较长的选项", count: 12), "短选项", "另一个选项", "最后的选项"]), round: 1, maximumRounds: 5, questionIndex: 0, totalQuestions: 1)
expect(panel.preferredContentHeight > shortHeight, "long questions and options expand instead of being truncated")

let originalModelID = AppSettings.modelID
AppSettings.modelID = AIProvider.codexSubscriptionID
expect(AppSettings.modelOption.id == AIProvider.codexSubscriptionID
       && AppSettings.modelOption.model == "codex/gpt-6.1-terra"
       && AppSettings.modelOption.baseURL.host == "127.0.0.1",
       "Codex subscription selection survives through the shared model-option boundary")
AppSettings.modelID = originalModelID

let originalModelIDForSettings = AppSettings.modelID
AppSettings.modelID = "deepseek"
let settings = SettingsWindowController()
expect(settings.window!.title == AppIdentity.current.displayName,
       "settings uses the product identity in chrome and keeps its page title in content")
expect(settings.window!.collectionBehavior.contains(.moveToActiveSpace)
       && !settings.window!.collectionBehavior.contains(.canJoinAllSpaces)
       && !settings.window!.isRestorable,
       "settings follow the active Space")
settings.window!.contentView!.layoutSubtreeIfNeeded()
let settingViews = views(settings.window!.contentView!)
let authModes = settingViews.compactMap { $0 as? NSSegmentedControl }.first { $0.accessibilityLabel() == "认证方式" }!
let providers = settingViews.compactMap { $0 as? NSPopUpButton }.first { $0.accessibilityLabel() == "服务" }!
let settingSecret = settingViews.compactMap { $0 as? NSSecureTextField }.first!
expect(settingSecret.frame.width >= 400, "API Key field fills the settings form")
let credentialCopy = settingViews.compactMap { $0 as? NSTextField }.map(\.stringValue).joined(separator: "\n")
expect(credentialCopy.contains("API Key 按厂商存入 macOS 钥匙串")
       && credentialCopy.contains("不显示已保存密钥")
       && !credentialCopy.contains("API Key 由 Talis 保存"),
       "credential copy names the macOS keychain accurately and does not imply Talis owns the stored key")
expect(authModes.segmentCount == 2
       && authModes.label(forSegment: 0) == "API Key"
       && authModes.label(forSegment: 1) == "订阅共享"
       && authModes.selectedSegment == 0,
       "settings starts API-key providers under an explicit authentication method")
let originalProviderNames = [
    "DeepSeek", "Kimi", "MiniMax", "OpenAI API", "Anthropic", "Google", "xAI",
    "腾讯混元", "百度文心", "阿里通义", "字节豆包", "智谱 GLM"
]
expect(providers.numberOfItems == 12 && providers.itemTitles == originalProviderNames,
       "API Key mode preserves all twelve previously supported providers")
expect(!providers.itemTitles.contains(where: { $0.contains("v4") || $0.contains("gpt-") }), "settings displays providers without model versions")
expect(settingSecret.stringValue.isEmpty, "settings never pre-fills the saved secret")
expect(button("移除 API Key…", in: settings.window!.contentView!).action != nil, "key removal uses a deliberate confirmation action")
let keyPageLink = button("获取 API Key ↗", in: settings.window!.contentView!)
let keyPageLinkColor = keyPageLink.attributedTitle.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
expect(keyPageLink.contentTintColor.map { colorsMatch($0, AppTheme.accentTextColor) } == true
       && keyPageLinkColor.map { colorsMatch($0, AppTheme.accentTextColor) } == true,
       "the real external-key link uses the readable brand action color instead of looking like passive body copy")
authModes.selectedSegment = 1
triggerAction(authModes)
expect(providers.numberOfItems >= 1 && providers.itemTitles.contains("Codex"),
       "subscription mode always exposes Codex and includes every discovered local service")
expect(AppSettings.modelID == "deepseek",
       "switching authentication method changes the form without saving a provider")
let codexStatus = settingViews.compactMap { $0 as? NSTextField }.first { $0.accessibilityLabel() == "设置状态" }!
expect(!settingSecret.isEnabled
       && keyPageLink.isHiddenOrHasHiddenAncestor
       && button("移除 API Key…", in: settings.window!.contentView!).isHiddenOrHasHiddenAncestor
       && codexStatus.stringValue.contains("无需 API Key"),
       "Codex subscription hides every API-key control and explains subscription login")

let localCatalogFixture = Data("""
{"data":[
  {"id":"codex/gpt-6.1-sol","owned_by":"codex","native_endpoints":["/v1/responses"]},
  {"id":"openai/gpt-6.1-terra","owned_by":"openai","native_endpoints":["/v1/chat/completions","/v1/responses"]},
  {"id":"kimi-work/k3d1-agent","owned_by":"kimi-work","native_endpoints":["/v1/chat/completions"],"reasoning_levels":["low","high","max"]},
  {"id":"deepseek/deepseek-flash","owned_by":"deepseek","native_endpoints":["/v1/chat/completions"],"reasoning_levels":["max"]}
]}
""".utf8)
let localServices = try! AILocalSubscriptionCatalog.parseModelsData(localCatalogFixture)
expect(localServices.map(\.owner) == ["codex", "openai", "kimi-work", "deepseek"],
       "subscription discovery groups every local gateway service by owner")
expect(AILocalSubscriptionCatalog.providers(from: localServices).map(\.name)
       == ["Codex", "OpenAI", "Kimi Work", "DeepSeek"],
       "subscription discovery exposes all local shareable service names")
expect(localServices.first(where: { $0.owner == "kimi-work" })?.chatReasoningEffort == "low"
       && localServices.first(where: { $0.owner == "deepseek" })?.chatReasoningEffort == nil,
       "local services only request a reasoning level their catalog actually supports")
let catalogDefaultsKey = "ai.local-subscriptions.catalog"
let oldCatalogData = UserDefaults.standard.data(forKey: catalogDefaultsKey)
UserDefaults.standard.set(Data("""
[{"owner":"kimi-work","displayName":"Kimi Work","providerID":"local-subscription-kimi-work","modelID":"kimi-work/k3d1-agent","usesResponsesAPI":false}]
""".utf8), forKey: catalogDefaultsKey)
expect(AILocalSubscriptionCatalog.cachedServices.first?.chatReasoningEffort == nil,
       "an existing cached subscription catalog upgrades without losing services")
if let oldCatalogData {
    UserDefaults.standard.set(oldCatalogData, forKey: catalogDefaultsKey)
} else {
    UserDefaults.standard.removeObject(forKey: catalogDefaultsKey)
}
AILocalSubscriptionCatalog.save(localServices)
let previousLocalModelID = AppSettings.modelID
let localOpenAIProvider = AILocalSubscriptionCatalog.providers(from: localServices)[1]
AppSettings.modelID = localOpenAIProvider.id
expect(AppSettings.modelOption.id == localOpenAIProvider.id
       && AppSettings.modelOption.model == "openai/gpt-6.1-terra",
       "a selected local shared service survives the model-option boundary")
AppSettings.modelID = previousLocalModelID
if let oldCatalogData {
    UserDefaults.standard.set(oldCatalogData, forKey: catalogDefaultsKey)
} else {
    UserDefaults.standard.removeObject(forKey: catalogDefaultsKey)
}
authModes.selectedSegment = 0
triggerAction(authModes)
expect(providers.numberOfItems == 12 && providers.titleOfSelectedItem == "DeepSeek",
       "switching back restores the complete API-key provider group")
let codexProvider = AIProvider.find(AIProvider.codexSubscriptionID)!
let endpointKey = "ai.endpoint.\(AIProvider.codexSubscriptionID)"
let previousSubscriptionEndpoint = UserDefaults.standard.string(forKey: endpointKey)
AppSettings.setEndpoint(URL(string: "http://127.0.0.1:3425/v1")!, providerID: codexProvider.id)
expect(AppSettings.endpoint(for: codexProvider).absoluteString == "http://127.0.0.1:3425/v1",
       "the subscription provider may save its loopback HTTP endpoint")
if let previousSubscriptionEndpoint {
    UserDefaults.standard.set(previousSubscriptionEndpoint, forKey: endpointKey)
} else {
    UserDefaults.standard.removeObject(forKey: endpointKey)
}

var presencePending: [String: CheckedContinuation<Bool, Error>] = [:]
var presenceCompleted = 0
let statusSettings = SettingsWindowController(keyPresence: { provider in
    defer { presenceCompleted += 1 }
    return try await withCheckedThrowingContinuation { presencePending[provider] = $0 }
})
statusSettings.show()
let statusViews = views(statusSettings.window!.contentView!)
let statusProviders = statusViews.compactMap { $0 as? NSPopUpButton }.first { $0.accessibilityLabel() == "服务" }!
let keyStatus = statusViews.compactMap { $0 as? NSTextField }.first { $0.accessibilityLabel() == "设置状态" }!
let statusSecret = statusViews.compactMap { $0 as? NSSecureTextField }.first!
pump(until: { presencePending["deepseek"] != nil })
expect(keyStatus.stringValue == "正在检查密钥状态…" && statusSecret.isEnabled, "pending metadata query leaves settings responsive")
statusProviders.selectItem(at: 1)
activate(statusProviders)
pump(until: { presencePending["kimi"] != nil })
presencePending.removeValue(forKey: "kimi")!.resume(returning: false)
pump(until: { keyStatus.stringValue.contains("尚未保存 API Key") })
presencePending.removeValue(forKey: "deepseek")!.resume(returning: true)
pump(until: { presenceCompleted == 2 })
expect(statusProviders.titleOfSelectedItem == "Kimi" && keyStatus.stringValue.contains("尚未保存 API Key"), "late metadata from the old provider cannot overwrite the current provider")
expect(!button("移除 API Key…", in: statusSettings.window!.contentView!).isEnabled, "missing current-provider key does not inherit an old remove action")
statusProviders.selectItem(at: 0)
activate(statusProviders)
pump(until: { presencePending["deepseek"] != nil })
presencePending.removeValue(forKey: "deepseek")!.resume(returning: true)
pump(until: { keyStatus.stringValue == "此厂商已保存 API Key。" })
expect(button("移除 API Key…", in: statusSettings.window!.contentView!).isEnabled && statusSecret.stringValue.isEmpty, "presence enables removal without retrieving or displaying the secret")
statusProviders.selectItem(withTitle: "Anthropic")
activate(statusProviders)
pump(until: { presencePending["anthropic"] != nil })
let metadataError = URLError(.notConnectedToInternet)
presencePending.removeValue(forKey: "anthropic")!.resume(throwing: metadataError)
pump(until: { keyStatus.stringValue == metadataError.localizedDescription })
expect(keyStatus.stringValue == metadataError.localizedDescription, "metadata failure remains an error instead of pretending the key is absent")
AppSettings.modelID = originalModelIDForSettings
statusSettings.window?.orderOut(nil)


func inspectForm(_ window: NSWindow, name: String) {
    window.contentView!.layoutSubtreeIfNeeded()
    let all = views(window.contentView!)
    let backdrops = all.compactMap { $0 as? WindowContentView }
    expect(backdrops.count == 1, "\(name) uses the shared semantic window surface")
    for appearance in [NSAppearance.Name.aqua, .darkAqua] {
        backdrops[0].appearance = NSAppearance(named: appearance)
        backdrops[0].updateLayer()
        backdrops[0].effectiveAppearance.performAsCurrentDrawingAppearance {
            expect(NSColor(cgColor: backdrops[0].layer!.backgroundColor!)!.usingColorSpace(.sRGB)! == AppTheme.windowColor.usingColorSpace(.sRGB)!, "\(name) follows the shared pearl-purple window color in \(appearance.rawValue)")
        }
    }
    backdrops[0].appearance = nil
    expect(window.isOpaque && !window.titlebarAppearsTransparent, "\(name) retains its native titled-window chrome")
    for grid in all.compactMap({ $0 as? NSGridView }) {
        expect(grid.rowAlignment == .firstBaseline, "\(name) aligns field rows by text baseline")
        for row in 0..<grid.numberOfRows where !grid.row(at: row).isHidden {
            guard let label = grid.cell(atColumnIndex: 0, rowIndex: row).contentView,
                  let field = grid.cell(atColumnIndex: 1, rowIndex: row).contentView else { continue }
            let a = label.convert(NSPoint(x: 0, y: label.bounds.height - label.firstBaselineOffsetFromTop), to: grid).y
            let b = field.convert(NSPoint(x: 0, y: field.bounds.height - field.firstBaselineOffsetFromTop), to: grid).y
            expect(abs(a - b) < 1, "\(name) visible field \(row) has the same label/control baseline")
            expect(field.bounds.width >= 280, "\(name) field \(row) remains usable at minimum window size")
        }
    }
}
settings.window!.setContentSize(NSSize(width: 600, height: 452))
inspectForm(settings.window!, name: "settings at minimum width")
let settingsGrid = settingViews.compactMap { $0 as? NSGridView }.max { $0.numberOfRows < $1.numberOfRows }!
settingsGrid.row(at: 3).isHidden = false
inspectForm(settings.window!, name: "settings with custom endpoint")
settingsGrid.row(at: 3).isHidden = true
let secretForLayout = settingViews.compactMap { $0 as? NSSecureTextField }.first!
let helperForLayout = settingViews.compactMap { $0 as? NSTextField }.first {
    $0.stringValue.hasPrefix("Talis 不显示已保存密钥")
}!
let helperX = helperForLayout.convert(NSPoint(x: helperForLayout.alignmentRectInsets.left, y: 0), to: settings.window!.contentView).x
let secretX = secretForLayout.convert(.zero, to: settings.window!.contentView).x
expect(abs(helperX - secretX) < 1, "key helper text follows the input column")

if !isUIReview { verifyLocalization() }

manager.window!.setContentSize(NSSize(width: 820, height: 492))
inspectForm(manager.window!, name: "template manager at minimum size")
templatePreview.window!.setContentSize(NSSize(width: 600, height: 512))
inspectForm(templatePreview.window!, name: "template preview at minimum size")

for appearance in [NSAppearance.Name.aqua, .darkAqua] {
    let surface = contentSurfaces.compactMap { $0 as? ThemedSurfaceView }.first { views($0).contains { $0 === editor } }!
    surface.appearance = NSAppearance(named: appearance)
    surface.updateLayer()
    surface.effectiveAppearance.performAsCurrentDrawingAppearance {
        expect(NSColor(cgColor: surface.layer!.backgroundColor!)!.usingColorSpace(.sRGB)! == surface.fillColor.usingColorSpace(.sRGB)!, "content layer resolves its semantic fill in \(appearance.rawValue)")
    }
    surface.effectiveAppearance.performAsCurrentDrawingAppearance {
        expect(NSColor(cgColor: surface.layer!.backgroundColor!)!.usingColorSpace(.sRGB)! == AppTheme.contentColor.usingColorSpace(.sRGB)!, "editor surface follows the current appearance rather than retaining an initialization color")
    }
    for keycap in contentSurfaces.compactMap({ $0 as? ShortcutKeyView }) {
        keycap.appearance = NSAppearance(named: appearance)
        keycap.updateLayer()
        keycap.effectiveAppearance.performAsCurrentDrawingAppearance {
            expect(NSColor(cgColor: keycap.layer!.backgroundColor!)!.usingColorSpace(.sRGB)! == NSColor.controlBackgroundColor.usingColorSpace(.sRGB)!, "keycaps follow the current appearance")
        }
        keycap.appearance = nil
    }
    let body = contrast(.labelColor, AppTheme.contentColor, appearance: appearance)
    let secondary = contrast(AppTheme.secondaryTextColor, AppTheme.contentColor, appearance: appearance)
    print("Contrast \(appearance.rawValue): body=\(String(format: "%.2f", body)) secondary=\(String(format: "%.2f", secondary))")
    expect(body >= 4.5, "body text meets contrast target in \(appearance.rawValue)")
    expect(contrast(AppTheme.accentTextColor, AppTheme.contentColor, appearance: appearance) >= 4.5, "brand actions remain readable in \(appearance.rawValue)")
    expect(contrast(AppTheme.primaryTextColor, AppTheme.accentColor, appearance: appearance) >= 4.5, "primary action text remains readable in \(appearance.rawValue)")
    expect(contrast(AppTheme.primaryActionTextColor, AppTheme.primaryActionColor, appearance: appearance) >= 4.5, "filled primary control text remains readable in \(appearance.rawValue)")
    expect(contrast(AppTheme.errorTextColor, AppTheme.contentColor, appearance: appearance) >= 4.5, "error messages meet contrast target")
    expect(contrast(AppTheme.secondaryTextColor, AppTheme.contentColor, appearance: appearance) >= 4.5, "supporting text meets contrast on content surfaces")
    expect(secondary >= 4.5, "secondary and placeholder text meet contrast target in \(appearance.rawValue)")
    surface.appearance = nil
}
expect(contentSurfaces.allSatisfy { $0.appearance == nil }, "appearance probes restore every content surface before UI Review")
// A local update must restore the current draft and its complete editing context.
let restoredTurns = (1...3).map { index in
    UpdateSession.Turn(query: "输入 \(index)", result: "结果 \(index)", actionTitle: "微调", createdAt: Date(timeIntervalSince1970: 1000 + Double(index)))
}
let updateFixture = UpdateSession(text: "待继续编辑的正文", turns: restoredTurns)
let updateURL = FileManager.default.temporaryDirectory.appendingPathComponent("talis-update-\(UUID().uuidString).json")
let updateEncoder = JSONEncoder(); updateEncoder.dateEncodingStrategy = .iso8601
try! updateEncoder.encode(updateFixture).write(to: updateURL)
let updateReadback = try! UpdateSession.read(from: updateURL)
try! FileManager.default.removeItem(at: updateURL)
controller.restoreUpdateSession(updateReadback)
expect(editor.string == updateFixture.text, "explicit update handoff restores the complete current draft")
expect(!button("修改记录 · 3 轮", in: root).isHidden && !button("复制 Prompt  ⌘↵", in: root).isHidden, "explicit update handoff restores all rounds and result stage")
activate(button("修改记录 · 3 轮", in: root))
let restoredHistory = NSApp.windows.first { $0.title == "修改记录" && $0.isVisible }!
let restoredText = views(restoredHistory.contentView!).compactMap { $0 as? NSTextView }.first!.string
expect(restoredText.contains("输入 3") && restoredText.contains("结果 3"), "restored history exposes the original input and result")
restoredHistory.close()
// One editing session moves between the active-space quick panel and a
// resizable workspace suitable for Split View or another display.
let quickPanelBeforeWorkspace = controller.window
controller.toggleWorkspaceMode()
controller.window!.contentView!.layoutSubtreeIfNeeded()
let workspaceRoot = controller.window!.contentView!
expect(controller.isInWorkspaceMode && controller.window is WorkspaceWindow,
       "workspace switch uses an ordinary native window")
expect(controller.workspaceEditorUsesFlexibleHeightForTesting,
       "workspace editor fills available height without feeding window height back into a fixed constraint")
expect(quickPanelBeforeWorkspace?.isVisible == false && controller.window!.isVisible,
       "workspace switch removes the emptied quick panel instead of leaving a blank floating window above it")
expect(controller.window!.styleMask.contains(.resizable) && controller.window!.level == .normal,
       "workspace can be resized and does not float over Split View")
expect(!controller.window!.isRestorable,
       "workspace does not ask AppKit to resurrect an ordinary prompt session")
expect(controller.window!.title == AppIdentity.current.displayName
       && !views(workspaceRoot).compactMap { $0 as? NSTextField }.contains {
           $0.stringValue == AppIdentity.current.displayName && !$0.isHiddenOrHasHiddenAncestor
       },
       "workspace keeps one visible product title in native chrome instead of repeating it in content")
expect(controller.window!.collectionBehavior.contains(.moveToActiveSpace)
       && !controller.window!.collectionBehavior.contains(.canJoinAllSpaces),
       "workspace moves to the chosen desktop rather than appearing everywhere")
expect(editor.string == updateFixture.text && !button("修改记录 · 3 轮", in: workspaceRoot).isHidden,
       "workspace switch preserves the current draft and complete history")
controller.window!.setContentSize(NSSize(width: 900, height: 780))
controller.windowDidResize(Notification(name: NSWindow.didResizeNotification, object: controller.window!))
workspaceRoot.layoutSubtreeIfNeeded()
expect(workspaceRoot.frame.width == 900 && editor.enclosingScrollView!.frame.height >= 400,
       "workspace uses the available width and height for the same editor")
controller.performShowTemplates()
expect(controller.workspaceEditorUsesFlexibleHeightForTesting
       && !controller.workspaceEditorUsesCompactFixedHeightForTesting,
       "Template Center opens separately without squeezing the workspace editor")
controller.window!.setContentSize(NSSize(width: 640, height: 560))
controller.windowDidResize(Notification(name: NSWindow.didResizeNotification, object: controller.window!))
let workspacePickerRoot = controller.templatePickerViewForTesting!
workspacePickerRoot.layoutSubtreeIfNeeded()
let workspaceTemplateScroll = views(workspacePickerRoot).compactMap { $0 as? NSScrollView }.first { $0.documentView is TopAlignedStackView }!
expect(workspaceTemplateScroll.frame.height >= 180 && workspaceTemplateScroll.frame.maxY <= workspacePickerRoot.bounds.maxY,
       "template selection remains usable in its own picker at minimum workspace size")
controller.promptTextViewDidRequestClose(editor)
FixtureProtocol.content = "{\"status\":\"ask\",\"questions\":[{\"question\":\"用于什么场景？\",\"options\":[\"个人使用\",\"团队协作\"]}]}"
controller.performClarification()
pump(until: { views(controller.clarificationPanelForTesting!).compactMap { $0 as? NSTextField }.contains { $0.stringValue == "用于什么场景？" } })
workspaceRoot.layoutSubtreeIfNeeded()
let workspaceQuestion = controller.clarificationPanelForTesting!
expect(controller.clarificationSheetWindowForTesting?.sheetParent === controller.window,
       "workspace clarification attaches to the resizable workspace without replacing its content")
expect(workspaceQuestion.frame.height >= 180 && !button("提交本轮", in: workspaceQuestion).isHiddenOrHasHiddenAncestor,
       "clarification remains visible and actionable in the workspace sheet")
activate(button("结束追问", in: workspaceQuestion))
controller.toggleWorkspaceMode()
expect(!controller.isInWorkspaceMode && controller.window is PromptPanel
       && controller.window!.collectionBehavior.contains(.moveToActiveSpace)
       && !controller.window!.collectionBehavior.contains(.canJoinAllSpaces),
       "returning to quick mode follows the active desktop without another editing session")
let quickRoot = controller.window!.contentView!
expect(views(quickRoot).compactMap { $0 as? NSTextField }.contains {
    $0.stringValue == AppIdentity.current.displayName && !$0.isHiddenOrHasHiddenAncestor
}, "returning to quick mode restores its in-content product identity")
expect(editor.string == updateFixture.text && !button("修改记录 · 3 轮", in: quickRoot).isHidden
       && controller.window!.isVisible,
       "quick mode preserves content and keeps the active prompt panel visible")
expect(controller.window!.frame.height < 500,
       "returning to quick mode measures native chrome separately and keeps actions beside the compact editor")
activate(button("清空", in: root))
editor.keyDown(with: key("z", code: 6, flags: .command))
expect(editor.string == updateFixture.text && !button("修改记录 · 3 轮", in: root).isHidden, "clear and undo retain restored text and all history")
FixtureProtocol.status = 200; FixtureProtocol.content = "继续后的结果"; FixtureProtocol.delay = 0.03
controller.performRefine()
pump(until: { editor.isEditable })
let restoredRequest = FixtureProtocol.lastMessages.compactMap { $0["content"] }.joined(separator: "\n")
expect(restoredTurns.allSatisfy { restoredRequest.contains($0.query) && restoredRequest.contains($0.result) }, "the next AI request includes the restored three-round context")
let statusMenuController = StatusBarController(installsSystemItem: false)
let statusMenuTitles = statusMenuController.menuItemTitlesForTesting().filter { !$0.isEmpty }
expect(statusMenuTitles == [
    "打开 Talis", "新建 Prompt", "恢复上次草稿", "修改记录", "模板中心",
    "设置…", "关于 Talis", "退出 Talis"
], "status bar menu exposes the compact session, navigation and app commands")
var menuNewPromptInvoked = false
var menuRestoreInvoked = false
statusMenuController.onNewPrompt = { menuNewPromptInvoked = true }
statusMenuController.onRestoreLastDraft = { menuRestoreInvoked = true }
expect(statusMenuController.invokeMenuItemForTesting("新建 Prompt")
       && statusMenuController.invokeMenuItemForTesting("恢复上次草稿")
       && menuNewPromptInvoked && menuRestoreInvoked,
       "status menu actions dispatch to the shared prompt controller")
statusMenuController.canRestoreDraft = { false }
expect(!statusMenuController.isMenuItemEnabledForTesting("恢复上次草稿"),
       "status menu disables recovery when the prompt controller has no restorable draft")
statusMenuController.canRestoreDraft = { true }
expect(statusMenuController.isMenuItemEnabledForTesting("恢复上次草稿"),
       "status menu enables recovery once a dismissed draft exists")
let statusBarIcon = AppTheme.statusBarIcon()
expect(statusBarIcon.isTemplate && statusBarIcon.size == NSSize(width: 18, height: 18),
       "status bar icon is an 18pt monochrome template image")
print("PASS: \(checks) production AppKit UI, keyboard, search, accessibility, unsaved-edit, AI cancellation and contrast checks; fictional HTTP only, no user template or key writes")
restoreClipboard()
}

func verifyLocalization() {
    let previousLanguage = AppLocalization.preference
    defer { AppLocalization.preference = previousLanguage }
    AppLocalization.preference = .simplifiedChinese
    let controller = PromptWindowController(clientFactory: { client }, motionPreference: { true }, templatePreviewFactory: { TemplatePreviewWindowController(draft: $0, persistDraft: transientTemplate) })
    var root: NSView { controller.window!.contentView! }
    var editor: PromptTextView { views(root).compactMap { $0 as? PromptTextView }.first! }
    func edit(_ text: String) {
        editor.string = text
        controller.textDidChange(Notification(name: NSText.didChangeNotification, object: editor))
    }
    func hideTemplates() {
        let search = views(controller.templatePickerViewForTesting!).compactMap { $0 as? NSSearchField }.first!
        search.cancelOperation(nil)
        pump(until: { false }, seconds: 0.15)
    }
    let systemItem = PromptStore.prompts.first { $0.sourceTitle == "把需求整理成Prompt" }!
    let originalSystemID = systemItem.origin
    let originalSystemBody = systemItem.body
    let originalInstruction = AIAction.refine.instruction
    let savedCustomTitle = "Publish in English"
    let savedCustomBody = "  【Project】::\nKeep the exact body.\n"
    let userItem = UserPromptTemplate(id: UUID(), title: savedCustomTitle, detail: "My draft", body: savedCustomBody, createdAt: Date(), updatedAt: Date()).libraryItem
    let sourceTemplate = LibraryItem(title: "长文翻译", detail: "保留结构、术语表、语气与译后校对", symbolName: "book", badge: "写作", body: "Body unchanged")

    controller.show()
    controller.window?.makeKey()
    let draft = "保留这段正文：【项目】"
    edit(draft)
    FixtureProtocol.status = 200
    FixtureProtocol.transportError = nil
    FixtureProtocol.delay = 120
    controller.performRefine()
    pump(until: { controller.canCancelAI })
    let stopTitle = views(root).compactMap { $0 as? NSButton }.first { $0.title == "停止" || $0.title == "Stop" }
    let stopDescription = "cancel=\(controller.canCancelAI), title=\(stopTitle?.title ?? "missing"), enabled=\(stopTitle?.isEnabled == true), action=\(String(describing: stopTitle?.action))"
    expect(controller.canCancelAI && stopTitle?.action != nil,
           "Chinese busy state exposes the stop action; \(stopDescription)")
    AppLocalization.preference = .english
    expect(AppLocalization.preference == .english && UserDefaults.standard.string(forKey: "app.language") == "en", "English selection is persisted")
    let englishUpdated = UserPromptTemplate(
        id: UUID(),
        title: "Badge Probe",
        detail: "",
        body: "",
        createdAt: Date().addingTimeInterval(-30 * 86400),
        updatedAt: Date().addingTimeInterval(-86400)
    )
    let englishBadgeHost = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 64))
    let englishBadgeRow = CommandRowView()
    englishBadgeRow.configure(with: englishUpdated.libraryItem, isSelected: true, allowsApply: false)
    englishBadgeHost.addSubview(englishBadgeRow)
    NSLayoutConstraint.activate([
        englishBadgeRow.leadingAnchor.constraint(equalTo: englishBadgeHost.leadingAnchor),
        englishBadgeRow.trailingAnchor.constraint(equalTo: englishBadgeHost.trailingAnchor),
        englishBadgeRow.topAnchor.constraint(equalTo: englishBadgeHost.topAnchor)
    ])
    englishBadgeHost.layoutSubtreeIfNeeded()
    expect(views(englishBadgeRow).compactMap { $0 as? NSTextField }.contains { $0.stringValue == "Update" }
           && englishBadgeRow.recencyUsesTitleBaselineForTesting
           && englishBadgeRow.recencyBadgeWidthForTesting > 34,
           "English Update capsule expands for its text and shares the title baseline")
    let untranslatedProviders = AIProvider.all.filter {
        $0.name.range(of: "\\p{Han}", options: .regularExpression) != nil
    }
    let untranslatedEndpoints = AIProvider.all.flatMap(\.endpoints).filter {
        $0.name.range(of: "\\p{Han}", options: .regularExpression) != nil
    }
    expect(untranslatedProviders.isEmpty && untranslatedEndpoints.isEmpty,
           "provider and endpoint labels update after a runtime language switch: \(untranslatedProviders.map(\.name)) / \(untranslatedEndpoints.map(\.name))")
    let languagePopupProbe = NSPopUpButton()
    languagePopupProbe.addItems(withTitles: ["跟随系统", "简体中文", "English"])
    languagePopupProbe.selectItem(at: 2)
    AppLocalization.refresh(languagePopupProbe)
    expect(languagePopupProbe.indexOfSelectedItem == 2 && languagePopupProbe.title == "English",
           "language refresh updates menu items without replacing the selected popup title")
    let helpText = UsageHelpWindowController.plainText()
    expect(helpText.contains("Open and Edit") && helpText.range(of: "\\p{Han}", options: .regularExpression) == nil,
           "English help guide is fully localized and no longer inherits Chinese body copy")
    let helpWindow = UsageHelpWindowController()
    let helpContent = helpWindow.window!.contentView!
    helpContent.layoutSubtreeIfNeeded()
    let helpScroll = views(helpContent).compactMap { $0 as? NSScrollView }.first!
    let helpSections = (helpScroll.documentView as? NSStackView)?.arrangedSubviews ?? []
    expect(helpScroll.hasVerticalScroller && !helpScroll.autohidesScrollers && helpSections.count == 6,
           "the guide is a visible six-section scroll page instead of one oversized alert")
    helpWindow.close()
    let previousModelID = AppSettings.modelID
    AppSettings.modelID = AIProvider.codexSubscriptionID
    let settings = SettingsWindowController(keyPresence: { _ in false })
    let settingsProbeContent = settings.window!.contentView!
    let settingsLabels = views(settingsProbeContent).compactMap { $0 as? NSTextField }.map(\.stringValue)
    expect(settingsLabels.contains("Settings") && settingsLabels.contains("General") && settingsLabels.contains("AI Service"),
           "settings separates app-level General controls from AI service configuration")
    expect(settingsLabels.contains("Choose how Talis connects. API keys stay in macOS Keychain; subscriptions use the account already signed in on this Mac.")
           && settingsLabels.contains("Talis never shows saved keys or copies sign-in credentials.")
           && settingsLabels.filter { $0.contains("Keychain") }.count == 1,
           "AI Service introduction, current status and privacy boundary no longer repeat the same storage fact")
    let serviceRegion = views(settingsProbeContent).compactMap { $0 as? NSPopUpButton }.first {
        $0.accessibilityLabel() == "Service Region"
    }
    expect(serviceRegion?.isHiddenOrHasHiddenAncestor == true,
           "subscription mode does not show a redundant service-region row")
    let saveSettings = views(settingsProbeContent).compactMap { $0 as? NSButton }.first {
        $0.title == "Save Service Settings"
    }
    expect(saveSettings?.isEnabled == false,
           "AI settings do not offer a primary save action before anything changes")
    AppSettings.modelID = previousModelID
    expect(editor.string == draft && button("Refine", in: root).title == "Refine" && controller.canCancelAI,
           "language switching keeps the current draft and translates the running state")
    expect(button("Rewrite", in: root).title == "Rewrite" && button("Grill-me", in: root).title == "Grill-me", "the three mode buttons translate independently")
    root.layoutSubtreeIfNeeded()
    let templateMenu = controller.templateEntryButtonForTesting
    root.layoutSubtreeIfNeeded()
    expect(templateMenu.title == "Templates"
           && templateMenu.imagePosition == .imageTrailing
           && templateMenu.image != nil,
           "the template entry keeps the title and chevron together in one compact button")
    controller.performStopAI()
    expect(editor.string == draft, "stopping after a language change preserves the original text")
    controller.promptTextViewDidRequestClose(editor)
    let untranslatedMetadata = PromptStore.items(for: .prompt).filter {
        [$0.title, $0.detail, $0.badge].contains { $0.range(of: "\\p{Han}", options: .regularExpression) != nil }
    }
    expect(untranslatedMetadata.isEmpty,
           "English system template metadata has no Chinese residue: \(untranslatedMetadata.map { "\($0.title) / \($0.detail) / \($0.badge)" })")
    controller.performShowTemplates()
    let englishPickerRoot = controller.templatePickerViewForTesting!
    expect(controller.templatePickerWindowForTesting?.title == "Template Center"
           && views(englishPickerRoot).compactMap { $0 as? NSSegmentedControl }.first?.label(forSegment: 0) == "System"
           && views(englishPickerRoot).compactMap { $0 as? NSSegmentedControl }.first?.label(forSegment: 1) == "My",
           "English Template Center localizes the native title and source controls")
    expect(!button("Save as New", in: englishPickerRoot).isHidden
           && !button("Manage", in: englishPickerRoot).isHidden,
           "English Template Center uses compact action labels")
    expect(views(englishPickerRoot).compactMap { $0 as? CommandRowView }.contains { views($0).compactMap { $0 as? NSTextField }.contains { $0.stringValue == "Turn a Request into a Prompt" } },
           "an already-open template card follows the selected language")
    englishPickerRoot.layoutSubtreeIfNeeded()
    let localizedApply = views(englishPickerRoot).compactMap { $0 as? CommandRowView }.first { !$0.applyButton.isHidden }!.applyButton
    expect(localizedApply.title == "Apply" && localizedApply.bounds.width >= localizedApply.fittingSize.width - 1, "English template apply button keeps its complete title")
    edit("Draft that the selected template will replace")
    controller.performShowTemplates()
    let replacementApply = button("Replace", in: controller.templatePickerViewForTesting!)
    controller.templatePickerViewForTesting!.layoutSubtreeIfNeeded()
    expect(replacementApply.bounds.width >= replacementApply.fittingSize.width - 1, "English replacement button also keeps its complete title")
    let englishTemplate = transientTemplate(TemplateDraft(title: "Weekly Review", detail: "Decisions and actions", body: "Review【Input】"))
    let englishManager = TemplateManagerWindowController(templatesProvider: { [englishTemplate] })
    let englishManagerRoot = englishManager.window!.contentView!
    englishManagerRoot.layoutSubtreeIfNeeded()
    let englishManagerVisibleCopy = views(englishManagerRoot).flatMap { view -> [String] in
        if let field = view as? NSTextField { return [field.stringValue, field.placeholderString ?? ""] }
        if let button = view as? NSButton { return [button.title] }
        return []
    }.filter { !$0.isEmpty }
    let englishManagerSearch = views(englishManagerRoot).compactMap { $0 as? NSSearchField }.first!
    let englishDescriptionLabel = views(englishManagerRoot).compactMap { $0 as? NSTextField }.first { $0.stringValue == "Description" }
    expect(englishManagerVisibleCopy.allSatisfy { $0.range(of: "\\p{Han}", options: .regularExpression) == nil }
           && englishManagerSearch.placeholderString == "Search"
           && englishManagerSearch.cell?.title == ""
           && (englishDescriptionLabel?.frame.width ?? 0) >= (englishDescriptionLabel?.fittingSize.width ?? .greatestFiniteMagnitude) - 1,
           "English template management has no Chinese residue, fits its labels, and keeps one search text layer")
    englishManager.close()
    let templateMatch = PromptTemplateMatch(item: systemItem, mode: .prompt, score: 8, matchedKeywords: ["prompt"])
    expect(PromptTemplateMatcher.signature(for: "Prompt input", match: templateMatch).contains(systemItem.sourceTitle),
           "language switching does not invalidate the active template suggestion")

    let templateRoundTrip = sourceTemplate.replacingBody("Different body, same identity")
    expect(templateRoundTrip.origin == sourceTemplate.origin && templateRoundTrip.title == "Long-form Translation", "overridden system templates keep their stable identity and translated title")
    AppLocalization.preference = .simplifiedChinese
    expect(templateRoundTrip.title == "长文翻译" && templateRoundTrip.body == "Different body, same identity", "a localized template can switch back without losing its source title or override body")
    expect(PromptTemplateMatcher.primaryPlaceholder(for: sourceTemplate) == "【待翻译文本】", "placeholder mapping uses the source title in both languages")
    expect(systemItem.origin == originalSystemID && systemItem.body == originalSystemBody, "English presentation never rewrites the system template ID or model body")
    expect(userItem.title == savedCustomTitle && userItem.body == savedCustomBody && userItem.origin.kind == .user,
           "personal template title and body remain user-authored")
    expect(AIAction.refine.instruction == originalInstruction && AIAction.refine.buttonTitle == "微调", "display language does not translate the model system instruction")
    AppLocalization.preference = .english
    expect(AIAction.refine.instruction == originalInstruction && AIAction.refine.buttonTitle == "Refine", "English action labels keep the original model instruction")

    let languageSettings = SettingsWindowController(keyPresence: { _ in true })
    let settingsContent = languageSettings.window!.contentView!
    let languageControls = views(settingsContent).compactMap { $0 as? NSSegmentedControl }.first { $0.accessibilityLabel() == "Authentication" }!
    expect(languageControls.label(forSegment: 0) == "API Key" && languageControls.label(forSegment: 1) == "Subscription", "authentication segments translate without swapping their labels")
    let languagePopup = views(settingsContent).compactMap { $0 as? NSPopUpButton }.first { $0.accessibilityLabel() == "App Language" }!
    expect(languagePopup.itemTitles == ["Follow System", "简体中文", "English"], "language selector offers system, Simplified Chinese, and English")
    let languageStatus = views(settingsContent).compactMap { $0 as? NSTextField }.first { $0.accessibilityLabel() == "Settings status" }!
    let languageSecret = views(settingsContent).compactMap { $0 as? NSSecureTextField }.first!
    let languageEndpoint = views(settingsContent).compactMap { $0 as? NSTextField }.first { $0.accessibilityLabel() == "HTTPS base URL" }!
    pump(until: { languageStatus.stringValue == "API Key saved for this provider." })
    let originalSecret = languageSecret.stringValue
    expect(languageSecret.placeholderString == "Enter a new API Key; leave blank to keep the existing key", "English settings do not expose a saved-key status as the secret field placeholder")
    languageEndpoint.stringValue = "https://example.invalid/unsaved"
    languageStatus.stringValue = "此厂商已保存 API Key。"
    AppLocalization.preference = .simplifiedChinese
    expect(languageControls.label(forSegment: 1) == "订阅共享" && languageStatus.stringValue == "此厂商已保存 API Key。", "settings round-trip translates both segments and status")
    expect(languageSecret.placeholderString == "输入新 API Key；留空保留已有密钥" && languageSecret.stringValue == originalSecret, "a saved-key message cannot overwrite the secure field placeholder")
    AppLocalization.preference = .english
    expect(languageStatus.stringValue == "API Key saved for this provider.", "settings status follows the current language")
    expect(languageEndpoint.stringValue == "https://example.invalid/unsaved", "language switching retains an unsaved endpoint")
    AppLocalization.preference = .english
    expect(languageSecret.placeholderString == "Enter a new API Key; leave blank to keep the existing key", "a second language round-trip preserves the secure field source")
    AppLocalization.preference = .simplifiedChinese
    expect(languageSecret.placeholderString == "输入新 API Key；留空保留已有密钥", "Chinese placeholder survives a second round-trip")
    AppLocalization.preference = .english
    expect(views(settingsContent).compactMap { $0 as? NSPopUpButton }.first { $0.accessibilityLabel() == "Service Region" }?.itemTitles.first == "Official API", "provider regions translate in the service settings")
    let localizedEndpoint = views(settingsContent).compactMap { $0 as? NSPopUpButton }.first { $0.accessibilityLabel() == "Service Region" }!
    AppLocalization.preference = .simplifiedChinese
    expect(localizedEndpoint.title == "官方接口", "the selected provider region returns to Chinese")
    AppLocalization.preference = .english
    expect(localizedEndpoint.title == "Official API", "the selected provider region is rebuilt in English")
    languageSettings.window!.setContentSize(NSSize(width: 640, height: 520))
    settingsContent.layoutSubtreeIfNeeded()
    let languageGrid = views(settingsContent).compactMap { $0 as? NSGridView }.max { $0.numberOfRows < $1.numberOfRows }!
    let saveFrame = button("Save Service Settings", in: settingsContent).convert(button("Save Service Settings", in: settingsContent).bounds, to: settingsContent)
    expect(saveFrame.maxY <= settingsContent.bounds.maxY && languageGrid.numberOfRows == 5, "English settings keep the five AI rows and the save action inside the window")
    languageSettings.window?.orderOut(nil)

    let languagePanel = ClarificationPanelView(frame: NSRect(x: 0, y: 0, width: 620, height: 460))
    // Production attaches this observer through ClarificationWindowController.
    AppLocalization.observe(languagePanel, selector: #selector(ClarificationPanelView.refreshLocalization))
    var localizedAnswer: ClarificationAnswer?
    languagePanel.onSubmit = { localizedAnswer = $0 }
    languagePanel.configure(question: ClarificationQuestion(question: "Who is this for?", options: ["Writers", "Developers"]), round: 1, maximumRounds: 5, questionIndex: 0, totalQuestions: 2)
    languagePanel.showError(title: L("追问失败"), message: "Fixture failure; original answer retained.", retryTitle: L("重试"), retry: {})
    AppLocalization.preference = .simplifiedChinese
    expect(button("跳过", in: languagePanel).title == "跳过" && button("重试", in: languagePanel).title == "重试", "clarification failure actions translate without changing the question")
    expect(views(languagePanel).compactMap { $0 as? NSTextField }.contains { $0.stringValue == "Fixture failure; original answer retained." }, "an existing provider error is retained verbatim")
    languagePanel.configure(question: ClarificationQuestion(question: "Who is this for?", options: ["Writers", "Developers"]), round: 1, maximumRounds: 5, questionIndex: 0, totalQuestions: 2)
    AppLocalization.preference = .english
    expect(views(languagePanel).compactMap { $0 as? NSTextField }.contains { $0.stringValue == "Grill-me · Round 1 · Question 1 of 2" }, "clarification metadata is generated from its round and question state")
    expect(button("Next Question", in: languagePanel).title == "Next Question", "the next-question title uses the actual question index")
    activate(button("Skip", in: languagePanel))
    expect(localizedAnswer?.answer == "（用户跳过）" && localizedAnswer?.skipped == true, "the skipped-answer protocol remains the stable machine value")
    languagePanel.configure(question: ClarificationQuestion(question: "Who is this for?", options: ["Writers", "Developers"]), round: 1, maximumRounds: 5, questionIndex: 1, totalQuestions: 2)
    expect(button("Submit Answers", in: languagePanel).title == "Submit Answers", "the final question submits rather than advancing")
    expect((button("Submit Answers", in: languagePanel) as! TalisActionButton).surface == .push,
           "grill-me submit uses the solid primary surface for readable action text")

    let localizedHistory = HistoryWindowController()
    localizedHistory.update([.init(round: 1, action: "微调", date: Date(timeIntervalSince1970: 0), input: "Original input", output: "Original output")])
    expect(localizedHistory.window!.title == "Revision History", "history window title is translated")
    expect(views(localizedHistory.window!.contentView!).compactMap { $0 as? NSPopUpButton }.first!.itemTitles.first?.hasPrefix("Round 1 · Refine · ") == true, "history reconstructs its heading from stored semantic data")
    AppLocalization.preference = .simplifiedChinese
    expect(views(localizedHistory.window!.contentView!).compactMap { $0 as? NSPopUpButton }.first!.itemTitles.first?.hasPrefix("第 1 轮 · 微调 · ") == true, "history returns to Chinese without string replacement corruption")
    let clarificationHistory = ClarificationSession(
        originalQuery: "Write a product introduction.",
        rounds: [ClarificationRoundRecord(answers: [
            ClarificationAnswer(question: "Who is it for?", answer: "Students")
        ])]
    )
    AppLocalization.preference = .english
    localizedHistory.update([.init(round: 1, action: "追问", date: Date(), input: clarificationHistory.historyQuery(), output: "Result",
                                  clarificationRounds: clarificationHistory.rounds, originalQuery: clarificationHistory.originalQuery)])
    let historyText = views(localizedHistory.window!.contentView!).compactMap { $0 as? NSTextView }.first!.string
    expect(historyText.contains("Grill-me History:\nRound 1") && !historyText.contains("追问记录") && !historyText.contains("第 1 轮"),
           "English history localizes app-generated transcript labels without translating the user's answer")
    let localizedStatus = StatusBarController(installsSystemItem: false)
    AppLocalization.preference = .english
    expect(localizedStatus.menuItemTitlesForTesting().contains("New Prompt") && localizedStatus.menuItemTitlesForTesting().contains("Revision History"), "the status-bar menu follows the language change")
    FixtureProtocol.delay = 0.02
    FixtureProtocol.content = "Result kept unchanged"
    AppLocalization.preference = .simplifiedChinese
    edit(draft)
    controller.performRefine()
    pump(until: { controller.hasConversationHistory })
    AppLocalization.preference = .english
    expect(editor.string == "Result kept unchanged" && controller.hasConversationHistory, "generated results and conversation history survive the language switch")
    expect(L("打开与编辑\n%@：唤起输入框").contains("Open and Edit"), "multiline help is loaded from the English resource")
    AppLocalization.preference = .simplifiedChinese
    NotificationCenter.default.post(name: AppLocalization.didChangeNotification, object: nil)
    controller.performShowTemplates()
    controller.promptTextViewDidRequestClose(editor)
    AppLocalization.preference = .english
    expect(button("Revision History · 1 Round", in: root).title == "Revision History · 1 Round"
           && !button("Revision History · 1 Round", in: root).isHidden,
           "switching back to English after closing templates restores the history title")
    AppLocalization.preference = .simplifiedChinese
    controller.promptTextViewDidRequestClose(editor)
    controller.window?.orderOut(nil)
    NotificationCenter.default.removeObserver(controller, name: AppLocalization.didChangeNotification, object: nil)
    languageSettings.window?.close()
    localizedHistory.window?.close()
}

// An optional local review bundle renders these same production controllers with intercepted HTTP.
// It uses the existing Preview identity; no production Keychain or template directory is used.
final class UIReviewDelegate: NSObject, NSApplicationDelegate {
    private let controller = PromptWindowController(clientFactory: { client }, templatePreviewFactory: { TemplatePreviewWindowController(draft: $0, persistDraft: transientTemplate) })
    private var root: NSView { controller.window!.contentView! }
    private lazy var editor = views(root).compactMap { $0 as? PromptTextView }.first!
    private var preview: TemplatePreviewWindowController?
    private var settingsController: SettingsWindowController?
    private var managerController: TemplateManagerWindowController?
    func applicationWillTerminate(_ notification: Notification) { restoreClipboard() }
    func installMenu() {
        let main = NSMenu()
        let application = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "退出界面检查", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        application.submenu = appMenu
        main.addItem(application)
        let editItem = NSMenuItem(title: "编辑", action: nil, keyEquivalent: "")
        let editMenu = NSMenu(title: "编辑")
        for (title, action, shortcut) in [
            ("撤销", "undo:", "z"), ("剪切", "cut:", "x"), ("复制", "copy:", "c"),
            ("粘贴", "paste:", "v"), ("全选", "selectAll:", "a")
        ] {
            editMenu.addItem(withTitle: title, action: Selector(action), keyEquivalent: shortcut)
        }
        editMenu.addItem(withTitle: "关闭窗口", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        editItem.submenu = editMenu
        main.addItem(editItem)
        let review = NSMenuItem(title: "界面检查", action: nil, keyEquivalent: "")
        let menu = NSMenu()
        for (title, selector, shortcut) in [
            ("浅色主窗口", #selector(light), "1"), ("深色主窗口", #selector(dark), "2"),
            ("追问未回答", #selector(shortClarification), "3"), ("追问无需补充", #selector(noQuestions), "n"),
            ("追问提交失败", #selector(clarificationFailure), "4"),
            ("三模式基准", #selector(modeBaseline), "u"),
            ("微调 hover", #selector(modeHover), "5"), ("深色微调 hover", #selector(darkModeHover), "6"),
            ("深色追问", #selector(darkClarification), "7"),
            ("长追问", #selector(clarification), "8"), ("模板预览", #selector(templatePreview), "9"),
            ("失败反馈", #selector(failure), "f"), ("TLS 失败", #selector(tlsFailure), "t"), ("修改历史", #selector(history), "h"),
            ("设置", #selector(settingsView), "s"), ("模板管理", #selector(managerView), "m"),
            ("独立工作窗口", #selector(workspace), "d"),
            ("处理中", #selector(loading), "l"), ("模板建议", #selector(suggestionView), "g"),
            ("提取模板链路", #selector(extractTemplate), "e"),
            ("空内容与模板", #selector(emptyTemplates), "0"), ("带内容的模板", #selector(filledTemplates), "p"),
            ("深色模板中心", #selector(darkFilledTemplates), "P"),
            ("长占位符", #selector(placeholders), "k"), ("六轮记录", #selector(sixRounds), "r"),
            ("填写与修改", #selector(placeholderForm), "b"),
            ("追问等待", #selector(clarificationWaiting), "j")
        ] {
            let item = NSMenuItem(title: title, action: selector, keyEquivalent: shortcut)
            item.keyEquivalentModifierMask = [.command, .option]
            item.target = self
            menu.addItem(item)
        }
        review.submenu = menu
        main.addItem(review)
        app.mainMenu = main
    }
    private func edit(_ text: String) {
        editor.string = text
        editor.setSelectedRange(NSRange(location: (text as NSString).length, length: 0))
        controller.textDidChange(Notification(name: NSText.didChangeNotification, object: editor))
    }
    private func prepare() {
        if controller.canCancelAI { controller.performStopAI() }
        if controller.canCancelAI { controller.performStopAI() }
        controller.show()
        for title in ["微调", "重构", "追问"] {
            let control = button(title, in: root)
            control.contentTintColor = .labelColor
        }
        let clear = button("清空", in: root)
        if clear.isEnabled { activate(clear) }
        edit("@deepseek-ai/dsh-subagent-codex 跟你怎么协作\n发散看去，你还能跟哪些 外部 agent 协作，还是 按 work/coding Agent 排名 最终确定的范围")
        FixtureProtocol.status = 200
        FixtureProtocol.transportError = nil
        FixtureProtocol.delay = 0.05
        FixtureProtocol.content = "会议记录【原文】\n\n请提取已经确定的决定、负责人和截止日期，未确定的信息保留为空。"
    }
    @objc func light() { prepare(); controller.window?.appearance = NSAppearance(named: .aqua) }
    @objc func dark() { prepare(); controller.window?.appearance = NSAppearance(named: .darkAqua) }
    @objc func reviewStop() { loading() }
    @objc func reviewClarificationFailure() { clarificationFailure() }
    @objc func reviewClarificationFailureDark() {
        clarificationFailure()
        controller.window?.appearance = NSAppearance(named: .darkAqua)
        controller.clarificationSheetWindowForTesting?.appearance = NSAppearance(named: .darkAqua)
    }
    @objc func reviewRestoreDraft() {
        prepare()
        controller.hide()
        controller.show()
    }
    @objc func clarification() {
        prepare()
        let question = String(repeating: "请说明这份材料的主要使用场景和需要作出的决定。", count: 8)
        let options = [String(repeating: "团队周会后整理行动项与待确认问题", count: 7), "项目启动前准备讨论材料", "向负责人汇报进展", "个人梳理下一步"]
        let object: [String: Any] = ["status": "ask", "questions": [["question": question, "options": options]]]
        FixtureProtocol.content = String(data: try! JSONSerialization.data(withJSONObject: object), encoding: .utf8)!
        controller.performClarification()
        pump(until: {
            guard let panel = controller.clarificationPanelForTesting else { return false }
            return views(panel).compactMap { $0 as? NSTextField }.contains { $0.stringValue.hasPrefix("请说明这份材料") }
        })
    }
    @objc func shortClarification() {
        prepare()
        let object: [String: Any] = ["status": "ask", "questions": [["question": "你希望基于什么实际运行环境评估与外部 Agent 的协作？", "options": ["ChatGPT 网页或客户端", "通过 API 构建的应用或工作流", "IDE、终端或代码仓库中的 Agent 环境", "只做通用调研，不限定运行环境"]]]]
        FixtureProtocol.content = String(data: try! JSONSerialization.data(withJSONObject: object), encoding: .utf8)!
        controller.performClarification()
        pump(until: {
            guard let panel = controller.clarificationPanelForTesting else { return false }
            return views(panel).compactMap { $0 as? NSTextField }.contains { $0.stringValue.contains("实际运行环境") }
        })
    }
    @objc func clarificationFailure() {
        shortClarification()
        let panel = controller.clarificationPanelForTesting!
        activate(button("通过 API 构建的应用或工作流", in: panel))
        FixtureProtocol.transportError = URLError(.networkConnectionLost)
        activate(button("提交本轮", in: panel))
        pump(until: { !button("重试", in: panel).isHidden })
    }
    @objc func noQuestions() {
        prepare()
        FixtureProtocol.content = clarificationFinalResponse("根据当前信息整理后的 Prompt")
        FixtureProtocol.delay = 0.05
        controller.performClarification()
        pump(until: {
            guard let panel = controller.clarificationPanelForTesting else { return false }
            return views(panel).compactMap { $0 as? NSTextField }
                .contains { $0.stringValue == "追问 · 无需补充" }
        })
    }
    @objc func clarificationWaiting() {
        shortClarification()
        let panel = controller.clarificationPanelForTesting!
        activate(button("通过 API 构建的应用或工作流", in: panel))
        FixtureProtocol.delay = 120
        activate(button("提交本轮", in: panel))
    }
    private func prepareModeScene(dark: Bool) {
        prepare()
        controller.performRefine()
        pump(until: { editor.isEditable })
        controller.window?.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
    }
    private func hoverMode(dark: Bool) {
        prepareModeScene(dark: dark)
        (button("微调", in: root) as? ModeHoverButton)?.setHovering(true)
    }
    @objc func modeBaseline() {
        prepareModeScene(dark: false)
        (button("微调", in: root) as? ModeHoverButton)?.setHovering(false)
    }
    @objc func modeHover() { hoverMode(dark: false) }
    @objc func darkModeHover() { hoverMode(dark: true) }
    @objc func darkClarification() {
        shortClarification()
        controller.clarificationSheetWindowForTesting?.appearance = NSAppearance(named: .darkAqua)
    }
    @objc func templatePreview() {
        let draft = TemplateDraft(title: "周会行动项", detail: "整理决定与后续安排", body: String(repeating: "请根据【会议记录】提取决定、负责人和截止日期。未确定的信息保留为空。\n\n", count: 25))
        let preview = TemplatePreviewWindowController(draft: draft, persistDraft: transientTemplate)
        self.preview = preview
        preview.window?.appearance = NSAppearance(named: .darkAqua)
        preview.show()
    }
    @objc func settingsView() {
        let settings = SettingsWindowController(keyPresence: { _ in false })
        settings.window?.appearance = controller.window?.appearance
        settingsController = settings
        settings.show()
    }
    @objc func codexSubscriptionSettings() {
        let settings = SettingsWindowController(keyPresence: { _ in false })
        settingsController = settings
        settings.show()
        let content = settings.window!.contentView!
        let authModes = views(content).compactMap { $0 as? NSSegmentedControl }.first {
            $0.accessibilityLabel() == "认证方式"
        }!
        authModes.selectedSegment = 1
        triggerAction(authModes)
    }
    @objc func apiKeySettings() {
        let settings = SettingsWindowController(keyPresence: { _ in false })
        settingsController = settings
        settings.show()
        let content = settings.window!.contentView!
        let authModes = views(content).compactMap { $0 as? NSSegmentedControl }.first {
            $0.accessibilityLabel() == "认证方式"
        }!
        authModes.selectedSegment = 0
        triggerAction(authModes)
    }
    @objc func managerView() {
        var templates = (1...12).map { index in transientTemplate(TemplateDraft(title: "周会记录 \(index)", detail: "决定、负责人和截止日期", body: String(repeating: "根据【会议记录】整理已确定的决定和行动项。\n", count: 20))) }
        let manager = TemplateManagerWindowController(
            templatesProvider: { templates },
            addTemplate: { draft in let item = transientTemplate(draft); templates.insert(item, at: 0); return item },
            updateTemplate: { item in
                if let index = templates.firstIndex(where: { $0.id == item.id }) {
                    var saved = item; saved.updatedAt = Date(); templates[index] = saved
                }
            },
            removeTemplate: { id in templates.removeAll { $0.id == id } }
        )
        manager.window?.appearance = controller.window?.appearance
        managerController = manager
        manager.show()
    }
    @objc func workspace() {
        prepare()
        controller.toggleWorkspaceMode()
    }
    @objc func extractTemplate() {
        prepare()
        FixtureProtocol.content = "{\"title\":\"周会行动项\",\"detail\":\"整理决定与后续安排\",\"body\":\"请根据【会议记录】提取决定、负责人和截止日期。\"}"
        controller.performShowTemplates()
        activate(button("存为新", in: controller.templatePickerViewForTesting!))
    }
    @objc func suggestionView() { prepare(); edit("请帮我润色文案，调整语气，让表达更清晰。") }
    @objc func loading() { prepare(); FixtureProtocol.delay = 120; controller.performRefine(); pump(until: { controller.canCancelAI }) }
    @objc func failure() { prepare(); FixtureProtocol.status = 503; controller.performRefine() }
    @objc func tlsFailure() {
        prepare()
        FixtureProtocol.transportError = URLError(.secureConnectionFailed)
        controller.performRegenerate()
        pump(until: { !button("重试", in: root).isHidden && editor.isEditable })
    }
    @objc func emptyTemplates() { prepare(); activate(button("清空", in: root)); controller.performShowTemplates() }
    @objc func filledTemplates() { prepare(); controller.performShowTemplates() }
    @objc func darkFilledTemplates() {
        filledTemplates()
        controller.window?.appearance = NSAppearance(named: .darkAqua)
    }
    @objc func placeholders() {
        prepare()
        let lines = (1...42).map { "第 \($0) 行：用于检查长内容和占位符定位。" }
        edit(lines.joined(separator: "\n") + "\n请处理【最后事项】")
        editor.scrollRangeToVisible(NSRange(location: (editor.string as NSString).length, length: 0))
    }
    @objc func placeholderForm() {
        prepare()
        edit("请根据以下信息整理项目周报，保留待确认事项。\n\n【项目名称】\n【本周进展】：已完成第一版交互方案\n【待确认事项】：\n\n输出决定、负责人和截止日期。")
        controller.promptTextView(editor, focusPlaceholder: PlaceholderNavigator().ranges(in: editor.string).first!)
    }
    @objc func sixRounds() {
        prepare()
        for index in 1...6 {
            FixtureProtocol.content = String(repeating: "第 \(index) 轮：会议记录中的决定和负责人需要逐项对应。\n", count: 18)
            controller.performRefine()
            pump(until: { editor.isEditable })
        }
    }
    @objc func history() {
        prepare()
        FixtureProtocol.content = String(repeating: "会议记录中的决定和负责人需要逐项对应。\n", count: 35)
        controller.performRefine()
    }
}
func runUIReview() {
    app.setActivationPolicy(.accessory)
    let review = UIReviewDelegate()
    app.delegate = review
    review.installMenu()
    review.light()
    if CommandLine.arguments.contains("--review-stopped") {
        review.clarificationWaiting()
    }
    if CommandLine.arguments.contains("--review-no-questions") {
        review.noQuestions()
    }
    if CommandLine.arguments.contains("--review-templates") {
        for window in app.windows { window.orderOut(nil) }
        review.managerView()
    }
    if CommandLine.arguments.contains("--review-loading") {
        review.loading()
    }
    if CommandLine.arguments.contains("--review-stop-contrast") {
        review.reviewStop()
    }
    if CommandLine.arguments.contains("--review-clarification-failure") {
        review.reviewClarificationFailure()
    }
    if CommandLine.arguments.contains("--review-clarification-failure-dark") {
        review.reviewClarificationFailureDark()
    }
    if CommandLine.arguments.contains("--review-restore-draft") {
        review.reviewRestoreDraft()
    }
    if CommandLine.arguments.contains("--review-template-center") {
        review.filledTemplates()
    }
    if CommandLine.arguments.contains("--review-template-center-dark") {
        review.darkFilledTemplates()
    }
    if CommandLine.arguments.contains("--review-codex-subscription") {
        review.codexSubscriptionSettings()
    }
    if CommandLine.arguments.contains("--review-api-key-settings") {
        review.apiKeySettings()
    }
    app.run()
}
func captureSettingsSnapshot(to url: URL) -> Bool {
    let previousModel = UserDefaults.standard.string(forKey: "ai.model")
    UserDefaults.standard.set("deepseek", forKey: "ai.model")
    defer {
        if let previousModel {
            UserDefaults.standard.set(previousModel, forKey: "ai.model")
        } else {
            UserDefaults.standard.removeObject(forKey: "ai.model")
        }
    }
    let settings = SettingsWindowController(keyPresence: { _ in true })
    guard let content = settings.window?.contentView else { return false }
    content.appearance = NSAppearance(named: .aqua)
    content.frame = NSRect(origin: .zero, size: NSSize(width: 640, height: 452))
    content.layoutSubtreeIfNeeded()
    pump(until: {
        views(content).compactMap { $0 as? NSTextField }
            .contains { $0.stringValue.contains("已保存 API Key") }
    }, seconds: 1)
    content.layoutSubtreeIfNeeded()
    content.displayIfNeeded()
    guard let bitmap = content.bitmapImageRepForCachingDisplay(in: content.bounds) else { return false }
    content.cacheDisplay(in: content.bounds, to: bitmap)
    guard let data = bitmap.representation(using: .png, properties: [:]) else { return false }
    do {
        try data.write(to: url)
        return true
    } catch {
        return false
    }
}
func captureLocalizedReview(to directory: URL) -> Bool {
    defer { restoreClipboard() }
    app.setActivationPolicy(.accessory)
    AppLocalization.preference = .english
    let originalContent = FixtureProtocol.content
    let originalDelay = FixtureProtocol.delay
    FixtureProtocol.delay = 0.05
    let controller = PromptWindowController(
        clientFactory: { client },
        motionPreference: { true },
        templatePreviewFactory: { TemplatePreviewWindowController(draft: $0, persistDraft: transientTemplate) }
    )
    var root: NSView { controller.window!.contentView! }
    let editor = views(root).compactMap { $0 as? PromptTextView }.first!
    func edit(_ text: String) {
        editor.string = text
        editor.setSelectedRange(NSRange(location: (text as NSString).length, length: 0))
        controller.textDidChange(Notification(name: NSText.didChangeNotification, object: editor))
    }
    func save(_ name: String, _ view: NSView) -> Bool {
        pump(until: { false }, seconds: 0.15)
        view.layoutSubtreeIfNeeded()
        view.displayIfNeeded()
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return false }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        guard let data = bitmap.representation(using: .png, properties: [:]) else { return false }
        do {
            try data.write(to: directory.appendingPathComponent(name + ".png"))
            return true
        } catch {
            return false
        }
    }
    controller.toggleWorkspaceMode()
    controller.window!.setContentSize(NSSize(width: 1120, height: 720))
    controller.window!.orderFrontRegardless()
    pump(until: { false }, seconds: 0.2)
    edit("Write a 70-word introduction to a Pomodoro app for university students. It runs on macOS, supports a 25-minute timer and pause/resume. Do not add features that were not provided.")
    FixtureProtocol.content = """
    Write a 70-word introduction to Focus Timer for university students.

    Audience: University students managing short study sessions.
    Product facts:
    - Available on macOS.
    - Includes a 25-minute timer.
    - Supports pause and resume.
    Length: 70 words.
    Tone: Clear, practical and encouraging.
    Do not invent additional features.
    """
    controller.performRefine()
    pump(until: { controller.hasConversationHistory })
    guard save("english-workspace", root) else { return false }
    let settings = SettingsWindowController(keyPresence: { _ in false })
    settings.window!.setContentSize(NSSize(width: 720, height: 540))
    let settingsContent = settings.window!.contentView!
    pump(until: {
        views(settingsContent).compactMap { $0 as? NSTextField }
            .contains { $0.stringValue == "No API Key saved for this provider." }
    })
    pump(until: { false }, seconds: 0.5)
    settings.window!.orderFrontRegardless()
    settingsContent.layoutSubtreeIfNeeded()
    settingsContent.displayIfNeeded()
    guard save("english-settings", settings.window!.contentView!) else { return false }
    let help = UsageHelpWindowController()
    help.window!.setContentSize(NSSize(width: 700, height: 620))
    help.show(relativeTo: controller.window)
    pump(until: { false }, seconds: 0.2)
    guard save("english-help", help.window!.contentView!) else { return false }
    help.close()
    controller.performShowTemplates()
    guard save("english-templates", root) else { return false }
    guard save("english-template-shortcuts", controller.templateShortcutPopoverViewForTesting()) else { return false }
    controller.promptTextViewDidRequestClose(editor)
    let object: [String: Any] = [
        "status": "ask",
        "questions": [[
            "question": "Which should this introduction emphasize?",
            "options": ["A simple study routine", "The product facts only"]
        ]]
    ]
    FixtureProtocol.content = String(data: try! JSONSerialization.data(withJSONObject: object), encoding: .utf8)!
    controller.performClarification()
    guard let panel = controller.clarificationPanelForTesting else { return false }
    pump(until: { views(panel).compactMap { $0 as? NSTextField }.contains { $0.stringValue.contains("Which should") } })
    guard save("english-grill-me", panel) else { return false }
    activate(button("The product facts only", in: panel))
    guard save("english-grill-me-selected", panel) else { return false }
    if let answerField = views(panel).compactMap({ $0 as? GrowingClarificationAnswerField }).first {
        answerField.stringValue = "Keep the verified product facts.\nUse a clear, practical tone.\nDo not add unsupported features."
        panel.layoutSubtreeIfNeeded()
        guard save("english-grill-me-custom-expanded", panel) else { return false }
    }
    FixtureProtocol.content = originalContent
    FixtureProtocol.delay = originalDelay
    return true
}
func capturePublicDemo(to directory: URL, frameRate: Double = 10) -> Bool {
    defer { restoreClipboard() }
    try! FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    app.setActivationPolicy(.accessory)
    app.activate(ignoringOtherApps: true)
    AppLocalization.preference = .english
    let controller = PromptWindowController(
        clientFactory: { client },
        motionPreference: { true },
        templatePreviewFactory: { TemplatePreviewWindowController(draft: $0, persistDraft: transientTemplate) }
    )
    var root: NSView { controller.window!.contentView! }
    let editor = views(root).compactMap { $0 as? PromptTextView }.first!
    func edit(_ text: String) {
        editor.string = text
        editor.setSelectedRange(NSRange(location: (text as NSString).length, length: 0))
        controller.textDidChange(Notification(name: NSText.didChangeNotification, object: editor))
    }
    func hideTemplates() {
        controller.promptTextViewDidRequestClose(editor)
        pump(until: { false }, seconds: 0.15)
    }
    func save(_ name: String, _ view: NSView) -> Bool {
        view.layoutSubtreeIfNeeded()
        view.window?.displayIfNeeded()
        pump(until: { false }, seconds: 0.03)
        // cacheDisplay omits AppKit's native glass and some layer-backed
        // button text. Capture the real isolated window instead of repainting
        // only its backdrop into an offscreen bitmap.
        guard let window = view.window else {
            fputs("FAIL: real window capture unavailable for \(name)\n", stderr)
            return false
        }
        let windowNumber = CGWindowID(window.windowNumber)
        let image: CGImage
        let semaphore = DispatchSemaphore(value: 0)
        var captured: CGImage?
        Task {
            defer { semaphore.signal() }
            let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard let source = content?.windows.first(where: { $0.windowID == windowNumber }) else { return }
            let filter = SCContentFilter(desktopIndependentWindow: source)
            let configuration = SCStreamConfiguration()
            configuration.width = max(1, Int(source.frame.width * 2))
            configuration.height = max(1, Int(source.frame.height * 2))
            configuration.showsCursor = false
            configuration.captureResolution = .best
            captured = try? await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
        }
        while semaphore.wait(timeout: .now()) == .timedOut {
            RunLoop.current.run(until: Date().addingTimeInterval(0.01))
        }
        guard let captured else {
            fputs("FAIL: ScreenCaptureKit did not return \(name)\n", stderr)
            return false
        }
        image = captured
        let bitmap = NSBitmapImageRep(cgImage: image)
        guard let data = bitmap.representation(using: .png, properties: [:]) else { return false }
        do {
            try data.write(to: directory.appendingPathComponent(name + ".png"))
            return true
        } catch {
            return false
        }
    }
    let stages = [
        "01-input", "02-request", "03-working", "04-result", "05-edited",
        "06-grill-me", "07-answer", "08-final", "09-copy", "10-templates",
        "11-history", "12-settings", "13-chinese"
    ]
    var last: (NSView, String)?
    var index = 0
    func frame(_ view: NSView, _ name: String, seconds: Double = 1) -> Bool {
        print("DEMO stage \(name)")
        let count = max(1, Int((seconds * frameRate).rounded()))
        for _ in 0..<count {
            guard save(String(format: "frame-%04d", index), view) else { return false }
            index += 1
            pump(until: { false }, seconds: 1 / frameRate)
        }
        if name != last?.1 {
            guard save(name, view) else { return false }
            last = (view, name)
        }
        return true
    }

    // Use the ordinary floating panel for the public sequence. Its layout
    // already has a complete capture path; do not substitute a stale workspace
    // contentView after the controller moves the editor hierarchy.
    controller.show()
    controller.window!.orderFrontRegardless()
    edit("Write a 70-word introduction to Focus Timer for university students.")
    pump(until: { false }, seconds: 0.4)
    guard frame(root, "01-input", seconds: 3) else { return false }
    FixtureProtocol.delay = 0.1
    FixtureProtocol.content = """
    Write a 70-word introduction to Focus Timer for university students.

    Audience: University students managing short study sessions.
    Product facts:
    - Available on macOS.
    - Includes a 25-minute timer.
    - Supports pause and resume.
    Length: 70 words.
    Tone: Clear, practical and encouraging.
    Do not invent additional features.
    """
    controller.performRefine()
    guard frame(root, "02-request", seconds: 0.2) else { return false }
    FixtureProtocol.delay = 120
    controller.performRefine()
    pump(until: { controller.canCancelAI })
    guard frame(root, "03-working", seconds: 1.5) else { return false }
    controller.performStopAI()
    pump(until: { editor.isEditable })
    FixtureProtocol.delay = 0.1
    controller.performRefine()
    pump(until: { controller.hasConversationHistory && controller.canRunAI })
    pump(until: { false }, seconds: 0.4)
    guard frame(root, "04-result", seconds: 3) else { return false }

    FixtureProtocol.content = clarificationAskResponse(
        question: "Which should this introduction emphasize?",
        options: ["A simple study routine", "The product facts only"]
    )
    controller.performClarification()
    guard let panel = controller.clarificationPanelForTesting else { return false }
    pump(until: { views(panel).compactMap { $0 as? NSTextField }.contains { $0.stringValue.contains("Which should") } })
    panel.window?.makeKey()
    guard frame(panel, "06-grill-me", seconds: 3) else { return false }
    activate(button("The product facts only", in: panel))
    panel.layoutSubtreeIfNeeded()
    let submit = button("Submit Answers", in: panel)
    expect(submit.isEnabled && !submit.isHiddenOrHasHiddenAncestor && submit.frame.maxY <= panel.bounds.maxY,
           "the public grill-me capture includes an enabled submit action")
    if let actionButton = submit as? TalisActionButton {
        actionButton.setWindowActive(true)
        // The demo harness activates the fixture App without turning its
        // sheet into a key window. Keep the enabled primary action visible.
        pump(until: { false }, seconds: 0.15)
    }
    (submit as? TalisActionButton)?.setWindowActive(false)
    expect((submit as? TalisActionButton)?.bezelColor != nil,
           "the enabled grill-me submit action retains its primary appearance in an inactive window")
    (submit as? TalisActionButton)?.setWindowActive(true)
    guard frame(panel, "07-answer", seconds: 2) else { return false }
    FixtureProtocol.content = clarificationFinalResponse(editor.string)
    activate(button("Submit Answers", in: panel))
    pump(until: { controller.clarificationSheetWindowForTesting == nil })
    pump(until: { controller.canRunAI })
    pump(until: { false }, seconds: 0.4)
    guard frame(root, "08-final", seconds: 1.5) else { return false }
    edit(editor.string + "\nKeep every statement grounded in these facts.")
    guard frame(root, "05-edited", seconds: 1.5) else { return false }
    controller.performPasteBack()
    guard frame(root, "09-copy", seconds: 0.6) else { return false }
    pump(until: {
        views(root).compactMap { $0 as? NSButton }
            .contains { $0.title == "Copy Prompt  ⌘↵" }
    }, seconds: 1.6)
    controller.performShowTemplates()
    guard frame(root, "10-templates", seconds: 3) else { return false }
    hideTemplates()
    controller.performShowHistory()
    guard let history = NSApp.windows.first(where: { $0.title == "Revision History" && $0.isVisible }),
          let historyRoot = history.contentView else { return false }
    guard frame(historyRoot, "11-history", seconds: 3) else { return false }
    history.close()

    AppLocalization.preference = .simplifiedChinese
    let settings = SettingsWindowController(keyPresence: { _ in false })
    settings.window!.setContentSize(NSSize(width: 720, height: 540))
    settings.show(relativeTo: controller.window)
    AppLocalization.preference = .english
    pump(until: {
        views(settings.window!.contentView!).compactMap { $0 as? NSTextField }
            .contains { $0.stringValue == "No API Key saved for this provider." }
    }, seconds: 4)
    settings.window?.makeKey()
    guard frame(settings.window!.contentView!, "12-settings", seconds: 3) else { return false }
    AppLocalization.preference = .simplifiedChinese
    settings.window!.contentView!.layoutSubtreeIfNeeded()
    guard frame(settings.window!.contentView!, "13-chinese", seconds: 2) else { return false }
    settings.window!.close()
    controller.window!.orderOut(nil)
    let manifest = ["stages": stages, "frameCount": index, "frameRate": frameRate] as [String: Any]
    try! JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
        .write(to: directory.appendingPathComponent("capture.json"))
    return true
}

func captureReleaseFilm(to directory: URL, frameRate: Double = 30) -> Bool {
    defer { restoreClipboard() }
    let framesDirectory = directory.appendingPathComponent("frames", isDirectory: true)
    let stillsDirectory = directory.appendingPathComponent("stills", isDirectory: true)
    try! FileManager.default.createDirectory(at: framesDirectory, withIntermediateDirectories: true)
    try! FileManager.default.createDirectory(at: stillsDirectory, withIntermediateDirectories: true)

    var frameIndex = 0
    var segments: [[String: Any]] = []
    var clicks: [[String: Any]] = []

    func captureWindow(_ view: NSView) -> CGImage? {
        guard let window = view.window else { return nil }
        let windowNumber = CGWindowID(window.windowNumber)
        let semaphore = DispatchSemaphore(value: 0)
        var captured: CGImage?
        Task {
            defer { semaphore.signal() }
            guard let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true),
                  let source = content.windows.first(where: { $0.windowID == windowNumber }) else { return }
            let filter = SCContentFilter(desktopIndependentWindow: source)
            let configuration = SCStreamConfiguration()
            configuration.width = max(1, Int(source.frame.width * 2))
            configuration.height = max(1, Int(source.frame.height * 2))
            configuration.showsCursor = false
            configuration.captureResolution = .best
            captured = try? await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
        }
        while semaphore.wait(timeout: .now()) == .timedOut {
            RunLoop.current.run(until: Date().addingTimeInterval(0.005))
        }
        return captured
    }

    func write(_ image: CGImage, to url: URL) -> Bool {
        let bitmap = NSBitmapImageRep(cgImage: image)
        guard let data = bitmap.representation(using: .png, properties: [:]) else { return false }
        do {
            try data.write(to: url)
            return true
        } catch {
            return false
        }
    }

    @discardableResult
    func captureFrame(_ view: NSView) -> Bool {
        view.layoutSubtreeIfNeeded()
        view.window?.displayIfNeeded()
        views(view).compactMap { $0 as? TalisActionButton }.forEach { $0.setWindowActive(true) }
        if let window = view.window, !window.isKeyWindow {
            app.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            RunLoop.current.run(until: Date().addingTimeInterval(0.01))
        }
        guard let image = captureWindow(view) else {
            fputs("FAIL: release film capture unavailable at frame \(frameIndex)\n", stderr)
            return false
        }
        let url = framesDirectory.appendingPathComponent(String(format: "frame-%06d.png", frameIndex))
        guard write(image, to: url) else { return false }
        frameIndex += 1
        return true
    }

    @discardableResult
    func still(_ view: NSView, name: String) -> Bool {
        view.layoutSubtreeIfNeeded()
        view.window?.displayIfNeeded()
        guard let image = captureWindow(view) else { return false }
        return write(image, to: stillsDirectory.appendingPathComponent(name + ".png"))
    }

    func addSegment(_ id: String, view: String, description: String, startedAt: Int) {
        segments.append([
            "id": id,
            "view": view,
            "description": description,
            "start_frame": startedAt,
            "end_frame": frameIndex,
            "start_seconds": Double(startedAt) / frameRate,
            "end_seconds": Double(frameIndex) / frameRate
        ])
    }

    @discardableResult
    func record(_ view: NSView, id: String, seconds: Double, viewName: String, description: String) -> Bool {
        let startedAt = frameIndex
        let count = max(1, Int((seconds * frameRate).rounded()))
        for _ in 0..<count {
            let next = Date().addingTimeInterval(1 / frameRate)
            guard captureFrame(view) else { return false }
            while Date() < next { RunLoop.current.run(until: Date().addingTimeInterval(0.003)) }
        }
        addSegment(id, view: viewName, description: description, startedAt: startedAt)
        return true
    }

    @discardableResult
    func recordUntil(
        _ view: NSView,
        id: String,
        maxSeconds: Double,
        viewName: String,
        description: String,
        condition: () -> Bool
    ) -> Bool {
        let startedAt = frameIndex
        let limit = Int((maxSeconds * frameRate).rounded())
        for index in 0..<limit {
            let next = Date().addingTimeInterval(1 / frameRate)
            guard captureFrame(view) else { return false }
            if index >= Int(frameRate * 0.35), condition() { break }
            while Date() < next { RunLoop.current.run(until: Date().addingTimeInterval(0.003)) }
        }
        addSegment(id, view: viewName, description: description, startedAt: startedAt)
        return true
    }

    func recordClick(on target: NSView, in root: NSView, label: String) {
        let center = target.convert(NSPoint(x: target.bounds.midX, y: target.bounds.midY), to: root)
        guard root.bounds.width > 0, root.bounds.height > 0 else { return }
        clicks.append([
            "frame": frameIndex,
            "x": center.x / root.bounds.width,
            "y": 1 - center.y / root.bounds.height,
            "label": label
        ])
    }

    app.setActivationPolicy(.regular)
    app.activate(ignoringOtherApps: true)
    AppLocalization.preference = .english

    let controller = PromptWindowController(
        clientFactory: { client },
        motionPreference: { true },
        templatePreviewFactory: { TemplatePreviewWindowController(draft: $0, persistDraft: transientTemplate) }
    )
    var root: NSView { controller.window!.contentView! }
    let editor = views(root).compactMap { $0 as? PromptTextView }.first!

    func edit(_ text: String) {
        editor.string = text
        editor.setSelectedRange(NSRange(location: (text as NSString).length, length: 0))
        controller.textDidChange(Notification(name: NSText.didChangeNotification, object: editor))
    }

    controller.show()
    controller.window!.orderFrontRegardless()
    controller.window!.makeKey()
    pump(until: { false }, seconds: 0.25)
    guard record(root, id: "empty", seconds: 1.2, viewName: "prompt", description: "Empty editable Prompt workspace") else { return false }
    guard still(root, name: "01-empty") else { return false }

    let request = "Write a 60-word launch note for a macOS focus timer for students. It includes a 25-minute timer and pause/resume. Do not add features that were not provided."
    let typingStart = frameIndex
    let typingFrames = Int(frameRate * 4.8)
    for index in 0..<typingFrames {
        let count = max(1, request.count * (index + 1) / typingFrames)
        edit(String(request.prefix(count)))
        let next = Date().addingTimeInterval(1 / frameRate)
        guard captureFrame(root) else { return false }
        while Date() < next { RunLoop.current.run(until: Date().addingTimeInterval(0.003)) }
    }
    addSegment("typing", view: "prompt", description: "A request is written into the editor", startedAt: typingStart)
    guard record(root, id: "ready", seconds: 1.4, viewName: "prompt", description: "The editable request before AI assistance") else { return false }
    guard still(root, name: "02-request") else { return false }

    FixtureProtocol.delay = 1.4
    FixtureProtocol.status = 200
    FixtureProtocol.transportError = nil
    FixtureProtocol.content = """
    Write a 60-word product introduction for Focus Timer.

    Audience: University students who need short, focused study sessions.
    Product facts:
    - Runs on macOS.
    - Includes a 25-minute timer.
    - Supports pause and resume.

    Requirements:
    - 60 words.
    - Clear, practical, and encouraging.
    - Do not invent additional features.
    """
    let refine = button("Refine", in: root)
    recordClick(on: refine, in: root, label: "Refine")
    controller.performRefine()
    guard recordUntil(root, id: "refine", maxSeconds: 2.8, viewName: "prompt", description: "Refine runs and returns an editable structured request", condition: { controller.canRunAI && editor.isEditable }) else { return false }
    guard record(root, id: "result", seconds: 2.6, viewName: "prompt", description: "The returned Prompt remains editable") else { return false }
    guard still(root, name: "03-result") else { return false }

    let copy = views(root).compactMap { $0 as? NSButton }.first { $0.title.hasPrefix("Copy Prompt") }!
    recordClick(on: copy, in: root, label: "Copy")
    controller.performPasteBack()
    guard record(root, id: "copy", seconds: 1.4, viewName: "prompt", description: "The finished Prompt is copied to the clipboard") else { return false }
    pump(until: { views(root).compactMap { $0 as? NSButton }.contains { $0.title.hasPrefix("Copy Prompt") } }, seconds: 1.8)

    let ask: [String: Any] = [
        "status": "ask",
        "questions": [[
            "question": "Which point should the introduction emphasize?",
            "options": ["A simple study routine", "The verified product facts"]
        ]]
    ]
    FixtureProtocol.delay = 0.5
    FixtureProtocol.content = String(data: try! JSONSerialization.data(withJSONObject: ask), encoding: .utf8)!
    let followUp = button("Grill-me", in: root)
    recordClick(on: followUp, in: root, label: "Grill-me")
    controller.performClarification()
    let panel = controller.clarificationPanelForTesting!
    panel.window?.makeKey()
    pump(until: { views(panel).compactMap { $0 as? NSTextField }.contains { $0.stringValue.contains("Which point") } })
    guard record(panel, id: "grill-me", seconds: 1.8, viewName: "grill-me", description: "Grill-me asks for one missing decision") else { return false }
    let option = button("The verified product facts", in: panel)
    recordClick(on: option, in: panel, label: "Select answer")
    activate(option)
    guard record(panel, id: "answer", seconds: 1.5, viewName: "grill-me", description: "A suggested answer is selected") else { return false }
    guard still(panel, name: "04-grill-me") else { return false }

    let finalPrompt = """
    Write a 60-word product introduction for Focus Timer.

    Audience: University students who need short, focused study sessions.
    Emphasis: Keep every claim grounded in the verified product facts.
    Product facts:
    - Runs on macOS.
    - Includes a 25-minute timer.
    - Supports pause and resume.

    Requirements:
    - 60 words.
    - Clear, practical, and encouraging.
    - Do not invent additional features.
    """
    FixtureProtocol.content = clarificationFinalResponse(finalPrompt)
    let submit = button("Submit Answers", in: panel)
    recordClick(on: submit, in: panel, label: "Submit")
    activate(submit)
    pump(until: { controller.clarificationSheetWindowForTesting == nil })
    pump(until: { controller.canRunAI })
    guard record(root, id: "final", seconds: 2.2, viewName: "prompt", description: "The selected answer is incorporated into the editable Prompt") else { return false }
    guard still(root, name: "05-final") else { return false }

    let templateMenu = controller.templateEntryButtonForTesting
    recordClick(on: templateMenu, in: root, label: "Templates")
    controller.performShowTemplates()
    let templatePickerRoot = controller.templatePickerViewForTesting!
    guard record(templatePickerRoot, id: "templates", seconds: 2.5, viewName: "templates", description: "Template Center exposes reusable system templates") else { return false }
    if let row = views(templatePickerRoot).compactMap({ $0 as? CommandRowView }).first(where: {
        views($0).compactMap { $0 as? NSTextField }.contains { $0.stringValue == "Turn a Request into a Prompt" }
    }) {
        recordClick(on: row.selectionButton, in: templatePickerRoot, label: "Select template")
        activate(row.selectionButton)
    }
    guard record(templatePickerRoot, id: "template-selected", seconds: 1.4, viewName: "templates", description: "Selecting a template is separate from applying it") else { return false }
    guard still(templatePickerRoot, name: "06-templates") else { return false }
    controller.promptTextViewDidRequestClose(editor)
    pump(until: { false }, seconds: 0.25)

    controller.performShowHistory()
    guard let history = NSApp.windows.first(where: { $0.title == "Revision History" && $0.isVisible }),
          let historyRoot = history.contentView else { return false }
    history.makeKey()
    guard record(historyRoot, id: "history", seconds: 2.4, viewName: "history", description: "Revision History retains every round in the session") else { return false }
    guard still(historyRoot, name: "07-history") else { return false }
    history.close()

    let settings = SettingsWindowController(keyPresence: { _ in false })
    settings.window!.setContentSize(NSSize(width: 720, height: 540))
    settings.show(relativeTo: controller.window)
    let settingsRoot = settings.window!.contentView!
    pump(until: {
        views(settingsRoot).compactMap { $0 as? NSTextField }
            .contains { $0.stringValue == "No API Key saved for this provider." }
    }, seconds: 3)
    settings.window!.makeKey()
    guard record(settingsRoot, id: "settings-en", seconds: 2.2, viewName: "settings", description: "The English interface is available in Settings") else { return false }
    guard still(settingsRoot, name: "08-settings-en") else { return false }
    let languagePopup = views(settingsRoot).compactMap { $0 as? NSPopUpButton }.first {
        $0.accessibilityLabel() == "App Language" || $0.accessibilityLabel() == "应用语言"
    }!
    languagePopup.selectItem(at: 1)
    triggerAction(languagePopup)
    settingsRoot.layoutSubtreeIfNeeded()
    pump(until: { false }, seconds: 0.3)
    guard record(settingsRoot, id: "settings-zh", seconds: 2.1, viewName: "settings", description: "The same settings page can switch to Simplified Chinese") else { return false }
    guard still(settingsRoot, name: "09-settings-zh") else { return false }
    AppLocalization.preference = .english
    settings.close()
    controller.window!.orderOut(nil)

    let manifest: [String: Any] = [
        "frameCount": frameIndex,
        "frameRate": frameRate,
        "pixelScale": 2,
        "source": "Isolated production AppKit controls with fictional HTTP responses; no personal templates, credentials, or real model requests.",
        "segments": segments,
        "clicks": clicks
    ]
    try! JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
        .write(to: directory.appendingPathComponent("capture.json"))
    print("Captured \(frameIndex) release-film frames at \(frameRate) fps")
    return true
}
if isUIReview {
    if CommandLine.arguments.contains("--verify-localization") {
        verifyLocalization()
        print("PASS: localization source keys, settings round-trip, grill-me, history and user content")
        restoreClipboard()
        exit(0)
    }
    if let option = CommandLine.arguments.firstIndex(of: "--capture-api-key-settings"),
       CommandLine.arguments.indices.contains(option + 1),
       captureSettingsSnapshot(to: URL(fileURLWithPath: CommandLine.arguments[option + 1])) {
        exit(0)
    }
    if let option = CommandLine.arguments.firstIndex(of: "--capture-localized-review"),
       CommandLine.arguments.indices.contains(option + 1),
       captureLocalizedReview(to: URL(fileURLWithPath: CommandLine.arguments[option + 1], isDirectory: true)) {
        exit(0)
    }
    if let option = CommandLine.arguments.firstIndex(of: "--capture-public-demo"),
       CommandLine.arguments.indices.contains(option + 1) {
        let success = capturePublicDemo(to: URL(fileURLWithPath: CommandLine.arguments[option + 1], isDirectory: true))
        restoreClipboard()
        exit(success ? 0 : 1)
    }
    if let option = CommandLine.arguments.firstIndex(of: "--capture-release-film"),
       CommandLine.arguments.indices.contains(option + 1) {
        let success = captureReleaseFilm(to: URL(fileURLWithPath: CommandLine.arguments[option + 1], isDirectory: true))
        restoreClipboard()
        exit(success ? 0 : 1)
    }
    runUIReview()
}
restoreClipboard()
