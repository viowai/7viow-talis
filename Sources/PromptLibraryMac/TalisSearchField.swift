import AppKit

/// Keeps AppKit's search-field chrome in one text layer.
///
/// macOS can create an internal text control while resolving a search field.
/// Normalizing the public cell and avoiding localization traversal into private
/// subviews prevents a clipped duplicate of the placeholder from being drawn.
final class TalisSearchField: NSSearchField {
    override var placeholderString: String? {
        didSet { normalizeNativeLayers() }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        normalizeNativeLayers()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        normalizeNativeLayers()
    }

    func preparePlaceholder(_ text: String) {
        placeholderString = text
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        normalizeNativeLayers()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        normalizeNativeLayers()
    }

    private func normalizeNativeLayers() {
        guard let searchCell = cell as? NSSearchFieldCell else { return }
        searchCell.title = ""
        searchCell.placeholderString = placeholderString
        searchCell.usesSingleLineMode = true
        searchCell.lineBreakMode = .byTruncatingTail
        searchCell.isScrollable = true
    }
}
