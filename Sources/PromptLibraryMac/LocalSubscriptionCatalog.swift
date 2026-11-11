import Foundation

struct AILocalSubscriptionService: Codable, Equatable {
    let owner: String
    let displayName: String
    let providerID: String
    let modelID: String
    let usesResponsesAPI: Bool
    var chatReasoningEffort: String? = nil
}

enum AILocalSubscriptionCatalog {
    static let endpoint = URL(string: "http://127.0.0.1:3425/v1")!
    private static let cacheKey = "ai.local-subscriptions.catalog"

    static var cachedServices: [AILocalSubscriptionService] {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let services = try? JSONDecoder().decode([AILocalSubscriptionService].self, from: data),
              !services.isEmpty else {
            return fallbackServices
        }
        return services
    }

    static func providers(from services: [AILocalSubscriptionService] = cachedServices) -> [AIProvider] {
        services.map { service in
            AIProvider(
                id: service.providerID,
                nameKey: service.displayName,
                initialModel: service.modelID,
                pattern: ".*",
                endpoints: [AIEndpoint("本机共享", endpoint.absoluteString)],
                keyURL: endpoint,
                apiProtocol: service.usesResponsesAPI ? .openAIResponses : .chatCompletions,
                rollingAlias: service.modelID,
                requiresAPIKey: false,
                chatReasoningEffort: service.chatReasoningEffort
            )
        }
    }

    static func provider(for providerID: String) -> AIProvider? {
        providers().first { $0.id == providerID }
    }

    @discardableResult
    static func discover(session: URLSession = .shared) async -> [AILocalSubscriptionService]? {
        var request = URLRequest(url: endpoint.appendingPathComponent("models"))
        request.timeoutInterval = 2
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            let services = try parseModelsData(data)
            guard !services.isEmpty else { return nil }
            save(services)
            return services
        } catch {
            return nil
        }
    }

    static func parseModelsData(_ data: Data) throws -> [AILocalSubscriptionService] {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rows = root["data"] as? [[String: Any]] else {
            throw CocoaError(.fileReadCorruptFile)
        }

        struct Candidate {
            let id: String
            let endpoints: [String]
            let reasoningLevels: [String]
        }

        var grouped: [String: [Candidate]] = [:]
        for row in rows {
            guard let owner = row["owned_by"] as? String, !owner.isEmpty,
                  let id = row["id"] as? String, !id.isEmpty else { continue }
            let endpoints = row["native_endpoints"] as? [String] ?? []
            let reasoningLevels = row["reasoning_levels"] as? [String] ?? []
            grouped[owner, default: []].append(Candidate(id: id, endpoints: endpoints, reasoningLevels: reasoningLevels))
        }

        let order = ["codex", "openai", "kimi-work", "deepseek"]
        let owners = grouped.keys.sorted {
            let left = order.firstIndex(of: $0) ?? Int.max
            let right = order.firstIndex(of: $1) ?? Int.max
            return left == right ? $0.localizedStandardCompare($1) == .orderedAscending : left < right
        }

        return owners.compactMap { owner in
            guard let candidates = grouped[owner], !candidates.isEmpty else { return nil }
            let preferred = candidates.first { $0.id.lowercased().contains("terra") }
                ?? candidates.first { !$0.id.lowercased().contains("preview") }
                ?? candidates[0]
            let prefersResponses = owner == "codex" || owner == "openai"
            let usesResponses = preferred.endpoints.contains("/v1/responses")
                && (prefersResponses || !preferred.endpoints.contains("/v1/chat/completions"))
            return AILocalSubscriptionService(
                owner: owner,
                displayName: displayName(for: owner),
                providerID: owner == "codex" ? AIProvider.codexSubscriptionID : "local-subscription-\(sanitize(owner))",
                modelID: preferred.id,
                usesResponsesAPI: usesResponses,
                chatReasoningEffort: preferred.reasoningLevels.contains("low") ? "low" : nil
            )
        }
    }

    static func save(_ services: [AILocalSubscriptionService]) {
        guard let data = try? JSONEncoder().encode(services) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey)
    }

    private static var fallbackServices: [AILocalSubscriptionService] {
        [
            AILocalSubscriptionService(
                owner: "codex",
                displayName: "Codex",
                providerID: AIProvider.codexSubscriptionID,
                modelID: "codex/gpt-6.1-terra",
                usesResponsesAPI: true,
                chatReasoningEffort: "low"
            )
        ]
    }

    private static func displayName(for owner: String) -> String {
        switch owner {
        case "codex": return "Codex"
        case "openai": return "OpenAI"
        case "kimi-work": return "Kimi Work"
        case "deepseek": return "DeepSeek"
        default:
            return owner
                .split(whereSeparator: { $0 == "-" || $0 == "_" })
                .map { $0.prefix(1).uppercased() + $0.dropFirst() }
                .joined(separator: " ")
        }
    }

    private static func sanitize(_ value: String) -> String {
        value.lowercased().map { character in
            character.isLetter || character.isNumber ? character : "-"
        }.reduce(into: "") { $0.append($1) }
    }
}
