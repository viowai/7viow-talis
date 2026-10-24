import AppKit
import Carbon
import TalisCore

enum LibraryMode: Int, CaseIterable {
    case prompt
    case skill

    var title: String {
        switch self {
        case .prompt: return "系统模板"
        case .skill: return "我的模板"
        }
    }

    var subtitle: String {
        switch self {
        case .prompt: return "系统"
        case .skill: return "我的"
        }
    }
}

enum TemplateKind: String {
    case system
    case user
}

enum TemplateOrigin: Equatable {
    case system(id: String)
    case user(id: UUID)

    var kind: TemplateKind {
        switch self {
        case .system: return .system
        case .user: return .user
        }
    }
}

enum TemplateUpdatePolicy {
    case systemAndUser
    case userOnly

    // Current release allows both system templates and user templates to be updated.
    // Future releases can switch this to `.userOnly` without changing editor state tracking.
    static let current: TemplateUpdatePolicy = .systemAndUser

    func allows(_ origin: TemplateOrigin?) -> Bool {
        guard let origin else { return false }
        switch (self, origin.kind) {
        case (.systemAndUser, _), (.userOnly, .user):
            return true
        case (.userOnly, .system):
            return false
        }
    }
}

enum TemplateUpdateError: LocalizedError {
    case missingTemplate

    var errorDescription: String? {
        switch self {
        case .missingTemplate:
            return "原模板不存在，可能已在模板库中被删除。"
        }
    }
}

struct LibraryItem {
    let title: String
    let detail: String
    let symbolName: String
    let badge: String
    let body: String
    let origin: TemplateOrigin

    init(title: String, detail: String, symbolName: String, badge: String, body: String, origin: TemplateOrigin? = nil) {
        self.title = title
        self.detail = detail
        self.symbolName = symbolName
        self.badge = badge
        self.body = body
        self.origin = origin ?? .system(id: Self.defaultSystemID(for: title))
    }

    func replacingBody(_ newBody: String) -> LibraryItem {
        LibraryItem(
            title: title,
            detail: detail,
            symbolName: symbolName,
            badge: badge,
            body: newBody,
            origin: origin
        )
    }

    private static func defaultSystemID(for title: String) -> String {
        let normalizedTitle = title
            .folding(options: [.caseInsensitive, .widthInsensitive, .diacriticInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "\n", with: "-")
            .replacingOccurrences(of: "\t", with: "-")
        return "system.\(normalizedTitle)"
    }
}

enum PromptStore {
    static let prompts: [LibraryItem] = [
        LibraryItem(
            title: "模糊需求转高质量 Prompt",
            detail: "补齐目标、上下文、约束、输出格式和自检规则",
            symbolName: "wand.and.stars",
            badge: "PRT-001",
            body: """
            # 角色
            你是一个资深提示词工程专家，擅长把模糊任务翻译成高质量、可执行、低歧义的 AI Prompt。

            # 任务
            将我的原始需求，转化为适合大模型执行的高质量 Prompt，不是简单润色，而是补齐目标、上下文、约束、输出格式和自检规则。

            # 输入
            - 原始需求：【原始需求】
            - 目标模型：【目标模型】
            - 任务类型：【任务类型】
            - 使用场景：【使用场景】
            - 我最关心的结果：【最关心的结果】
            - 已知背景信息：【背景信息】
            - 输出语言：【输出语言】
            - 输出形式：【输出形式】
            - 需要避免的问题：【避免事项】

            # 处理要求
            1. 先判断原始需求缺少哪些关键信息。
            2. 将任务补充为完整 Prompt 结构：角色、目标、上下文、约束、输出格式、质量标准。
            3. 给出 2 个版本：通用版、增强版。
            4. 如果原始需求信息不足，单独列出“建议补充信息”。
            5. 最后说明这个 Prompt 为什么比原始需求更有效。

            # 输出格式
            ## 一、需求缺口判断
            - ...

            ## 二、优化后的 Prompt
            ### 通用版
            ...
            ### 增强版
            ...

            ## 三、建议补充信息
            - ...

            ## 四、优化说明
            - ...
            """
        ),
        LibraryItem(
            title: "会议前 Briefing 生成",
            detail: "整理背景、争议点、待决事项和主持人口播摘要",
            symbolName: "person.2.wave.2",
            badge: "COM-007",
            body: """
            # 角色
            你是一个会议 briefing 顾问，擅长把复杂议题整理成参会者可快速消化的会前预读包。

            # 任务
            为一场关键会议生成会前 briefing，帮助参会者在会前理解背景、争议点、待决事项和预期产出。

            # 输入
            - 会议主题：【会议主题】
            - 参会角色：【参会角色】
            - 会议目标：【会议目标】
            - 背景信息：【背景信息】
            - 当前争议点：【当前争议点】
            - 会上需要做出的决策：【待决策项】
            - 会议时长：【会议时长】
            - 已有材料：【已有材料】

            # 处理要求
            1. 明确区分：背景、当前状态、争议点、待决策项、会前准备。
            2. 对不同参会角色，指出他们重点要关注什么。
            3. 不写成长篇散文，要适合会前快速阅读。
            4. 最后输出一个“主持人口播版摘要”。

            # 输出格式
            ## 一、会议背景
            - ...

            ## 二、当前状态
            - ...

            ## 三、核心争议点
            - ...

            ## 四、会中需决策事项
            - ...

            ## 五、参会者会前准备
            | 角色 | 重点关注 | 需要准备 |
            |---|---|---|

            ## 六、主持人口播版摘要
            - ...
            """
        ),
        LibraryItem(
            title: "假设清单与验证优先级",
            detail: "识别错了会致命的假设，并设计最小验证",
            symbolName: "checklist",
            badge: "DEC-008",
            body: """
            # 角色
            你是一个假设驱动设计顾问，擅长从方案中识别关键假设，并按风险与验证成本排优先级。

            # 任务
            根据我的方案内容，提炼核心假设，判断哪些假设最值得优先验证，并给出轻量验证方式。

            # 输入
            - 方案内容：【方案内容】
            - 目标用户：【目标用户】
            - 预期结果：【预期结果】
            - 当前阶段：【当前阶段】
            - 已知证据：【已知证据】
            - 我最担心失败的地方：【最担心失败点】

            # 处理要求
            1. 区分用户假设、需求假设、流程假设、技术假设、商业假设。
            2. 对每个假设评估：错误代价、验证难度、验证优先级。
            3. 优先找“错了会致命”的假设。
            4. 每个高优先级假设给一个最小验证方法。

            # 输出格式
            ## 一、假设清单
            | 假设 | 类型 | 错误代价 | 验证难度 | 优先级 |
            |---|---|---|---|---|

            ## 二、最先验证的前三项
            - ...

            ## 三、建议验证方式
            - ...
            """
        ),
        LibraryItem(
            title: "生产前质量把关",
            detail: "发布前扫雷，输出风险等级、放行判断和 checklist",
            symbolName: "checkmark.shield",
            badge: "QAS-005",
            body: """
            # 角色
            你是一个生产前质量把关顾问，擅长在发布、上线、交付前进行系统性风险扫雷和放行判断。

            # 任务
            对我的内容、方案、页面或流程进行“发布前检查”，识别高风险问题、低级错误和放行条件。

            # 输入
            - 待检查对象：【待检查对象】
            - 发布/上线场景：【发布场景】
            - 目标用户：【目标用户】
            - 最不能出的问题：【最不能出的问题】
            - 已知风险点：【已知风险点】
            - 是否有合规/品牌/技术边界：【边界条件】
            - 发布时间压力：【时间压力】

            # 处理要求
            1. 从内容正确性、逻辑完整性、体验断点、品牌/语气风险、技术/执行风险几个维度检查。
            2. 区分致命问题、重要问题、可放后修的问题。
            3. 给出“可发布 / 有条件发布 / 不建议发布”的判断。
            4. 对高优先级问题给出最小修复建议。
            5. 最后输出一份最小放行 checklist。

            # 输出格式
            ## 一、风险扫雷结果
            | 维度 | 问题 | 风险等级 | 建议 |
            |---|---|---|---|

            ## 二、放行判断
            - 可发布 / 有条件发布 / 不建议发布
            - 原因：

            ## 三、最小放行 checklist
            - ...
            """
        ),
        LibraryItem(
            title: "内容选题池生成",
            detail: "把零散想法聚类为栏目、选题、形式和先发顺序",
            symbolName: "rectangle.stack.badge.plus",
            badge: "CNT-002",
            body: """
            # 角色
            你是一个内容策略顾问，擅长把零散想法整理成成体系、可持续输出的内容选题池。

            # 任务
            根据我提供的方向、素材和目标受众，帮我生成一套有结构、有差异、有优先级的内容选题体系。

            # 输入
            - 我的原始想法：【原始想法】
            - 目标受众：【目标受众】
            - 内容平台：【内容平台】
            - 内容目标：【内容目标】
            - 偏好内容形式：【偏好形式】
            - 我不想写的方向：【排除方向】
            - 我已有的优势内容：【优势内容】

            # 处理要求
            1. 先把想法聚类成 3-5 个主题栏目。
            2. 每个栏目下生成若干选题，而不是混排。
            3. 标出每个选题更适合的形式和优先级。
            4. 尽量兼顾“高传播、强专业、可持续”三类。
            5. 最后给一个建议的先发顺序。

            # 输出格式
            ## 一、主题栏目建议
            - ...

            ## 二、选题池
            | 栏目 | 选题 | 适合形式 | 目标受众 | 优先级 |
            |---|---|---|---|---|

            ## 三、建议先发顺序
            - ...

            ## 四、系列化建议
            - ...
            """
        ),
        LibraryItem(
            title: "Prompt 防注入加固",
            detail: "从注入、越权、误答和信息泄露角度加固提示词",
            symbolName: "lock.shield",
            badge: "PRT-006",
            body: """
            # 角色
            你是一个 Prompt 安全加固顾问，擅长识别 Prompt 中的注入风险、权限越界、歧义漏洞和信息不足误答风险。

            # 任务
            对我的 Prompt 进行安全与鲁棒性加固，增强其面对恶意输入、模糊输入和越权请求时的稳定性。

            # 输入
            - 原始 Prompt：【原始 Prompt】
            - 使用场景：【使用场景】
            - 可访问的数据/工具：【数据和工具】
            - 绝不能泄露的信息：【禁止泄露信息】
            - 绝不能执行的动作：【禁止动作】
            - 常见恶意/异常输入：【异常输入样例】
            - 当前最担心的漏洞：【担心漏洞】

            # 处理要求
            1. 先识别高风险点：注入、权限越界、数据泄露、模糊指令覆盖、错误自信。
            2. 针对每类风险补充约束语句和优先级规则。
            3. 明确当信息不足时应澄清、拒答或降级处理。
            4. 最后给一个“加固前 vs 加固后”的关键改动说明。

            # 输出格式
            ## 一、风险点识别
            - ...

            ## 二、加固后 Prompt
            - ...

            ## 三、异常输入处理原则
            - ...

            ## 四、关键改动说明
            - ...
            """
        ),
        LibraryItem(
            title: "深度长文翻译",
            detail: "保留结构、术语表、语气与译后校对",
            symbolName: "character.book.closed",
            badge: "写作",
            body: """
            请将以下内容翻译为【目标语言】。

            翻译要求：
            1. 保留原文的段落结构、标题层级、列表格式和引用格式。
            2. 专有名词、产品名、人名、地名保持一致；不确定的术语请在译文后添加「译注」。
            3. 保持【语气风格】的表达，不要机械直译。
            4. 如发现原文存在歧义，请先给出最可能译法，再列出「可能歧义」。

            原文：
            【待翻译文本】

            输出格式：
            - 译文
            - 关键术语对照表
            - 可能歧义与译注
            """
        )
    ]

    static let skills: [LibraryItem] = [
        LibraryItem(
            title: "工单分流与路由规则",
            detail: "把工单样本转成分类、优先级和团队路由规则",
            symbolName: "arrow.triangle.branch",
            badge: "AIW-005",
            body: """
            # 角色
            你是一个服务运营分流顾问，擅长把工单内容转成分类、优先级和路由规则。

            # 任务
            根据工单内容与处理团队分工，设计一套工单分流和路由规则，帮助系统或人工快速分派。

            # 输入
            - 工单样本：【工单样本】
            - 当前处理团队：【处理团队】
            - 是否有 SLA：【SLA 规则】
            - 高风险问题类型：【高风险类型】
            - 需要优先识别的信息：【优先识别信息】
            - 容易混淆的类别：【混淆类别】

            # 处理要求
            1. 先定义一级分类、二级分类和紧急程度。
            2. 每类规则尽量写成可判断的条件。
            3. 标出需要优先升级处理的工单类型。
            4. 对边界模糊类补充人工复核规则。

            # 输出格式
            ## 一、分类与路由规则
            | 类别 | 判定条件 | 去向团队 | 优先级 |
            |---|---|---|---|

            ## 二、升级处理条件
            - ...

            ## 三、人工复核规则
            - ...
            """
        ),
        LibraryItem(
            title: "写作润色技能",
            detail: "保持原意，提升清晰度、节奏和表达力度",
            symbolName: "sparkles",
            badge: "编辑",
            body: """
            你是专业中文编辑。请润色以下内容。

            原文：
            【待润色文本】

            润色方向：
            【目标风格】

            要求：
            1. 保持事实和原意不变。
            2. 提升逻辑衔接和可读性。
            3. 删除空泛表达，保留有信息量的细节。
            4. 输出「润色版」和「主要修改说明」。
            """
        ),
        LibraryItem(
            title: "代码审查技能",
            detail: "按真实风险优先级输出问题、位置和修复建议",
            symbolName: "chevron.left.forwardslash.chevron.right",
            badge: "开发",
            body: """
            你是资深工程代码审查助手。请审查以下代码变更，重点关注真实缺陷、回归风险、边界条件和测试缺口。

            # 输入
            - 代码或 Diff：【代码或 Diff】
            - 相关业务背景：【业务背景】
            - 运行环境：【运行环境】
            - 我最担心的问题：【担心问题】

            # 输出格式
            ## 一、高风险问题
            - 文件/位置：
            - 问题：
            - 影响：
            - 修复建议：

            ## 二、中低风险问题
            - ...

            ## 三、测试建议
            - ...

            ## 四、可以接受的残余风险
            - ...
            """
        ),
        LibraryItem(
            title: "研究归纳技能",
            detail: "把碎片资料整理为结论、证据和待验证假设",
            symbolName: "doc.text.magnifyingglass",
            badge: "研究",
            body: """
            你是研究分析助手。请整理以下材料，并形成可行动结论。

            研究问题：
            【研究问题】

            材料：
            【材料内容】

            请输出：
            - 一句话结论
            - 关键发现
            - 支撑证据
            - 反例或不确定性
            - 下一步需要验证的假设
            """
        )
    ]

    static func items(for mode: LibraryMode) -> [LibraryItem] {
        switch mode {
        case .prompt: return (prompts + skills + EcosystemTemplates.items).map(SystemTemplateOverrideStore.resolvedItem)
        case .skill: return UserTemplateStore.libraryItems()
        }
    }
}

final class PlaceholderNavigator {
    private let pattern = "【[^】\\n]+】"

    func ranges(in string: String) -> [NSRange] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsRange = NSRange(string.startIndex..<string.endIndex, in: string)
        return regex.matches(in: string, range: nsRange).map(\.range)
    }

    func nextRange(in string: String, after selectedRange: NSRange) -> NSRange? {
        let allRanges = ranges(in: string)
        guard !allRanges.isEmpty else { return nil }
        let currentEnd = selectedRange.location + max(selectedRange.length, 0)
        if let next = allRanges.first(where: { $0.location >= currentEnd }) {
            return next
        }
        return allRanges.first
    }
}

struct PromptTemplateMatch {
    let item: LibraryItem
    let mode: LibraryMode
    let score: Int
    let matchedKeywords: [String]
}

enum PromptTemplateMatcher {
    private static let keywordMap: [String: [String]] = [
        "模糊需求转高质量 Prompt": ["prompt", "提示词", "指令", "咒语", "需求", "优化", "改写", "结构化", "生成 prompt", "写 prompt", "system prompt"],
        "会议前 Briefing 生成": ["会议", "会前", "briefing", "纪要", "议题", "参会", "决策", "主持", "背景", "会前材料"],
        "假设清单与验证优先级": ["假设", "验证", "优先级", "风险", "实验", "最小验证", "方案", "需求假设"],
        "生产前质量把关": ["发布", "上线", "质量", "检查", "扫雷", "放行", "风险", "验收", "checklist"],
        "内容选题池生成": ["内容", "选题", "栏目", "小红书", "公众号", "视频", "创作", "素材", "受众"],
        "Prompt 防注入加固": ["注入", "越权", "泄露", "安全", "加固", "prompt 安全", "恶意输入", "权限"],
        "深度长文翻译": ["翻译", "译文", "英文", "中文", "日文", "韩文", "术语", "长文", "本地化", "英译中", "中译英"],
        "工单分流与路由规则": ["工单", "分流", "路由", "客服", "sla", "升级", "派单", "处理团队"],
        "写作润色技能": ["润色", "改稿", "文案", "表达", "清晰", "语气", "写作", "编辑"],
        "代码审查技能": ["代码", "审查", "review", "diff", "bug", "风险", "测试", "修复", "回归"],
        "研究归纳技能": ["研究", "归纳", "资料", "结论", "证据", "洞察", "调研", "分析"]
    ]

    static func bestMatch(for input: String) -> PromptTemplateMatch? {
        let normalized = normalize(input)
        guard normalized.count >= 6, normalized != "/" else { return nil }

        let candidates: [(LibraryMode, LibraryItem)] =
            PromptStore.items(for: .prompt).map { (.prompt, $0) } + PromptStore.items(for: .skill).map { (.skill, $0) }

        let matches = candidates.compactMap { mode, item -> PromptTemplateMatch? in
            let result = score(item: item, input: normalized)
            guard result.score >= 4, !result.keywords.isEmpty else { return nil }
            return PromptTemplateMatch(item: item, mode: mode, score: result.score, matchedKeywords: result.keywords)
        }
        return matches.sorted { lhs, rhs in
            if lhs.score == rhs.score {
                return lhs.mode.rawValue < rhs.mode.rawValue
            }
            return lhs.score > rhs.score
        }.first
    }

    static func primaryPlaceholder(for item: LibraryItem) -> String? {
        let map: [String: String] = [
            "模糊需求转高质量 Prompt": "【原始需求】",
            "会议前 Briefing 生成": "【会议主题】",
            "假设清单与验证优先级": "【方案内容】",
            "生产前质量把关": "【待检查对象】",
            "内容选题池生成": "【原始想法】",
            "Prompt 防注入加固": "【原始 Prompt】",
            "深度长文翻译": "【待翻译文本】",
            "工单分流与路由规则": "【工单样本】",
            "写作润色技能": "【待润色文本】",
            "代码审查技能": "【代码或 Diff】",
            "研究归纳技能": "【材料内容】"
        ]
        return map[item.title]
    }

    static func filledTemplate(from item: LibraryItem, userInput: String, navigator: PlaceholderNavigator) -> String {
        let trimmedInput = userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else { return item.body }

        if let primary = primaryPlaceholder(for: item), item.body.contains(primary) {
            return item.body.replacingOccurrences(of: primary, with: trimmedInput)
        }

        guard let firstRange = navigator.ranges(in: item.body).first, let range = Range(firstRange, in: item.body) else {
            return item.body + "\n\n" + trimmedInput
        }
        var output = item.body
        output.replaceSubrange(range, with: trimmedInput)
        return output
    }

    static func signature(for input: String, match: PromptTemplateMatch) -> String {
        "\(match.mode.rawValue)|\(match.item.title)|\(normalize(input))"
    }

    private static func score(item: LibraryItem, input: String) -> (score: Int, keywords: [String]) {
        let keywords = keywordMap[item.title] ?? []
        var total = 0
        var matched: [(keyword: String, score: Int)] = []
        for keyword in keywords {
            let normalizedKeyword = normalize(keyword)
            guard !normalizedKeyword.isEmpty else { continue }
            if input.contains(normalizedKeyword) {
                let value = max(2, min(6, normalizedKeyword.count))
                total += value
                matched.append((keyword, value))
            } else if let fuzzyScore = fuzzyKeywordScore(keyword: normalizedKeyword, input: input) {
                total += fuzzyScore
                matched.append((keyword, fuzzyScore))
            }
        }

        if input.contains(normalize(item.title)) {
            total += 8
            matched.append((item.title, 8))
        }
        item.title
            .components(separatedBy: CharacterSet.whitespacesAndNewlines)
            .map(normalize)
            .filter { !$0.isEmpty && input.contains($0) }
            .forEach { value in
                total += 3
                matched.append((value, 3))
            }
        var bestByKeyword: [String: Int] = [:]
        for item in matched {
            bestByKeyword[item.keyword] = max(bestByKeyword[item.keyword] ?? 0, item.score)
        }
        let rankedKeywords = bestByKeyword.sorted { lhs, rhs in
            lhs.value == rhs.value ? lhs.key.count > rhs.key.count : lhs.value > rhs.value
        }
        let uniqueKeywords = rankedKeywords.prefix(4).map(\.key)
        return (total, uniqueKeywords)
    }

    private static func fuzzyKeywordScore(keyword: String, input: String) -> Int? {
        guard keyword.count >= 2 else { return nil }
        if containsCharactersInOrder(keyword, in: input) {
            return max(2, min(4, keyword.count - 1))
        }
        let keywordSet = Set(keyword)
        let inputSet = Set(input)
        let overlap = keywordSet.intersection(inputSet).count
        let ratio = Double(overlap) / Double(max(keywordSet.count, 1))
        if ratio >= 0.72 {
            return 2
        }
        return nil
    }

    private static func containsCharactersInOrder(_ keyword: String, in input: String) -> Bool {
        var index = input.startIndex
        for character in keyword {
            guard let found = input[index...].firstIndex(of: character) else { return false }
            index = input.index(after: found)
        }
        return true
    }

    private static func normalize(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .widthInsensitive, .diacriticInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\t", with: "")
    }
}

final class TemplateSuggestionView: NSView {
    static let height: CGFloat = 64

    private let blurView = NSVisualEffectView()
    private let symbolView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let detailLabel = NSTextField(labelWithString: "")
    private let keywordStack = NSStackView()
    private let buttonStack = NSStackView()
    private let applyButton = NSButton(title: "套用", target: nil, action: nil)
    private let ignoreButton = NSButton(title: "忽略", target: nil, action: nil)
    var onApply: (() -> Void)?
    var onIgnore: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureLayout()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureLayout()
    }

    func configure(with match: PromptTemplateMatch) {
        let image = NSImage(systemSymbolName: "sparkle.magnifyingglass", accessibilityDescription: nil)
        image?.isTemplate = true
        symbolView.image = image
        symbolView.contentTintColor = .controlAccentColor
        symbolView.isHidden = false
        buttonStack.isHidden = false
        keywordStack.isHidden = match.matchedKeywords.isEmpty
        AppTheme.applyTextStyle(to: titleLabel, text: "匹配到模板：\(match.item.title)", size: 12, weight: .medium, color: NSColor.black.withAlphaComponent(0.88))
        AppTheme.applyTextStyle(to: detailLabel, text: match.item.detail, size: 11, color: NSColor.black.withAlphaComponent(0.62))
        setHighlightedKeywords(match.matchedKeywords)
        toolTip = "确认后会把当前输入填入模板，生成本次可直接使用的 Prompt。"
    }

    private func configureLayout() {
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.backgroundColor = NSColor.white.withAlphaComponent(0.2).cgColor
        layer?.borderColor = NSColor.white.withAlphaComponent(0.42).cgColor
        layer?.borderWidth = 1
        layer?.masksToBounds = false
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.22
        layer?.shadowOffset = NSSize(width: 0, height: -1)
        layer?.shadowRadius = 12

        blurView.translatesAutoresizingMaskIntoConstraints = false
        blurView.material = .hudWindow
        blurView.blendingMode = .withinWindow
        blurView.state = .active
        blurView.wantsLayer = true
        blurView.layer?.cornerRadius = 10
        blurView.layer?.masksToBounds = true

        symbolView.translatesAutoresizingMaskIntoConstraints = false
        symbolView.imageScaling = .scaleProportionallyDown

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.drawsBackground = false

        detailLabel.translatesAutoresizingMaskIntoConstraints = false
        detailLabel.lineBreakMode = .byTruncatingTail
        detailLabel.drawsBackground = false

        applyButton.target = self
        applyButton.action = #selector(applyPressed)
        applyButton.bezelStyle = .rounded
        applyButton.controlSize = .small
        applyButton.font = AppTheme.medium(11)

        ignoreButton.target = self
        ignoreButton.action = #selector(ignorePressed)
        ignoreButton.bezelStyle = .rounded
        ignoreButton.controlSize = .small
        ignoreButton.font = AppTheme.medium(11)

        keywordStack.orientation = .horizontal
        keywordStack.spacing = 4
        keywordStack.alignment = .centerY
        keywordStack.distribution = .gravityAreas
        keywordStack.translatesAutoresizingMaskIntoConstraints = false

        let textContainer = NSView()
        textContainer.translatesAutoresizingMaskIntoConstraints = false
        textContainer.addSubview(titleLabel)
        textContainer.addSubview(detailLabel)
        textContainer.addSubview(keywordStack)

        buttonStack.orientation = .horizontal
        buttonStack.spacing = 6
        buttonStack.alignment = .centerY
        buttonStack.distribution = .gravityAreas
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        buttonStack.addArrangedSubview(ignoreButton)
        buttonStack.addArrangedSubview(applyButton)
        buttonStack.setContentHuggingPriority(.required, for: .horizontal)
        buttonStack.setContentCompressionResistancePriority(.required, for: .horizontal)

        addSubview(blurView, positioned: .below, relativeTo: nil)
        addSubview(symbolView)
        addSubview(textContainer)
        addSubview(buttonStack)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: Self.height),

            blurView.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: trailingAnchor),
            blurView.topAnchor.constraint(equalTo: topAnchor),
            blurView.bottomAnchor.constraint(equalTo: bottomAnchor),

            symbolView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            symbolView.centerYAnchor.constraint(equalTo: centerYAnchor),
            symbolView.widthAnchor.constraint(equalToConstant: 22),
            symbolView.heightAnchor.constraint(equalToConstant: 22),

            textContainer.leadingAnchor.constraint(equalTo: symbolView.trailingAnchor, constant: 10),
            textContainer.trailingAnchor.constraint(equalTo: buttonStack.leadingAnchor, constant: -10),
            textContainer.centerYAnchor.constraint(equalTo: centerYAnchor),
            textContainer.heightAnchor.constraint(equalToConstant: 48),

            titleLabel.leadingAnchor.constraint(equalTo: textContainer.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: textContainer.trailingAnchor),
            titleLabel.topAnchor.constraint(equalTo: textContainer.topAnchor),
            titleLabel.heightAnchor.constraint(equalToConstant: 16),

            detailLabel.leadingAnchor.constraint(equalTo: textContainer.leadingAnchor),
            detailLabel.trailingAnchor.constraint(equalTo: textContainer.trailingAnchor),
            detailLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            detailLabel.heightAnchor.constraint(equalToConstant: 15),

            keywordStack.leadingAnchor.constraint(equalTo: textContainer.leadingAnchor),
            keywordStack.trailingAnchor.constraint(lessThanOrEqualTo: textContainer.trailingAnchor),
            keywordStack.topAnchor.constraint(equalTo: detailLabel.bottomAnchor, constant: 3),
            keywordStack.heightAnchor.constraint(equalToConstant: 14),

            buttonStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            buttonStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            buttonStack.widthAnchor.constraint(equalToConstant: 92)
        ])
    }

    private func setHighlightedKeywords(_ keywords: [String]) {
        keywordStack.arrangedSubviews.forEach { view in
            keywordStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        for keyword in keywords.prefix(4) {
            let label = NSTextField(labelWithString: keyword)
            label.translatesAutoresizingMaskIntoConstraints = false
            label.font = AppTheme.medium(10)
            label.textColor = NSColor.black.withAlphaComponent(0.82)
            label.alignment = .center
            label.drawsBackground = false
            label.wantsLayer = true
            label.layer?.cornerRadius = 5
            label.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.8).cgColor
            label.layer?.borderColor = NSColor.black.withAlphaComponent(0.18).cgColor
            label.layer?.borderWidth = 1
            keywordStack.addArrangedSubview(label)
            NSLayoutConstraint.activate([
                label.heightAnchor.constraint(equalToConstant: 14),
                label.widthAnchor.constraint(greaterThanOrEqualToConstant: max(30, CGFloat(keyword.count * 10)))
            ])
        }
    }

    @objc private func applyPressed() {
        onApply?()
    }

    @objc private func ignorePressed() {
        onIgnore?()
    }
}

protocol PromptTextViewDelegate: AnyObject {
    func promptTextViewDidRequestMenu(_ textView: PromptTextView)
    func promptTextViewDidRequestModeSwitch(_ textView: PromptTextView)
    func promptTextViewDidRequestPlaceholderJump(_ textView: PromptTextView)
    func promptTextViewDidRequestSelection(_ textView: PromptTextView)
    func promptTextViewDidRequestMenuMove(_ textView: PromptTextView, delta: Int)
    func promptTextViewDidRequestClose(_ textView: PromptTextView)
    func promptTextViewDidRequestCommit(_ textView: PromptTextView)
    func promptTextViewDidRequestUndo(_ textView: PromptTextView)
    func promptTextViewDidRequestRedo(_ textView: PromptTextView)
    func promptTextViewMenuIsVisible(_ textView: PromptTextView) -> Bool
}

final class PromptTextView: NSTextView {
    weak var promptDelegate: PromptTextViewDelegate?
    var placeholder = "输入 / 打开系统模板或我的模板"

    override var acceptsFirstResponder: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard string.isEmpty, !placeholder.isEmpty else { return }
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font ?? AppTheme.regular(AppTheme.editorFontSize),
            .foregroundColor: NSColor.placeholderTextColor
        ]
        let origin = NSPoint(x: textContainerInset.width + 4, y: textContainerInset.height + 1)
        placeholder.draw(at: origin, withAttributes: attributes)
    }

    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let keyCode = event.keyCode
        let characters = event.charactersIgnoringModifiers ?? ""
        let menuVisible = promptDelegate?.promptTextViewMenuIsVisible(self) ?? false

        let isCommandOnly = flags.contains(.command)
            && !flags.contains(.shift)
            && !flags.contains(.option)
            && !flags.contains(.control)

        if isCommandOnly, keyCode == 6 {
            promptDelegate?.promptTextViewDidRequestUndo(self)
            return
        }

        if flags.contains(.command), keyCode == 36 {
            promptDelegate?.promptTextViewDidRequestCommit(self)
            return
        }

        if keyCode == 53 {
            promptDelegate?.promptTextViewDidRequestClose(self)
            return
        }

        if keyCode == 48 {
            if menuVisible {
                promptDelegate?.promptTextViewDidRequestModeSwitch(self)
            } else {
                promptDelegate?.promptTextViewDidRequestPlaceholderJump(self)
            }
            return
        }

        if menuVisible {
            if keyCode == 125 {
                promptDelegate?.promptTextViewDidRequestMenuMove(self, delta: 1)
                return
            }
            if keyCode == 126 {
                promptDelegate?.promptTextViewDidRequestMenuMove(self, delta: -1)
                return
            }
            if keyCode == 36 {
                promptDelegate?.promptTextViewDidRequestSelection(self)
                return
            }
        }

        if characters == "/" {
            promptDelegate?.promptTextViewDidRequestMenu(self)
            return
        }

        super.keyDown(with: event)
    }

    @objc func undo(_ sender: Any?) {
        promptDelegate?.promptTextViewDidRequestUndo(self)
    }

    @objc func redo(_ sender: Any?) {
        promptDelegate?.promptTextViewDidRequestRedo(self)
    }

    override func insertTab(_ sender: Any?) {
        if promptDelegate?.promptTextViewMenuIsVisible(self) == true {
            promptDelegate?.promptTextViewDidRequestModeSwitch(self)
        } else {
            promptDelegate?.promptTextViewDidRequestPlaceholderJump(self)
        }
    }

    override func insertBacktab(_ sender: Any?) {
        insertTab(sender)
    }
}

final class PromptPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class CommandRowView: NSControl {
    static let rowHeight: CGFloat = 58

    private let symbolView = NSImageView()
    private let textContainer = NSView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let detailLabel = NSTextField(labelWithString: "")
    private let badgeLabel = NSTextField(labelWithString: "")
    var onChoose: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureLayout()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureLayout()
    }

    func configure(with item: LibraryItem, isSelected: Bool) {
        let image = NSImage(systemSymbolName: item.symbolName, accessibilityDescription: nil)
        image?.isTemplate = true
        symbolView.image = image
        symbolView.contentTintColor = .secondaryLabelColor
        AppTheme.applyTextStyle(to: titleLabel, text: item.title, size: 13, weight: .medium)
        AppTheme.applyTextStyle(to: detailLabel, text: item.detail, size: 12, color: .secondaryLabelColor)
        AppTheme.applyTextStyle(to: badgeLabel, text: item.badge, size: 11, weight: .medium, color: .secondaryLabelColor, alignment: .right)
        setSelected(isSelected)
        toolTip = "\(item.title)\n\(item.detail)"
    }

    func setSelected(_ isSelected: Bool) {
        layer?.backgroundColor = isSelected
            ? NSColor.controlAccentColor.withAlphaComponent(0.22).cgColor
            : NSColor.clear.cgColor
        layer?.borderColor = isSelected
            ? NSColor.controlAccentColor.withAlphaComponent(0.3).cgColor
            : NSColor.clear.cgColor
    }

    override func mouseDown(with event: NSEvent) {
        onChoose?()
    }

    private func configureLayout() {
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = 9
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.borderWidth = 1
        symbolView.translatesAutoresizingMaskIntoConstraints = false
        symbolView.imageScaling = .scaleProportionallyDown
        symbolView.setContentHuggingPriority(.required, for: .horizontal)

        textContainer.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = AppTheme.medium(13)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.drawsBackground = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        detailLabel.font = AppTheme.regular(12)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.lineBreakMode = .byTruncatingTail
        detailLabel.drawsBackground = false
        detailLabel.translatesAutoresizingMaskIntoConstraints = false
        detailLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        detailLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        badgeLabel.font = AppTheme.medium(11)
        badgeLabel.textColor = .secondaryLabelColor
        badgeLabel.alignment = .right
        badgeLabel.lineBreakMode = .byTruncatingTail
        badgeLabel.drawsBackground = false
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        badgeLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        addSubview(symbolView)
        addSubview(textContainer)
        addSubview(badgeLabel)
        textContainer.addSubview(titleLabel)
        textContainer.addSubview(detailLabel)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: Self.rowHeight),

            symbolView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            symbolView.centerYAnchor.constraint(equalTo: centerYAnchor),
            symbolView.widthAnchor.constraint(equalToConstant: 24),
            symbolView.heightAnchor.constraint(equalToConstant: 24),

            textContainer.leadingAnchor.constraint(equalTo: symbolView.trailingAnchor, constant: 12),
            textContainer.trailingAnchor.constraint(equalTo: badgeLabel.leadingAnchor, constant: -10),
            textContainer.centerYAnchor.constraint(equalTo: centerYAnchor),
            textContainer.heightAnchor.constraint(equalToConstant: 36),

            titleLabel.leadingAnchor.constraint(equalTo: textContainer.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: textContainer.trailingAnchor),
            titleLabel.topAnchor.constraint(equalTo: textContainer.topAnchor),
            titleLabel.heightAnchor.constraint(equalToConstant: 17),

            detailLabel.leadingAnchor.constraint(equalTo: textContainer.leadingAnchor),
            detailLabel.trailingAnchor.constraint(equalTo: textContainer.trailingAnchor),
            detailLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            detailLabel.heightAnchor.constraint(equalToConstant: 16),

            badgeLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            badgeLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            badgeLabel.widthAnchor.constraint(equalToConstant: 70)
        ])
    }
}

final class PromptWindowController: NSWindowController, NSTextViewDelegate, PromptTextViewDelegate {
    private static let preferredWindowWidth: CGFloat = 700
    private static let defaultActionsHint = "Tab 切换占位符 · ⌘↵ 复制 · Esc 收起"
    private static let contextTimestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private struct EditorSnapshot {
        let text: String
        let origin: TemplateOrigin?
        let title: String?
        let selectedRange: NSRange
    }
    private struct ConversationTurn {
        let query: String
        let result: String
        let actionTitle: String
        let createdAt: Date
    }

    private let navigator = PlaceholderNavigator()
    var onOpenSettings: (() -> Void)?
    var onManageTemplates: (() -> Void)?
    var onTemplateSaved: (() -> Void)?
    private var currentMode: LibraryMode = .prompt
    private var selectedIndex: Int = 0
    private var commandMenuVisible = false
    private var isRunningAI = false

    private let rootView = NSVisualEffectView()
    private let contentStack = NSStackView()
    private let topBar = NSStackView()
    private let titleLabel = NSTextField(labelWithString: AppIdentity.current.displayName)
    private let subtitleLabel = NSTextField(labelWithString: "输入 / 打开指令菜单")
    private let clearButton = NSButton(title: "清空", target: nil, action: nil)
    private let contextSummaryButton = NSButton(title: "", target: nil, action: nil)
    private let contextPanel = NSVisualEffectView()
    private let contextPanelScrollView = HistoryScrollView()
    private let contextPanelTextView = NSTextView()
    private let scrollView = NSScrollView()
    private let textView = PromptTextView()
    private let templateSuggestionView = TemplateSuggestionView()

    private let dropdownContainer = NSStackView()
    private let dropdownHeaderStack = NSStackView()
    private let modeControl = NSSegmentedControl(labels: ["系统模板", "我的模板"], trackingMode: .selectOne, target: nil, action: nil)
    private let manageTemplatesButton = NSButton()
    private let commandListView = NSStackView()
    private let commandListScrollView = NSScrollView()
    private let footerLabel = NSTextField(labelWithString: "↑↓ 选择 · ↵ 插入结构化模板 · Tab 切换数据源")

    private let actionsContainer = NSStackView()
    private let actionsLabel = NSTextField(labelWithString: PromptWindowController.defaultActionsHint)
    private let refineButton = NSButton(title: "AI 微调", target: nil, action: nil)
    private let regenerateButton = NSButton(title: "重新生成", target: nil, action: nil)
    private let clarifyButton = NSButton(title: "追问模式", target: nil, action: nil)
    private let updateTemplateButton = NSButton(title: "更新模板", target: nil, action: nil)
    private let saveTemplateButton = NSButton(title: "存为模板", target: nil, action: nil)
    private let commitButton = NSButton(title: "复制", target: nil, action: nil)
    private let clarificationPanel = ClarificationPanelView()

    private var editorHeightConstraint: NSLayoutConstraint?
    private var commandListHeightConstraint: NSLayoutConstraint?
    private var commandRows: [CommandRowView] = []
    private var pendingTemplateMatch: PromptTemplateMatch?
    private var ignoredTemplateTitles = Set<String>()
    private var templateMatchWorkItem: DispatchWorkItem?
    private var isApplyingTemplateSuggestion = false
    private var templatePreviewController: TemplatePreviewWindowController?
    private var actionsFeedbackWorkItem: DispatchWorkItem?
    private var activeTemplateOrigin: TemplateOrigin?
    private var activeTemplateTitle: String?
    private var undoSnapshots: [EditorSnapshot] = []
    private var redoSnapshots: [EditorSnapshot] = []
    private var isRestoringEditorSnapshot = false
    private var conversationTurns: [ConversationTurn] = []
    private var isContextPanelExpanded = false
    private var clarificationSession: ClarificationSession?
    private var pendingClarificationRound: ClarificationRound?
    private var pendingClarificationQuestionIndex = 0
    private var pendingClarificationAnswers: [ClarificationAnswer] = []
    private var clarificationRunID: UUID?

    init() {
        let panel = PromptPanel(
            contentRect: NSRect(x: 0, y: 0, width: Self.preferredWindowWidth, height: 124),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isRestorable = false
        panel.isReleasedWhenClosed = false
        AppTheme.configureGlassWindow(panel)
        super.init(window: panel)
        configureUI()
        refreshMenu()
        commandMenuVisible = false
        updateSecondaryVisibility(animated: false)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func toggle() {
        if window?.isVisible == true {
            hide()
        } else {
            show()
        }
    }

    func show() {
        guard let window else { return }
        positionWindow(window)
        NSApp.activate(ignoringOtherApps: true)
        NSApp.unhide(nil)
        window.deminiaturize(nil)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        window.makeFirstResponder(textView)
        resizeWindowForContent(animated: false)
    }

    func hide() {
        commandMenuVisible = false
        pendingTemplateMatch = nil
        templateMatchWorkItem?.cancel()
        updateSecondaryVisibility(animated: false)
        window?.orderOut(nil)
    }

    private func configureUI() {
        guard let contentView = window?.contentView else { return }
        configureRoot(in: contentView)
        configureInput()
        configureTemplateSuggestion()
        configureDropdown()
        configureClarification()
        configureActions()
        installLayout(in: contentView)

        updateTabs()
        updatePlaceholderVisibility()
        adjustEditorHeight(animated: false)
    }

    private func configureRoot(in contentView: NSView) {
        rootView.translatesAutoresizingMaskIntoConstraints = false
        rootView.material = .hudWindow
        rootView.blendingMode = .behindWindow
        rootView.state = .active
        rootView.wantsLayer = true
        rootView.layer?.cornerRadius = 18
        rootView.layer?.masksToBounds = true
        contentView.addSubview(rootView)
    }

    private func configureInput() {
        contentStack.orientation = .vertical
        contentStack.spacing = 8
        contentStack.alignment = .leading
        contentStack.distribution = .fill
        contentStack.detachesHiddenViews = true
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = AppTheme.semibold(AppTheme.titleFontSize)
        subtitleLabel.font = AppTheme.regular(AppTheme.bodyFontSize)
        subtitleLabel.textColor = .secondaryLabelColor

        let labelStack = NSStackView(views: [titleLabel, subtitleLabel])
        labelStack.orientation = .vertical
        labelStack.spacing = 1
        labelStack.alignment = .leading

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        clearButton.target = self
        clearButton.action = #selector(clearInput)
        clearButton.bezelStyle = .rounded
        clearButton.controlSize = .small
        clearButton.font = AppTheme.medium(11)

        topBar.orientation = .horizontal
        topBar.spacing = 8
        topBar.alignment = .centerY
        topBar.translatesAutoresizingMaskIntoConstraints = false
        topBar.addArrangedSubview(labelStack)
        topBar.addArrangedSubview(spacer)
        topBar.addArrangedSubview(clearButton)

        configureContextHistory()

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.wantsLayer = true
        scrollView.layer?.cornerRadius = 10
        scrollView.layer?.backgroundColor = NSColor.textBackgroundColor.withAlphaComponent(0.28).cgColor
        scrollView.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.35).cgColor
        scrollView.layer?.borderWidth = 1
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        textView.translatesAutoresizingMaskIntoConstraints = true
        textView.autoresizingMask = [.width]
        textView.frame = NSRect(x: 0, y: 0, width: 612, height: 52)
        textView.promptDelegate = self
        textView.delegate = self
        textView.isRichText = false
        textView.allowsUndo = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.font = AppTheme.regular(AppTheme.editorFontSize)
        textView.textColor = .labelColor
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 0, height: 8)
        textView.minSize = NSSize(width: 0, height: 34)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 612, height: CGFloat.greatestFiniteMagnitude)
        textView.placeholder = "输入问题，或键入 / 触发上下文指令..."
        scrollView.documentView = textView

        contentStack.addArrangedSubview(topBar)
        contentStack.addArrangedSubview(contextSummaryButton)
        contentStack.addArrangedSubview(contextPanel)
        contentStack.addArrangedSubview(scrollView)
        rootView.addSubview(contentStack)
    }

    private func configureContextHistory() {
        contextSummaryButton.translatesAutoresizingMaskIntoConstraints = false
        contextSummaryButton.target = self
        contextSummaryButton.action = #selector(contextSummaryPressed)
        contextSummaryButton.bezelStyle = .rounded
        contextSummaryButton.controlSize = .small
        contextSummaryButton.alignment = .left
        contextSummaryButton.font = AppTheme.medium(11)
        contextSummaryButton.cell?.lineBreakMode = .byTruncatingTail
        contextSummaryButton.image = NSImage(systemSymbolName: "clock.arrow.circlepath", accessibilityDescription: "上下文历史")
        contextSummaryButton.image?.isTemplate = true
        contextSummaryButton.imagePosition = .imageLeading
        contextSummaryButton.contentTintColor = .labelColor
        contextSummaryButton.toolTip = "点击查看完整上下文"
        contextSummaryButton.isHidden = true
        contextSummaryButton.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        contextPanel.translatesAutoresizingMaskIntoConstraints = false
        contextPanel.material = .hudWindow
        contextPanel.blendingMode = .withinWindow
        contextPanel.state = .active
        contextPanel.wantsLayer = true
        contextPanel.layer?.cornerRadius = 10
        contextPanel.layer?.borderColor = NSColor.white.withAlphaComponent(0.32).cgColor
        contextPanel.layer?.borderWidth = 1
        contextPanel.layer?.masksToBounds = true
        contextPanel.isHidden = true

        contextPanelScrollView.translatesAutoresizingMaskIntoConstraints = false
        contextPanelScrollView.borderType = .noBorder
        contextPanelScrollView.drawsBackground = false
        contextPanelScrollView.hasVerticalScroller = true
        contextPanelScrollView.autohidesScrollers = true

        contextPanelTextView.translatesAutoresizingMaskIntoConstraints = true
        contextPanelTextView.configureHistoryWrapping()
        contextPanelTextView.frame = NSRect(x: 0, y: 0, width: 650, height: 134)
        contextPanelTextView.isEditable = false
        contextPanelTextView.isSelectable = true
        contextPanelTextView.isRichText = false
        contextPanelTextView.drawsBackground = false
        contextPanelTextView.font = AppTheme.regular(11)
        contextPanelTextView.textColor = .labelColor
        contextPanelTextView.textContainerInset = NSSize(width: 8, height: 8)
        contextPanelTextView.textContainer?.widthTracksTextView = true
        contextPanelTextView.textContainer?.containerSize = NSSize(width: 650, height: CGFloat.greatestFiniteMagnitude)
        contextPanelScrollView.documentView = contextPanelTextView

        contextPanel.addSubview(contextPanelScrollView)

        NSLayoutConstraint.activate([
            contextPanelScrollView.leadingAnchor.constraint(equalTo: contextPanel.leadingAnchor, constant: 4),
            contextPanelScrollView.trailingAnchor.constraint(equalTo: contextPanel.trailingAnchor, constant: -4),
            contextPanelScrollView.topAnchor.constraint(equalTo: contextPanel.topAnchor, constant: 4),
            contextPanelScrollView.bottomAnchor.constraint(equalTo: contextPanel.bottomAnchor, constant: -4)
        ])
    }

    private func configureTemplateSuggestion() {
        templateSuggestionView.isHidden = true
        templateSuggestionView.onApply = { [weak self] in
            self?.applyTemplateSuggestion()
        }
        templateSuggestionView.onIgnore = { [weak self] in
            self?.ignoreTemplateSuggestion()
        }
        contentStack.addArrangedSubview(templateSuggestionView)
    }

    private func configureDropdown() {
        dropdownContainer.orientation = .vertical
        dropdownContainer.spacing = 8
        dropdownContainer.alignment = .leading
        dropdownContainer.detachesHiddenViews = true
        dropdownContainer.translatesAutoresizingMaskIntoConstraints = false
        dropdownContainer.isHidden = true

        modeControl.target = self
        modeControl.action = #selector(modeControlChanged)
        modeControl.selectedSegment = currentMode.rawValue
        modeControl.segmentStyle = .rounded
        modeControl.controlSize = .regular
        modeControl.font = AppTheme.medium(12)
        modeControl.translatesAutoresizingMaskIntoConstraints = false

        manageTemplatesButton.image = NSImage(systemSymbolName: "slider.horizontal.3", accessibilityDescription: "管理我的模板")
        manageTemplatesButton.image?.isTemplate = true
        manageTemplatesButton.bezelStyle = .rounded
        manageTemplatesButton.controlSize = .regular
        manageTemplatesButton.target = self
        manageTemplatesButton.action = #selector(manageTemplatesPressed)
        manageTemplatesButton.toolTip = "管理我的模板库"
        manageTemplatesButton.translatesAutoresizingMaskIntoConstraints = false

        let headerSpacer = NSView()
        headerSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        dropdownHeaderStack.orientation = .horizontal
        dropdownHeaderStack.spacing = 8
        dropdownHeaderStack.alignment = .centerY
        dropdownHeaderStack.translatesAutoresizingMaskIntoConstraints = false
        dropdownHeaderStack.addArrangedSubview(modeControl)
        dropdownHeaderStack.addArrangedSubview(headerSpacer)
        dropdownHeaderStack.addArrangedSubview(manageTemplatesButton)

        commandListView.orientation = .vertical
        commandListView.spacing = 2
        commandListView.alignment = .leading
        commandListView.distribution = .fill
        commandListView.edgeInsets = NSEdgeInsets(top: 6, left: 6, bottom: 6, right: 6)
        commandListView.translatesAutoresizingMaskIntoConstraints = true
        commandListView.autoresizingMask = [.width]
        commandListView.wantsLayer = true
        commandListView.layer?.cornerRadius = 10
        commandListView.layer?.backgroundColor = NSColor.textBackgroundColor.withAlphaComponent(0.2).cgColor
        commandListView.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.3).cgColor
        commandListView.layer?.borderWidth = 1

        commandListScrollView.translatesAutoresizingMaskIntoConstraints = false
        commandListScrollView.drawsBackground = false
        commandListScrollView.hasVerticalScroller = true
        commandListScrollView.hasHorizontalScroller = false
        commandListScrollView.autohidesScrollers = true
        commandListScrollView.documentView = commandListView

        footerLabel.font = AppTheme.regular(AppTheme.bodyFontSize)
        footerLabel.textColor = .secondaryLabelColor

        dropdownContainer.addArrangedSubview(dropdownHeaderStack)
        dropdownContainer.addArrangedSubview(commandListScrollView)
        dropdownContainer.addArrangedSubview(footerLabel)
        contentStack.addArrangedSubview(dropdownContainer)
    }

    private func configureActions() {
        actionsContainer.orientation = .horizontal
        actionsContainer.spacing = 8
        actionsContainer.alignment = .centerY
        actionsContainer.detachesHiddenViews = true
        actionsContainer.translatesAutoresizingMaskIntoConstraints = false
        actionsContainer.isHidden = true

        actionsLabel.font = AppTheme.regular(AppTheme.bodyFontSize)
        actionsLabel.textColor = .secondaryLabelColor

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        refineButton.target = self
        refineButton.action = #selector(refineButtonPressed)
        refineButton.bezelStyle = .rounded
        refineButton.controlSize = .regular
        refineButton.font = AppTheme.medium(12)

        regenerateButton.target = self
        regenerateButton.action = #selector(regenerateButtonPressed)
        regenerateButton.bezelStyle = .rounded
        regenerateButton.controlSize = .regular
        regenerateButton.font = AppTheme.medium(12)

        clarifyButton.target = self
        clarifyButton.action = #selector(clarifyButtonPressed)
        clarifyButton.bezelStyle = .rounded
        clarifyButton.controlSize = .regular
        clarifyButton.font = AppTheme.medium(12)
        clarifyButton.toolTip = "信息不足时逐轮追问，清晰后生成最终 Prompt"

        updateTemplateButton.target = self
        updateTemplateButton.action = #selector(updateTemplateButtonPressed)
        updateTemplateButton.bezelStyle = .rounded
        updateTemplateButton.controlSize = .regular
        updateTemplateButton.font = AppTheme.medium(12)
        updateTemplateButton.isHidden = true

        saveTemplateButton.target = self
        saveTemplateButton.action = #selector(saveTemplateButtonPressed)
        saveTemplateButton.bezelStyle = .rounded
        saveTemplateButton.controlSize = .regular
        saveTemplateButton.font = AppTheme.medium(12)

        commitButton.target = self
        commitButton.action = #selector(commitButtonPressed)
        commitButton.bezelStyle = .rounded
        commitButton.controlSize = .regular
        commitButton.font = AppTheme.medium(12)

        actionsContainer.addArrangedSubview(actionsLabel)
        actionsContainer.addArrangedSubview(spacer)
        actionsContainer.addArrangedSubview(refineButton)
        actionsContainer.addArrangedSubview(regenerateButton)
        actionsContainer.addArrangedSubview(clarifyButton)
        actionsContainer.addArrangedSubview(updateTemplateButton)
        actionsContainer.addArrangedSubview(saveTemplateButton)
        actionsContainer.addArrangedSubview(commitButton)
        contentStack.addArrangedSubview(actionsContainer)
    }

    private func configureClarification() {
        clarificationPanel.isHidden = true
        clarificationPanel.onSubmit = { [weak self] answer in
            self?.submitClarificationAnswer(answer)
        }
        contentStack.addArrangedSubview(clarificationPanel)
    }

    private func installLayout(in contentView: NSView) {
        editorHeightConstraint = scrollView.heightAnchor.constraint(equalToConstant: 34)
        commandListHeightConstraint = commandListScrollView.heightAnchor.constraint(equalToConstant: 0)

        NSLayoutConstraint.activate([
            rootView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            rootView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            rootView.topAnchor.constraint(equalTo: contentView.topAnchor),
            rootView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            rootView.widthAnchor.constraint(equalToConstant: Self.preferredWindowWidth),

            contentStack.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 14),
            contentStack.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -14),
            contentStack.topAnchor.constraint(equalTo: rootView.topAnchor, constant: 14),
            contentStack.bottomAnchor.constraint(equalTo: rootView.bottomAnchor, constant: -14),

            topBar.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            topBar.heightAnchor.constraint(equalToConstant: 32),

            contextSummaryButton.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            contextSummaryButton.heightAnchor.constraint(equalToConstant: 28),
            contextPanel.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            contextPanel.heightAnchor.constraint(equalToConstant: 150),

            scrollView.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            editorHeightConstraint!,
            templateSuggestionView.widthAnchor.constraint(equalTo: contentStack.widthAnchor),

            dropdownContainer.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            dropdownHeaderStack.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            modeControl.widthAnchor.constraint(equalToConstant: 240),
            manageTemplatesButton.widthAnchor.constraint(equalToConstant: 34),
            commandListScrollView.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            commandListHeightConstraint!,

            clarificationPanel.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            clarificationPanel.heightAnchor.constraint(equalToConstant: ClarificationPanelView.preferredHeight),

            actionsContainer.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            actionsContainer.heightAnchor.constraint(equalToConstant: 32)
        ])
    }

    private func positionWindow(_ window: NSWindow) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main ?? NSScreen.screens.first
        let visibleFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let size = NSSize(width: Self.preferredWindowWidth, height: window.frame.height)
        window.setContentSize(NSSize(width: Self.preferredWindowWidth, height: max(1, window.contentView?.frame.height ?? window.frame.height)))
        let origin = NSPoint(
            x: visibleFrame.midX - size.width / 2,
            y: visibleFrame.maxY - size.height - 120
        )
        window.setFrameOrigin(origin)
    }

    private func resizeWindowForContent(animated: Bool) {
        guard let window else { return }
        let editorHeight = editorHeightConstraint?.constant ?? 34
        let secondaryHeight = commandMenuVisible ? dropdownHeight : normalSecondaryHeight
        let desiredHeight = editorHeight + 82 + contextHistoryHeight + (secondaryHeight > 0 ? secondaryHeight + 8 : 0)
        var frame = window.frame
        let oldMaxY = frame.maxY
        frame.size.width = Self.preferredWindowWidth
        frame.size.height = desiredHeight
        let visibleFrame = (window.screen ?? NSScreen.main)?.visibleFrame
        if let visibleFrame {
            frame.origin.y = max(visibleFrame.minY + 12, min(oldMaxY - desiredHeight, visibleFrame.maxY - desiredHeight - 12))
        } else {
            frame.origin.y = oldMaxY - desiredHeight
        }

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                window.animator().setFrame(frame, display: true)
                window.contentView?.layoutSubtreeIfNeeded()
            }
        } else {
            window.setFrame(frame, display: true)
        }
    }

    private var shouldShowActions: Bool {
        !commandMenuVisible
            && pendingClarificationRound == nil
            && !textView.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var shouldShowTemplateSuggestion: Bool {
        clarificationSession == nil && pendingTemplateMatch != nil && !commandMenuVisible
    }

    private var normalSecondaryHeight: CGFloat {
        var visibleHeights: [CGFloat] = []
        if shouldShowTemplateSuggestion { visibleHeights.append(TemplateSuggestionView.height) }
        if pendingClarificationRound != nil { visibleHeights.append(ClarificationPanelView.preferredHeight) }
        if shouldShowActions { visibleHeights.append(32) }
        guard !visibleHeights.isEmpty else { return 0 }
        return visibleHeights.reduce(0, +) + CGFloat(visibleHeights.count - 1) * 8
    }

    private var contextHistoryHeight: CGFloat {
        guard !conversationTurns.isEmpty else { return 0 }
        return 28 + 8 + (isContextPanelExpanded ? 150 + 8 : 0)
    }

    private var dropdownHeight: CGFloat {
        return 32 + 8 + commandListHeight + 8 + 18
    }

    private var commandListHeight: CGFloat {
        let available = (window?.screen?.visibleFrame.height ?? 900) - (editorHeightConstraint?.constant ?? 34) - contextHistoryHeight - 230
        return min(commandDocumentHeight, max(120, min(420, available)))
    }

    private var commandDocumentHeight: CGFloat {
        let count = CGFloat(PromptStore.items(for: currentMode).count)
        guard count > 0 else { return 0 }
        return 12 + count * CommandRowView.rowHeight + max(0, count - 1) * commandListView.spacing
    }

    private func updateTabs() {
        modeControl.selectedSegment = currentMode.rawValue
        manageTemplatesButton.isHidden = currentMode != .skill
    }

    private func updatePlaceholderVisibility() {
        clearButton.isHidden = textView.string.isEmpty
        textView.needsDisplay = true
    }

    private func currentEditorSnapshot() -> EditorSnapshot {
        EditorSnapshot(
            text: textView.string,
            origin: activeTemplateOrigin,
            title: activeTemplateTitle,
            selectedRange: textView.selectedRange()
        )
    }

    private func editorSnapshot(text: String, origin: TemplateOrigin?, title: String?, selectedRange: NSRange? = nil) -> EditorSnapshot {
        EditorSnapshot(
            text: text,
            origin: origin,
            title: title,
            selectedRange: selectedRange ?? NSRange(location: min((text as NSString).length, textView.selectedRange().location), length: 0)
        )
    }

    private func snapshotsEqual(_ lhs: EditorSnapshot, _ rhs: EditorSnapshot) -> Bool {
        lhs.text == rhs.text
            && lhs.origin == rhs.origin
            && lhs.title == rhs.title
            && lhs.selectedRange.location == rhs.selectedRange.location
            && lhs.selectedRange.length == rhs.selectedRange.length
    }

    private func registerEditorUndoStep() {
        guard !isRestoringEditorSnapshot else { return }
        let snapshot = currentEditorSnapshot()
        if let last = undoSnapshots.last, snapshotsEqual(last, snapshot) {
            return
        }
        undoSnapshots.append(snapshot)
        if undoSnapshots.count > 100 {
            undoSnapshots.removeFirst(undoSnapshots.count - 100)
        }
        redoSnapshots.removeAll()
    }

    private func applyEditorSnapshot(_ snapshot: EditorSnapshot, actionName: String, registersUndo: Bool = true) {
        if registersUndo {
            registerEditorUndoStep()
        }

        isRestoringEditorSnapshot = true
        activeTemplateOrigin = snapshot.origin
        activeTemplateTitle = snapshot.title
        textView.string = snapshot.text
        isRestoringEditorSnapshot = false
        updatePlaceholderVisibility()
        adjustEditorHeight(animated: true)
        updateSecondaryVisibility(animated: true)

        let textLength = (snapshot.text as NSString).length
        let safeLocation = min(max(0, snapshot.selectedRange.location), textLength)
        let safeLength = min(max(0, snapshot.selectedRange.length), textLength - safeLocation)
        let safeRange = NSRange(location: safeLocation, length: safeLength)
        textView.setSelectedRange(safeRange)
        textView.scrollRangeToVisible(safeRange)
        window?.makeFirstResponder(textView)
    }

    private func performEditorUndo() {
        guard let snapshot = undoSnapshots.popLast() else {
            NSSound.beep()
            return
        }
        redoSnapshots.append(currentEditorSnapshot())
        applyEditorSnapshot(snapshot, actionName: "撤销", registersUndo: false)
        refreshEditorAfterUndoRedo()
    }

    private func performEditorRedo() {
        guard let snapshot = redoSnapshots.popLast() else {
            NSSound.beep()
            return
        }
        undoSnapshots.append(currentEditorSnapshot())
        applyEditorSnapshot(snapshot, actionName: "重做", registersUndo: false)
        refreshEditorAfterUndoRedo()
    }

    private func refreshEditorAfterUndoRedo() {
        updatePlaceholderVisibility()
        adjustEditorHeight(animated: true)
        updateSecondaryVisibility(animated: true)
        window?.makeFirstResponder(textView)
    }

    @objc private func modeControlChanged() {
        currentMode = LibraryMode(rawValue: modeControl.selectedSegment) ?? .prompt
        selectedIndex = 0
        refreshMenu()
    }

    @objc private func clearInput() {
        selectedIndex = 0
        commandMenuVisible = false
        pendingTemplateMatch = nil
        ignoredTemplateTitles.removeAll()
        templateMatchWorkItem?.cancel()
        resetClarification()
        resetConversationContext()
        applyEditorSnapshot(
            editorSnapshot(text: "", origin: nil, title: nil, selectedRange: NSRange(location: 0, length: 0)),
            actionName: "清空"
        )
    }

    private func refreshMenu() {
        updateTabs()
        rebuildCommandRows()
        refreshSelectionChrome()
        commandListHeightConstraint?.constant = commandListHeight
        resizeWindowForContent(animated: commandMenuVisible)
    }

    private func rebuildCommandRows() {
        commandRows.forEach { row in
            commandListView.removeArrangedSubview(row)
            row.removeFromSuperview()
        }
        commandRows = []

        let items = PromptStore.items(for: currentMode)
        for (index, item) in items.enumerated() {
            let row = CommandRowView()
            row.configure(with: item, isSelected: index == selectedIndex)
            row.onChoose = { [weak self] in
                self?.selectedIndex = index
                self?.insertSelectedTemplate()
            }
            commandListView.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: commandListView.widthAnchor, constant: -12).isActive = true
            commandRows.append(row)
        }
        commandListView.setFrameSize(NSSize(width: Self.preferredWindowWidth - 28, height: commandDocumentHeight))
        commandListView.layoutSubtreeIfNeeded()
        if commandRows.indices.contains(selectedIndex) {
            commandListView.scrollToVisible(commandRows[selectedIndex].frame)
        }
    }

    private func refreshSelectionChrome() {
        let itemCount = PromptStore.items(for: currentMode).count
        if selectedIndex < 0 || selectedIndex >= itemCount {
            return
        }
        for (index, row) in commandRows.enumerated() {
            row.setSelected(index == selectedIndex)
        }
        commandListView.scrollToVisible(commandRows[selectedIndex].frame)
    }

    private func showCommandMenu() {
        commandMenuVisible = true
        pendingTemplateMatch = nil
        templateMatchWorkItem?.cancel()
        selectedIndex = min(selectedIndex, max(0, PromptStore.items(for: currentMode).count - 1))
        refreshMenu()
        updateSecondaryVisibility(animated: true)
    }

    private func updateSecondaryVisibility(animated: Bool) {
        adjustEditorHeight(animated: false)
        let showActions = shouldShowActions
        let showSuggestion = shouldShowTemplateSuggestion
        let showClarification = pendingClarificationRound != nil && !commandMenuVisible
        updateTemplateButtonVisibility()
        updateContextHistoryVisibility()
        let changes = {
            self.templateSuggestionView.isHidden = !showSuggestion
            self.clarificationPanel.isHidden = !showClarification
            self.dropdownContainer.isHidden = !self.commandMenuVisible
            self.actionsContainer.isHidden = !showActions
            self.commandListHeightConstraint?.constant = self.commandMenuVisible ? self.commandListHeight : 0
        }

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.14
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                changes()
                self.rootView.layoutSubtreeIfNeeded()
            }
        } else {
            changes()
        }
        resizeWindowForContent(animated: animated)
    }

    private func updateContextHistoryVisibility() {
        let hasContext = !conversationTurns.isEmpty
        contextSummaryButton.isHidden = !hasContext
        contextPanel.isHidden = !hasContext || !isContextPanelExpanded
        guard hasContext else {
            contextSummaryButton.title = ""
            contextPanelTextView.string = ""
            return
        }

        contextSummaryButton.title = contextSummaryText()
        contextPanelTextView.string = fullContextText()
    }

    private func contextSummaryText() -> String {
        guard let last = conversationTurns.last else { return "" }
        let summary = oneLineSummary(last.query, limit: 34)
        let result = oneLineSummary(last.result, limit: 26)
        let disclosure = isContextPanelExpanded ? "收起" : "展开"
        return "上一轮 \(last.actionTitle)：\(summary) → \(result) · \(disclosure)"
    }

    private func fullContextText() -> String {
        conversationTurns.enumerated().map { index, turn in
            """
            第 \(index + 1) 轮 · \(turn.actionTitle) · \(Self.contextTimestampFormatter.string(from: turn.createdAt))
            查询：
            \(turn.query)

            结果：
            \(turn.result)
            """
        }.joined(separator: "\n\n────────\n\n")
    }

    private func oneLineSummary(_ value: String, limit: Int) -> String {
        let collapsed = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        guard collapsed.count > limit else { return collapsed }
        return String(collapsed.prefix(limit)) + "..."
    }

    @objc private func contextSummaryPressed() {
        guard !conversationTurns.isEmpty else { return }
        isContextPanelExpanded.toggle()
        updateContextHistoryVisibility()
        resizeWindowForContent(animated: true)
        window?.makeFirstResponder(textView)
    }

    private func updateTemplateButtonVisibility() {
        let hasEditableTemplate = TemplateUpdatePolicy.current.allows(activeTemplateOrigin)
        let hasBody = !textView.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        updateTemplateButton.isHidden = !(hasEditableTemplate && hasBody)
        if let title = activeTemplateTitle, hasEditableTemplate {
            updateTemplateButton.toolTip = "用当前 Prompt 更新「\(title)」"
        } else {
            updateTemplateButton.toolTip = "从模板插入后，可用当前 Prompt 更新原模板"
        }
    }

    private func trackTemplateSource(_ item: LibraryItem) {
        activeTemplateOrigin = item.origin
        activeTemplateTitle = item.title
        updateTemplateButtonVisibility()
    }

    private func clearTemplateSource() {
        activeTemplateOrigin = nil
        activeTemplateTitle = nil
        updateTemplateButtonVisibility()
    }

    @objc private func commitButtonPressed() {
        copyPromptToClipboard()
    }

    @objc private func refineButtonPressed() {
        runAIAction(.refine)
    }

    @objc private func regenerateButtonPressed() {
        runAIAction(.regenerate)
    }

    @objc private func clarifyButtonPressed() {
        startClarification()
    }

    @objc private func saveTemplateButtonPressed() {
        runSaveAsTemplate()
    }

    @objc private func updateTemplateButtonPressed() {
        updateCurrentTemplate()
    }

    @objc private func manageTemplatesPressed() {
        onManageTemplates?()
    }

    private func aiContextTurns() -> [AIContextTurn] {
        conversationTurns.map { turn in
            AIContextTurn(actionTitle: turn.actionTitle, query: turn.query, result: turn.result)
        }
    }

    private func appendConversationTurn(query: String, result: String, actionTitle: String) {
        conversationTurns.append(ConversationTurn(
            query: query,
            result: result,
            actionTitle: actionTitle,
            createdAt: Date()
        ))
        if conversationTurns.count > 3 {
            conversationTurns.removeFirst(conversationTurns.count - 3)
        }
        isContextPanelExpanded = false
        updateContextHistoryVisibility()
        resizeWindowForContent(animated: true)
    }

    private func resetConversationContext() {
        conversationTurns.removeAll()
        isContextPanelExpanded = false
        updateContextHistoryVisibility()
    }

    private func startClarification() {
        guard !isRunningAI, clarificationSession == nil else { return }
        let input = textView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else {
            NSSound.beep()
            return
        }
        guard configuredAPIKey() != nil else { return }

        let session = ClarificationSession(originalQuery: input)
        let runID = UUID()
        pendingTemplateMatch = nil
        templateMatchWorkItem?.cancel()
        clarificationSession = session
        pendingClarificationRound = nil
        pendingClarificationQuestionIndex = 0
        pendingClarificationAnswers = []
        clarificationRunID = runID
        textView.isEditable = false
        isRunningAI = true
        setAIControlsEnabled(false, activeTitle: "追问分析中...")
        updateSecondaryVisibility(animated: true)
        evaluateClarification(session: session, runID: runID, fallbackSession: nil)
    }

    private func submitClarificationAnswer(_ answer: ClarificationAnswer) {
        guard
            !isRunningAI,
            var session = clarificationSession,
            let round = pendingClarificationRound,
            round.questions.indices.contains(pendingClarificationQuestionIndex),
            let runID = clarificationRunID
        else { return }

        pendingClarificationAnswers.append(answer)
        let nextIndex = pendingClarificationQuestionIndex + 1
        if round.questions.indices.contains(nextIndex) {
            pendingClarificationQuestionIndex = nextIndex
            showPendingClarificationQuestion()
            return
        }

        let previousSession = session
        session.appendRound(answers: pendingClarificationAnswers)
        clarificationSession = session
        isRunningAI = true
        clarificationPanel.setLoading(true)
        setAIControlsEnabled(false, activeTitle: "追问分析中...")
        evaluateClarification(session: session, runID: runID, fallbackSession: previousSession)
    }

    private func evaluateClarification(
        session: ClarificationSession,
        runID: UUID,
        fallbackSession: ClarificationSession?
    ) {
        Task { [weak self] in
            do {
                guard let apiKey = try KeychainStore.readAPIKey(), !apiKey.isEmpty else { throw CredentialVaultError.missingKey }
                let client = OpenAIClient(apiKey: apiKey, modelOption: AppSettings.modelOption)
                let decision = try await client.runClarification(session: session)
                await MainActor.run {
                    guard let self, self.clarificationRunID == runID else { return }
                    self.isRunningAI = false
                    self.setAIControlsEnabled(true)
                    switch decision {
                    case .ask(let round):
                        self.clarificationSession = session
                        self.pendingClarificationRound = round
                        self.pendingClarificationQuestionIndex = 0
                        self.pendingClarificationAnswers = []
                        self.showPendingClarificationQuestion()
                    case .final(let prompt):
                        self.completeClarification(prompt: prompt, session: session)
                    }
                }
            } catch {
                await MainActor.run {
                    guard let self, self.clarificationRunID == runID else { return }
                    self.isRunningAI = false
                    self.setAIControlsEnabled(true)
                    if let fallbackSession {
                        self.clarificationSession = fallbackSession
                        if !self.pendingClarificationAnswers.isEmpty {
                            self.pendingClarificationAnswers.removeLast()
                        }
                        if let round = self.pendingClarificationRound {
                            self.pendingClarificationQuestionIndex = max(0, round.questions.count - 1)
                        }
                        self.showPendingClarificationQuestion()
                    } else {
                        self.resetClarification()
                        self.updateSecondaryVisibility(animated: true)
                    }
                    self.showAlert(title: "追问模式失败", message: error.localizedDescription)
                }
            }
        }
    }

    private func showPendingClarificationQuestion() {
        guard
            let session = clarificationSession,
            let round = pendingClarificationRound,
            round.questions.indices.contains(pendingClarificationQuestionIndex)
        else { return }

        clarificationPanel.configure(
            question: round.questions[pendingClarificationQuestionIndex],
            round: session.nextRoundNumber,
            maximumRounds: ClarificationSession.maximumRounds,
            questionIndex: pendingClarificationQuestionIndex,
            totalQuestions: round.questions.count
        )
        updateSecondaryVisibility(animated: true)
        clarificationPanel.focusCustomAnswer()
    }

    private func completeClarification(prompt: String, session: ClarificationSession) {
        let historyQuery = session.historyQuery()
        resetClarification()
        applyEditorSnapshot(
            editorSnapshot(
                text: prompt,
                origin: activeTemplateOrigin,
                title: activeTemplateTitle,
                selectedRange: NSRange(location: 0, length: 0)
            ),
            actionName: "追问生成"
        )
        appendConversationTurn(query: historyQuery, result: prompt, actionTitle: "追问生成")
        highlightFirstPlaceholder()
        showActionsFeedback("已结合全部回答生成")
    }

    private func resetClarification() {
        clarificationRunID = nil
        clarificationSession = nil
        pendingClarificationRound = nil
        pendingClarificationQuestionIndex = 0
        pendingClarificationAnswers = []
        clarificationPanel.setLoading(false)
        textView.isEditable = true
    }

    private func runAIAction(_ action: AIAction) {
        guard !isRunningAI, clarificationSession == nil else {
            NSSound.beep()
            return
        }
        let input = textView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else {
            NSSound.beep()
            return
        }
        guard let apiKey = configuredAPIKey() else { return }

        isRunningAI = true
        setAIControlsEnabled(false, activeTitle: "\(action.buttonTitle)中...")
        let client = OpenAIClient(apiKey: apiKey, modelOption: AppSettings.modelOption)
        let inheritedContext = aiContextTurns()

        Task { [weak self] in
            do {
                let output = try await client.run(action: action, input: input, context: inheritedContext)
                await MainActor.run {
                    guard let self else { return }
                    self.applyEditorSnapshot(
                        self.editorSnapshot(
                            text: output,
                            origin: self.activeTemplateOrigin,
                            title: self.activeTemplateTitle,
                            selectedRange: NSRange(location: 0, length: 0)
                        ),
                        actionName: action.buttonTitle
                    )
                    self.appendConversationTurn(query: input, result: output, actionTitle: action.buttonTitle)
                    self.highlightFirstPlaceholder()
                    self.isRunningAI = false
                    self.setAIControlsEnabled(true)
                }
            } catch {
                await MainActor.run {
                    guard let self else { return }
                    self.isRunningAI = false
                    self.setAIControlsEnabled(true)
                    self.showAlert(title: "\(action.buttonTitle)失败", message: error.localizedDescription)
                }
            }
        }
    }

    private func runSaveAsTemplate() {
        guard !isRunningAI, clarificationSession == nil else {
            NSSound.beep()
            return
        }
        let input = textView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else {
            NSSound.beep()
            return
        }
        guard let apiKey = configuredAPIKey() else { return }

        isRunningAI = true
        setAIControlsEnabled(false, activeTitle: "生成模板中...")
        let client = OpenAIClient(apiKey: apiKey, modelOption: AppSettings.modelOption)

        Task { [weak self] in
            do {
                let draft = try await client.generateTemplateDraft(from: input)
                await MainActor.run {
                    guard let self else { return }
                    self.isRunningAI = false
                    self.setAIControlsEnabled(true)
                    self.showTemplatePreview(draft)
                }
            } catch {
                await MainActor.run {
                    guard let self else { return }
                    self.isRunningAI = false
                    self.setAIControlsEnabled(true)
                    self.showAlert(title: "生成模板失败", message: error.localizedDescription)
                }
            }
        }
    }

    private func showTemplatePreview(_ draft: TemplateDraft) {
        let controller = TemplatePreviewWindowController(draft: draft)
        controller.onSave = { [weak self] template in
            guard let self else { return }
            self.activeTemplateOrigin = .user(id: template.id)
            self.activeTemplateTitle = template.title
            self.onTemplateSaved?()
            self.currentMode = .skill
            self.selectedIndex = 0
            self.refreshMenu()
            self.updateSecondaryVisibility(animated: true)
            self.showActionsFeedback("已保存为模板")
        }
        templatePreviewController = controller
        controller.show()
    }

    private func updateCurrentTemplate() {
        guard let origin = activeTemplateOrigin, TemplateUpdatePolicy.current.allows(origin) else {
            NSSound.beep()
            return
        }
        let body = textView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else {
            NSSound.beep()
            return
        }

        let title: String
        let message: String
        switch origin {
        case .system:
            title = activeTemplateTitle ?? "系统模板"
            message = "将用当前编辑区的 Prompt 覆盖「\(title)」的本地系统模板版本。"
        case .user(let templateID):
            guard let existing = UserTemplateStore.all().first(where: { $0.id == templateID }) else {
                clearTemplateSource()
                showAlert(title: "无法更新模板", message: "原模板不存在，可能已在模板库中被删除。")
                return
            }
            title = existing.title
            message = "将用当前编辑区的 Prompt 覆盖「\(title)」的模板正文。"
        }

        guard confirmTemplateUpdate(title: title, message: message) else { return }

        do {
            try updateTemplate(origin: origin, title: title, body: body)
            activeTemplateTitle = title
            onTemplateSaved?()
            refreshMenu()
            updateSecondaryVisibility(animated: true)
            showActionsFeedback("模板已更新")
            window?.makeFirstResponder(textView)
        } catch {
            showAlert(title: "更新模板失败", message: error.localizedDescription)
        }
    }

    private func confirmTemplateUpdate(title: String, message: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = "更新模板？"
        alert.informativeText = message
        alert.addButton(withTitle: "更新")
        alert.addButton(withTitle: "取消")
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func updateTemplate(origin: TemplateOrigin, title: String, body: String) throws {
        switch origin {
        case .system(let id):
            try SystemTemplateOverrideStore.update(id: id, title: title, body: body)
        case .user(let templateID):
            guard var existing = UserTemplateStore.all().first(where: { $0.id == templateID }) else {
                clearTemplateSource()
                throw TemplateUpdateError.missingTemplate
            }
            existing.body = body
            try UserTemplateStore.update(existing)
        }
    }

    private func setAIControlsEnabled(_ enabled: Bool, activeTitle: String? = nil) {
        refineButton.isEnabled = enabled
        regenerateButton.isEnabled = enabled
        clarifyButton.isEnabled = enabled
        updateTemplateButton.isEnabled = enabled
        saveTemplateButton.isEnabled = enabled
        commitButton.isEnabled = enabled
        clearButton.isEnabled = enabled
        refineButton.title = activeTitle == "AI 微调中..." ? activeTitle! : "AI 微调"
        regenerateButton.title = activeTitle == "重新生成中..." ? activeTitle! : "重新生成"
        clarifyButton.title = activeTitle == "追问分析中..." ? activeTitle! : "追问模式"
        saveTemplateButton.title = activeTitle == "生成模板中..." ? activeTitle! : "存为模板"
    }

    private func scheduleTemplateSuggestionEvaluation() {
        templateMatchWorkItem?.cancel()
        let input = textView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            clarificationSession == nil,
            input.count >= 6,
            !commandMenuVisible,
            !isApplyingTemplateSuggestion
        else {
            pendingTemplateMatch = nil
            updateSecondaryVisibility(animated: true)
            return
        }
        let scheduledInput = input
        let item = DispatchWorkItem { [weak self] in
            self?.evaluateTemplateSuggestion(for: scheduledInput)
        }
        templateMatchWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: item)
    }

    private func evaluateTemplateSuggestion(for scheduledInput: String) {
        templateMatchWorkItem = nil
        let input = textView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            clarificationSession == nil,
            !input.isEmpty,
            !commandMenuVisible,
            !isApplyingTemplateSuggestion
        else {
            pendingTemplateMatch = nil
            updateSecondaryVisibility(animated: true)
            return
        }
        guard input == scheduledInput else { return }

        guard let match = PromptTemplateMatcher.bestMatch(for: input), !ignoredTemplateTitles.contains(match.item.title) else {
            return
        }

        pendingTemplateMatch = match
        templateSuggestionView.configure(with: match)
        updateSecondaryVisibility(animated: true)
    }

    private func applyTemplateSuggestion() {
        guard let match = pendingTemplateMatch else { return }
        let input = textView.string
        isApplyingTemplateSuggestion = true
        pendingTemplateMatch = nil
        templateMatchWorkItem?.cancel()
        let output = PromptTemplateMatcher.filledTemplate(from: match.item, userInput: input, navigator: navigator)
        applyEditorSnapshot(
            editorSnapshot(text: output, origin: match.item.origin, title: match.item.title, selectedRange: NSRange(location: 0, length: 0)),
            actionName: "套用模板"
        )
        commandMenuVisible = false
        updateSecondaryVisibility(animated: true)
        highlightFirstPlaceholder()
        isApplyingTemplateSuggestion = false
    }

    private func ignoreTemplateSuggestion() {
        if let match = pendingTemplateMatch {
            ignoredTemplateTitles.insert(match.item.title)
        }
        pendingTemplateMatch = nil
        templateMatchWorkItem?.cancel()
        updateSecondaryVisibility(animated: true)
        window?.makeFirstResponder(textView)
    }

    private func configuredAPIKey() -> String? {
        do {
            guard let value = try KeychainStore.readAPIKey(), !value.isEmpty else {
                showMissingAPIKeyAlert()
                return nil
            }
            return value
        } catch {
            showAlert(title: "读取 API Key 失败", message: error.localizedDescription)
            return nil
        }
    }

    private func showMissingAPIKeyAlert() {
        let alert = NSAlert()
        alert.messageText = "需要先配置模型 API Key"
        alert.informativeText = "请为当前供应商配置 API Key，密钥会保存在 macOS Keychain。"
        alert.addButton(withTitle: "打开设置")
        alert.addButton(withTitle: "取消")
        if alert.runModal() == .alertFirstButtonReturn {
            onOpenSettings?()
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "好")
        alert.runModal()
    }

    private func insertSelectedTemplate() {
        let items = PromptStore.items(for: currentMode)
        guard items.indices.contains(selectedIndex) else { return }
        let item = items[selectedIndex]
        pendingTemplateMatch = nil
        templateMatchWorkItem?.cancel()
        applyEditorSnapshot(
            editorSnapshot(text: item.body, origin: item.origin, title: item.title, selectedRange: NSRange(location: 0, length: 0)),
            actionName: "插入模板"
        )
        commandMenuVisible = false
        updateSecondaryVisibility(animated: true)
        highlightFirstPlaceholder()
    }

    private func highlightFirstPlaceholder() {
        guard let first = navigator.ranges(in: textView.string).first else { return }
        textView.setSelectedRange(first)
        textView.scrollRangeToVisible(first)
    }

    private func jumpToNextPlaceholder() {
        guard let next = navigator.nextRange(in: textView.string, after: textView.selectedRange()) else {
            NSSound.beep()
            return
        }
        textView.setSelectedRange(next)
        textView.scrollRangeToVisible(next)
    }

    private func adjustEditorHeight(animated: Bool) {
        guard let layoutManager = textView.layoutManager, let textContainer = textView.textContainer else { return }
        let availableWidth = max(scrollView.contentSize.width, scrollView.bounds.width, 612)
        textView.frame.size.width = availableWidth
        textContainer.containerSize = NSSize(width: availableWidth, height: CGFloat.greatestFiniteMagnitude)
        layoutManager.ensureLayout(for: textContainer)
        let usedRect = layoutManager.usedRect(for: textContainer)
        let lineHeight = ceil(layoutManager.defaultLineHeight(for: textView.font ?? AppTheme.regular(AppTheme.editorFontSize)))
        let explicitLineCount = max(1, textView.string.components(separatedBy: .newlines).count)
        let lineEstimate = CGFloat(explicitLineCount) * lineHeight + textView.textContainerInset.height * 2 + 12
        let rawHeight = ceil(usedRect.height + textView.textContainerInset.height * 2 + 8)
        let targetHeight = max(34, min(commandMenuVisible ? 120 : 400, max(rawHeight, lineEstimate)))
        editorHeightConstraint?.constant = targetHeight
        textView.frame.size.height = max(targetHeight, usedRect.height + textView.textContainerInset.height * 2 + 24)

        let changes = {
            self.rootView.layoutSubtreeIfNeeded()
            self.resizeWindowForContent(animated: false)
        }
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                changes()
            }
        } else {
            changes()
        }
    }

    private func copyPromptToClipboard() {
        let output = textView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !output.isEmpty else {
            NSSound.beep()
            return
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.declareTypes([.string], owner: nil)
        let copied = pasteboard.setString(output, forType: .string) || pasteboard.writeObjects([output as NSString])
        guard copied else {
            showAlert(title: "复制失败", message: "系统剪贴板暂时不可用，请稍后重试。")
            return
        }
        showCopySuccessFeedback()
    }

    private func showCopySuccessFeedback() {
        showActionsFeedback("复制成功")
    }

    private func showActionsFeedback(_ message: String) {
        actionsFeedbackWorkItem?.cancel()
        actionsLabel.textColor = .systemGreen
        actionsLabel.stringValue = message
        window?.makeFirstResponder(textView)

        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.actionsLabel.textColor = .secondaryLabelColor
            self.actionsLabel.stringValue = Self.defaultActionsHint
        }
        actionsFeedbackWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4, execute: item)
    }

    func performRefine() {
        show()
        runAIAction(.refine)
    }

    func performRegenerate() {
        show()
        runAIAction(.regenerate)
    }

    func performClarification() {
        show()
        startClarification()
    }

    func performPasteBack() {
        copyPromptToClipboard()
    }

    func refreshTemplateLibrary() {
        if currentMode == .skill {
            selectedIndex = 0
            refreshMenu()
            updateSecondaryVisibility(animated: true)
        }
    }

    func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
        registerEditorUndoStep()
        return true
    }

    func textDidChange(_ notification: Notification) {
        guard !isRestoringEditorSnapshot else { return }
        textView.needsDisplay = true
        updatePlaceholderVisibility()
        commandMenuVisible = false
        if let match = pendingTemplateMatch, !isApplyingTemplateSuggestion {
            ignoredTemplateTitles.insert(match.item.title)
            pendingTemplateMatch = nil
        }
        if !isApplyingTemplateSuggestion, clarificationSession == nil {
            scheduleTemplateSuggestionEvaluation()
        }
        adjustEditorHeight(animated: true)
        updateSecondaryVisibility(animated: true)
    }

    func promptTextViewDidRequestMenu(_ textView: PromptTextView) {
        showCommandMenu()
    }

    func promptTextViewDidRequestModeSwitch(_ textView: PromptTextView) {
        currentMode = currentMode == .prompt ? .skill : .prompt
        selectedIndex = 0
        refreshMenu()
    }

    func promptTextViewDidRequestPlaceholderJump(_ textView: PromptTextView) {
        jumpToNextPlaceholder()
    }

    func promptTextViewDidRequestSelection(_ textView: PromptTextView) {
        insertSelectedTemplate()
    }

    func promptTextViewDidRequestMenuMove(_ textView: PromptTextView, delta: Int) {
        let count = PromptStore.items(for: currentMode).count
        guard count > 0 else { return }
        selectedIndex = (selectedIndex + delta + count) % count
        refreshSelectionChrome()
    }

    func promptTextViewDidRequestClose(_ textView: PromptTextView) {
        if commandMenuVisible {
            commandMenuVisible = false
            updateSecondaryVisibility(animated: true)
        } else if !textView.string.isEmpty {
            clearInput()
        } else {
            hide()
        }
    }

    func promptTextViewDidRequestCommit(_ textView: PromptTextView) {
            copyPromptToClipboard()
    }

    func promptTextViewDidRequestUndo(_ textView: PromptTextView) {
        performEditorUndo()
    }

    func promptTextViewDidRequestRedo(_ textView: PromptTextView) {
        performEditorRedo()
    }

    func promptTextViewMenuIsVisible(_ textView: PromptTextView) -> Bool {
        commandMenuVisible
    }

}

final class GlobalHotKey {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let onPressed: () -> Void

    init(onPressed: @escaping () -> Void) {
        self.onPressed = onPressed
    }

    func register() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let userData else { return noErr }
                var hotKeyID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                if hotKeyID.id == 1 {
                    let owner = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
                    DispatchQueue.main.async {
                        owner.onPressed()
                    }
                }
                return noErr
            },
            1,
            &eventType,
            selfPointer,
            &handlerRef
        )

        let hotKeyID = EventHotKeyID(signature: Self.fourCharCode("PLIB"), id: 1)
        RegisterEventHotKey(
            UInt32(kVK_Space),
            AppIdentity.current.hotKeyModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    deinit {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let handlerRef {
            RemoveEventHandler(handlerRef)
        }
    }

    private static func fourCharCode(_ string: String) -> OSType {
        var result: UInt32 = 0
        for scalar in string.unicodeScalars.prefix(4) {
            result = (result << 8) + scalar.value
        }
        return result
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var promptController: PromptWindowController?
    private var settingsController: SettingsWindowController?
    private var templateManagerController: TemplateManagerWindowController?
    private var hotKey: GlobalHotKey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        let settingsController = SettingsWindowController()
        self.settingsController = settingsController
        do { try KeychainStore.migrateLegacyIfNeeded() }
        catch { settingsController.show() }
        let templateManagerController = TemplateManagerWindowController()
        self.templateManagerController = templateManagerController
        let controller = PromptWindowController()
        promptController = controller
        controller.onOpenSettings = { [weak self] in
            self?.showSettings()
        }
        controller.onManageTemplates = { [weak self] in
            self?.showTemplateManager()
        }
        templateManagerController.onChange = { [weak controller] in
            controller?.refreshTemplateLibrary()
        }
        configureMainMenu()
        configureStatusItem(controller: controller)
        hotKey = GlobalHotKey { [weak controller] in
            controller?.toggle()
        }
        hotKey?.register()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            controller.show()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        promptController?.show()
        return true
    }

    private func configureStatusItem(controller: PromptWindowController) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let image = NSImage(named: "StatusBarIcon") {
            image.size = NSSize(width: 18, height: 18)
            image.isTemplate = true
            item.button?.image = image
            item.button?.imagePosition = .imageOnly
        } else {
            item.button?.title = "T"
        }
        item.button?.toolTip = AppIdentity.current.displayName

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "打开 \(AppIdentity.current.displayName)", action: #selector(showPromptWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "修改 API Key...", action: #selector(showSettings), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "设置 AI 模型...", action: #selector(showSettings), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q"))
        for item in menu.items {
            item.target = self
        }
        item.menu = menu
        statusItem = item
    }

    private func configureMainMenu() {
        let mainMenu = NSMenu(title: "Main Menu")

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu(title: AppIdentity.current.displayName)
        appMenu.addItem(makeMenuItem("关于 \(AppIdentity.current.displayName)", action: #selector(showAbout), key: ""))
        appMenu.addItem(.separator())
        appMenu.addItem(makeMenuItem("修改 API Key...", action: #selector(showSettings), key: ","))
        appMenu.addItem(makeMenuItem("设置 AI 模型...", action: #selector(showSettings), key: ""))
        appMenu.addItem(.separator())
        appMenu.addItem(makeMenuItem("隐藏 \(AppIdentity.current.displayName)", action: #selector(NSApplication.hide(_:)), key: "h", target: NSApp))
        appMenu.addItem(makeMenuItem("退出 \(AppIdentity.current.displayName)", action: #selector(quit), key: "q"))
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let fileMenuItem = NSMenuItem()
        let fileMenu = NSMenu(title: "文件")
        fileMenu.addItem(makeMenuItem("打开 \(AppIdentity.current.displayName)", action: #selector(showPromptWindow), key: "o"))
        fileMenu.addItem(makeMenuItem("关闭窗口", action: #selector(closePromptWindow), key: "w"))
        fileMenuItem.submenu = fileMenu
        mainMenu.addItem(fileMenuItem)

        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "编辑")
        editMenu.addItem(makeResponderMenuItem("撤销", action: #selector(PromptTextView.undo(_:)), key: "z"))
        editMenu.addItem(makeResponderMenuItem("重做", action: #selector(PromptTextView.redo(_:)), key: "Z"))
        editMenu.addItem(.separator())
        editMenu.addItem(makeResponderMenuItem("剪切", action: #selector(NSText.cut(_:)), key: "x"))
        editMenu.addItem(makeResponderMenuItem("复制", action: #selector(NSText.copy(_:)), key: "c"))
        editMenu.addItem(makeResponderMenuItem("粘贴", action: #selector(NSText.paste(_:)), key: "v"))
        editMenu.addItem(makeResponderMenuItem("全选", action: #selector(NSText.selectAll(_:)), key: "a"))
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        let promptMenuItem = NSMenuItem()
        let promptMenu = NSMenu(title: "Prompt")
        promptMenu.addItem(makeMenuItem("唤起输入框", action: #selector(showPromptWindow), key: "p"))
        promptMenu.addItem(makeMenuItem("AI 微调当前 Prompt", action: #selector(refineCurrentPrompt), key: "r"))
        promptMenu.addItem(makeMenuItem("重新生成当前 Prompt", action: #selector(regenerateCurrentPrompt), key: "g"))
        promptMenu.addItem(makeMenuItem("追问生成当前 Prompt", action: #selector(clarifyCurrentPrompt), key: ""))
        promptMenu.addItem(makeMenuItem("复制", action: #selector(pasteBackToPreviousApp), key: "\r"))
        promptMenu.addItem(.separator())
        promptMenu.addItem(makeMenuItem("修改 API Key...", action: #selector(showSettings), key: ""))
        promptMenu.addItem(makeMenuItem("设置 AI 模型...", action: #selector(showSettings), key: ""))
        promptMenuItem.submenu = promptMenu
        mainMenu.addItem(promptMenuItem)

        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: "窗口")
        windowMenu.addItem(makeResponderMenuItem("最小化", action: #selector(NSWindow.miniaturize(_:)), key: "m"))
        windowMenu.addItem(makeMenuItem("显示 \(AppIdentity.current.displayName)", action: #selector(showPromptWindow), key: "0"))
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)
        NSApp.windowsMenu = windowMenu

        let helpMenuItem = NSMenuItem()
        let helpMenu = NSMenu(title: "帮助")
        helpMenu.addItem(makeMenuItem("使用说明", action: #selector(showUsageHelp), key: "?"))
        helpMenuItem.submenu = helpMenu
        mainMenu.addItem(helpMenuItem)
        NSApp.helpMenu = helpMenu

        NSApp.mainMenu = mainMenu
    }

    private func makeMenuItem(_ title: String, action: Selector, key: String, target: AnyObject? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = target ?? self
        return item
    }

    private func makeResponderMenuItem(_ title: String, action: Selector, key: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = nil
        return item
    }

    @objc private func showPromptWindow() {
        promptController?.show()
    }

    @objc private func closePromptWindow() {
        promptController?.hide()
    }

    @objc private func showSettings() {
        settingsController?.show()
    }

    @objc private func showTemplateManager() {
        templateManagerController?.show()
    }

    @objc private func refineCurrentPrompt() {
        promptController?.performRefine()
    }

    @objc private func regenerateCurrentPrompt() {
        promptController?.performRegenerate()
    }

    @objc private func clarifyCurrentPrompt() {
        promptController?.performClarification()
    }

    @objc private func pasteBackToPreviousApp() {
        promptController?.performPasteBack()
    }

    @objc private func showAbout() {
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: AppIdentity.current.displayName,
            .applicationVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0",
            .credits: NSAttributedString(string: "全局 Prompt 输入框，支持结构化模板、占位符跳转和 AI 微调。")
        ])
    }

    @objc private func showUsageHelp() {
        let alert = NSAlert()
        alert.messageText = "\(AppIdentity.current.displayName) 使用说明"
        alert.informativeText = "按 \(AppIdentity.current.shortcutLabel) 唤起输入框；输入 / 打开指令面板；Tab 切换模板来源或跳转占位符；⌘↵ 复制。AI 微调、重新生成、追问模式和存为模板需要先配置模型 API Key。"
        alert.addButton(withTitle: "好")
        alert.runModal()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

AppTheme.registerBundledFonts()

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
