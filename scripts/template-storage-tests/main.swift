import Foundation

// This test-owned identity isolates actual production storage in its own folder.
struct AppIdentity {
    static let current = AppIdentity()
    let dataDirectoryName = "TalisStorageTests-\(UUID().uuidString).noindex"
    let isPreview = true
}
struct Failure: Error { let message: String }
var checks = 0
func expect(_ condition: Bool, _ message: String) throws {
    guard condition else { throw Failure(message: message) }
    checks += 1
}
func run() throws {
    let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        .appendingPathComponent(AppIdentity.current.dataDirectoryName)
    defer { try? FileManager.default.removeItem(at: root) }
    let fixtures = ["  【字段】::：\n  ", "没有占位符的模板\n", "【】", "【未闭合", "【名字:】内容"]
    for (index, body) in fixtures.enumerated() {
        let item = try UserTemplateStore.add(TemplateDraft(title: "模板\(index)", detail: "说明", body: body))
        try expect(UserTemplateStore.all().first { $0.id == item.id }?.body == body, "new template body must round-trip exactly")
        var changed = item
        changed.body = "\n" + body + "\t"
        try UserTemplateStore.update(changed)
        try expect(UserTemplateStore.all().first { $0.id == item.id }?.body == changed.body, "updated template body must round-trip exactly")
        let id = "system.literal-\(index)"
        try SystemTemplateOverrideStore.update(id: id, title: "系统模板", body: body)
        try expect(SystemTemplateOverrideStore.body(for: id) == body, "system override body must round-trip exactly")
        try SystemTemplateOverrideStore.update(id: id, title: "系统模板", body: changed.body)
        try expect(SystemTemplateOverrideStore.body(for: id) == changed.body, "updated override preserves all whitespace")
    }
}
do { try run(); print("PASS: \(checks) production template storage round-trips; isolated test identity, no real template writes") }
catch { fputs("FAIL: \(error)\n", stderr); exit(1) }
