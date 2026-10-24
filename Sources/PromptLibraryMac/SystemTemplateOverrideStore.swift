import Foundation

struct SystemTemplateOverride: Codable, Equatable, Identifiable {
    var id: String
    var title: String
    var body: String
    var updatedAt: Date
}

enum SystemTemplateOverrideStore {
    private static let fileName = "system-template-overrides.json"

    static func all() -> [SystemTemplateOverride] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([SystemTemplateOverride].self, from: data)) ?? []
    }

    static func body(for id: String) -> String? {
        all().first { $0.id == id }?.body
    }

    static func resolvedItem(_ item: LibraryItem) -> LibraryItem {
        guard case .system(let id) = item.origin, let body = body(for: id), !body.isEmpty else {
            return item
        }
        return item.replacingBody(body)
    }

    static func update(id: String, title: String, body: String) throws {
        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBody.isEmpty else { return }
        var overrides = all()
        if let index = overrides.firstIndex(where: { $0.id == id }) {
            overrides[index].title = title
            overrides[index].body = trimmedBody
            overrides[index].updatedAt = Date()
        } else {
            overrides.append(SystemTemplateOverride(id: id, title: title, body: trimmedBody, updatedAt: Date()))
        }
        try save(overrides)
    }

    private static func save(_ overrides: [SystemTemplateOverride]) throws {
        try FileManager.default.createDirectory(
            at: supportDirectory,
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(overrides.sorted { $0.updatedAt > $1.updatedAt })
        try data.write(to: fileURL, options: .atomic)
    }

    private static var supportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent(AppIdentity.current.dataDirectoryName, isDirectory: true)
    }

    private static var fileURL: URL {
        supportDirectory.appendingPathComponent(fileName)
    }
}
