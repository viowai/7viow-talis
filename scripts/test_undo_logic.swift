import Foundation

private enum TemplateOrigin: Equatable {
    case system(id: String)
    case user(id: UUID)
}

private struct EditorSnapshot: Equatable {
    let text: String
    let origin: TemplateOrigin?
    let title: String?
    let selectedLocation: Int
}

private final class EditorHistoryHarness {
    private(set) var snapshot: EditorSnapshot
    private(set) var undoSnapshots: [EditorSnapshot] = []
    private(set) var redoSnapshots: [EditorSnapshot] = []
    private var isRestoring = false

    init(snapshot: EditorSnapshot) {
        self.snapshot = snapshot
    }

    func registerManualChangeBeforeEditing() {
        registerUndoStep()
    }

    func replaceTextManually(_ text: String) {
        registerManualChangeBeforeEditing()
        snapshot = EditorSnapshot(text: text, origin: snapshot.origin, title: snapshot.title, selectedLocation: text.count)
    }

    func apply(_ next: EditorSnapshot) {
        registerUndoStep()
        restore(next)
    }

    func undo() {
        precondition(!undoSnapshots.isEmpty, "Expected undo to be available")
        let previous = undoSnapshots.removeLast()
        redoSnapshots.append(snapshot)
        restore(previous)
    }

    func redo() {
        precondition(!redoSnapshots.isEmpty, "Expected redo to be available")
        let next = redoSnapshots.removeLast()
        undoSnapshots.append(snapshot)
        restore(next)
    }

    private func registerUndoStep() {
        guard !isRestoring else { return }
        if undoSnapshots.last == snapshot {
            return
        }
        undoSnapshots.append(snapshot)
        redoSnapshots.removeAll()
    }

    private func restore(_ next: EditorSnapshot) {
        isRestoring = true
        snapshot = next
        isRestoring = false
    }
}

private func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

private let userTemplateID = UUID()
private let empty = EditorSnapshot(text: "", origin: nil, title: nil, selectedLocation: 0)
private let systemTemplate = EditorSnapshot(
    text: "系统模板正文",
    origin: .system(id: "system.translate"),
    title: "深度长文翻译",
    selectedLocation: 0
)
private let regenerated = EditorSnapshot(
    text: "重新生成后的 Prompt",
    origin: .system(id: "system.translate"),
    title: "深度长文翻译",
    selectedLocation: 3
)
private let userTemplate = EditorSnapshot(
    text: "我的模板正文",
    origin: .user(id: userTemplateID),
    title: "我的测试模板",
    selectedLocation: 0
)

private let editor = EditorHistoryHarness(snapshot: empty)
editor.apply(systemTemplate)
editor.apply(regenerated)
expect(editor.snapshot == regenerated, "regenerated snapshot should be current")

editor.undo()
expect(editor.snapshot == systemTemplate, "first undo should restore inserted template and origin")
expect(!editor.undoSnapshots.isEmpty, "second undo should remain available")
expect(!editor.redoSnapshots.isEmpty, "redo should be available after first undo")

editor.undo()
expect(editor.snapshot == empty, "second undo should restore initial empty editor")
expect(editor.undoSnapshots.isEmpty, "no more undo should remain at initial state")

editor.redo()
expect(editor.snapshot == systemTemplate, "first redo should restore inserted template")
editor.redo()
expect(editor.snapshot == regenerated, "second redo should restore regenerated prompt")

editor.apply(userTemplate)
editor.apply(empty)
expect(editor.snapshot == empty, "clear should empty editor")
editor.undo()
expect(editor.snapshot == userTemplate, "undo clear should restore user template source and text")

editor.replaceTextManually("我的模板正文 plus")
expect(editor.snapshot.text == "我的模板正文 plus", "manual edit should update text")
editor.undo()
expect(editor.snapshot == userTemplate, "undo manual edit should restore previous text and template source")

print("undo logic tests passed")
