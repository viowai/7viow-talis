import Foundation

public struct ClarificationAnswer: Equatable, Sendable {
    public let question: String
    public let answer: String
    public let skipped: Bool

    public init(question: String, answer: String, skipped: Bool = false) {
        self.question = question.trimmingCharacters(in: .whitespacesAndNewlines)
        self.answer = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        self.skipped = skipped
    }
}

public struct ClarificationQuestion: Equatable, Sendable {
    public let question: String
    public let options: [String]

    public init(question: String, options: [String]) {
        self.question = question.trimmingCharacters(in: .whitespacesAndNewlines)
        var seen = Set<String>()
        self.options = options.compactMap { value in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !seen.contains(trimmed) else { return nil }
            seen.insert(trimmed)
            return trimmed
        }.prefix(4).map { $0 }
    }
}

public struct ClarificationRound: Equatable, Sendable {
    public static let maximumQuestions = 3

    public let questions: [ClarificationQuestion]

    public init(questions: [ClarificationQuestion]) {
        var seen = Set<String>()
        self.questions = questions.compactMap { question in
            guard
                !question.question.isEmpty,
                question.options.count >= 2,
                !seen.contains(question.question)
            else { return nil }
            seen.insert(question.question)
            return question
        }.prefix(Self.maximumQuestions).map { $0 }
    }
}

public enum ClarificationDecision: Equatable, Sendable {
    case ask(ClarificationRound)
    case final(String)
}

public struct ClarificationRoundRecord: Equatable, Sendable {
    public let answers: [ClarificationAnswer]

    public init(answers: [ClarificationAnswer]) {
        self.answers = Array(answers.prefix(ClarificationRound.maximumQuestions))
    }
}

public struct ClarificationSession: Equatable, Sendable {
    public static let maximumRounds = 5

    public let originalQuery: String
    public private(set) var rounds: [ClarificationRoundRecord]

    public init(originalQuery: String, rounds: [ClarificationRoundRecord] = []) {
        self.originalQuery = originalQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        self.rounds = Array(rounds.prefix(Self.maximumRounds))
    }

    public var completedRounds: Int { rounds.count }
    public var mustGenerateFinal: Bool { completedRounds >= Self.maximumRounds }
    public var nextRoundNumber: Int { min(completedRounds + 1, Self.maximumRounds) }

    public mutating func appendRound(answers: [ClarificationAnswer]) {
        guard rounds.count < Self.maximumRounds, !answers.isEmpty else { return }
        rounds.append(ClarificationRoundRecord(answers: answers))
    }

    public func requestContent() -> String {
        var sections = ["用户原始 query：\n\(originalQuery)"]
        if rounds.isEmpty {
            sections.append("澄清记录：\n暂无")
        } else {
            let transcript = rounds.enumerated().map { roundIndex, round in
                let items = round.answers.enumerated().map { questionIndex, item in
                    let answerText = item.skipped ? "跳过（用户未提供信息）" : item.answer
                    return "问题 \(questionIndex + 1)：\(item.question)\n用户回答：\(answerText)"
                }.joined(separator: "\n")
                return "第 \(roundIndex + 1) 轮\n\(items)"
            }.joined(separator: "\n\n")
            sections.append("澄清记录（生成最终 Prompt 时必须全部纳入，不得遗漏）：\n\(transcript)")
        }
        sections.append("当前已完成 \(completedRounds) 轮追问；最多允许 \(Self.maximumRounds) 轮。")
        if mustGenerateFinal {
            sections.append("已达到追问上限。现在必须生成最终 Prompt，不得继续提问。")
        }
        return sections.joined(separator: "\n\n")
    }

    public func historyQuery() -> String {
        guard !rounds.isEmpty else { return originalQuery }
        let transcript = rounds.enumerated().map { roundIndex, round in
            let items = round.answers.map { item in
                let answerText = item.skipped ? "跳过" : item.answer
                return "- \(item.question) → \(answerText)"
            }.joined(separator: "\n")
            return "第 \(roundIndex + 1) 轮\n\(items)"
        }.joined(separator: "\n")
        return "\(originalQuery)\n\n追问记录：\n\(transcript)"
    }
}

public enum ClarificationPromptBuilder {
    public static func systemInstruction(forceFinal: Bool) -> String {
        let modeRule = forceFinal
            ? "已达到追问上限。你只能返回 final，禁止继续返回 ask。"
            : "若信息清晰、完整、可执行，返回 final；否则只追问当前最影响执行的一项信息。"

        return """
        你是 Talis 的 Prompt 澄清与生成引擎。请判断用户意图和目标是否清晰、完整、可执行。

        判断标准：
        1. 核心目标和要完成的任务明确。
        2. 执行所必需的对象、输入、范围或场景已经给出。
        3. 关键约束和期望输出足以支持执行；不要为了非必要偏好而过度追问。
        4. 每轮必须结合原始 query 与全部历史回答重新判断，不能只看最近一轮。

        \(modeRule)

        当需要追问时：
        - 每轮返回 1 至 3 个彼此相关、互不重复的高信息增益问题。
        - 同一轮的问题应共同补齐一个执行缺口，不要混入无关偏好。
        - 给出 2 至 4 个简短、具体、互斥或可清楚区分的选项。
        - 不要把“跳过”“其他”放进 options；应用会单独提供跳过和自定义回答。

        当生成最终 Prompt 时：
        - 必须综合原始 query 与所有轮次回答，不遗漏关键信息。
        - 用户跳过的问题不得擅自虚构答案；必要时用清晰占位符表达待补信息。
        - 输出应直接可执行，包含适当的目标、上下文、约束、步骤、输出格式与质量标准。

        只输出一个 JSON 对象，不要 Markdown、解释或代码块。允许的结构只有：
        {"status":"ask","questions":[{"question":"问题1","options":["选项1","选项2"]},{"question":"问题2","options":["选项1","选项2"]}]}
        或
        {"status":"final","prompt":"最终 Prompt"}
        """
    }
}

public enum ClarificationResponseParser {
    public static func parse(_ rawText: String) -> ClarificationDecision? {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let jsonText: String
        if let start = trimmed.firstIndex(of: "{"), let end = trimmed.lastIndex(of: "}"), start <= end {
            jsonText = String(trimmed[start...end])
        } else {
            return .final(trimmed)
        }

        guard
            let data = jsonText.data(using: .utf8),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return .final(trimmed)
        }

        let status = (object["status"] as? String)?.lowercased()
        if status == "ask" {
            let rawQuestions: [[String: Any]]
            if let questions = object["questions"] as? [[String: Any]] {
                rawQuestions = questions
            } else if let question = object["question"] as? String {
                rawQuestions = [["question": question, "options": object["options"] as? [String] ?? []]]
            } else {
                return nil
            }

            let questions = rawQuestions.compactMap { item -> ClarificationQuestion? in
                guard let question = item["question"] as? String else { return nil }
                let normalized = ClarificationQuestion(
                    question: question,
                    options: item["options"] as? [String] ?? []
                )
                return normalized.options.count >= 2 ? normalized : nil
            }
            let round = ClarificationRound(questions: questions)
            guard !round.questions.isEmpty else { return nil }
            return .ask(round)
        }

        if status == "final",
           let prompt = object["prompt"] as? String,
           !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            return .final(prompt.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return nil
    }
}
