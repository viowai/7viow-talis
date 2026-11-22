import Foundation

enum ModelDiscoveryError: Error {
    case invalidResponse
    case noEligibleModel
}

actor ModelResolver {
    static let shared = ModelResolver(defaults: .standard)
    private struct Entry: Codable {
        var model: String
        var attemptedAt: Date
    }
    private let defaults: UserDefaults?
    private let now: () -> Date
    private let cacheKey = "ai.resolved-models.v1"
    private var cache: [String: Entry]

    init(defaults: UserDefaults? = nil, now: @escaping () -> Date = Date.init) {
        self.defaults = defaults
        self.now = now
        cache = defaults?.data(forKey: cacheKey).flatMap { try? JSONDecoder().decode([String: Entry].self, from: $0) } ?? [:]
    }

    func invalidate(providerID: String) {
        cache = cache.filter { !$0.key.hasPrefix(providerID + "|") }
        persist()
    }

    func resolve(option: OpenAIClient.ModelOption, apiKey: String, session: URLSession,
                 excluding: String? = nil) async throws -> String {
        guard let provider = AIProvider.find(option.id) else { return option.model }
        let key = provider.id + "|" + option.baseURL.absoluteString
        // A provider's default family can change in an app update. A fresh
        // cache from the previous family must not override that choice.
        let old = cache[key].flatMap { provider.rank($0.model) != nil ? $0 : nil }
        if excluding == nil {
            if let old, now().timeIntervalSince(old.attemptedAt) < 24 * 60 * 60 { return old.model }
            if let alias = provider.rollingAlias { return alias }
        }
        do {
            let candidates = try await discover(provider: provider, baseURL: option.baseURL, apiKey: apiKey, session: session)
            guard let selected = provider.select(candidates, excluding: excluding) else { throw ModelDiscoveryError.noEligibleModel }
            cache[key] = Entry(model: selected, attemptedAt: now())
            persist()
            return selected
        } catch {
            if Task.isCancelled || (error as? URLError)?.code == .cancelled { throw error }
            // A directory outage is not a model outage. Never use a model already
            // rejected by the inference endpoint as a recovery fallback.
            let fallback = old?.model ?? option.model
            guard fallback != excluding else { throw ModelDiscoveryError.noEligibleModel }
            cache[key] = Entry(model: fallback, attemptedAt: now())
            persist()
            return fallback
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(cache) { defaults?.set(data, forKey: cacheKey) }
    }

    private func discover(provider: AIProvider, baseURL: URL, apiKey: String, session: URLSession) async throws -> [AIModelCandidate] {
        if var document = provider.catalogDocument {
            if provider.id == "minimax", baseURL.host == "api.minimax.io" {
                document = URL(string: "https://platform.minimax.io/docs/guides/models-intro.md")!
            }
            if provider.id == "zhipu", baseURL.host == "api.z.ai" {
                document = URL(string: "https://docs.z.ai/llms.txt")!
            }
            var request = URLRequest(url: document)
            request.timeoutInterval = 6
            let (data, response) = try await session.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let body = String(data: data, encoding: .utf8) else { throw ModelDiscoveryError.invalidResponse }
            return Self.documentCandidates(body)
        }

        var components = URLComponents(url: baseURL.appendingPathComponent("models"), resolvingAgainstBaseURL: false)!
        var result: [AIModelCandidate] = []
        var cursors = Set<String>()
        while true {
            try Task.checkCancellation()
            var request = URLRequest(url: components.url!)
            request.timeoutInterval = 6
            Self.authorize(&request, provider: provider, apiKey: apiKey)
            let (data, response) = try await session.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let items = (json["data"] ?? json["models"]) as? [[String: Any]] else { throw ModelDiscoveryError.invalidResponse }
            result += items.compactMap(Self.candidate)
            let cursor: String?
            let parameter: String
            if json["has_more"] as? Bool == true {
                guard let last = json["last_id"] as? String ?? items.last?["id"] as? String else { throw ModelDiscoveryError.invalidResponse }
                cursor = last; parameter = "after_id"
            } else {
                cursor = json["nextPageToken"] as? String
                parameter = "pageToken"
            }
            guard let cursor, !cursor.isEmpty else { return result }
            guard cursors.insert(cursor).inserted else { throw ModelDiscoveryError.invalidResponse }
            components.queryItems = [URLQueryItem(name: parameter, value: cursor)]
        }
    }

    static func authorize(_ request: inout URLRequest, provider: AIProvider?, apiKey: String) {
        if provider?.requiresAPIKey == false { return }
        if provider?.apiProtocol == .anthropicMessages {
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        } else {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
    }

    static func documentCandidates(_ body: String) -> [AIModelCandidate] {
        let regex = try! NSRegularExpression(pattern: #"[A-Za-z][A-Za-z0-9_.-]+"#)
        var seen = Set<String>()
        var sections: [(level: Int, unavailable: Bool)] = []
        var result: [AIModelCandidate] = []
        let unavailable = { (text: String) in
            ["preview", "experimental", "deprecated", "retired", "预览", "实验", "已停用", "即将下线", "已下线"].contains(where: text.lowercased().contains)
        }
        for rawLine in body.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            let level = line.prefix(while: { $0 == "#" }).count
            if level > 0 {
                while let last = sections.last, last.level >= level { sections.removeLast() }
                sections.append((level, unavailable(line)))
            }
            guard !sections.contains(where: { $0.unavailable }), !unavailable(line) else { continue }
            for match in regex.matches(in: line, range: NSRange(line.startIndex..., in: line)) {
                guard let range = Range(match.range, in: line) else { continue }
                let raw = String(line[range])
                let id = raw.lowercased().hasPrefix("glm-") ? raw.lowercased() : raw
                if seen.insert(id).inserted { result.append(AIModelCandidate(id: id)) }
            }
        }
        return result
    }

    static func candidate(_ object: [String: Any]) -> AIModelCandidate? {
        guard var id = object["id"] as? String ?? object["name"] as? String else { return nil }
        if id.hasPrefix("models/") { id.removeFirst("models/".count) }
        let lifecycle = object["lifecycle"] as? String ?? (object["lifecycle"] as? [String: Any])?["stage"] as? String ?? object["status"] as? String ?? "active"
        let architecture = object["architecture"] as? [String: Any]
        let output = object["output_modalities"] as? [String] ?? architecture?["output_modalities"] as? [String]
        let methods = object["supportedGenerationMethods"] as? [String]
        let text = (output == nil || output!.contains("text")) && (methods == nil || methods!.contains("generateContent"))
        return AIModelCandidate(id: id, created: object["created"] as? Double ?? 0,
                                active: !["retired", "deprecated", "disabled", "offline"].contains(lifecycle.lowercased()),
                                textOutput: text, line: object["line"] as? String)
    }
}
