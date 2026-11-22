import AppKit

final class StatusBarController: NSObject, NSMenuDelegate, NSMenuItemValidation {
    var onToggle: (() -> Void)?
    var onNewPrompt: (() -> Void)?
    var onRestoreLastDraft: (() -> Void)?
    var onShowHistory: (() -> Void)?
    var onShowTemplates: (() -> Void)?
    var onShowSettings: (() -> Void)?
    var onShowAbout: (() -> Void)?
    var onQuit: (() -> Void)?
    var promptIsVisible: () -> Bool = { false }
    var canRestoreDraft: () -> Bool = { false }
    var canShowHistory: () -> Bool = { false }
    var canChooseTemplate: () -> Bool = { true }

    private var statusItem: NSStatusItem?
    private var menu: NSMenu?

    init(installsSystemItem: Bool = true) {
        super.init()
        menu = makeMenu()
        AppLocalization.observe(self, selector: #selector(refreshLocalization))
        guard installsSystemItem else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = AppTheme.statusBarIcon()
        item.button?.imagePosition = .imageOnly
        item.button?.target = self
        item.button?.action = #selector(statusItemPressed(_:))
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        item.button?.setAccessibilityLabel(AppIdentity.current.displayName)
        item.button?.toolTip = "\(AppIdentity.current.displayName)（\(AppIdentity.current.shortcutLabel)）"
        statusItem = item
    }

    func menuItemTitlesForTesting() -> [String] {
        menu?.items.map(\.title) ?? []
    }

    func invokeMenuItemForTesting(_ title: String) -> Bool {
        guard let item = menu?.items.first(where: { $0.title == title }),
              let action = item.action else { return false }
        NSApp.sendAction(action, to: item.target, from: item)
        return true
    }

    func isMenuItemEnabledForTesting(_ title: String) -> Bool {
        guard let item = menu?.items.first(where: { $0.title == title }) else { return false }
        return validateMenuItem(item)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        guard let first = menu.items.first(where: { $0.action == #selector(togglePrompt) }) else { return }
        first.title = promptIsVisible() ? AppLocalization.format("隐藏 %@", AppIdentity.current.displayName) : AppLocalization.format("打开 %@", AppIdentity.current.displayName)
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(restoreLastDraft) { return canRestoreDraft() }
        if menuItem.action == #selector(showHistory) { return canShowHistory() }
        if menuItem.action == #selector(showTemplates) { return canChooseTemplate() }
        return true
    }

    @objc private func statusItemPressed(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        let secondary = event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true
        if secondary, let menu {
            menuNeedsUpdate(menu)
            menu.popUp(
                positioning: nil,
                at: NSPoint(x: 0, y: sender.bounds.height + 4),
                in: sender
            )
        } else {
            onToggle?()
        }
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu(title: AppIdentity.current.displayName)
        menu.delegate = self
        for (title, action) in [
            (AppLocalization.format("打开 %@", AppIdentity.current.displayName), #selector(togglePrompt)),
            (L("新建 Prompt"), #selector(newPrompt)),
            (L("恢复上次草稿"), #selector(restoreLastDraft)),
            (L("修改记录"), #selector(showHistory)),
            (L("模板中心"), #selector(showTemplates))
        ] {
            menu.addItem(item(title, action))
        }
        menu.addItem(.separator())
        menu.addItem(item(L("设置…"), #selector(showSettings)))
        menu.addItem(item(AppLocalization.format("关于 %@", AppIdentity.current.displayName), #selector(showAbout)))
        menu.addItem(.separator())
        menu.addItem(item(AppLocalization.format("退出 %@", AppIdentity.current.displayName), #selector(quit)))
        return menu
    }

    @objc private func refreshLocalization() { menu = makeMenu() }

    private func item(_ title: String, _ action: Selector) -> NSMenuItem {
        let menuItem = NSMenuItem(title: title, action: action, keyEquivalent: "")
        menuItem.target = self
        return menuItem
    }

    @objc private func togglePrompt() { onToggle?() }
    @objc private func newPrompt() { onNewPrompt?() }
    @objc private func restoreLastDraft() { onRestoreLastDraft?() }
    @objc private func showHistory() { onShowHistory?() }
    @objc private func showTemplates() { onShowTemplates?() }
    @objc private func showSettings() { onShowSettings?() }
    @objc private func showAbout() { onShowAbout?() }
    @objc private func quit() { onQuit?() }
}
