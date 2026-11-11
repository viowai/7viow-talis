import Foundation
import TalisCore

enum AIAction {
    case refine
    case regenerate

    var runningTitle: String {
        switch self {
        case .refine: return L("正在微调…")
        case .regenerate: return L("正在重构…")
        }
    }

    var completedTitle: String {
        switch self {
        case .refine: return L("微调已完成")
        case .regenerate: return L("重构已完成")
        }
    }

    var failureTitle: String {
        switch self {
        case .refine: return L("微调失败")
        case .regenerate: return L("重构失败")
        }
    }

    var buttonTitle: String {
        switch self {
        case .refine: return L("微调")
        case .regenerate: return L("重构")
        }
    }

    var instruction: String {
        switch self {
        case .refine:
            return """
            你是一个资深 Prompt 编辑专家。请在不改变用户核心意图的前提下，对下面的 Prompt 做精细微调。

            要求：
            1. 保留原意和关键内容；【】是普通文本标记，可按用户要求修改或删除，不能强制保留其名称、数量或标点。
            2. 补强角色、目标、约束、输出格式和质量标准。
            3. 删除含糊、重复、空泛的表达。
            4. 只输出优化后的 Prompt，不要输出解释。
            """
        case .regenerate:
            return """
            你是一个结构化 Prompt 生成专家。请基于用户当前内容，重新生成一版更完整、更清晰、更可执行的 Prompt。

            要求：
            1. 可以重组结构，但必须保留用户原始意图。
            2. 使用清晰标题、分段、列表和输出格式。
            3. 需要表达待补信息时可以使用【占位符】；是否使用、名称和标点按当前需求决定，不要求每份Prompt都包含占位符。
            4. 只输出重新生成后的 Prompt，不要输出解释。
            """
        }
    }
}

struct AIContextTurn {
    let actionTitle: String
    let query: String
    let result: String
}

struct OpenAIClient {
    struct ModelOption: Equatable {
        let id: String
        let titleKey: String
        let model: String
        let baseURL: URL

        var title: String { L(titleKey) }

        init(id: String, title: String, model: String, baseURL: URL) {
            self.id = id
            self.titleKey = title
            self.model = model
            self.baseURL = baseURL
        }
    }

    static let modelOptions: [ModelOption] = AIProvider.all.map {
        ModelOption(id: $0.id, title: $0.nameKey, model: $0.initialModel, baseURL: $0.endpoints[0].url)
    }

    static let defaultModelID = "deepseek"

    static func modelOption(for id: String) -> ModelOption {
        modelOptions.first { $0.id == id } ?? modelOptions[0]
    }

    let apiKey: String
    let modelOption: ModelOption
    let urlSession: URLSession
    let modelResolver: ModelResolver
    let operationTimeout: TimeInterval

    init(apiKey: String, modelOption: ModelOption, urlSession: URLSession = .shared, modelResolver: ModelResolver = .shared, operationTimeout: TimeInterval = 90) {
        self.apiKey = apiKey
        self.modelOption = modelOption
        self.urlSession = urlSession
        self.modelResolver = modelResolver
        self.operationTimeout = operationTimeout
    }

    func run(action: AIAction, input: String, context: [AIContextTurn] = []) async throws -> String {
        let sourceInput = input
        guard !sourceInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIClientError.emptyInput
        }

        let responseLanguage: TalisContentLanguage = AppLocalization.isEnglish
            ? .english
            : .simplifiedChinese
        let text = try await send(
            system: action.instruction + "\n\n" + ClarificationPromptBuilder.contentLanguageInstruction(responseLanguage),
            user: Self.contextualUserContent(input: sourceInput, context: context)
        )
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIClientError.emptyResponse
        }
        return text
    }

    func runClarification(session: ClarificationSession) async throws -> ClarificationDecision {
        try await withDeadline { try await self.clarificationDecision(session: session) }
    }

    private func clarificationDecision(session: ClarificationSession) async throws -> ClarificationDecision {
        guard !session.originalQuery.isEmpty else {
            throw AIClientError.emptyInput
        }

        let responseLanguage: TalisContentLanguage = AppLocalization.isEnglish ? .english : .simplifiedChinese
        let text = try await sendWithoutDeadline(
            system: ClarificationPromptBuilder.systemInstruction(
                forceFinal: session.mustGenerateFinal,
                responseLanguage: responseLanguage
            ),
            user: session.requestContent()
        )
        guard let decision = ClarificationResponseParser.parse(text) else {
            throw AIClientError.invalidClarificationResponse
        }

        if session.mustGenerateFinal, case .ask = decision {
            let retryReminder = responseLanguage == .english
                ? "The previous response incorrectly continued asking questions. Return the final Prompt now with status final."
                : "上一次响应错误地继续提问。请立即返回 status 为 final 的最终 Prompt。"
            let retryText = try await sendWithoutDeadline(
                system: ClarificationPromptBuilder.systemInstruction(
                    forceFinal: true,
                    responseLanguage: responseLanguage
                ),
                user: session.requestContent() + "\n\n" + retryReminder
            )
            guard let retryDecision = ClarificationResponseParser.parse(retryText), case .final = retryDecision else {
                throw AIClientError.invalidClarificationResponse
            }
            return try await validatedFinalDecision(retryDecision, session: session)
        }

        if case .final = decision {
            return try await validatedFinalDecision(decision, session: session)
        }
        return decision
    }

    private func validatedFinalDecision(
        _ decision: ClarificationDecision,
        session: ClarificationSession
    ) async throws -> ClarificationDecision {
        guard case .final(let prompt) = decision else {
            throw AIClientError.invalidClarificationResponse
        }

        let finalPrompt = prompt
        if PromptStructureIntegrity.preservesMarkdownBlockStructure(
            original: session.originalQuery,
            generated: finalPrompt
        ) {
            return .final(finalPrompt)
        }

        let repairText = try await sendWithoutDeadline(
            system: ClarificationPromptBuilder.structureRepairInstruction(
                responseLanguage: AppLocalization.isEnglish ? .english : .simplifiedChinese
            ),
            user: session.structureRepairContent(rejectedPrompt: prompt)
        )
        guard let repairDecision = ClarificationResponseParser.parse(repairText),
              case .final(let repairedPrompt) = repairDecision else {
            throw AIClientError.invalidClarificationStructure
        }

        let finalRepair = repairedPrompt
        guard PromptStructureIntegrity.preservesMarkdownBlockStructure(
            original: session.originalQuery,
            generated: finalRepair
        ) else {
            throw AIClientError.invalidClarificationStructure
        }
        return .final(finalRepair)
    }

    func generateTemplateDraft(from input: String) async throws -> TemplateDraft {
        let sourceInput = input
        guard !sourceInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIClientError.emptyInput
        }

        let responseLanguage: TalisContentLanguage = AppLocalization.isEnglish
            ? .english
            : .simplifiedChinese
        let titleLimit = responseLanguage == .english ? "不超过 8 个英文单词" : "不超过 18 个汉字"
        let detailLimit = responseLanguage == .english ? "不超过 20 个英文单词" : "不超过 40 个汉字"
        let system = """
        你是一位资深的 Prompt 模板提取与优化专家。请严格遵循以下要求，对用户提供的原始需求进行加工，输出一个可直接复用的 prompt 模板。

        目标：生成结构清晰、占位符明确的 prompt 模板，确保用户只需填入具体内容即可复用。

        约束与流程：
        1. 根据用户输入，提取通用逻辑与框架，剔除用户特定细节，形成模板骨架。
        2. 有待补信息时，可在合适位置使用清楚的【事项名称】标记；已有具体信息或无需填写的模板不必包含占位符，不强制其标点。
        3. 标记措辞应结合具体任务；尊重用户指定的文字，不强制重命名已有标记。
        4. 最终 body 必须是可直接复用的 prompt 模板正文，不要把分析过程、说明、确认话术、JSON 字段说明写进 body。
        5. 保存前确认由应用的预览弹窗完成，因此 body 中不要包含“请确认以上模板是否符合您的预期？”等确认语句。

        为了让应用保存模板，请只输出一个 JSON 对象，不要 Markdown，不要解释，不要代码块。
        JSON 结构必须严格为：
        {"title":"模板名称","detail":"一句话说明","body":"经优化后的可复用 prompt 模板"}

        字段要求：
        - title：清晰、短促、可复用的模板名称，\(titleLimit)。
        - detail：一句话总结模板用途和适用场景，\(detailLimit)。
        - body：直接输出经优化后的 prompt 模板，无需额外说明或标记。

        \(ClarificationPromptBuilder.contentLanguageInstruction(responseLanguage))
        """

        let text = try await send(system: system, user: "原始 Prompt：\n\(sourceInput)")
        if let draft = Self.extractTemplateDraft(from: text) {
            return Self.normalizedTemplateDraft(draft, originalInput: sourceInput)
        }
        return Self.normalizedTemplateDraft(TemplateDraft(
            title: L("我的 Prompt 模板"),
            detail: L("从当前 Prompt 自动生成"),
            body: text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? sourceInput : text
        ), originalInput: sourceInput)
    }

    private func withDeadline<T: Sendable>(_ operation: @escaping @Sendable () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(self.operationTimeout * 1_000_000_000))
                throw URLError(.timedOut)
            }
            defer { group.cancelAll() }
            return try await group.next()!
        }
    }

    private func send(system: String, user: String) async throws -> String {
        try await withDeadline { try await self.sendWithoutDeadline(system: system, user: user) }
    }

    private func sendWithoutDeadline(system: String, user: String) async throws -> String {
        let model = try await modelResolver.resolve(option: modelOption, apiKey: apiKey, session: urlSession)
        do {
            return try await send(model: model, system: system, user: user)
        } catch let failure as AIHTTPFailure {
            if failure.isUnavailableModel {
                let replacement: String?
                do {
                    replacement = try await modelResolver.resolve(option: modelOption, apiKey: apiKey, session: urlSession, excluding: model)
                } catch {
                    if Task.isCancelled || error is CancellationError || (error as? URLError)?.code == .cancelled { throw error }
                    replacement = nil
                }
                if let replacement, replacement != model {
                    do { return try await send(model: replacement, system: system, user: user) }
                    catch let retry as AIHTTPFailure { throw AIClientError.requestFailed(retry.message) }
                }
            }
            throw AIClientError.requestFailed(failure.message)
        }
    }

    private func send(model: String, system: String, user: String) async throws -> String {
        let provider = AIProvider.find(modelOption.id)
        let anthropic = provider?.apiProtocol == .anthropicMessages
        let responses = provider?.apiProtocol == .openAIResponses
        let endpoint = anthropic ? "messages" : responses ? "responses" : "chat/completions"
        var request = URLRequest(url: modelOption.baseURL.appendingPathComponent(endpoint))
        request.httpMethod = "POST"
        ModelResolver.authorize(&request, provider: provider, apiKey: apiKey)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if responses { request.setValue("text/event-stream", forHTTPHeaderField: "Accept") }
        request.timeoutInterval = 60

        var payload: [String: Any]
        if responses {
            payload = [
                "model": model,
                "instructions": system,
                "input": [[
                    "role": "user",
                    "content": [["type": "input_text", "text": user]]
                ]],
                "reasoning": ["effort": "low"],
                "store": false,
                "stream": true
            ]
        } else {
            payload = [
                "model": model,
                "messages": [
                    ["role": "system", "content": system],
                    ["role": "user", "content": user]
                ],
                "stream": false
            ]
        }
        if anthropic {
            payload["system"] = system
            payload["messages"] = [["role": "user", "content": user]]
            payload["max_tokens"] = 16384
            payload["output_config"] = ["effort": "low"]
        } else if !responses, let effort = provider?.chatReasoningEffort {
            payload["reasoning_effort"] = effort
        } else if modelOption.id == "alibaba" {
            // DashScope's hybrid-thinking models require this for non-streaming.
            payload["enable_thinking"] = false
        } else if modelOption.id == "bytedance" {
            payload["thinking"] = ["type": "disabled"]
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        if responses {
            return try await sendResponsesStream(request: request)
        }
        let (data, response) = try await urlSession.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, !(200..<300).contains(httpResponse.statusCode) {
            throw httpFailure(data: data, status: httpResponse.statusCode)
        }

        guard let text = Self.extractOutputText(from: data) else {
            throw AIClientError.emptyResponse
        }
        return text
    }

    private func sendResponsesStream(request: URLRequest) async throws -> String {
        let (bytes, response) = try await urlSession.bytes(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ModelDiscoveryError.invalidResponse
        }
        if !(200..<300).contains(httpResponse.statusCode) {
            var data = Data()
            for try await byte in bytes {
                data.append(byte)
            }
            throw httpFailure(data: data, status: httpResponse.statusCode)
        }

        var deltaText = ""
        var doneText: String?
        for try await line in bytes.lines {
            try Task.checkCancellation()
            guard line.hasPrefix("data:") else { continue }
            let raw = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
            if raw == "[DONE]" { break }
            guard let data = raw.data(using: .utf8),
                  let event = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = event["type"] as? String else { continue }
            switch type {
            case "response.output_text.delta":
                if let delta = event["delta"] as? String { deltaText += delta }
            case "response.output_text.done":
                doneText = event["text"] as? String
            case "response.completed":
                if let response = event["response"] as? [String: Any],
                   let data = try? JSONSerialization.data(withJSONObject: response) {
                    doneText = Self.extractOutputText(from: data) ?? doneText
                }
                let text = doneText ?? deltaText
                guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw AIClientError.emptyResponse
                }
                return text
            case "response.incomplete":
                throw AIClientError.incompleteResponse
            case "response.failed", "error":
                let response = event["response"] as? [String: Any]
                let error = response?["error"] as? [String: Any] ?? event["error"] as? [String: Any]
                let message = error?["message"] as? String ?? event["message"] as? String
                    ?? AppLocalization.format("%@ 请求失败。", modelOption.title)
                let code = error?["code"] as? String ?? event["code"] as? String ?? "response_failed"
                throw AIHTTPFailure(status: httpResponse.statusCode, message: userFacingError(message: message, code: code), code: code)
            default:
                continue
            }
        }
        throw AIClientError.incompleteResponse
    }

    private func httpFailure(data: Data, status: Int) -> AIHTTPFailure {
        let rawMessage = Self.extractErrorMessage(from: data) ?? AppLocalization.format("%@ 请求失败：HTTP %@", modelOption.title, status)
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        let code = (json?["error"] as? [String: Any])?["code"] as? String ?? ""
        return AIHTTPFailure(
            status: status,
            message: userFacingError(message: rawMessage, code: code),
            code: code
        )
    }

    private func userFacingError(message: String, code: String) -> String {
        let lowerMessage = message.lowercased()
        let lowerCode = code.lowercased()
        if modelOption.id == "openai",
           lowerCode == "insufficient_quota"
            || lowerMessage.contains("no credits remaining")
            || lowerMessage.contains("insufficient_quota") {
            return L("OpenAI API 余额已用尽。请改用“订阅共享”中的 Codex，或为 OpenAI API 充值。")
        }
        if modelOption.id == AIProvider.codexSubscriptionID,
           lowerMessage.contains("plan isn't eligible") || lowerMessage.contains("plan isn’t eligible") {
            return L("当前 ChatGPT 账号的 Codex 订阅不可用于此请求。请检查登录与套餐。")
        }
        guard !apiKey.isEmpty else { return message }
        return message.replacingOccurrences(of: apiKey, with: L("[密钥已隐藏]"))
    }

    func requestErrorMessage(for error: NSError) -> String {
        guard error.domain == NSURLErrorDomain else { return error.localizedDescription }
        let code = URLError.Code(rawValue: error.code)
        switch code {
        case .timedOut:
            return L("等待超时，请重试。")
        case .networkConnectionLost:
            return L("网络连接中断，请重试。")
        case .notConnectedToInternet:
            return L("网络未连接，请连接后重试。")
        case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
            if modelOption.id == AIProvider.codexSubscriptionID {
                return L("Codex 订阅当前不可用。请确认已登录 Codex 订阅。")
            }
            if AIProvider.find(modelOption.id)?.requiresAPIKey == false {
                return L("本机共享服务当前不可用。请确认服务已登录且本地共享网关正在运行。")
            }
            return L("无法连接 AI 服务，请稍后重试。")
        case .secureConnectionFailed:
            return L("TLS 安全连接未能建立，请重试。")
        case .serverCertificateUntrusted, .serverCertificateHasBadDate, .serverCertificateNotYetValid,
             .serverCertificateHasUnknownRoot, .clientCertificateRejected, .clientCertificateRequired:
            return L("AI 服务的证书无法验证，请检查网络或代理设置。")
        case .dataNotAllowed:
            return L("当前网络限制 AI 请求，请切换网络后重试。")
        default:
            return error.localizedDescription
        }
    }

    private static func contextualUserContent(input: String, context: [AIContextTurn]) -> String {
        let recentContext = Array(context.suffix(3))
        guard !recentContext.isEmpty else {
            return "待处理内容：\n\(input)"
        }

        let contextText = recentContext.enumerated().map { index, turn in
            """
            第 \(index + 1) 轮
            操作：\(turn.actionTitle)
            用户查询：
            \(truncatedContextText(turn.query))
            模型结果：
            \(truncatedContextText(turn.result))
            """
        }.joined(separator: "\n\n---\n\n")

        return """
        以下是最近最多 3 轮历史上下文。请只在它能提升当前任务连贯性和准确性时参考，不要机械复述历史结果。

        \(contextText)

        当前待处理内容：
        \(input)
        """
    }

    private static func truncatedContextText(_ value: String, limit: Int = 2400) -> String {
        guard value.count > limit else { return value }
        return String(value.prefix(limit)) + "\n...（已截断）"
    }

    private static func extractOutputText(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if let outputText = json["output_text"] as? String {
            return outputText
        }
        if let content = json["content"] as? [[String: Any]] {
            let text = content.filter { $0["type"] as? String == "text" }.compactMap { $0["text"] as? String }
            if !text.isEmpty { return text.joined(separator: "\n") }
        }
        if
            let choices = json["choices"] as? [[String: Any]],
            let first = choices.first,
            let message = first["message"] as? [String: Any],
            let content = message["content"] as? String
        {
            return content
        }
        guard let output = json["output"] as? [[String: Any]] else { return nil }
        let chunks = output.flatMap { item -> [String] in
            guard let content = item["content"] as? [[String: Any]] else { return [] }
            return content.compactMap { part in
                if let text = part["text"] as? String { return text }
                if let text = part["output_text"] as? String { return text }
                return nil
            }
        }
        return chunks.isEmpty ? nil : chunks.joined(separator: "\n")
    }

    private static func extractErrorMessage(from data: Data) -> String? {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let error = json["error"] as? [String: Any]
        else { return nil }
        return error["message"] as? String
    }

    private static func extractTemplateDraft(from text: String) -> TemplateDraft? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let jsonText: String
        if let start = trimmed.firstIndex(of: "{"), let end = trimmed.lastIndex(of: "}"), start <= end {
            jsonText = String(trimmed[start...end])
        } else {
            jsonText = trimmed
        }
        guard
            let data = jsonText.data(using: .utf8),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let title = object["title"] as? String,
            let body = object["body"] as? String
        else { return nil }
        let detail = object["detail"] as? String ?? L("个人模板")
        return TemplateDraft(title: title, detail: detail, body: body)
    }

    private static func normalizedTemplateDraft(_ draft: TemplateDraft, originalInput: String) -> TemplateDraft {
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? L("我的 Prompt 模板")
            : draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let detail = draft.detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? L("从当前 Prompt 自动生成")
            : draft.detail.trimmingCharacters(in: .whitespacesAndNewlines)
        var body = draft.body
        if body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            body = originalInput
        }


        return TemplateDraft(title: title, detail: detail, body: body)
    }


}

private struct AIHTTPFailure: Error {
    let status: Int
    let message: String
    let code: String

    var isUnavailableModel: Bool {
        guard [400, 404, 410].contains(status) else { return false }
        if ["model_not_found", "model_not_exist", "model_retired", "model_deprecated"].contains(code.lowercased()) { return true }
        let lower = message.lowercased()
        return (lower.contains("model") || lower.contains("模型")) &&
            ["not found", "does not exist", "model_not_found", "model_not_exist", "retired", "decommissioned", "不再提供", "不存在", "已下线", "已停用"].contains(where: lower.contains)
    }
}

enum AIClientError: LocalizedError {
    case emptyInput
    case emptyResponse
    case incompleteResponse
    case missingAPIKey
    case invalidClarificationResponse
    case invalidClarificationStructure
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .emptyInput:
            return L("请先输入需求或插入模板。")
        case .emptyResponse:
            return L("模型没有返回可用内容。")
        case .incompleteResponse:
            return L("模型结果未完整返回，请重试。")
        case .missingAPIKey:
            return L("请先在“设置”的 AI 服务中填写所选厂商的 API Key。")
        case .invalidClarificationResponse:
            return L("模型返回的追问格式不可用，请重试。")
        case .invalidClarificationStructure:
            return L("模型返回的结果没有保留原有标题或列表结构。原文和追问记录已保留，请重试。")
        case .requestFailed(let message):
            return message
        }
    }
}
