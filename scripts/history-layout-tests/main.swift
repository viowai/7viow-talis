import AppKit

let app = NSApplication.shared
let scrollView = HistoryScrollView(frame: NSRect(x: 0, y: 0, width: 420, height: 150))
scrollView.hasVerticalScroller = true
let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 650, height: 134))
textView.configureHistoryWrapping()
textView.isEditable = false
textView.isSelectable = true
textView.isRichText = false
textView.font = .systemFont(ofSize: 11)
textView.textContainerInset = NSSize(width: 8, height: 8)
textView.textContainer?.containerSize = NSSize(width: 650, height: CGFloat.greatestFiniteMagnitude)
textView.string = String(repeating: "较长的中文历史查询必须在阅读区内完整换行，不能从右侧截断。", count: 48)
scrollView.documentView = textView
scrollView.layout()
let manager = textView.layoutManager!
let container = textView.textContainer!
manager.ensureLayout(for: container)
var lines = 0
manager.enumerateLineFragments(forGlyphRange: manager.glyphRange(for: container)) { _, used, _, _, _ in
    precondition(used.maxX <= container.containerSize.width + 0.5)
    lines += 1
}
precondition(lines > 1, "Long history text must wrap into multiple lines")
precondition(!textView.isHorizontallyResizable && textView.isVerticallyResizable)
precondition(textView.frame.width <= scrollView.contentSize.width + 0.5)
precondition(container.containerSize.width <= scrollView.contentSize.width)
precondition(textView.frame.height > scrollView.contentSize.height)
scrollView.setFrameSize(NSSize(width: 300, height: 150))
scrollView.layout()
precondition(textView.frame.width <= scrollView.contentSize.width + 0.5)
print("PASS: long Chinese history wraps into \(lines) lines without horizontal overflow")
