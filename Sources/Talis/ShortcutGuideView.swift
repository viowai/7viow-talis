import AppKit

/// Each row describes one operation; keys and actions align in separate columns.
final class ShortcutGuideView: NSStackView {
    struct Entry {
        let key: String
        let action: String
    }

    static var templateEntries: [Entry] {
        [
            Entry(key: "↑↓", action: L("选择")),
            Entry(key: "↵", action: L("应用")),
            Entry(key: "Tab", action: L("来源")),
            Entry(key: "Esc", action: L("收起"))
        ]
    }

    let entries: [Entry]
    var preferredHeight: CGFloat { CGFloat(entries.count) * 22 + CGFloat(max(0, entries.count - 1)) * 6 }

    init(entries: [Entry]) {
        self.entries = entries
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        orientation = .vertical
        alignment = .leading
        distribution = .fill
        spacing = 6
        for entry in entries {
            let row = entryView(for: entry)
            addArrangedSubview(row)
            NSLayoutConstraint.activate([
                row.widthAnchor.constraint(equalTo: widthAnchor),
                row.heightAnchor.constraint(equalToConstant: 22)
            ])
        }
        heightAnchor.constraint(equalToConstant: preferredHeight).isActive = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func entryView(for entry: Entry) -> NSStackView {
        let key = ShortcutKeyView(key: entry.key)
        let action = NSTextField(labelWithString: entry.action)
        action.font = AppTheme.regular(12)
        action.textColor = AppTheme.secondaryTextColor
        action.setContentCompressionResistancePriority(.required, for: .horizontal)
        let row = NSStackView(views: [key, action])
        row.translatesAutoresizingMaskIntoConstraints = false
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: 22),
            key.widthAnchor.constraint(equalToConstant: 60),
            action.trailingAnchor.constraint(lessThanOrEqualTo: row.trailingAnchor)
        ])
        return row
    }
}

/// Return is a system symbol, so its shape isn't lost to Unicode font metrics.
final class ShortcutKeyView: ThemedSurfaceView {
    init(key: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        fillColor = .controlBackgroundColor
        layer?.cornerRadius = 5
        let parts = NSStackView()
        parts.orientation = .horizontal
        parts.spacing = 3
        parts.alignment = .centerY
        parts.translatesAutoresizingMaskIntoConstraints = false
        let text = key.replacingOccurrences(of: "↵", with: "")
        if !text.isEmpty {
            let label = NSTextField(labelWithString: text)
            label.font = AppTheme.medium(12)
            label.textColor = .secondaryLabelColor
            label.setAccessibilityElement(false)
            parts.addArrangedSubview(label)
        }
        if key.contains("↵") {
            let image = NSImageView()
            image.image = NSImage(systemSymbolName: "return", accessibilityDescription: nil)
            image.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
            image.contentTintColor = .secondaryLabelColor
            image.setAccessibilityElement(false)
            image.translatesAutoresizingMaskIntoConstraints = false
            parts.addArrangedSubview(image)
            NSLayoutConstraint.activate([
                image.widthAnchor.constraint(equalToConstant: 16),
                image.heightAnchor.constraint(equalToConstant: 14)
            ])
        }
        addSubview(parts)
        setAccessibilityElement(true)
        setAccessibilityRole(.staticText)
        setAccessibilityLabel(key.contains("↵") ? (key.contains("⌘") ? "Command + Return" : "Return") : key)
        NSLayoutConstraint.activate([
            parts.centerXAnchor.constraint(equalTo: centerXAnchor),
            parts.centerYAnchor.constraint(equalTo: centerYAnchor),
            parts.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 4),
            parts.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: 2),
            parts.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -2)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
