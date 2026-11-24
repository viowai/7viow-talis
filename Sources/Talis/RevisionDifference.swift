import AppKit

struct RevisionDifference {
    static let buttonIcon: NSImage = {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { _ in
            NSColor.black.setStroke()
            let path = NSBezierPath(roundedRect: NSRect(x: 2, y: 1, width: 14, height: 16), xRadius: 3, yRadius: 3)
            path.lineWidth = 1.5
            path.lineCapStyle = .round
            for (a, b) in [(NSPoint(x: 6, y: 6.5), NSPoint(x: 12, y: 6.5)),
                           (NSPoint(x: 9, y: 4), NSPoint(x: 9, y: 9)),
                           (NSPoint(x: 6, y: 12.5), NSPoint(x: 12, y: 12.5))] {
                path.move(to: a)
                path.line(to: b)
            }
            path.stroke()
            return true
        }
        image.isTemplate = true
        return image
    }()
    enum Kind { case unchanged, removed, inserted }
    struct Row { let kind: Kind; let text: String }
    let rows: [Row]
    let added: Int
    let deleted: Int

    init(before: String, after: String) {
        func lines(_ value: String) -> [Substring] {
            value.isEmpty ? [] : value.replacingOccurrences(of: "\r\n", with: "\n").split(separator: "\n", omittingEmptySubsequences: false)
        }
        let old = lines(before), new = lines(after)
        let changes = new.difference(from: old)
        var removals = Set<Int>(), insertions = Set<Int>()
        for change in changes {
            switch change {
            case .remove(let index, _, _): removals.insert(index)
            case .insert(let index, _, _): insertions.insert(index)
            }
        }
        var output: [Row] = [], i = 0, j = 0
        while i < old.count || j < new.count {
            if removals.contains(i) {
                output.append(Row(kind: .removed, text: String(old[i]))); i += 1
            } else if insertions.contains(j) {
                output.append(Row(kind: .inserted, text: String(new[j]))); j += 1
            } else {
                output.append(Row(kind: .unchanged, text: String(new[j]))); i += 1; j += 1
            }
        }
        rows = output; added = insertions.count; deleted = removals.count
    }

    var summary: String { AppLocalization.format("新增 %@ 行 · 删除 %@ 行", added, deleted) }

    func rendered() -> (NSAttributedString, NSRange) {
        let output = NSMutableAttributedString(string: "")
        var first: NSRange?
        for (index, row) in rows.enumerated() {
            var attributes: [NSAttributedString.Key: Any] = [.font: AppTheme.regular(15), .foregroundColor: NSColor.labelColor]
            let prefix: String
            switch row.kind {
            case .unchanged: prefix = "   "
            case .removed:
                prefix = "−  "
                attributes[.backgroundColor] = NSColor.systemRed.withAlphaComponent(0.15)

            case .inserted:
                prefix = "+  "
                attributes[.backgroundColor] = NSColor.systemGreen.withAlphaComponent(0.15)

            }
            if row.kind != .unchanged && first == nil { first = NSRange(location: output.length, length: 1) }
            let start = output.length + (prefix as NSString).length
            output.append(NSAttributedString(string: prefix + row.text + "\n", attributes: attributes))
            let partner = row.kind == .removed ? index + 1 : index - 1
            if row.kind != .unchanged, rows.indices.contains(partner),
               rows[partner].kind == (row.kind == .removed ? .inserted : .removed) {
                let characters = Array(row.text), other = Array(rows[partner].text)
                let leading = zip(characters, other).prefix { $0 == $1 }.count
                let trailing = zip(characters.dropFirst(leading).reversed(), other.dropFirst(leading).reversed()).prefix { $0 == $1 }.count
                let lower = row.text.index(row.text.startIndex, offsetBy: leading)
                let upper = row.text.index(row.text.endIndex, offsetBy: -trailing)
                let span = NSRange(lower..<upper, in: row.text)
                output.addAttribute(row.kind == .removed ? .strikethroughStyle : .underlineStyle,
                                    value: NSUnderlineStyle.single.rawValue,
                                    range: NSRange(location: start + span.location, length: span.length))
            }
        }
        return (output, first ?? NSRange(location: 0, length: 0))
    }
}

final class RevisionReadingView: NSTextView {
    var handleShortcut: ((UInt16, Bool) -> Void)?
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if (flags == .command || flags == [.shift, .command]) && (event.keyCode == 6 || event.keyCode == 36) {
            handleShortcut?(event.keyCode, flags.contains(.shift))
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
    var returnToDraft: (() -> Void)?
    override func cancelOperation(_ sender: Any?) { returnToDraft?() }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { returnToDraft?(); return }
        super.keyDown(with: event)
    }
}
