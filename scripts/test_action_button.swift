import AppKit
import TalisCore

var checks = 0
func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fputs("FAIL: \(message)\n", stderr); exit(1) }
    checks += 1
}

func expectCapsuleFocusMask(_ actionButton: TalisActionButton, _ label: String) {
    expect(actionButton.focusRingType == .exterior && actionButton.focusRingMaskBounds == actionButton.bounds,
           "\(label) exposes an exterior focus ring at the control bounds")
    let size = actionButton.bounds.size
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(size.width),
        pixelsHigh: Int(size.height),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else { fputs("FAIL: cannot create focus mask bitmap\n", stderr); exit(1) }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    actionButton.drawFocusRingMask()
    NSGraphicsContext.restoreGraphicsState()
    let corners = [[0, 0], [Int(size.width) - 1, 0], [0, Int(size.height) - 1], [Int(size.width) - 1, Int(size.height) - 1]]
    expect(corners.allSatisfy { bitmap.colorAt(x: $0[0], y: $0[1])?.alphaComponent == 0 },
           "\(label) does not draw rectangular end caps")
    expect(bitmap.colorAt(x: Int(size.width) / 2, y: 0)?.alphaComponent == 1,
           "\(label) retains a visible capsule focus path")
}
func descendants(_ root: NSView) -> [NSView] {
    [root] + root.subviews.flatMap(descendants)
}

func runChecks() {
for actionTitle in ["使用整理后的 Prompt", "下一题", "提交本轮", "重试"] {
    let actionButton = TalisActionButton(title: actionTitle, target: nil, action: nil, surface: .push, emphasis: .primary)
    actionButton.frame = NSRect(x: 0, y: 0, width: 208, height: 36)
    actionButton.layoutSubtreeIfNeeded()
    expectCapsuleFocusMask(actionButton, actionTitle)
    expect(actionButton.intrinsicContentSize.width >= actionTitle.size(withAttributes: [.font: AppTheme.medium(14)]).width,
           "\(actionTitle) retains its full-title intrinsic width")
}

let primary = TalisActionButton(title: "使用整理后的 Prompt", target: nil, action: nil, surface: .push, emphasis: .primary)
primary.keepsPrimaryWhenInactive = true
primary.frame = NSRect(x: 0, y: 0, width: 208, height: 36)
primary.layoutSubtreeIfNeeded()
let restingColor = primary.layer?.backgroundColor
primary.setHovering(true)
expect(primary.layer?.backgroundColor != restingColor, "hover changes only the capsule surface")
primary.isHighlighted = true
expect(primary.isHighlighted && primary.focusRingMaskBounds == primary.bounds, "pressed state retains capsule focus geometry")
primary.isHighlighted = false
primary.setHovering(false)
primary.setWindowActive(false)
expect(primary.bezelColor != nil && primary.focusRingMaskBounds == primary.bounds, "inactive-window state retains solid surface and capsule focus geometry")

let panel = ClarificationPanelView()
panel.configureNoQuestions()
let panelWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 620, height: 254), styleMask: [.titled], backing: .buffered, defer: false)
panelWindow.contentView = panel
panel.frame = panelWindow.contentView!.bounds
panel.layoutSubtreeIfNeeded()
let noQuestionButton = descendants(panel).compactMap { $0 as? TalisActionButton }.first { $0.title == "使用整理后的 Prompt" }
expect(noQuestionButton != nil, "no-question primary action remains reachable")
if let noQuestionButton {
    expect(noQuestionButton.frame.width >= 200, "no-question action retains its repaired full-title width")
    expectCapsuleFocusMask(noQuestionButton, "no-question production panel")
}

let question = ClarificationQuestion(question: "检查按钮", options: ["选项一", "选项二"])
panel.configure(question: question, round: 1, maximumRounds: 5, questionIndex: 0, totalQuestions: 2)
panel.layoutSubtreeIfNeeded()
let actionButtons = descendants(panel).compactMap { $0 as? TalisActionButton }
expect(actionButtons.contains { $0.title == "下一题" }, "next action remains present")
panel.configure(question: question, round: 1, maximumRounds: 5, questionIndex: 0, totalQuestions: 1)
panel.layoutSubtreeIfNeeded()
expect(actionButtons.contains { $0.title == "提交本轮" }, "submit action remains present")
panel.showError(title: "提交失败", message: "模拟传输失败", retryTitle: "重试", retry: {})
panel.layoutSubtreeIfNeeded()
expect(actionButtons.contains { $0.title == "重试" && $0.isEnabled }, "retry action remains present and enabled")
panelWindow.close()
print("PASS: \(checks) focused shared-button checks; no network or persistent user data")
}

@main
enum ActionButtonCheck {
    static func main() {
        runChecks()
    }
}
