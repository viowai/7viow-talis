import AppKit

final class HistoryScrollView: NSScrollView {
    override func layout() {
        super.layout()
        guard let textView = documentView as? NSTextView, contentSize.width > 0 else { return }
        let width = contentSize.width
        textView.minSize.width = width
        textView.maxSize.width = width
        textView.setFrameSize(NSSize(width: width, height: max(contentSize.height, textView.frame.height)))
        textView.textContainer?.containerSize.width = max(1, width - 2 * textView.textContainerInset.width)
        if let manager = textView.layoutManager, let container = textView.textContainer {
            manager.ensureLayout(for: container)
            let height = max(contentSize.height, manager.usedRect(for: container).height + 2 * textView.textContainerInset.height)
            textView.setFrameSize(NSSize(width: width, height: height))
        }
        if contentView.bounds.origin.x != 0 {
            contentView.scroll(to: NSPoint(x: 0, y: contentView.bounds.origin.y))
        }
    }
}

extension NSTextView {
    func configureHistoryWrapping() {
        isHorizontallyResizable = false
        isVerticallyResizable = true
        minSize = .zero
        maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        autoresizingMask = [.width]
        textContainer?.widthTracksTextView = true
        textContainer?.heightTracksTextView = false
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        defaultParagraphStyle = paragraph
    }
}
