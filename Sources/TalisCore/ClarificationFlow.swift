import Foundation

public struct ClarificationAnswer: Equatable, Sendable {
    public let question: String
    public let answer: String
    public let skipped: Bool

    public init(question: String, answer: String, skipped: Bool = false) {
        self.question = question.trimmingCharacters(in: .whitespacesAndNewlines)
        self.answer = answer
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

public enum TalisContentLanguage: String, Sendable {
    case simplifiedChinese
    case english

    var promptName: String {
        switch self {
        case .simplifiedChinese: return "Simplified Chinese"
        case .english: return "English"
        }
    }
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
        self.originalQuery = originalQuery
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

    public func structureRepairContent(rejectedPrompt: String) -> String {
        """
        \(requestContent())

        上一次返回的 final Prompt 未完整保留原始 query 的结构，不能写回编辑器：
        <rejected_final_prompt>
        \(rejectedPrompt)
        </rejected_final_prompt>

        请只修复结构，不要重新追问，也不要丢掉已经纳入的澄清答案。输出新的 final Prompt。
        """
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
    public static func inferContentLanguage(
        from source: String,
        fallback: TalisContentLanguage
    ) -> TalisContentLanguage {
        let scalars = source.unicodeScalars
        let hanCount = scalars.filter { (0x3400...0x9FFF).contains(Int($0.value)) }.count
        let latinCount = scalars.filter {
            ($0.value >= 65 && $0.value <= 90) || ($0.value >= 97 && $0.value <= 122)
        }.count
        if hanCount >= 3 && hanCount >= latinCount / 3 {
            return .simplifiedChinese
        }
        if latinCount > 0 {
            return .english
        }
        return fallback
    }

    public static func contentLanguageInstruction(_ language: TalisContentLanguage) -> String {
        """
        语言规则：
        - 强制使用 \(language.promptName) 输出所有生成内容，不得根据用户输入语言自行判断。
        - 标题、说明、步骤、约束、输出格式和质量标准都必须使用 \(language.promptName)。
        - 保留代码、路径、API 名称、产品名、专有名词、占位符结构和用户必须原样保留的事实与字面值。
        - 除上述原样内容外，把输入中的说明性文字翻译为 \(language.promptName)，不能保留成段的其他语言。
        """
    }

    public static func clarificationLanguageInstruction(_ language: TalisContentLanguage) -> String {
        """
        输出语言规则：
        - 所有 question、options 和 final Prompt 都必须使用 \(language.promptName)，不得根据用户输入语言自行判断。
        - final Prompt 的标题、说明、步骤、约束、输出格式和质量标准都必须使用 \(language.promptName)。
        - 保留代码、路径、API 名称、产品名、专有名词、占位符结构和用户必须原样保留的事实与字面值。
        - 除上述原样内容外，把用户原文与已确认回答中的说明性文字翻译为 \(language.promptName)，不能保留成段的其他语言。
        """
    }

    public static func systemInstruction(
        forceFinal: Bool,
        responseLanguage: TalisContentLanguage = .simplifiedChinese
    ) -> String {
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
        \(clarificationLanguageInstruction(responseLanguage))

        当需要追问时：
        - 每轮返回 1 至 3 个彼此相关、互不重复的高信息增益问题。
        - 不要重复询问用户已经明确写出的任务类型；优先询问会改变执行结果的具体缺口。
        - 同一轮的问题应共同补齐一个执行缺口，不要混入无关偏好。
        - 给出 2 至 4 个简短、具体、互斥或可清楚区分的选项。
        - 不要把“跳过”“其他”放进 options；应用会单独提供跳过和自定义回答。

        当生成最终 Prompt 时：
        - 必须综合原始 query 与所有轮次回答，不遗漏关键信息。
        - 用户跳过的问题不得擅自虚构答案；必要时用清晰占位符表达待补信息。
        - 原始 query 已有的 Markdown 标题必须保留相同级别和顺序，不能合并、拆分、降级或改成普通段落。
        - 原始 query 已有的有序列表、无序列表及其项目顺序必须保留；不能改写成连续散文，也不能合并或删除项目。
        - 【】是可编辑的普通文字标记；按当前需求决定是否保留、修改或删除，不锁定其名称、数量、顺序或标点。
        - 你可以在不破坏上述结构的前提下补充内容，但不得把原有结构化 Prompt 拍平成纯文本。
        - 输出应直接可执行，包含适当的目标、上下文、约束、步骤、输出格式与质量标准。

        只输出一个 JSON 对象，不要 Markdown、解释或代码块。允许的结构只有：
        {"status":"ask","questions":[{"question":"问题1","options":["选项1","选项2"]},{"question":"问题2","options":["选项1","选项2"]}]}
        或
        {"status":"final","prompt":"最终 Prompt"}
        """
    }

    public static func structureRepairInstruction(
        responseLanguage: TalisContentLanguage = .simplifiedChinese
    ) -> String {
        """
        \(systemInstruction(forceFinal: true, responseLanguage: responseLanguage))

        本次响应是一次结构修复，不是重新开始澄清。请对比原始 query 和被拒绝的 final Prompt：
        - 原 query 的每个 Markdown 标题必须恢复相同级别和原顺序。
        - 原 query 的每个有序列表项和无序列表项必须恢复原类型和原顺序。
        - 不强制恢复、增添或改名【】标记；只修复标题与列表布局。
        - 保留已经确认的追问答案，可以补充内容，但不得再次提问。
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
            return .final(rawText)
        }

        guard
            let data = jsonText.data(using: .utf8),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return .final(rawText)
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
            return .final(prompt)
        }

        return nil
    }
}
