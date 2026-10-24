import Foundation

struct TemplateDraft: Codable, Equatable {
    var title: String
    var detail: String
    var body: String
}

struct UserPromptTemplate: Codable, Equatable, Identifiable {
    var id: UUID
    var title: String
    var detail: String
    var body: String
    var createdAt: Date
    var updatedAt: Date

    var libraryItem: LibraryItem {
        LibraryItem(
            title: title,
            detail: detail.isEmpty ? "我的专属 Prompt 模板" : detail,
            symbolName: "person.crop.square.filled.and.at.rectangle",
            badge: "我的",
            body: body,
            origin: .user(id: id)
        )
    }
}

enum UserTemplateStore {
    private static let fileName = "user-templates.json"

    static func all() -> [UserPromptTemplate] {
        guard
            let data = try? Data(contentsOf: fileURL)
        else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let templates = try? decoder.decode([UserPromptTemplate].self, from: data) else { return [] }
        return templates.sorted { $0.updatedAt > $1.updatedAt }
    }

    static func search(_ keyword: String) -> [UserPromptTemplate] {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return all() }
        let normalized = normalize(trimmed)
        return all().filter { template in
            normalize(template.title).contains(normalized)
                || normalize(template.detail).contains(normalized)
                || normalize(template.body).contains(normalized)
        }
    }

    @discardableResult
    static func add(_ draft: TemplateDraft) throws -> UserPromptTemplate {
        let now = Date()
        let template = UserPromptTemplate(
            id: UUID(),
            title: sanitizedTitle(draft.title),
            detail: draft.detail.trimmingCharacters(in: .whitespacesAndNewlines),
            body: draft.body.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: now,
            updatedAt: now
        )
        var templates = all()
        templates.insert(template, at: 0)
        try save(templates)
        return template
    }

    static func update(_ template: UserPromptTemplate) throws {
        var templates = all()
        guard let index = templates.firstIndex(where: { $0.id == template.id }) else { return }
        var updated = template
        updated.title = sanitizedTitle(updated.title)
        updated.detail = updated.detail.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.body = updated.body.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.updatedAt = Date()
        templates[index] = updated
        try save(templates)
    }

    static func delete(id: UUID) throws {
        let templates = all().filter { $0.id != id }
        try save(templates)
    }

    static func libraryItems() -> [LibraryItem] {
        all().map(\.libraryItem)
    }

    private static func save(_ templates: [UserPromptTemplate]) throws {
        try FileManager.default.createDirectory(
            at: supportDirectory,
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(templates)
        try data.write(to: fileURL, options: .atomic)
    }

    private static var supportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let talisDirectory = base.appendingPathComponent(AppIdentity.current.dataDirectoryName, isDirectory: true)
        let legacyDirectory = base.appendingPathComponent("Prompt Library", isDirectory: true)
        if !AppIdentity.current.isPreview,
           !FileManager.default.fileExists(atPath: talisDirectory.path),
           FileManager.default.fileExists(atPath: legacyDirectory.appendingPathComponent(fileName).path) {
            try? FileManager.default.createDirectory(at: talisDirectory, withIntermediateDirectories: true)
            try? FileManager.default.copyItem(
                at: legacyDirectory.appendingPathComponent(fileName),
                to: talisDirectory.appendingPathComponent(fileName)
            )
        }
        return talisDirectory
    }

    private static var fileURL: URL {
        supportDirectory.appendingPathComponent(fileName)
    }

    private static func sanitizedTitle(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "未命名模板" : trimmed
    }

    private static func normalize(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .widthInsensitive, .diacriticInsensitive], locale: .current)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\t", with: "")
    }
}
