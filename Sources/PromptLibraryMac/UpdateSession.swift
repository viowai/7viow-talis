import Foundation

/// An explicit local update handoff, never loaded during an ordinary launch.
struct UpdateSession: Codable {
    struct Turn: Codable {
        let query: String
        let result: String
        let actionTitle: String
        let createdAt: Date
    }
    let text: String
    let turns: [Turn]

    static func read(from url: URL) throws -> UpdateSession {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Self.self, from: Data(contentsOf: url))
    }
}
