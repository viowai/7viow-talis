import Foundation
import TalisCore

struct TemplateDraft { var title: String; var detail: String; var body: String }
struct CheckFailure: Error, CustomStringConvertible { let description: String }
struct Reply {
    var status = 200
    var body: Data
    init(_ object: Any, status: Int = 200) {
        self.status = status
        body = (try? JSONSerialization.data(withJSONObject: object)) ?? Data()
    }
    init(body: Data, status: Int = 200) {
        self.status = status
        self.body = body
    }
}
final class StubProtocol: URLProtocol {
    static var handler: (URLRequest) throws -> Reply = { _ in Reply([:]) }
    static var requests: [URLRequest] = []
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.requests.append(request)
        do {
            let reply = try Self.handler(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: reply.status, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: reply.body)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}
let configuration = URLSessionConfiguration.ephemeral
configuration.protocolClasses = [StubProtocol.self]
let session = URLSession(configuration: configuration)
var checks = 0
func check(_ value: Bool, _ label: String) throws { checks += 1; if !value { throw CheckFailure(description: label) } }
func body(_ request: URLRequest) -> [String: Any] {
    var data = request.httpBody ?? Data()
    if data.isEmpty, let stream = request.httpBodyStream {
        stream.open(); defer { stream.close() }
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable { let count = stream.read(&buffer, maxLength: buffer.count); if count <= 0 { break }; data.append(buffer, count: count) }
    }
    return ((try? JSONSerialization.jsonObject(with: data)) as? [String: Any]) ?? [:]
}
func textReply(_ text: String) -> Reply { Reply(["choices": [["message": ["content": text]]]]) }
func catalog(_ models: [String]) -> Reply { Reply(["data": models.map { ["id": $0] }]) }
func sseReply(_ events: [[String: Any]]) -> Reply {
    let lines = events.compactMap { event -> String? in
        guard let data = try? JSONSerialization.data(withJSONObject: event) else { return nil }
        return "data: \(String(decoding: data, as: UTF8.self))\n\n"
    }.joined() + "data: [DONE]\n\n"
    return Reply(body: Data(lines.utf8))
}
func reset(_ handler: @escaping (URLRequest) throws -> Reply) { StubProtocol.requests = []; StubProtocol.handler = handler }
func client(_ id: String, resolver: ModelResolver = ModelResolver(), base: URL? = nil) -> OpenAIClient {
    let original = OpenAIClient.modelOption(for: id)
    let option = OpenAIClient.ModelOption(id: id, title: original.title, model: original.model, baseURL: base ?? original.baseURL)
    return OpenAIClient(apiKey: "fictional-\(id)-key", modelOption: option, urlSession: session, modelResolver: resolver)
}
let fixture = OpenAIClient(apiKey: "fictional-key", modelOption: .init(id: "fixture", title: "Fixture", model: "fixture", baseURL: URL(string: "https://talis.invalid/v1")!), urlSession: session, modelResolver: ModelResolver())

func runChecks() async throws {
    let previousAppLanguage = AppLocalization.preference
    defer { AppLocalization.preference = previousAppLanguage }
    AppLocalization.preference = .simplifiedChinese
    let connectionError = URLError(.cannotConnectToHost) as NSError
    try check(client("deepseek").requestErrorMessage(for: connectionError) == "无法连接 AI 服务，请稍后重试。",
              "API connection errors are diagnosed from the operation client")
    try check(client(AIProvider.codexSubscriptionID).requestErrorMessage(for: connectionError)
              == "Codex 订阅当前不可用。请确认已登录 Codex 订阅。",
              "subscription connection errors keep their original provider without global settings")
    for errorCode in [URLError.Code.timedOut, .networkConnectionLost, .secureConnectionFailed] {
        let error = URLError(errorCode) as NSError
        try check(client("deepseek").requestErrorMessage(for: error)
                  == client(AIProvider.codexSubscriptionID).requestErrorMessage(for: error),
                  "shared transport diagnoses remain consistent across services: \(errorCode)")
    }
    let upstreamError = NSError(domain: "fixture.model", code: 3,
                                userInfo: [NSLocalizedDescriptionKey: "specific upstream reason"])
    try check(client("deepseek").requestErrorMessage(for: upstreamError) == "specific upstream reason",
              "provider diagnosis preserves non-network failure reasons")
    // Existing failure behavior must survive the new resolver and wire protocol.
    for (status, response, expected) in [
        (401, Reply(["error": ["message": "Invalid test credential"]], status: 401), "Invalid test credential"),
        (429, Reply([:], status: 429), "HTTP 429"),
        (500, Reply([:], status: 500), "HTTP 500"),
        (200, Reply(["choices": [["message": ["content": "   "]]]]), "没有返回可用内容")
    ] {
        reset { _ in response }
        do { _ = try await fixture.run(action: .refine, input: "fictional prompt"); throw CheckFailure(description: "expected failure \(status)") }
        catch let error as CheckFailure { throw error }
        catch { try check(error.localizedDescription.contains(expected), "HTTP/empty response classification \(status)") }
    }
    for code in [URLError.notConnectedToInternet, .networkConnectionLost, .timedOut, .cancelled] {
        reset { _ in throw URLError(code) }
        do { _ = try await fixture.run(action: .regenerate, input: "fictional prompt"); throw CheckFailure(description: "expected transport failure") }
        catch let error as CheckFailure { throw error }
        catch { try check((error as? URLError)?.code == code, "transport cancellation/error preserved") }
    }
    reset { _ in textReply("recovered") }
    let recovered = try await fixture.run(action: .refine, input: "fictional prompt")
    try check(recovered == "recovered", "subsequent operation recovers")
    try check(StubProtocol.requests.last?.timeoutInterval == 60, "inference timeout remains bounded")

    // Each actual provider must reach its documented endpoint with its own key.
    let contracts: [(String, String, String)] = [
        ("deepseek", "api.deepseek.com", "/chat/completions"), ("kimi", "api.moonshot.ai", "/v1/chat/completions"),
        ("minimax", "api.minimaxi.com", "/v1/chat/completions"), ("openai", "api.openai.com", "/v1/chat/completions"),
        ("anthropic", "api.anthropic.com", "/v1/messages"), ("google", "generativelanguage.googleapis.com", "/v1beta/openai/chat/completions"),
        ("xai", "api.x.ai", "/v1/chat/completions"), ("tencent", "tokenhub.tencentcloudmaas.com", "/v1/chat/completions"),
        ("baidu", "qianfan.baidubce.com", "/v2/chat/completions"), ("alibaba", "dashscope.aliyuncs.com", "/compatible-mode/v1/chat/completions"),
        ("bytedance", "ark.cn-beijing.volces.com", "/api/v3/chat/completions"), ("zhipu", "open.bigmodel.cn", "/api/paas/v4/chat/completions")
    ]
    for (id, host, path) in contracts {
        let provider = AIProvider.find(id)!
        reset { request in
            if request.httpMethod == "GET" {
                if provider.catalogDocument != nil {
                    try check(request.value(forHTTPHeaderField: "Authorization") == nil && request.value(forHTTPHeaderField: "x-api-key") == nil, "public catalog never receives credentials \(id)")
                    var reply = Reply([:]); reply.body = Data("# Models\n| `\(provider.initialModel)` | stable |\n| `\(provider.initialModel)-preview` | Preview |".utf8); return reply
                }
                return catalog([provider.initialModel])
            }
            try check(request.url?.host == host && request.url?.path == path, "provider endpoint \(id)")
            let payload = body(request)
            try check(payload["model"] as? String == provider.initialModel, "current model actually sent \(id)")
            if id == "anthropic" {
                try check(request.value(forHTTPHeaderField: "x-api-key") == "fictional-anthropic-key" && request.value(forHTTPHeaderField: "Authorization") == nil, "Anthropic native credential")
                try check(request.value(forHTTPHeaderField: "anthropic-version") == "2023-06-01", "Anthropic required version")
                try check(payload["system"] != nil && payload["max_tokens"] as? Int == 16384, "Messages request fields")
                return Reply(["content": [["type": "thinking", "thinking": "private reasoning"], ["type": "text", "text": "final text"]]])
            }
            try check(request.value(forHTTPHeaderField: "Authorization") == "Bearer fictional-\(id)-key", "independent provider credential \(id)")
            if ["deepseek", "kimi", "minimax", "openai"].contains(id) { try check(payload["reasoning_effort"] as? String == "low", "interactive effort \(id)") }
            if id == "alibaba" { try check(payload["enable_thinking"] as? Bool == false, "DashScope non-streaming hybrid model compatibility") }
            if id == "bytedance" { try check((payload["thinking"] as? [String: String])?["type"] == "disabled", "Doubao interactive text mode") }
            return textReply("final text")
        }
        let result = try await client(id).run(action: .refine, input: "fictional prompt")
        try check(result == "final text", "text output excludes thinking \(id)")
    }

    // The local subscription bridge uses the eligible Codex subscription and a
    // native Responses stream. It must never receive the API-key providers'
    // credential or reuse their Chat Completions payload.
    let codexSubscription = AIProvider.find(AIProvider.codexSubscriptionID)!
    try check(!codexSubscription.requiresAPIKey
               && codexSubscription.apiProtocol == .openAIResponses
               && codexSubscription.endpoints[0].url == URL(string: "http://127.0.0.1:3425/v1")!,
           "Codex subscription is a no-key local Responses provider")
    reset { request in
        if request.httpMethod == "GET" {
            try check(request.url?.path == "/v1/models", "subscription model directory path")
            try check(request.value(forHTTPHeaderField: "Authorization") == nil
                       && request.value(forHTTPHeaderField: "x-api-key") == nil,
                       "subscription model discovery never receives credentials")
            return catalog(["codex/gpt-6-astra", "codex/gpt-6.1-sol", "deepseek/deepseek-flash"])
        }
        try check(request.url?.path == "/v1/responses", "Codex subscription uses Responses API")
        try check(request.value(forHTTPHeaderField: "Authorization") == nil
                   && request.value(forHTTPHeaderField: "x-api-key") == nil,
                   "Codex subscription inference never receives credentials")
        try check(request.value(forHTTPHeaderField: "Accept") == "text/event-stream", "Responses stream header")
        let payload = body(request)
        try check(payload["model"] as? String == "codex/gpt-6.1-sol", "Codex model selected from its live directory")
        try check(payload["store"] as? Bool == false && payload["stream"] as? Bool == true,
                   "ChatGPT plan Responses payload is stateless and streaming")
        try check(payload["instructions"] as? String != nil, "Responses system instructions use the supported field")
        try check(payload["messages"] == nil && payload["temperature"] == nil
                   && payload["max_output_tokens"] == nil && payload["previous_response_id"] == nil,
                   "Responses payload omits Chat Completions and unsupported fields")
        let input = payload["input"] as? [[String: Any]]
        let content = input?.first?["content"] as? [[String: Any]]
        try check(content?.first?["type"] as? String == "input_text", "Responses input uses typed content")
        return sseReply([
            ["type": "response.output_text.delta", "delta": "final "],
            ["type": "response.output_text.delta", "delta": "text"],
            ["type": "response.output_text.done", "text": "final text"],
            ["type": "response.completed", "response": ["id": "resp_fixture"]]
        ])
    }
    let codexResult = try await client(AIProvider.codexSubscriptionID).run(action: .refine, input: "fictional prompt")
    try check(codexResult == "final text", "Responses SSE deltas combine into the final Prompt")

    // A local shared Chat Completions service forwards its supported low
    // reasoning effort instead of leaving the gateway on its slower default.
    let localKimi = AILocalSubscriptionService(
        owner: "kimi-work",
        displayName: "Kimi Work",
        providerID: "local-subscription-kimi-work",
        modelID: "kimi-work/k3d1-agent",
        usesResponsesAPI: false,
        chatReasoningEffort: "low"
    )
    let previousCatalog = UserDefaults.standard.data(forKey: "ai.local-subscriptions.catalog")
    AILocalSubscriptionCatalog.save([localKimi])
    defer {
        if let previousCatalog {
            UserDefaults.standard.set(previousCatalog, forKey: "ai.local-subscriptions.catalog")
        } else {
            UserDefaults.standard.removeObject(forKey: "ai.local-subscriptions.catalog")
        }
    }
    reset { request in
        try check(request.url?.path == "/v1/chat/completions", "local Kimi Work uses Chat Completions")
        try check(request.value(forHTTPHeaderField: "Authorization") == nil,
                  "local Kimi Work never receives an API credential")
        let payload = body(request)
        try check(payload["model"] as? String == localKimi.modelID, "local Kimi Work sends its discovered model")
        try check(payload["reasoning_effort"] as? String == "low",
                  "local Kimi Work requests its supported low reasoning effort")
        return textReply("local Kimi response")
    }
    let localKimiOption = OpenAIClient.ModelOption(
        id: localKimi.providerID,
        title: localKimi.displayName,
        model: localKimi.modelID,
        baseURL: AILocalSubscriptionCatalog.endpoint
    )
    let localKimiClient = OpenAIClient(
        apiKey: "",
        modelOption: localKimiOption,
        urlSession: session,
        modelResolver: ModelResolver(defaults: nil)
    )
    let localKimiResult = try await localKimiClient.run(action: .refine, input: "fictional local request")
    try check(localKimiResult == "local Kimi response", "local Kimi Work completes through the shared client")

    reset { request in
        if request.httpMethod == "GET" { return catalog(["codex/gpt-6.1-terra"]) }
        return sseReply([
            ["type": "response.output_text.done", "text": "completed without deltas"],
            ["type": "response.completed", "response": ["id": "resp_fixture"]]
        ])
    }
    let doneOnlyResult = try await client(AIProvider.codexSubscriptionID).run(action: .regenerate, input: "fictional prompt")
    try check(doneOnlyResult == "completed without deltas", "Responses done text is a valid non-delta fallback")

    // A partial stream must not replace the user's Prompt as a successful result.
    for terminal in [nil, "response.incomplete"] as [String?] {
        reset { request in
            if request.httpMethod == "GET" { return catalog(["codex/gpt-6.1-terra"]) }
            var events: [[String: Any]] = [["type": "response.output_text.delta", "delta": "unfinished Prompt"]]
            if let terminal {
                events.append(["type": terminal, "response": ["incomplete_details": ["reason": "max_output_tokens"]]])
            }
            return sseReply(events)
        }
        do {
            _ = try await client(AIProvider.codexSubscriptionID).run(action: .refine, input: "original Prompt")
            throw CheckFailure(description: "partial Responses stream must fail: \(terminal ?? "early end")")
        } catch let error as CheckFailure {
            throw error
        } catch {
            try check(error.localizedDescription.contains("未完整返回"), "partial Responses output exposes a retryable failure")
            try check(StubProtocol.requests.filter { $0.httpMethod == "POST" }.count == 1,
                      "an incomplete response never silently repeats inference")
        }
    }

    reset { request in
        if request.httpMethod == "GET" { return catalog(["codex/gpt-6.1-terra"]) }
        return sseReply([
            ["type": "response.output_text.delta", "delta": "partial"],
            ["type": "response.output_text.done", "text": "first block"],
            ["type": "response.completed", "response": ["output": [["content": [
                ["type": "output_text", "text": "first block"],
                ["type": "output_text", "text": "second block"]
            ]]]]]
        ])
    }
    let completedOutput = try await client(AIProvider.codexSubscriptionID).run(action: .regenerate, input: "fictional Prompt")
    try check(completedOutput == "first block\nsecond block", "completed response is authoritative over partial delta or a single done block")

    for operation in ["clarification", "template"] {
        reset { request in
            if request.httpMethod == "GET" { return catalog(["codex/gpt-6.1-terra"]) }
            return sseReply([["type": "response.output_text.delta", "delta": "unfinished output"]])
        }
        do {
            let subscription = client(AIProvider.codexSubscriptionID)
            if operation == "clarification" {
                _ = try await subscription.runClarification(session: ClarificationSession(originalQuery: "original Prompt"))
            } else {
                _ = try await subscription.generateTemplateDraft(from: "original Prompt")
            }
            throw CheckFailure(description: "incomplete stream must not produce a \(operation) result")
        } catch let error as CheckFailure {
            throw error
        } catch {
            try check(error.localizedDescription.contains("未完整返回"), "\(operation) propagates incomplete stream as a recoverable failure")
        }
    }

    reset { request in
        if request.httpMethod == "GET" { return catalog(["codex/gpt-6.1-sol"]) }
        return sseReply([
            ["type": "response.failed", "response": ["error": [
                "code": "subscription_unavailable",
                "message": "Codex subscription is unavailable"
            ]]]
        ])
    }
    do {
        _ = try await client(AIProvider.codexSubscriptionID).run(action: .regenerate, input: "fictional prompt")
        throw CheckFailure(description: "expected Responses failure event")
    } catch let error as CheckFailure {
        throw error
    } catch {
        try check(error.localizedDescription.contains("Codex subscription is unavailable"),
                  "Responses failure events preserve their actionable reason")
    }

    reset { request in
        if request.httpMethod == "GET" { return catalog(["gpt-6.1-terra"]) }
        return Reply(["error": [
            "code": "insufficient_quota",
            "message": "You have no credits remaining."
        ]], status: 429)
    }
    do {
        _ = try await client("openai").run(action: .refine, input: "fictional prompt")
        throw CheckFailure(description: "expected OpenAI quota failure")
    } catch let error as CheckFailure {
        throw error
    } catch {
        try check(error.localizedDescription.contains("订阅共享")
                  && error.localizedDescription.contains("Codex"),
                  "OpenAI API quota failure points to the subscription provider")
        try check(StubProtocol.requests.filter { $0.httpMethod == "POST" }.count == 1,
                  "quota failure never silently falls back to another provider")
    }

    // Future eligible versions win regardless of API order, while other tiers do not.
    let openai = AIProvider.find("openai")!
    try check(openai.select([.init(id: "gpt-6.2-terra"), .init(id: "gpt-6.10-terra"), .init(id: "gpt-99-astra"), .init(id: "gpt-8-terra-preview")]) == "gpt-6.10-terra", "numeric version comparison and efficiency tier")
    try check(openai.select([.init(id: "gpt-6-terra-2026-10-17"), .init(id: "gpt-6.1-terra")]) == "gpt-6.1-terra", "snapshot date never outranks a new minor version")
    try check(openai.select([.init(id: "gpt-8-terra", active: false), .init(id: "gpt-9-terra", textOutput: false), .init(id: "gpt-6-terra")]) == "gpt-6-terra", "retired/nontext metadata excluded")
    let claude = AIProvider.find("anthropic")!
    try check(claude.select([.init(id: "claude-haiku-7", line: "opus"), .init(id: "claude-haiku-6", line: "haiku")]) == "claude-haiku-6", "Anthropic line metadata controls tier")
    try check(claude.select([.init(id: "claude-haiku-5-20261017"), .init(id: "claude-haiku-5-5")]) == "claude-haiku-5-5", "Claude snapshot and version parsed independently")
    try check(AIProvider.find("kimi")!.select([.init(id: "kimi-k3.2-pro"), .init(id: "kimi-k4-pro-highspeed")]) == "kimi-k3.2-pro", "Kimi highspeed not selected")
    try check(AIProvider.find("minimax")!.select([.init(id: "MiniMax-M4-Flash"), .init(id: "MiniMax-M5-Pro")]) == "MiniMax-M4-Flash", "MiniMax Flash family")
    try check(AIProvider.find("bytedance")!.select([.init(id: "doubao-seed-2-1-lite-260915"), .init(id: "doubao-seed-2-1-lite-261020"), .init(id: "doubao-seed-3-0-pro-261021")]) == "doubao-seed-2-1-lite-261020", "Doubao snapshot replacement within Lite")
    let document = "# Current\n| GLM-5.4-Flash | stable |\n| GLM-8-Flash | Preview |\n## Preview\nGLM-9-Flash\n# Current again\nGLM-5.5-Flash\nGLM-9-FlashX"
    try check(AIProvider.find("zhipu")!.select(ModelResolver.documentCandidates(document)) == "glm-5.5-flash", "official document filters preview rows and sections")
    try check(ModelResolver.candidate(["name": "models/gemini-3.5-flash-lite", "supportedGenerationMethods": ["embedContent"]])?.textOutput == false, "Gemini capability parsing")

    // Cache is per provider/endpoint, expires, and persists only nonsecret metadata.
    var simulatedTime = Date()
    let suite = "local.talis.network-tests.\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    let resolver = ModelResolver(defaults: preferences, now: { simulatedTime })
    var listedModel = "gpt-6.1-terra"
    reset { request in request.httpMethod == "GET" ? catalog([listedModel]) : textReply(body(request)["model"] as? String ?? "missing") }
    let cachedClient = client("openai", resolver: resolver)
    let first = try await cachedClient.run(action: .refine, input: "first")
    listedModel = "gpt-6.2-terra"
    let cached = try await cachedClient.run(action: .refine, input: "second")
    try check(first == "gpt-6.1-terra" && cached == first && StubProtocol.requests.filter { $0.httpMethod == "GET" }.count == 1, "cached selection avoids repeated discovery")
    simulatedTime += 25 * 60 * 60
    let refreshed = try await cachedClient.run(action: .refine, input: "third")
    try check(refreshed == "gpt-6.2-terra", "expired cache follows new version automatically")
    let stored = preferences.data(forKey: "ai.resolved-models.v1")!
    try check(!String(decoding: stored, as: UTF8.self).contains("fictional-openai-key"), "key never enters persistent cache")
    let restarted = ModelResolver(defaults: preferences, now: { simulatedTime })
    let restart = try await client("openai", resolver: restarted).run(action: .refine, input: "restart")
    try check(restart == refreshed && StubProtocol.requests.filter { $0.httpMethod == "GET" }.count == 2, "restart retains fresh nonsecret cache")
    _ = try await client("openai", resolver: resolver, base: URL(string: "https://proxy.talis.invalid/v1")!).run(action: .refine, input: "other endpoint")
    try check(StubProtocol.requests.filter { $0.httpMethod == "GET" }.count == 3, "endpoint cache isolation")
    await resolver.invalidate(providerID: "openai")
    _ = try await cachedClient.run(action: .refine, input: "changed key")
    try check(StubProtocol.requests.filter { $0.httpMethod == "GET" }.count == 4, "key/endpoint save invalidates cache")

    // An update from Luna to Terra must not reuse yesterday's family, even
    // when its cache is fresh and the model directory is temporarily down.
    let oldFamilySuite = "local.talis.old-family-tests.\(UUID().uuidString)"
    let oldFamilyPreferences = UserDefaults(suiteName: oldFamilySuite)!
    defer { oldFamilyPreferences.removePersistentDomain(forName: oldFamilySuite) }
    oldFamilyPreferences.set(try JSONSerialization.data(withJSONObject: [
        "openai|https://api.openai.com/v1": [
            "model": "gpt-6-luna", "attemptedAt": Date().timeIntervalSinceReferenceDate
        ]
    ]), forKey: "ai.resolved-models.v1")
    reset { request in request.httpMethod == "GET" ? Reply([:], status: 503) : textReply(body(request)["model"] as? String ?? "missing") }
    let updatedFamily = try await client("openai", resolver: ModelResolver(defaults: oldFamilyPreferences)).run(action: .refine, input: "fictional family update")
    try check(updatedFamily == "gpt-6.1-terra", "old Luna cache cannot override Terra when discovery fails")
    try check(openai.select([.init(id: "gpt-99-luna"), .init(id: "gpt-6.1-terra")]) == "gpt-6.1-terra", "other model families cannot replace Terra")

    // A directory failure or irrelevant model list retains the current working default.
    for directory in [Reply([:], status: 503), catalog(["gpt-image-99", "gpt-9-terra-preview"])] {
        reset { request in request.httpMethod == "GET" ? directory : textReply(body(request)["model"] as? String ?? "missing") }
        let fallback = try await client("openai").run(action: .refine, input: "fictional prompt")
        try check(fallback == "gpt-6.1-terra", "directory failure/empty eligible list keeps default")
    }

    // Later pages participate; a model can be missed if only the first page is used.
    reset { request in
        if request.httpMethod == "GET" {
            if request.url?.query == nil { return Reply(["data": [["id": "claude-haiku-5-5", "line": "haiku"]], "has_more": true, "last_id": "claude-haiku-5-5"]) }
            try check(request.url!.query!.contains("after_id=claude-haiku-5-5"), "Anthropic pagination cursor")
            return Reply(["data": [["id": "claude-haiku-6-1", "line": "haiku"]], "has_more": false])
        }
        return Reply(["content": [["type": "text", "text": body(request)["model"]!]]])
    }
    let paged = try await client("anthropic").run(action: .refine, input: "fictional prompt")
    try check(paged == "claude-haiku-6-1", "latest candidate found on later page")

    // Only explicit model retirement triggers one refresh and one retry.
    var directoryReads = 0
    var inferenceCalls = 0
    reset { request in
        if request.httpMethod == "GET" { directoryReads += 1; return catalog([directoryReads == 1 ? "gpt-6-terra" : "gpt-6.2-terra"]) }
        inferenceCalls += 1
        if inferenceCalls == 1 { return Reply(["error": ["code": "model_not_found", "message": "Unavailable"]], status: 404) }
        return textReply(body(request)["model"] as! String)
    }
    let replacement = try await client("openai").run(action: .refine, input: "fictional prompt")
    try check(replacement == "gpt-6.2-terra" && directoryReads == 2 && inferenceCalls == 2, "one automatic same-provider replacement")

    // A recovered rolling alias must not fail again on every subsequent action.
    reset { request in
        if request.httpMethod == "GET" { return catalog(["deepseek-v99.1-flash"]) }
        let model = body(request)["model"] as! String
        if model == "deepseek-flash" { return Reply(["error": ["code": "model_retired", "message": "Model retired"]], status: 410) }
        return textReply(model)
    }
    let rollingResolver = ModelResolver(defaults: preferences, now: { simulatedTime })
    let rollingClient = client("deepseek", resolver: rollingResolver)
    let firstRecovered = try await rollingClient.run(action: .refine, input: "fictional first action")
    let nextRecovered = try await rollingClient.run(action: .regenerate, input: "fictional next action")
    try check(firstRecovered == "deepseek-v99.1-flash" && nextRecovered == firstRecovered, "recovered rolling model remains available to the next action")
    try check(StubProtocol.requests.filter { $0.httpMethod == "POST" }.count == 3, "next action reuses replacement without retrying the retired alias")
    let restartedRolling = ModelResolver(defaults: preferences, now: { simulatedTime })
    _ = try await client("deepseek", resolver: restartedRolling).run(action: .refine, input: "fictional restart")
    try check(StubProtocol.requests.filter { $0.httpMethod == "GET" }.count == 1 && StubProtocol.requests.filter { $0.httpMethod == "POST" }.count == 4, "restart preserves the recovered rolling selection")
    simulatedTime += 25 * 60 * 60
    _ = try await rollingClient.run(action: .refine, input: "fictional expired recovery cache")
    try check(StubProtocol.requests.filter { $0.httpMethod == "GET" }.count == 2 && StubProtocol.requests.filter { $0.httpMethod == "POST" }.count == 6, "expired recovery cache tries the rolling alias again and can refresh its replacement")

    reset { request in
        if request.httpMethod == "GET" { throw URLError(.cancelled) }
        return Reply(["error": ["code": "model_retired", "message": "Model retired"]], status: 410)
    }
    do {
        _ = try await client("deepseek").run(action: .refine, input: "fictional cancellation during recovery")
        throw CheckFailure(description: "expected recovery cancellation")
    } catch let error as CheckFailure { throw error }
    catch { try check((error as? URLError)?.code == .cancelled, "cancellation during model recovery is not replaced by the earlier model error") }
    for status in [401, 403, 429, 500, 404] {
        reset { request in request.httpMethod == "GET" ? catalog(["gpt-6-terra"]) : Reply(["error": ["message": status == 404 ? "Endpoint not found" : "Access denied"]], status: status) }
        do { _ = try await client("openai").run(action: .refine, input: "fictional prompt"); throw CheckFailure(description: "expected service failure") }
        catch let error as CheckFailure { throw error }
        catch { try check(StubProtocol.requests.filter { $0.httpMethod == "POST" }.count == 1, "no model retry for unrelated failure \(status)") }
    }

    // Placeholder syntax is optional; neither request nor response is silently rewritten.
    for literal in ["  普通正文\n  ", " 【内容】::【目:标：】\n "] {
        reset { request in
            let messages = body(request)["messages"] as! [[String: String]]
            try check(messages.last?["content"] == "待处理内容：\n" + literal, "request preserves literal user text and outer whitespace")
            return textReply(literal)
        }
        let output = try await client("deepseek").run(action: .refine, input: literal)
        try check(output == literal, "model text returns with its exact punctuation and whitespace")
        reset { _ in
            let data = try! JSONSerialization.data(withJSONObject: ["title":"模板", "detail":"说明", "body":literal])
            return textReply(String(data:data,encoding:.utf8)!)
        }
        let draft = try await client("deepseek").generateTemplateDraft(from: "提取模板")
        try check(draft.body == literal, "template extraction neither forces a field nor renames or normalizes one")
    }
    reset { _ in textReply("{\"status\":\"final\",\"prompt\":\"没有占位符的新结果\"}") }
    let freeFinal = try await client("deepseek").runClarification(session: ClarificationSession(originalQuery: "【可删除】："))
    try check(freeFinal == .final("没有占位符的新结果"), "clarification does not restore removed fields")

    reset { _ in textReply("结果") }
    let literalHistory = "  【历史】::\n\t "
    _ = try await client("deepseek").run(action: .refine, input: "当前正文", context: [.init(actionTitle: "微调", query: literalHistory, result: literalHistory)])
    let historyMessages = body(StubProtocol.requests.last!)["messages"] as! [[String: String]]
    try check(historyMessages.last!["content"]!.contains(literalHistory), "model history context preserves literal text below its declared size limit")

    // All existing operations pass through the same rolling model and preserve context.
    reset { request in
        let payload = body(request)
        try check(payload["model"] as? String == "deepseek-flash", "all operations use formal rolling alias")
        let messages = payload["messages"] as! [[String: String]]
        if messages[0]["content"]!.contains("JSON") {
            if messages[0]["content"]!.contains("模板提取") { return textReply("{\"title\":\"测试模板\",\"detail\":\"测试说明\",\"body\":\"处理【用户输入目标】\"}") }
            return textReply("{\"status\":\"final\",\"prompt\":\"完成用户目标\"}")
        }
        try check(messages[1]["content"]!.contains("previous query"), "existing context retained in production request")
        return textReply("refined")
    }
    let shared = client("deepseek")
    _ = try await shared.run(action: .refine, input: "new query", context: [.init(actionTitle: "AI 微调", query: "previous query", result: "previous result")])
    _ = try await shared.generateTemplateDraft(from: "fictional template")
    let decision = try await shared.runClarification(session: ClarificationSession(originalQuery: "fictional goal"))
    try check(decision == .final("完成用户目标"), "clarification JSON contract preserved")
    try check(StubProtocol.requests.count == 3 && StubProtocol.requests.allSatisfy { $0.httpMethod == "POST" }, "rolling alias requires no discovery or extra calls")

    AppLocalization.preference = .english
    reset { _ in textReply("English result") }
    _ = try await fixture.run(action: .refine, input: "中文输入必须保留事实")
    let englishMessages = body(StubProtocol.requests.last!)["messages"] as? [[String: String]]
    let englishSystem = englishMessages?.first?["content"] ?? ""
    let englishUser = englishMessages?.last?["content"] ?? ""
    try check(englishSystem.contains("English")
               && englishSystem.contains(ClarificationPromptBuilder.contentLanguageInstruction(.english)),
              "English app language overrides Chinese input for Refine and Rewrite")
    try check(englishUser.contains("中文输入必须保留事实"), "language forcing does not discard the user's source text")

    reset { _ in textReply("{\"status\":\"final\",\"prompt\":\"English final prompt\"}") }
    _ = try await fixture.runClarification(session: ClarificationSession(originalQuery: "中文原始需求"))
    let englishClarificationMessages = body(StubProtocol.requests.last!)["messages"] as? [[String: String]]
    let englishClarificationSystem = englishClarificationMessages?.first?["content"] ?? ""
    try check(englishClarificationSystem.contains("English")
               && englishClarificationSystem.contains("final Prompt"),
              "English app language forces the Grill-me final Prompt to English")
    AppLocalization.preference = .simplifiedChinese
}

var completed = false
var failure: String?
Task {
    do { try await runChecks() }
    catch { failure = String(describing: error) }
    completed = true
}
let deadline = Date().addingTimeInterval(25)
while !completed && Date() < deadline { RunLoop.current.run(until: Date().addingTimeInterval(0.01)) }
guard completed, failure == nil else { fputs("FAIL: \(failure ?? "timeout")\n", stderr); exit(1) }
print("PASS: \(checks) provider, model discovery, cache, request, failure recovery and operation checks; all HTTP intercepted, fictional keys only")
