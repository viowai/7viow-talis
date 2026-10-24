import Foundation
import TalisCore

enum AIAction {
    case refine
    case regenerate

    var buttonTitle: String {
        switch self {
        case .refine: return "AI 微调"
        case .regenerate: return "重新生成"
        }
    }

    var instruction: String {
        switch self {
        case .refine:
            return """
            你是一个资深 Prompt 编辑专家。请在不改变用户核心意图的前提下，对下面的 Prompt 做精细微调。

            要求：
            1. 保留原有结构和关键占位符，尤其是所有形如【占位符】的内容。
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
            3. 必要时补充【占位符】，方便用户继续填写。
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
        let title: String
        let model: String
        let baseURL: URL
    }

    static let modelOptions: [ModelOption] = [
        ModelOption(
            id: "deepseek",
            title: "DeepSeek - deepseek-v4-flash",
            model: "deepseek-v4-flash",
            baseURL: URL(string: "https://api.deepseek.com")!
        ),
        ModelOption(
            id: "kimi",
            title: "Kimi - kimi-k2.6",
            model: "kimi-k2.6",
            baseURL: URL(string: "https://api.moonshot.ai/v1")!
        ),
        ModelOption(
            id: "minimax",
            title: "MiniMax - MiniMax-M3",
            model: "MiniMax-M3",
            baseURL: URL(string: "https://api.minimaxi.com/v1")!
        ),
        ModelOption(
            id: "openai",
            title: "OpenAI - gpt-4.1-mini",
            model: "gpt-4.1-mini",
            baseURL: URL(string: "https://api.openai.com/v1")!
        )
    ]

    static let defaultModelID = "deepseek"

    static func modelOption(for id: String) -> ModelOption {
        modelOptions.first { $0.id == id } ?? modelOptions[0]
    }

    let apiKey: String
    let modelOption: ModelOption
    let urlSession: URLSession

    init(apiKey: String, modelOption: ModelOption, urlSession: URLSession = .shared) {
        self.apiKey = apiKey
        self.modelOption = modelOption
        self.urlSession = urlSession
    }

    func run(action: AIAction, input: String, context: [AIContextTurn] = []) async throws -> String {
        let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else {
            throw AIClientError.emptyInput
        }

        let text = try await send(
            system: action.instruction,
            user: Self.contextualUserContent(input: trimmedInput, context: context)
        )
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIClientError.emptyResponse
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func runClarification(session: ClarificationSession) async throws -> ClarificationDecision {
        guard !session.originalQuery.isEmpty else {
            throw AIClientError.emptyInput
        }

        let text = try await send(
            system: ClarificationPromptBuilder.systemInstruction(forceFinal: session.mustGenerateFinal),
            user: session.requestContent()
        )
        guard let decision = ClarificationResponseParser.parse(text) else {
            throw AIClientError.invalidClarificationResponse
        }

        if session.mustGenerateFinal, case .ask = decision {
            let retryText = try await send(
                system: ClarificationPromptBuilder.systemInstruction(forceFinal: true),
                user: session.requestContent() + "\n\n上一次响应错误地继续提问。请立即返回 status 为 final 的最终 Prompt。"
            )
            guard let retryDecision = ClarificationResponseParser.parse(retryText), case .final = retryDecision else {
                throw AIClientError.invalidClarificationResponse
            }
            return retryDecision
        }

        return decision
    }

    func generateTemplateDraft(from input: String) async throws -> TemplateDraft {
        let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else {
            throw AIClientError.emptyInput
        }

        let system = """
        你是一位资深的 Prompt 模板提取与优化专家。请严格遵循以下要求，对用户提供的原始需求进行加工，输出一个可直接复用的 prompt 模板。

        目标：生成结构清晰、占位符明确的 prompt 模板，确保用户只需填入具体内容即可复用。

        约束与流程：
        1. 根据用户输入，提取通用逻辑与框架，剔除用户特定细节，形成模板骨架。
        2. 在模板中所有需要用户补充具体信息的位置，使用【用户输入具体事项名称】作为精确占位符，并确保占位符出现在语义恰当的上下文中。例如【用户输入目标语言】、【用户输入会议记录】、【用户输入产品需求原文】。
        3. 不要使用空泛占位符，例如【内容】、【输入】、【信息】、【用户输入具体事项】。
        4. 最终 body 必须是可直接复用的 prompt 模板正文，不要把分析过程、说明、确认话术、JSON 字段说明写进 body。
        5. 保存前确认由应用的预览弹窗完成，因此 body 中不要包含“请确认以上模板是否符合您的预期？”等确认语句。

        为了让应用保存模板，请只输出一个 JSON 对象，不要 Markdown，不要解释，不要代码块。
        JSON 结构必须严格为：
        {"title":"模板名称","detail":"一句话说明","body":"经优化后的可复用 prompt 模板"}

        字段要求：
        - title：清晰、短促、可复用的模板名称，不超过 18 个汉字。
        - detail：一句话总结模板用途和适用场景，不超过 40 个汉字。
        - body：直接输出经优化后的 prompt 模板，无需额外说明或标记。
        """

        let text = try await send(system: system, user: "原始 Prompt：\n\(trimmedInput)")
        if let draft = Self.extractTemplateDraft(from: text) {
            return Self.normalizedTemplateDraft(draft, originalInput: trimmedInput)
        }
        return Self.normalizedTemplateDraft(TemplateDraft(
            title: "我的 Prompt 模板",
            detail: "从当前 Prompt 自动生成",
            body: text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? trimmedInput : text
        ), originalInput: trimmedInput)
    }

    private func send(system: String, user: String) async throws -> String {
        var request = URLRequest(url: modelOption.baseURL.appendingPathComponent("chat/completions"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60

        let payload: [String: Any] = [
            "model": modelOption.model,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user]
            ],
            "stream": false
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await urlSession.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, !(200..<300).contains(httpResponse.statusCode) {
            let message = Self.extractErrorMessage(from: data) ?? "\(modelOption.title) 请求失败：HTTP \(httpResponse.statusCode)"
            throw AIClientError.requestFailed(message)
        }

        guard let text = Self.extractOutputText(from: data) else {
            throw AIClientError.emptyResponse
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
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
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > limit else { return trimmed }
        return String(trimmed.prefix(limit)) + "\n...（已截断）"
    }

    private static func extractOutputText(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if let outputText = json["output_text"] as? String {
            return outputText
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
        let detail = object["detail"] as? String ?? "我的专属 Prompt 模板"
        return TemplateDraft(title: title, detail: detail, body: body)
    }

    private static func normalizedTemplateDraft(_ draft: TemplateDraft, originalInput: String) -> TemplateDraft {
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "我的 Prompt 模板"
            : draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let detail = draft.detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "从当前 Prompt 自动生成"
            : draft.detail.trimmingCharacters(in: .whitespacesAndNewlines)
        var body = draft.body.trimmingCharacters(in: .whitespacesAndNewlines)
        if body.isEmpty {
            body = originalInput
        }

        let placeholders = Self.placeholders(in: body)
        if placeholders.isEmpty {
            body += "\n\n请基于【用户输入具体事项名称】完成以上任务。"
        }
        body = Self.normalizeGenericPlaceholders(in: body)

        return TemplateDraft(title: title, detail: detail, body: body)
    }

    private static func placeholders(in text: String) -> [String] {
        let nsText = text as NSString
        guard let regex = try? NSRegularExpression(pattern: #"【[^】]{2,}】"#) else { return [] }
        var seen = Set<String>()
        return regex.matches(in: text, range: NSRange(location: 0, length: nsText.length)).compactMap { match in
            let value = nsText.substring(with: match.range)
            guard !seen.contains(value) else { return nil }
            seen.insert(value)
            return value
        }
    }

    private static func normalizeGenericPlaceholders(in text: String) -> String {
        var output = text
        let replacements = [
            "【内容】": "【用户输入具体事项名称】",
            "【输入】": "【用户输入具体事项名称】",
            "【信息】": "【用户输入具体事项名称】",
            "【文本】": "【用户输入具体事项名称】",
            "【用户输入具体事项】": "【用户输入具体事项名称】"
        ]
        for (placeholder, replacement) in replacements {
            output = output.replacingOccurrences(of: placeholder, with: replacement)
        }
        return output
    }
}

enum AIClientError: LocalizedError {
    case emptyInput
    case emptyResponse
    case missingAPIKey
    case invalidClarificationResponse
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .emptyInput:
            return "当前输入为空，无法处理。"
        case .emptyResponse:
            return "模型没有返回可用内容。"
        case .missingAPIKey:
            return "请先在设置中填写模型 API Key。"
        case .invalidClarificationResponse:
            return "模型返回的追问格式不可用，请重试。"
        case .requestFailed(let message):
            return message
        }
    }
}
