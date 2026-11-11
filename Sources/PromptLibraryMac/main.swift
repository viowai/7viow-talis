import AppKit
import Carbon
import TalisCore

enum LibraryMode: Int, CaseIterable {
    case prompt
    case skill

    var title: String {
        switch self {
        case .prompt: return L("系统")
        case .skill: return L("我的")
        }
    }

    var subtitle: String {
        switch self {
        case .prompt: return L("系统")
        case .skill: return L("我的")
        }
    }
}

enum TemplateKind: String {
    case system
    case user
}

enum TemplateRecency: Equatable {
    case new
    case updated

    var title: String { self == .new ? "New" : L("更新") }
    var explanation: String { self == .new ? L("7 天内新建的个人模板") : L("7 天内修改过的个人模板") }
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
            return L("原模板不存在，可能已在模板库中被删除。")
        }
    }
}

struct LibraryItem {
    let sourceTitle: String
    let sourceDetail: String
    let sourceBadge: String
    let symbolName: String
    var body: String
    let origin: TemplateOrigin
    let recency: TemplateRecency?
    var title: String { L(sourceTitle) }
    var detail: String { L(sourceDetail) }
    var badge: String { L(sourceBadge) }

    init(title: String, detail: String, symbolName: String, badge: String, body: String, origin: TemplateOrigin? = nil, recency: TemplateRecency? = nil) {
        self.sourceTitle = title
        self.sourceDetail = detail
        self.sourceBadge = badge
        self.symbolName = symbolName
        self.body = body
        self.origin = origin ?? .system(id: Self.defaultSystemID(for: title))
        self.recency = recency
    }

    func replacingBody(_ newBody: String) -> LibraryItem {
        var copy = self
        copy.body = newBody
        return copy
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
            title: "把需求整理成Prompt",
            detail: "补齐目标、上下文、约束、输出格式和自检规则",
            symbolName: "wand.and.stars",
            badge: "PRT-001",
            body: """
            # 角色
            你是一个资深Prompt工程专家，擅长把模糊任务翻译成高质量、可执行、低歧义的 AI Prompt。

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
            """,
            origin: .system(id: "system.模糊需求转高质量-prompt")
        ),
        LibraryItem(
            title: "准备会前材料",
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
            """,
            origin: .system(id: "system.会议前-briefing-生成")
        ),
        LibraryItem(
            title: "假设清单与验证优先级",
            detail: "找出影响方案成败的假设，安排验证顺序",
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
            title: "发布与交付前检查",
            detail: "检查发布前的问题，给出风险等级、发布建议和检查项",
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
            """,
            origin: .system(id: "system.生产前质量把关")
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
            detail: "从注入、越权、误答和信息泄露角度加固Prompt",
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
            title: "长文翻译",
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
            """,
            origin: .system(id: "system.深度长文翻译")
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
            title: "文稿润色模板",
            detail: "保留原意，理顺表达并删除空话",
            symbolName: "sparkles",
            badge: "文本编辑",
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
            """,
            origin: .system(id: "system.写作润色技能")
        ),
        LibraryItem(
            title: "代码审查模板",
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
            """,
            origin: .system(id: "system.代码审查技能")
        ),
        LibraryItem(
            title: "研究归纳模板",
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
            """,
            origin: .system(id: "system.研究归纳技能")
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
    struct Token: Equatable {
        let range: NSRange
        let markerRange: NSRange
        let insertionLocation: Int
        let hasTerminator: Bool
        let valueRange: NSRange
        let isFilled: Bool
    }

    private let pattern = "【[^【】\\r\\n]*】[：:]?"

    func ranges(in string: String) -> [NSRange] {
        tokens(in: string).map(\.range)
    }

    func tokens(in string: String) -> [Token] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsRange = NSRange(string.startIndex..<string.endIndex, in: string)
        let text = string as NSString
        let matches = regex.matches(in: string, range: nsRange)
        return matches.enumerated().map { index, match in
            let bracketLength = Self.bracketLength(in: match, string: string)
            let tokenRange = NSRange(location: match.range.location, length: bracketLength)
            let hasTerminator = match.range.length > bracketLength
            let markerLength = bracketLength + (hasTerminator ? 1 : 0)
            let markerRange = NSRange(location: match.range.location, length: markerLength)
            let insertion = NSMaxRange(markerRange)
            let nextTokenStart = index + 1 < matches.count ? matches[index + 1].range.location : text.length
            let remaining = NSRange(location: insertion, length: max(0, nextTokenStart - insertion))
            let paragraphEnd = text.range(of: "\n\n", options: [], range: remaining).location
            var valueEnd = paragraphEnd == NSNotFound ? nextTokenStart : paragraphEnd
            while valueEnd > insertion {
                let trailing = text.character(at: valueEnd - 1)
                guard trailing == 10 || trailing == 13 else { break }
                valueEnd -= 1
            }
            let valueRange = NSRange(location: insertion, length: max(0, valueEnd - insertion))
            return Token(
                range: tokenRange,
                markerRange: markerRange,
                insertionLocation: insertion,
                hasTerminator: hasTerminator,
                valueRange: valueRange,
                isFilled: !text.substring(with: valueRange).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
        }
    }

    func nextRange(in string: String, after selectedRange: NSRange, backwards: Bool = false) -> NSRange? {
        let allTokens = tokens(in: string)
        guard !allTokens.isEmpty else { return nil }
        if backwards {
            if let current = allTokens.lastIndex(where: { $0.range.location <= selectedRange.location }) {
                return allTokens[(current + allTokens.count - 1) % allTokens.count].range
            }
            return allTokens.last?.range
        }
        let currentEnd = selectedRange.location + max(selectedRange.length, 0)
        if let current = allTokens.first(where: {
            selectedRange.location >= $0.range.location
                && selectedRange.location <= $0.insertionLocation
        }), let next = allTokens.first(where: { $0.range.location >= current.insertionLocation }) {
            return next.range
        }
        if let next = allTokens.first(where: { $0.range.location >= currentEnd }) {
            return next.range
        }
        return allTokens.first?.range
    }

    private static func bracketLength(in match: NSTextCheckingResult, string: String) -> Int {
        let matched = (string as NSString).substring(with: match.range)
        return matched.hasSuffix("：") || matched.hasSuffix(":") ? max(1, match.range.length - 1) : match.range.length
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
        "把需求整理成Prompt": ["prompt", "提示词", "指令", "咒语", "需求", "优化", "改写", "结构化", "生成 prompt", "写 prompt", "system prompt"],
        "准备会前材料": ["会议", "会前", "briefing", "纪要", "议题", "参会", "决策", "主持", "背景", "会前材料"],
        "假设清单与验证优先级": ["假设", "验证", "优先级", "风险", "实验", "最小验证", "方案", "需求假设"],
        "发布与交付前检查": ["发布", "上线", "质量", "检查", "扫雷", "放行", "风险", "验收", "checklist"],
        "内容选题池生成": ["内容", "选题", "栏目", "小红书", "公众号", "视频", "创作", "素材", "受众"],
        "Prompt 防注入加固": ["注入", "越权", "泄露", "安全", "加固", "prompt 安全", "恶意输入", "权限"],
        "长文翻译": ["翻译", "译文", "英文", "中文", "日文", "韩文", "术语", "长文", "本地化", "英译中", "中译英"],
        "工单分流与路由规则": ["工单", "分流", "路由", "客服", "sla", "升级", "派单", "处理团队"],
        "文稿润色模板": ["润色", "改稿", "文案", "表达", "清晰", "语气", "写作", "编辑"],
        "代码审查模板": ["代码", "审查", "review", "diff", "bug", "风险", "测试", "修复", "回归"],
        "研究归纳模板": ["研究", "归纳", "资料", "结论", "证据", "洞察", "调研", "分析"]
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
            "把需求整理成Prompt": "【原始需求】",
            "准备会前材料": "【会议主题】",
            "假设清单与验证优先级": "【方案内容】",
            "发布与交付前检查": "【待检查对象】",
            "内容选题池生成": "【原始想法】",
            "Prompt 防注入加固": "【原始 Prompt】",
            "长文翻译": "【待翻译文本】",
            "工单分流与路由规则": "【工单样本】",
            "文稿润色模板": "【待润色文本】",
            "代码审查模板": "【代码或 Diff】",
            "研究归纳模板": "【材料内容】"
        ]
        return map[item.sourceTitle]
    }

    static func filledTemplate(from item: LibraryItem, userInput: String, navigator: PlaceholderNavigator) -> String {
        let sourceInput = userInput
        guard !sourceInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return item.body }

        if let primary = primaryPlaceholder(for: item), item.body.contains(primary) {
            return item.body.replacingOccurrences(of: primary, with: sourceInput)
        }

        guard let firstRange = navigator.ranges(in: item.body).first, let range = Range(firstRange, in: item.body) else {
            return item.body + "\n\n" + sourceInput
        }
        var output = item.body
        output.replaceSubrange(range, with: sourceInput)
        return output
    }

    static func signature(for input: String, match: PromptTemplateMatch) -> String {
        "\(match.mode.rawValue)|\(match.item.sourceTitle)|\(normalize(input))"
    }

    private static func score(item: LibraryItem, input: String) -> (score: Int, keywords: [String]) {
        let keywords = keywordMap[item.sourceTitle] ?? []
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

        if input.contains(normalize(item.sourceTitle)) {
            total += 8
            matched.append((item.sourceTitle, 8))
        }
        item.sourceTitle
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

final class TemplateSuggestionView: ThemedSurfaceView {
    static let height: CGFloat = 30
    private let menuButton = NSPopUpButton(frame: .zero, pullsDown: true)
    var onApply: (() -> Void)?
    var onIgnore: (() -> Void)?
    override init(frame: NSRect) {
        super.init(frame: frame)
        gradientColorsProvider = {
            [AppTheme.accentColor.withAlphaComponent(0.055),
             AppTheme.selectionColor.withAlphaComponent(0.34)]
        }
        borderColor = AppTheme.accentColor.withAlphaComponent(0.20)
        drawsBorder = true
        configureLayout()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override var intrinsicContentSize: NSSize {
        NSSize(width: min(300, menuButton.intrinsicContentSize.width), height: Self.height)
    }
    func configure(with match: PromptTemplateMatch) {
        menuButton.title = AppLocalization.format("可用模板：%@", match.item.title)
        menuButton.toolTip = match.item.title + "\n" + match.item.detail
        menuButton.setAccessibilityLabel(menuButton.title)
        menuButton.setAccessibilityHelp(L("选择套用或忽略此建议；") + match.item.detail)
        invalidateIntrinsicContentSize()
    }
    private func configureLayout() {
        translatesAutoresizingMaskIntoConstraints = false
        menuButton.addItem(withTitle: L("可用模板"))
        menuButton.menu?.item(at: 0)?.isHidden = true
        menuButton.menu?.autoenablesItems = false
        for (title, action) in [(L("套用此模板"), #selector(applyPressed)), (L("忽略本次建议"), #selector(ignorePressed))] {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
            item.target = self
            menuButton.menu?.addItem(item)
        }
        menuButton.bezelStyle = .toolbar
        menuButton.isBordered = false
        menuButton.font = AppTheme.medium(12)
        menuButton.cell?.lineBreakMode = .byTruncatingTail
        menuButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(menuButton)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: Self.height),
            widthAnchor.constraint(lessThanOrEqualToConstant: 300),
            menuButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 9),
            menuButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -9),
            menuButton.topAnchor.constraint(equalTo: topAnchor), menuButton.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    @objc private func applyPressed() { onApply?() }
    @objc private func ignorePressed() { onIgnore?() }
}

/// A recommendation belongs to the on-demand template center, never the main editor.
final class TemplateRecommendationView: ThemedSurfaceView {
    static let height: CGFloat = 64
    private let titleLabel = NSTextField(labelWithString: "")
    private let detailLabel = NSTextField(labelWithString: "")
    private let ignoreButton = NSButton(title: L("忽略"), target: nil, action: nil)
    private var ignoreWidthConstraint: NSLayoutConstraint?
    var onIgnore: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        gradientColorsProvider = {
            [AppTheme.selectionColor.withAlphaComponent(0.38), AppTheme.contentColor]
        }
        borderColor = AppTheme.accentColor.withAlphaComponent(0.28)
        titleLabel.font = AppTheme.semibold(14)
        detailLabel.font = AppTheme.regular(12)
        detailLabel.textColor = AppTheme.secondaryTextColor
        detailLabel.lineBreakMode = .byTruncatingTail
        for label in [titleLabel, detailLabel] {
            label.translatesAutoresizingMaskIntoConstraints = false
            label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            addSubview(label)
        }
        ignoreButton.target = self; ignoreButton.action = #selector(ignore)
        AppTheme.styleButton(ignoreButton, glass: true)
        ignoreButton.controlSize = .small
        ignoreButton.font = AppTheme.medium(12)
        ignoreButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(ignoreButton)
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: ignoreButton.leadingAnchor, constant: -12),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            detailLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            detailLabel.trailingAnchor.constraint(lessThanOrEqualTo: ignoreButton.leadingAnchor, constant: -12),
            detailLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 3),
            detailLabel.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -10),
            ignoreButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            ignoreButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            ignoreButton.heightAnchor.constraint(equalToConstant: 32)
        ])
        ignoreWidthConstraint = ignoreButton.widthAnchor.constraint(equalToConstant: 88)
        ignoreWidthConstraint?.isActive = true
        refreshLocalization()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(with match: PromptTemplateMatch) {
        titleLabel.stringValue = L("建议")
        titleLabel.toolTip = nil
        detailLabel.stringValue = L("已选中下方项")
        detailLabel.toolTip = nil
        setAccessibilityLabel(titleLabel.stringValue)
        setAccessibilityHelp(AppLocalization.format("%@：%@。已选中下方项，可在模板行应用。", match.item.title, match.item.detail))
    }

    func refreshLocalization() {
        AppLocalization.refresh(self)
        let width = (ignoreButton.title as NSString).size(withAttributes: [.font: ignoreButton.font!]).width
        ignoreWidthConstraint?.constant = max(88, ceil(width) + 28)
    }

    @objc private func ignore() { onIgnore?() }
}

protocol PromptTextViewDelegate: AnyObject {
    func promptTextViewDidRequestMenu(_ textView: PromptTextView)
    func promptTextViewDidRequestModeSwitch(_ textView: PromptTextView)
    func promptTextViewDidRequestPlaceholderJump(_ textView: PromptTextView, backwards: Bool)
    func promptTextView(_ textView: PromptTextView, focusPlaceholder range: NSRange)
    func promptTextViewDidEndComposition(_ textView: PromptTextView)
    func promptTextViewWillBeginComposition(_ textView: PromptTextView)
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
    var placeholder = L("输入内容…")
    private var compositionMutationDepth = 0
    var isHandlingComposition: Bool { compositionMutationDepth > 0 || hasMarkedText() }

    override var acceptsFirstResponder: Bool { true }

    func makeLocalizedContextMenu() -> NSMenu {
        let menu = NSMenu()
        for (title, action) in [
            (L("撤销"), #selector(undo(_:))),
            (L("重做"), #selector(redo(_:)))
        ] {
            menu.addItem(NSMenuItem(title: title, action: action, keyEquivalent: ""))
        }
        menu.addItem(.separator())
        for (title, action) in [
            (L("剪切"), #selector(cut(_:))),
            (L("复制"), #selector(copy(_:))),
            (L("粘贴"), #selector(paste(_:))),
            (L("全选"), #selector(selectAll(_:)))
        ] {
            menu.addItem(NSMenuItem(title: title, action: action, keyEquivalent: ""))
        }
        menu.addItem(.separator())
        let servicesItem = NSMenuItem(title: L("系统服务"), action: nil, keyEquivalent: "")
        let servicesMenu = NSMenu(title: L("系统服务"))
        servicesItem.submenu = servicesMenu
        NSApp.servicesMenu = servicesMenu
        menu.addItem(servicesItem)
        return menu
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        makeLocalizedContextMenu()
    }

    override func draw(_ dirtyRect: NSRect) {
        drawPlaceholderBands()
        super.draw(dirtyRect)

        guard string.isEmpty, !placeholder.isEmpty else { return }
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font ?? AppTheme.regular(AppTheme.editorFontSize),
            .foregroundColor: NSColor.placeholderTextColor
        ]
        let origin = NSPoint(x: textContainerInset.width + 4, y: textContainerInset.height + 1)
        placeholder.draw(at: origin, withAttributes: attributes)
    }

    override func insertText(_ insertString: Any, replacementRange: NSRange) {
        let completesComposition = hasMarkedText()
        if completesComposition { compositionMutationDepth += 1 }
        super.insertText(insertString, replacementRange: replacementRange)
        if completesComposition {
            compositionMutationDepth -= 1
            promptDelegate?.promptTextViewDidEndComposition(self)
        }
    }

    override func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
        if !hasMarkedText() { promptDelegate?.promptTextViewWillBeginComposition(self) }
        compositionMutationDepth += 1
        defer { compositionMutationDepth -= 1 }
        super.setMarkedText(string, selectedRange: selectedRange, replacementRange: replacementRange)
    }

    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let keyCode = event.keyCode
        let menuVisible = promptDelegate?.promptTextViewMenuIsVisible(self) ?? false
        if hasMarkedText() { super.keyDown(with: event); return }

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
            } else if !PlaceholderNavigator().tokens(in: string).isEmpty {
                promptDelegate?.promptTextViewDidRequestPlaceholderJump(self, backwards: flags.contains(.shift))
            } else if flags.contains(.shift) {
                window?.selectPreviousKeyView(self)
            } else {
                window?.selectNextKeyView(self)
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

        if isCommandOnly, keyCode == 40 {
            promptDelegate?.promptTextViewDidRequestMenu(self)
            return
        }

        if event.characters == "/", !flags.contains(.command), string.isEmpty {
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
        } else if !PlaceholderNavigator().tokens(in: string).isEmpty {
            promptDelegate?.promptTextViewDidRequestPlaceholderJump(self, backwards: false)
        } else {
            window?.selectNextKeyView(self)
        }
    }

    override func insertBacktab(_ sender: Any?) {
        if !PlaceholderNavigator().tokens(in: string).isEmpty {
            promptDelegate?.promptTextViewDidRequestPlaceholderJump(self, backwards: true)
        } else {
            window?.selectPreviousKeyView(self)
        }
    }

    private struct PlaceholderVisualSegment {
        var rect: NSRect
        var active: Bool
        var pending: Bool
    }

    private func placeholderLayoutItems() -> [(token: PlaceholderNavigator.Token, segments: [NSRect])] {
        guard let layoutManager, let textContainer, !string.isEmpty else { return [] }
        layoutManager.ensureLayout(for: textContainer)
        let origin = textContainerOrigin
        return PlaceholderNavigator().tokens(in: string).compactMap { token in
            guard token.range.location < (string as NSString).length else { return nil }
            let fieldRange = token.markerRange
            guard fieldRange.length > 0 else { return nil }
            let fieldGlyphs = layoutManager.glyphRange(forCharacterRange: fieldRange, actualCharacterRange: nil)
            var segments: [NSRect] = []
            layoutManager.enumerateLineFragments(forGlyphRange: fieldGlyphs) { _, usedRect, _, lineGlyphs, _ in
                let intersection = NSIntersectionRange(lineGlyphs, fieldGlyphs)
                guard intersection.length > 0 else { return }
                let startX = layoutManager.location(forGlyphAt: intersection.location).x
                let nextGlyph = NSMaxRange(intersection)
                let endX = nextGlyph < NSMaxRange(lineGlyphs)
                    ? layoutManager.location(forGlyphAt: nextGlyph).x
                    : usedRect.maxX
                let rect = NSRect(
                    x: min(startX, endX),
                    y: usedRect.minY,
                    width: max(2, abs(endX - startX)),
                    height: usedRect.height
                )
                let expanded = rect.insetBy(dx: -3, dy: -2.5).offsetBy(dx: origin.x, dy: origin.y)
                segments.append(expanded.integral)
            }
            return segments.isEmpty ? nil : (token, segments)
        }
    }

    func placeholderVisualRows() -> [NSRect] {
        placeholderSegments().map(\.rect).sorted { $0.minY < $1.minY }
    }

    private func placeholderSegments() -> [PlaceholderVisualSegment] {
        let selection = selectedRange()
        var segments: [PlaceholderVisualSegment] = []
        for item in placeholderLayoutItems() {
            let active = selection.length == 0
                && selection.location >= item.token.range.location
                && selection.location <= max(item.token.insertionLocation, NSMaxRange(item.token.valueRange))
            for rect in item.segments {
                let segment = PlaceholderVisualSegment(
                    rect: rect,
                    active: active,
                    pending: !item.token.isFilled
                )
                if let index = segments.firstIndex(where: {
                    abs($0.rect.midY - segment.rect.midY) < 2
                        && segment.rect.minX <= $0.rect.maxX + 2
                        && segment.rect.maxX >= $0.rect.minX - 2
                }) {
                    segments[index].rect = segments[index].rect.union(segment.rect)
                    segments[index].active = segments[index].active || segment.active
                    segments[index].pending = segments[index].pending || segment.pending
                } else {
                    segments.append(segment)
                }
            }
        }
        return segments.sorted {
            abs($0.rect.minY - $1.rect.minY) < 1
                ? $0.rect.minX < $1.rect.minX
                : $0.rect.minY < $1.rect.minY
        }
    }

    private func drawPlaceholderBands() {
        let segments = placeholderSegments()
        guard !segments.isEmpty else { return }
        effectiveAppearance.performAsCurrentDrawingAppearance {
            for item in segments {
                let fill = item.active
                    ? AppTheme.placeholderActiveFillColor
                    : item.pending
                        ? AppTheme.placeholderFillColor
                        : NSColor.labelColor.withAlphaComponent(0.018)
                fill.setFill()
                let stroke = item.active
                    ? AppTheme.accentColor.withAlphaComponent(0.52)
                    : item.pending
                        ? AppTheme.accentColor.withAlphaComponent(0.22)
                        : AppTheme.borderColor.withAlphaComponent(0.30)
                stroke.setStroke()
                let path = NSBezierPath(roundedRect: item.rect, xRadius: 9, yRadius: 9)
                path.lineWidth = item.active ? 1.25 : 0.8
                path.fill()
                path.stroke()
            }
        }
    }


}

final class PlaceholderMinimapView: NSView {
    private struct Marker {
        let position: CGFloat
        let range: NSRange
        let isFilled: Bool
    }
    private struct PreviewLine {
        let position: CGFloat
        let width: CGFloat
    }

    private var markers: [Marker] = []
    private var textLines: [PreviewLine] = []
    private var viewportStart: CGFloat = 0
    private var viewportEnd: CGFloat = 1
    var onJump: ((NSRange) -> Void)?

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.shadowColor = AppTheme.accentColor.cgColor
        layer?.shadowOpacity = 0.08
        layer?.shadowRadius = 8
        layer?.shadowOffset = CGSize(width: 0, height: -2)
        focusRingType = .exterior
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel(L("全文缩略图"))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(textView: NSTextView, tokens: [PlaceholderNavigator.Token], documentHeight: CGFloat, visibleRect: NSRect) {
        guard let layoutManager = textView.layoutManager, let textContainer = textView.textContainer else { return }
        layoutManager.ensureLayout(for: textContainer)
        let height = max(1, documentHeight)
        let origin = textView.textContainerOrigin
        markers = tokens.map {
            let glyph = layoutManager.glyphIndexForCharacter(at: $0.range.location)
            let line = layoutManager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
            return Marker(position: (origin.y + line.midY) / height, range: $0.range, isFilled: $0.isFilled)
        }
        var candidates: [PreviewLine] = []
        layoutManager.enumerateLineFragments(forGlyphRange: NSRange(location: 0, length: layoutManager.numberOfGlyphs)) { _, used, _, _, _ in
            guard used.width > 0 else { return }
            candidates.append(PreviewLine(
                position: (origin.y + used.midY) / height,
                width: min(1, max(0.15, used.width / max(1, textContainer.size.width)))
            ))
        }
        let maximumPreviewLines = max(2, Int((bounds.height - 18) / 2))
        if candidates.count <= maximumPreviewLines {
            textLines = candidates
        } else {
            textLines = (0..<maximumPreviewLines).map { index in
                let progress = CGFloat(index) / CGFloat(maximumPreviewLines - 1)
                let candidateIndex = Int((progress * CGFloat(candidates.count - 1)).rounded())
                return candidates[candidateIndex]
            }
        }
        viewportStart = max(0, min(1, visibleRect.minY / height))
        viewportEnd = max(viewportStart, min(1, visibleRect.maxY / height))
        setAccessibilityValue(AppLocalization.format("%@ 个占位符", markers.count))
        setAccessibilityHelp(L("点击紫色标记跳到对应占位符"))
        toolTip = markers.count == 1 ? L("全文缩略图；1 个占位符，点击紫色标记跳转") : AppLocalization.format("全文缩略图；%@ 个占位符，点击紫色标记跳转", markers.count)
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard !markers.isEmpty else { return }
        effectiveAppearance.performAsCurrentDrawingAppearance {
            let background = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 10, yRadius: 10)
            AppTheme.contentColor.withAlphaComponent(0.94).setFill()
            AppTheme.borderColor.withAlphaComponent(0.78).setStroke()
            background.lineWidth = 1
            background.fill()
            background.stroke()

            let viewport = NSRect(
                x: 3,
                y: 7 + viewportStart * max(0, bounds.height - 14),
                width: max(0, bounds.width - 6),
                height: max(12, (viewportEnd - viewportStart) * max(0, bounds.height - 14))
            )
            let viewportPath = NSBezierPath(roundedRect: viewport, xRadius: 6, yRadius: 6)
            AppTheme.accentColor.withAlphaComponent(0.07).setFill()
            AppTheme.accentColor.withAlphaComponent(0.18).setStroke()
            viewportPath.lineWidth = 0.75
            viewportPath.fill()
            viewportPath.stroke()

            for line in textLines {
                let availableWidth = max(0, bounds.width - 14)
                let width = max(7, availableWidth * line.width)
                let y = 8 + line.position * max(0, bounds.height - 18)
                AppTheme.secondaryTextColor.withAlphaComponent(0.30).setFill()
                NSBezierPath(
                    roundedRect: NSRect(x: 7, y: y, width: width, height: 1.5),
                    xRadius: 0.75,
                    yRadius: 0.75
                ).fill()
            }
            for marker in markers {
                let y = 7 + marker.position * max(0, bounds.height - 14)
                (marker.isFilled ? AppTheme.secondaryTextColor.withAlphaComponent(0.5) : AppTheme.accentColor).setFill()
                NSBezierPath(
                    roundedRect: NSRect(x: 4, y: y - 2, width: max(8, bounds.width - 8), height: 4),
                    xRadius: 2,
                    yRadius: 2
                ).fill()
            }
        }
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        guard let marker = nearestMarker(to: convert(event.locationInWindow, from: nil)) else { return }
        onJump?(marker.range)
    }

    override func keyDown(with event: NSEvent) {
        guard event.keyCode == 36 || event.keyCode == 49 else {
            super.keyDown(with: event)
            return
        }
        guard let marker = markers.first else { return }
        onJump?(marker.range)
    }

    override func accessibilityPerformPress() -> Bool {
        guard let marker = markers.first else { return false }
        onJump?(marker.range)
        return true
    }

    private func nearestMarker(to point: NSPoint) -> Marker? {
        markers.min {
            abs(markerY($0) - point.y) < abs(markerY($1) - point.y)
        }
    }

    private func markerY(_ marker: Marker) -> CGFloat {
        7 + marker.position * max(0, bounds.height - 14)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.shadowColor = AppTheme.accentColor.cgColor
        }
        needsDisplay = true
    }
}

final class PromptPanel: NSPanel {
    var onCancel: (() -> Void)?
    override func cancelOperation(_ sender: Any?) { onCancel?() }
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown, !isKeyWindow {
            NSApp.activate(ignoringOtherApps: true)
            makeKeyAndOrderFront(nil)
        }
        super.sendEvent(event)
    }
}

/// The quick panel follows the active desktop. The same workspace can move to
/// an ordinary resizable window when the user wants Split View or another display.
final class WorkspaceWindow: NSWindow {
    var onCancel: (() -> Void)?
    override func cancelOperation(_ sender: Any?) { onCancel?() }
}

final class CommandRowView: ThemedSurfaceView {
    static let rowHeight: CGFloat = 64
    private static weak var activeHoverRow: CommandRowView?
    let selectionButton = NSButton()
    private let titleLabel = NSTextField(labelWithString: "")
    private let detailLabel = NSTextField(labelWithString: "")
    private let recencyBadge = NSTextField(labelWithString: "")
    private var configuredItem: LibraryItem?
    private var isRowSelected = false
    private var isHovering = false
    private var hoverTrackingArea: NSTrackingArea?
    private var replacesContent = false
    private var allowsApply = true
    private var titleLeadingConstraint: NSLayoutConstraint?
    private var titleTrailingConstraint: NSLayoutConstraint?
    private var applyWidthConstraint: NSLayoutConstraint?
    private var recencyWidthConstraint: NSLayoutConstraint?
    private var recencyBaselineConstraint: NSLayoutConstraint?
    let applyButton = TalisActionButton(
        title: L("应用模板"),
        target: nil,
        action: nil,
        surface: .push,
        emphasis: .primary
    )
    var onApply: (() -> Void)?
    var onChoose: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureLayout()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(with item: LibraryItem, isSelected: Bool, replacesContent: Bool = false, allowsApply: Bool = true) {
        configuredItem = item
        self.allowsApply = allowsApply
        self.replacesContent = replacesContent
        applyButton.title = replacesContent ? L("替换") : L("应用")
        let buttonWidth = (applyButton.title as NSString).size(withAttributes: [.font: applyButton.font!]).width
        applyWidthConstraint?.constant = max(94, ceil(buttonWidth) + 28)
        applyButton.toolTip = replacesContent ? L("用此模板替换正文；可按 ⌘Z 撤销") : L("把此模板放入内容框")
        applyButton.setAccessibilityLabel(applyButton.title)
        AppTheme.applyTextStyle(to: titleLabel, text: item.title, size: 14, weight: .medium)
        AppTheme.applyTextStyle(to: detailLabel, text: item.detail, size: 12, color: AppTheme.secondaryTextColor)
        selectionButton.setAccessibilityLabel(item.title)
        selectionButton.setAccessibilityHelp([item.detail, item.recency?.explanation].compactMap { $0 }.joined(separator: "；"))
        recencyBadge.stringValue = item.recency?.title ?? ""
        recencyBadge.isHidden = item.recency == nil
        updateRecencyLayout()
        titleLabel.setAccessibilityElement(false)
        detailLabel.setAccessibilityElement(false)
        toolTip = item.title + "\n" + item.detail
        setSelected(isSelected)
    }
    func setSelected(_ selected: Bool) {
        isRowSelected = selected
        applyButton.isHidden = !selected || !allowsApply
        titleTrailingConstraint?.constant = applyButton.isHidden ? -12 : -(applyWidthConstraint?.constant ?? 94) - 24
        selectionButton.setAccessibilitySelected(selected)
        updateColors()
    }
    func setHovering(_ hovering: Bool) {
        let nextValue = hovering && selectionButton.isEnabled
        if nextValue {
            if let activeHoverRow = Self.activeHoverRow, activeHoverRow !== self {
                activeHoverRow.clearHover()
            }
            Self.activeHoverRow = self
        } else if Self.activeHoverRow === self {
            Self.activeHoverRow = nil
        }
        guard nextValue != isHovering else { return }
        isHovering = nextValue
        updateColors()
    }
    func clearHover() {
        setHovering(false)
    }
    static func clearAllHover() {
        activeHoverRow?.clearHover()
        activeHoverRow = nil
    }
    var recencyUsesTitleBaselineForTesting: Bool {
        recencyBaselineConstraint?.isActive == true
    }
    var recencyBadgeWidthForTesting: CGFloat { recencyWidthConstraint?.constant ?? 0 }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTrackingArea {
            removeTrackingArea(hoverTrackingArea)
        }
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        hoverTrackingArea = area
    }
    override func mouseEntered(with event: NSEvent) {
        setHovering(true)
    }
    override func mouseExited(with event: NSEvent) {
        setHovering(false)
    }
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateColors()
    }
    private func updateColors() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            let accent: NSColor = replacesContent ? .systemOrange : AppTheme.accentColor
            if isRowSelected {
                gradientColorsProvider = {
                    [accent.blended(withFraction: 0.91, of: AppTheme.contentColor)!,
                     accent.blended(withFraction: 0.82, of: AppTheme.contentColor)!]
                }
            } else if isHovering {
                gradientColorsProvider = {
                    [AppTheme.modeButtonHoverStart, AppTheme.modeButtonHoverEnd]
                }
            } else {
                gradientColorsProvider = nil
            }
            borderColor = isRowSelected
                ? accent.withAlphaComponent(0.65)
                : isHovering ? AppTheme.accentColor.withAlphaComponent(0.22) : .clear
            applyButton.emphasisColorOverride = accent
            applyButton.keepsPrimaryWhenInactive = true
            recencyBadge.layer?.backgroundColor = AppTheme.accentColor.withAlphaComponent(0.12).cgColor
            recencyBadge.layer?.borderColor = AppTheme.accentColor.withAlphaComponent(0.28).cgColor
            needsDisplay = true
        }
    }
    @objc private func choose() { onChoose?() }
    @objc private func apply() { onApply?() }
    private func configureLayout() {
        selectionButton.setAccessibilityElement(true)
        selectionButton.setAccessibilityRole(.button)
        selectionButton.title = ""
        selectionButton.isBordered = false
        selectionButton.target = self
        selectionButton.action = #selector(choose)
        selectionButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(selectionButton)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = AppTheme.cornerRadius
        layer?.borderWidth = 1
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        recencyBadge.font = AppTheme.semibold(9)
        recencyBadge.textColor = AppTheme.accentTextColor
        recencyBadge.alignment = .center
        recencyBadge.wantsLayer = true
        recencyBadge.layer?.cornerRadius = 7
        recencyBadge.layer?.borderWidth = 1
        recencyBadge.lineBreakMode = .byClipping
        recencyBadge.setAccessibilityElement(false)
        recencyBadge.translatesAutoresizingMaskIntoConstraints = false
        applyButton.target = self; applyButton.action = #selector(apply)
        applyButton.font = AppTheme.medium(12)
        for view in [titleLabel, detailLabel, recencyBadge] { view.translatesAutoresizingMaskIntoConstraints = false; selectionButton.addSubview(view) }
        applyButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(applyButton)
        for label in [titleLabel, detailLabel] {
            label.lineBreakMode = .byTruncatingTail
            label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        }
        titleLeadingConstraint = titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14)
        titleLeadingConstraint?.isActive = true
        titleTrailingConstraint = titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12)
        titleTrailingConstraint?.isActive = true
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: Self.rowHeight),
            selectionButton.leadingAnchor.constraint(equalTo: leadingAnchor),
            selectionButton.trailingAnchor.constraint(equalTo: trailingAnchor),
            selectionButton.topAnchor.constraint(equalTo: topAnchor),
            selectionButton.bottomAnchor.constraint(equalTo: bottomAnchor),
            recencyBadge.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            recencyBadge.heightAnchor.constraint(equalToConstant: 16),
            applyButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            applyButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            applyButton.heightAnchor.constraint(equalToConstant: 32),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 11),
            titleLabel.heightAnchor.constraint(equalToConstant: 19),
            detailLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            detailLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            detailLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            detailLabel.heightAnchor.constraint(equalToConstant: 17)
        ])
        recencyBaselineConstraint = recencyBadge.firstBaselineAnchor.constraint(equalTo: titleLabel.firstBaselineAnchor)
        recencyBaselineConstraint?.isActive = true
        recencyWidthConstraint = recencyBadge.widthAnchor.constraint(equalToConstant: 34)
        recencyWidthConstraint?.isActive = true
        applyWidthConstraint = applyButton.widthAnchor.constraint(equalToConstant: 94)
        applyWidthConstraint?.isActive = true
    }

    func refreshLocalization() {
        AppLocalization.refresh(self)
        if let configuredItem {
            applyButton.title = replacesContent ? L("替换") : L("应用")
            recencyBadge.stringValue = configuredItem.recency?.title ?? ""
            recencyBadge.isHidden = configuredItem.recency == nil
            updateRecencyLayout()
        }
        let buttonWidth = (applyButton.title as NSString).size(withAttributes: [.font: applyButton.font!]).width
        applyWidthConstraint?.constant = max(94, ceil(buttonWidth) + 28)
        setSelected(isRowSelected)
    }

    private func updateRecencyLayout() {
        guard let font = recencyBadge.font else { return }
        let textWidth = ceil((recencyBadge.stringValue as NSString).size(withAttributes: [.font: font]).width)
        let width = max(34, textWidth + 12)
        recencyWidthConstraint?.constant = width
        titleLeadingConstraint?.constant = recencyBadge.isHidden ? 14 : 20 + width
    }
}

final class PromptWindowController: NSWindowController, NSTextViewDelegate, PromptTextViewDelegate, NSSearchFieldDelegate, NSWindowDelegate {
    private static let preferredWindowWidth: CGFloat = 720
    private static let preferredWorkspaceSize = NSSize(width: 800, height: 760)
    private static let minimumWorkspaceSize = NSSize(width: 640, height: 560)
    private struct EditorSnapshot {
        let text: String
        let origin: TemplateOrigin?
        let title: String?
        let selectedRange: NSRange
        let context: [ConversationTurn]
    }
    private struct ConversationTurn: Equatable {
        let query: String
        let result: String
        let actionTitle: String
        let createdAt: Date
        var clarificationSession: ClarificationSession? = nil
    }

    private let navigator = PlaceholderNavigator()
    var onOpenSettings: (() -> Void)?
    var onManageTemplates: (() -> Void)?
    var onTemplateSaved: (() -> Void)?
    private var currentMode: LibraryMode = .prompt
    private var selectedIndex: Int = 0
    private var commandMenuVisible = false {
        didSet {
            if !commandMenuVisible { hideTemplatePicker() }
        }
    }
    private var isRunningAI = false

    private let rootView = WindowBackdropView(material: .popover)
    private var workspaceWindow: WorkspaceWindow?
    private var isWorkspaceMode = false
    private let contentStack = NSStackView()
    private let topBar = NSStackView()
    private let titleLabel = NSTextField(labelWithString: AppIdentity.current.displayName)
    private let editorToolbar = NSStackView()
    private let contentMenuButton = NSButton()
    private var contentMenuWidthConstraint: NSLayoutConstraint?
    private var templatePickerWindow: NSWindow?
    private let placeholderHint = NSTextField(labelWithString: L("【】标记和正文均可编辑\n按 Tab 跳到下一处"))
    private let placeholderHintContainer = ThemedSurfaceView()
    private let editorSeparator = NSBox()
    private let clearButton = NSButton(title: L("清空"), target: nil, action: nil)
    private var isShowingCopySuccess = false
    private let settingsButton = NSButton()
    private let librarySearch = TalisSearchField()
    private let libraryEmptyLabel = NSTextField(labelWithString: "")
    private let feedbackContainer = FeedbackStackView()
    private let feedbackSymbol = NSImageView()
    private let feedbackGlyphSlot = NSView()
    private let feedbackHeaderStack = NSStackView()
    private let feedbackTextStack = NSStackView()
    private let retryButton = NSButton(title: L("重试"), target: nil, action: nil)
    private var retryAction: (() -> Void)?
    private var waitingFeedbackWorkItem: DispatchWorkItem?
    private let activityIndicator = NSProgressIndicator()
    private var activeOperationTitle = ""
    private let stopButton = TalisActionButton(
        title: L("停止"),
        target: nil,
        action: nil,
        surface: .push,
        emphasis: .primary
    )
    private let errorDetailsButton = NSButton(title: L("详情"), target: nil, action: nil)
    private let feedbackMessageLabel = NSTextField(labelWithString: "")
    private var lastError: (title: String, message: String, details: String)?
    private var activeAITask: Task<Void, Never>?
    private var activeOperationID: UUID?
    private let clientFactory: (() -> OpenAIClient?)?
    private let motionPreference: () -> Bool
    private let templatePreviewFactory: (TemplateDraft) -> TemplatePreviewWindowController
    private let contextSummaryButton = NSButton(title: "", target: nil, action: nil)
    private let restoreDraftButton = NSButton(title: L("恢复上次草稿"), target: nil, action: nil)
    private let historyController = HistoryWindowController()
    private let scrollView = NSScrollView()
    private let editorSurface = ThemedSurfaceView()
    private let editorFooter = NSView()
    private let textView = PromptTextView()
    private let templateRecommendationView = TemplateRecommendationView()
    private let placeholderMinimap = PlaceholderMinimapView()
    private let scrollToTopButton = NSButton()
    private var scrollBoundsObserver: NSObjectProtocol?
    private var templateHoverResetObserver: NSObjectProtocol?

    private let dropdownContainer = NSStackView()
    private let dropdownHeaderStack = NSStackView()
    private let modeControl = NSSegmentedControl(labels: [L("系统"), L("我的")], trackingMode: .selectOne, target: nil, action: nil)
    private let manageTemplatesButton = NSButton()
    private let librarySearchRow = NSStackView()
    private let shortcutHelpButton = NSButton()
    private let templateShortcutPopover = NSPopover()
    private let commandListView = TopAlignedStackView()
    private let commandListScrollView = NSScrollView()
    private let templateManagementStack = NSStackView()
    private let saveTemplateButton = NSButton(title: L("存为新"), target: nil, action: nil)
    private let updateTemplateButton = NSButton(title: L("更新"), target: nil, action: nil)

    private let actionsContainer = NSStackView()
    private var modeGlassContainer: NSView?
    private let actionsLabel = NSTextField(labelWithString: "")
    private let refineButton = ModeHoverButton(title: L("微调"), target: nil, action: nil)
    private let regenerateButton = ModeHoverButton(title: L("重构"), target: nil, action: nil)
    private let clarifyButton = ModeHoverButton(title: L("追问"), target: nil, action: nil)
    private let commitButton = TalisActionButton(
        title: L("复制 Prompt"),
        target: nil,
        action: nil,
        surface: .glass,
        emphasis: .neutral
    )
    private var clarificationWindowController: ClarificationWindowController?
    private var clarificationHostFrame: NSRect?

    private var editorHeightConstraint: NSLayoutConstraint?
    private var workspaceEditorMinimumHeightConstraint: NSLayoutConstraint?
    private var editorFooterHeightConstraint: NSLayoutConstraint?
    private var editorToolbarHeightConstraint: NSLayoutConstraint?
    private var editorScrollTrailingConstraint: NSLayoutConstraint?
    private var scrollToTopBottomConstraint: NSLayoutConstraint?
    private var scrollToTopAboveMapConstraint: NSLayoutConstraint?
    private var updatingEditorOverlays = false
    private var feedbackHeightConstraint: NSLayoutConstraint?
    private var commandListHeightConstraint: NSLayoutConstraint?
    private var commandRows: [CommandRowView] = []
    private var pendingTemplateMatch: PromptTemplateMatch?
    private var ignoredTemplateTitles = Set<String>()
    private var templateMatchWorkItem: DispatchWorkItem?
    private var templatePreviewController: TemplatePreviewWindowController?
    private var actionsFeedbackWorkItem: DispatchWorkItem?
    private var activeTemplateOrigin: TemplateOrigin?
    private var activeTemplateTitle: String?
    private var undoSnapshots: [EditorSnapshot] = []
    private var redoSnapshots: [EditorSnapshot] = []
    private var recoverableDraft: EditorSnapshot?
    private var startsNewSessionOnNextShow = true
    private var isRestoringEditorSnapshot = false
    private var conversationTurns: [ConversationTurn] = []
    private var clarificationSession: ClarificationSession?
    private var pendingNoQuestionFinal: (prompt: String, session: ClarificationSession)?
    private var pendingClarificationRound: ClarificationRound?
    private var pendingClarificationQuestionIndex = 0
    private var pendingClarificationAnswers: [ClarificationAnswer] = []
    private var clarificationRunID: UUID?
    private var clarificationClient: OpenAIClient?
    private var clarificationIsActive: Bool {
        clarificationSession != nil || clarificationWindowController != nil
    }
    private var minimumEditorHeight: CGFloat { isWorkspaceMode ? 160 : 112 }

    override var window: NSWindow? {
        get { isWorkspaceMode ? workspaceWindow : super.window }
        set { super.window = newValue }
    }

    init(clientFactory: (() -> OpenAIClient?)? = nil, motionPreference: @escaping () -> Bool = { AppTheme.reducesMotion },
         templatePreviewFactory: @escaping (TemplateDraft) -> TemplatePreviewWindowController = { TemplatePreviewWindowController(draft: $0) }) {
        self.clientFactory = clientFactory
        self.motionPreference = motionPreference
        self.templatePreviewFactory = templatePreviewFactory
        let panel = PromptPanel(
            contentRect: NSRect(x: 0, y: 0, width: Self.preferredWindowWidth, height: 260),
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
        AppTheme.configureWindow(panel)
        super.init(window: panel)
        panel.delegate = self
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.onCancel = { [weak self] in
            guard let self else { return }
            self.promptTextViewDidRequestClose(self.textView)
        }
        configureUI()
        refreshMenu()
        commandMenuVisible = false
        updateSecondaryVisibility(animated: false)
    }

    var isInWorkspaceMode: Bool { isWorkspaceMode }
    var workspaceEditorUsesFlexibleHeightForTesting: Bool {
        isWorkspaceMode
            && editorHeightConstraint?.isActive == false
            && workspaceEditorMinimumHeightConstraint?.isActive == true
    }
    var workspaceEditorUsesCompactFixedHeightForTesting: Bool {
        isWorkspaceMode
            && editorHeightConstraint?.isActive == true
            && workspaceEditorMinimumHeightConstraint?.isActive == false
    }

    func toggleWorkspaceMode() {
        guard clarificationWindowController == nil else {
            NSSound.beep()
            clarificationWindowController?.focusAnswer()
            return
        }
        if isWorkspaceMode { showQuickPanel() } else { showWorkspace() }
    }

    @objc func toggleWorkspaceWindow() { toggleWorkspaceMode() }

    private func installWorkspaceSurface(in window: NSWindow) {
        guard let contentView = window.contentView else { return }
        // Move the existing editor hierarchy as one unit. Keep the visual
        // backdrops local to each native window instead of moving NSVisualEffectView.
        let content = contentStack
        content.removeFromSuperview()
        let root = WindowBackdropView(material: .popover)
        root.translatesAutoresizingMaskIntoConstraints = false
        root.wantsLayer = true
        root.layer?.cornerRadius = isWorkspaceMode ? 0 : 16
        root.layer?.masksToBounds = true
        contentView.addSubview(root)
        root.addSubview(content)
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            root.topAnchor.constraint(equalTo: contentView.topAnchor),
            root.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            content.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 20),
            content.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -20),
            content.topAnchor.constraint(equalTo: root.topAnchor, constant: 20),
            content.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -20)
        ])
    }

    private func showWorkspace() {
        if startsNewSessionOnNextShow {
            beginFreshSession()
            startsNewSessionOnNextShow = false
        }
        let quickPanel = super.window
        let workspace: WorkspaceWindow
        if let existing = workspaceWindow {
            workspace = existing
        } else {
            workspace = WorkspaceWindow(
                contentRect: NSRect(origin: .zero, size: Self.preferredWorkspaceSize),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered, defer: false
            )
            workspace.title = "Talis"
            workspace.minSize = Self.minimumWorkspaceSize
            workspace.level = .normal
            workspace.collectionBehavior = [.moveToActiveSpace]
            workspace.isReleasedWhenClosed = false
            workspace.isRestorable = false
            workspace.onCancel = { [weak self] in self?.showQuickPanel() }
            AppTheme.configureWindow(workspace)
            workspace.delegate = self
            workspaceWindow = workspace
        }
        isWorkspaceMode = true
        titleLabel.isHidden = true
        editorHeightConstraint?.isActive = false
        workspaceEditorMinimumHeightConstraint?.isActive = true
        // Capture the quick panel before switching the controller's `window`
        // getter so the emptied floating surface cannot remain above workspace.
        quickPanel?.orderOut(nil)
        installWorkspaceSurface(in: workspace)
        workspace.contentView?.layoutSubtreeIfNeeded()
        updateWorkspaceLayout()
        updateSecondaryVisibility(animated: false)
        workspace.contentView?.layoutSubtreeIfNeeded()
        AppTheme.center(workspace, on: quickPanel?.screen ?? NSScreen.main)
        NSApp.activate(ignoringOtherApps: true)
        workspace.makeKeyAndOrderFront(nil)
        focusCurrentWorkspace()
    }

    private func showQuickPanel() { restoreQuickPanel() }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let scrollBoundsObserver {
            NotificationCenter.default.removeObserver(scrollBoundsObserver)
        }
        if let templateHoverResetObserver {
            NotificationCenter.default.removeObserver(templateHoverResetObserver)
        }
    }

    func restoreUpdateSession(_ session: UpdateSession) {
        startsNewSessionOnNextShow = false
        let turns = session.turns.map {
            ConversationTurn(query: $0.query, result: $0.result, actionTitle: $0.actionTitle, createdAt: $0.createdAt)
        }
        applyEditorSnapshot(EditorSnapshot(text: session.text, origin: nil, title: nil,
                            selectedRange: NSRange(location: 0, length: 0), context: turns),
                            actionName: L("恢复会话"), registersUndo: false)
        updateContextHistoryVisibility()
    }

    func toggle() {
        if window?.isVisible == true {
            hide()
        } else {
            show()
        }
    }

    func show() {
        if startsNewSessionOnNextShow {
            beginFreshSession()
            startsNewSessionOnNextShow = false
        }
        if isWorkspaceMode {
            showWorkspace()
            return
        }
        if workspaceWindow != nil {
            restoreQuickPanel()
            return
        }
        guard let window else { return }
        positionWindow(window)
        NSApp.activate(ignoringOtherApps: true)
        NSApp.unhide(nil)
        window.deminiaturize(nil)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        if pendingClarificationRound != nil { clarificationWindowController?.focusAnswer() }
        else { window.makeFirstResponder(textView) }
        resizeWindowForContent(animated: false)
        scheduleEditorOverlayRefresh()
    }

    private func restoreQuickPanel() {
        guard let panel = super.window as? PromptPanel else { return }
        super.window?.orderOut(nil)
        isWorkspaceMode = false
        titleLabel.isHidden = false
        workspaceWindow?.orderOut(nil)
        workspaceWindow = nil
        super.window = panel
        installWorkspaceSurface(in: panel)
        workspaceEditorMinimumHeightConstraint?.isActive = false
        editorHeightConstraint?.isActive = true
        adjustEditorHeight(animated: false)
        updateSecondaryVisibility(animated: false)
        panel.contentView?.layoutSubtreeIfNeeded()
        show()
    }

    private func updateWorkspaceLayout() {
        guard isWorkspaceMode, let window else { return }
        editorHeightConstraint?.isActive = false
        workspaceEditorMinimumHeightConstraint?.isActive = true
        window.contentView?.layoutSubtreeIfNeeded()
    }

    func windowDidResize(_ notification: Notification) {
        guard isWorkspaceMode else { return }
        updateEditorOverlays()
    }

    func windowDidResignKey(_ notification: Notification) {
        CommandRowView.clearAllHover()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if sender === templatePickerWindow {
            commandMenuVisible = false
            return false
        }
        if isWorkspaceMode {
            showQuickPanel()
        } else {
            endCurrentSessionAndHide()
        }
        return false
    }

    private func focusCurrentWorkspace() {
        if pendingClarificationRound != nil { clarificationWindowController?.focusAnswer() }
        else { window?.makeFirstResponder(textView) }
    }

    func hide() {
        endCurrentSessionAndHide()
    }

    var canRestoreLastDraft: Bool {
        guard let recoverableDraft else { return false }
        let hasRecovery = !recoverableDraft.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !recoverableDraft.context.isEmpty
        let currentIsEmpty = textView.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && conversationTurns.isEmpty
        return hasRecovery && (startsNewSessionOnNextShow || currentIsEmpty)
    }

    var hasVisibleSession: Bool {
        window?.isVisible == true
    }

    func performNewPrompt() {
        if isRunningAI || clarificationSession != nil { cancelActiveAIWithoutFeedback() }
        if let current = snapshotIfWorthKeeping() { recoverableDraft = current }
        beginFreshSession()
        startsNewSessionOnNextShow = false
        show()
        window?.makeFirstResponder(textView)
    }

    func restoreLastDraft() {
        guard let snapshot = recoverableDraft else {
            NSSound.beep()
            return
        }
        recoverableDraft = nil
        startsNewSessionOnNextShow = false
        show()
        applyEditorSnapshot(snapshot, actionName: L("恢复上次草稿"), registersUndo: false)
        undoSnapshots.removeAll()
        redoSnapshots.removeAll()
    }

    func performShowHistory() {
        if startsNewSessionOnNextShow,
           let recoverableDraft,
           !recoverableDraft.context.isEmpty {
            restoreLastDraft()
        } else {
            show()
        }
        guard !conversationTurns.isEmpty else { return }
        historyController.showLatest(relativeTo: window)
    }

    private func endCurrentSessionAndHide() {
        if clarificationSession != nil {
            resetClarification(dismissWindow: true)
        }
        if isRunningAI {
            cancelActiveAIWithoutFeedback()
            setAIControlsEnabled(true)
        }
        if let current = snapshotIfWorthKeeping() { recoverableDraft = current }
        commandMenuVisible = false
        pendingTemplateMatch = nil
        templateMatchWorkItem?.cancel()
        startsNewSessionOnNextShow = true
        updateSecondaryVisibility(animated: false)
        window?.orderOut(nil)
    }

    private func beginFreshSession() {
        commandMenuVisible = false
        pendingTemplateMatch = nil
        ignoredTemplateTitles.removeAll()
        templateMatchWorkItem?.cancel()
        actionsFeedbackWorkItem?.cancel()
        lastError = nil
        retryAction = nil
        retryButton.isHidden = true
        errorDetailsButton.isHidden = true
        isShowingCopySuccess = false
        actionFeedbackReset()
        undoSnapshots.removeAll()
        redoSnapshots.removeAll()
        applyEditorSnapshot(
            EditorSnapshot(
                text: "",
                origin: nil,
                title: nil,
                selectedRange: NSRange(location: 0, length: 0),
                context: []
            ),
            actionName: L("新建 Prompt"),
            registersUndo: false
        )
    }

    private func snapshotIfWorthKeeping() -> EditorSnapshot? {
        let snapshot = currentEditorSnapshot()
        guard !snapshot.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !snapshot.context.isEmpty else {
            return nil
        }
        return snapshot
    }

    private func cancelActiveAIWithoutFeedback() {
        activeOperationID = nil
        activeOperationTitle = ""
        waitingFeedbackWorkItem?.cancel()
        activeAITask?.cancel()
        activeAITask = nil
        isRunningAI = false
        resetClarification(dismissWindow: true)
        actionFeedbackReset()
        textView.isEditable = true
    }

    private func actionFeedbackReset() {
        actionsLabel.stringValue = ""
        actionsLabel.toolTip = nil
        actionsLabel.textColor = AppTheme.secondaryTextColor
        feedbackMessageLabel.stringValue = ""
        feedbackMessageLabel.isHidden = true
        feedbackSymbol.isHidden = true
        activityIndicator.stopAnimation(nil)
        activityIndicator.isHidden = true
        feedbackContainer.tone = .neutral
    }

    private func configureUI() {
        guard let contentView = window?.contentView else { return }
        configureRoot(in: contentView)
        configureInput()
        configureDropdown()
        configureActions()
        installLayout(in: contentView)

        updateTabs()
        updatePlaceholderVisibility()
        adjustEditorHeight(animated: false)
    }

    private func configureRoot(in contentView: NSView) {
        rootView.translatesAutoresizingMaskIntoConstraints = false
        rootView.wantsLayer = true
        rootView.layer?.cornerRadius = 16
        rootView.layer?.masksToBounds = true
        contentView.addSubview(rootView)
        let accent = GuidedAccentView(frame: .zero)
        accent.translatesAutoresizingMaskIntoConstraints = false
        rootView.addSubview(accent)
        NSLayoutConstraint.activate([
            accent.leadingAnchor.constraint(equalTo: rootView.leadingAnchor), accent.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            accent.topAnchor.constraint(equalTo: rootView.topAnchor), accent.heightAnchor.constraint(equalToConstant: 210)
        ])
    }

    private func configureInput() {
        contentStack.orientation = .vertical
        contentStack.spacing = 12
        contentStack.alignment = .leading
        contentStack.distribution = .fill
        contentStack.detachesHiddenViews = true
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = AppTheme.semibold(17)
        let labelStack = NSStackView(views: [GuidedIdentityView(frame: .zero), titleLabel])
        labelStack.orientation = .horizontal
        labelStack.spacing = 10
        labelStack.alignment = .centerY
        titleLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        topBar.orientation = .horizontal
        topBar.spacing = 8
        topBar.alignment = .centerY
        topBar.translatesAutoresizingMaskIntoConstraints = false
        topBar.addArrangedSubview(labelStack)
        topBar.addArrangedSubview(spacer)
        topBar.addArrangedSubview(restoreDraftButton)
        topBar.addArrangedSubview(contextSummaryButton)
        settingsButton.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
        settingsButton.title = ""
        settingsButton.imagePosition = .imageOnly
        settingsButton.target = self
        settingsButton.action = #selector(settingsPressed)
        settingsButton.setAccessibilityLabel(L("设置"))
        settingsButton.toolTip = L("设置（⌘,）")
        AppTheme.styleButton(settingsButton, glass: true)
        let templateToolGroup = GlassToolGroup(content: contentMenuButton)
        let settingsToolGroup = GlassToolGroup(content: settingsButton)
        let tools = NSStackView(views: [templateToolGroup, settingsToolGroup])
        tools.orientation = .horizontal
        tools.alignment = .centerY
        tools.spacing = AppTheme.Spacing.control
        for button in [settingsButton] {
            button.bezelStyle = .toolbar
            button.isBordered = false
            button.contentTintColor = .labelColor
            button.image?.isTemplate = true
        }
        topBar.addArrangedSubview(tools)

        configureContextHistory()
        editorToolbar.orientation = .horizontal
        editorToolbar.alignment = .centerY
        editorToolbar.spacing = 8
        editorToolbar.detachesHiddenViews = true
        editorToolbar.translatesAutoresizingMaskIntoConstraints = false
        let objectSpacer = NSView()
        objectSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        placeholderHint.font = AppTheme.regular(12)
        placeholderHint.textColor = AppTheme.secondaryTextColor
        placeholderHint.maximumNumberOfLines = 2
        placeholderHint.setAccessibilityLabel(L("待填标记说明"))
        placeholderHint.translatesAutoresizingMaskIntoConstraints = false
        placeholderHintContainer.fillColor = AppTheme.placeholderFillColor
        placeholderHintContainer.borderColor = AppTheme.accentColor.withAlphaComponent(0.28)
        placeholderHintContainer.layer?.cornerRadius = 8
        placeholderHintContainer.translatesAutoresizingMaskIntoConstraints = false
        placeholderHintContainer.isHidden = true
        placeholderHintContainer.addSubview(placeholderHint)
        placeholderHint.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        NSLayoutConstraint.activate([
            placeholderHint.leadingAnchor.constraint(equalTo: placeholderHintContainer.leadingAnchor, constant: 9),
            placeholderHint.trailingAnchor.constraint(equalTo: placeholderHintContainer.trailingAnchor, constant: -9),
            placeholderHint.topAnchor.constraint(equalTo: placeholderHintContainer.topAnchor, constant: 4),
            placeholderHint.bottomAnchor.constraint(equalTo: placeholderHintContainer.bottomAnchor, constant: -4),
            placeholderHintContainer.heightAnchor.constraint(equalToConstant: 44)
        ])
        stylePlaceholderHint()
        clearButton.bezelStyle = .toolbar
        clearButton.isBordered = false
        clearButton.font = AppTheme.regular(12)
        clearButton.target = self; clearButton.action = #selector(clearInput)
        clearButton.toolTip = L("清空正文与修改记录；可按 ⌘Z 撤销")
        for view in [placeholderHintContainer, objectSpacer, clearButton] {
            editorToolbar.addArrangedSubview(view)
        }
        editorFooter.translatesAutoresizingMaskIntoConstraints = false
        editorSurface.addSubview(editorFooter)
        editorFooter.addSubview(editorToolbar)
        editorSeparator.boxType = .separator
        editorSeparator.translatesAutoresizingMaskIntoConstraints = false
        editorFooter.addSubview(editorSeparator)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.borderType = .noBorder
        AppTheme.configureContentScrollView(scrollView)
        editorSurface.translatesAutoresizingMaskIntoConstraints = false
        editorSurface.fillColor = AppTheme.contentColor
        editorSurface.addSubview(scrollView)
        editorScrollTrailingConstraint = scrollView.trailingAnchor.constraint(equalTo: editorSurface.trailingAnchor)
        editorFooterHeightConstraint = editorFooter.heightAnchor.constraint(equalToConstant: 0)
        editorToolbarHeightConstraint = editorToolbar.heightAnchor.constraint(equalToConstant: 24)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: editorSurface.leadingAnchor),
            editorScrollTrailingConstraint!,
            scrollView.topAnchor.constraint(equalTo: editorSurface.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: editorFooter.topAnchor),
            editorFooter.leadingAnchor.constraint(equalTo: editorSurface.leadingAnchor),
            editorFooter.trailingAnchor.constraint(equalTo: editorSurface.trailingAnchor),
            editorFooter.bottomAnchor.constraint(equalTo: editorSurface.bottomAnchor),
            editorFooterHeightConstraint!,
            editorSeparator.leadingAnchor.constraint(equalTo: editorFooter.leadingAnchor, constant: AppTheme.Spacing.section),
            editorSeparator.trailingAnchor.constraint(equalTo: editorFooter.trailingAnchor, constant: -AppTheme.Spacing.section),
            editorSeparator.heightAnchor.constraint(equalToConstant: 1),
            editorSeparator.bottomAnchor.constraint(equalTo: editorToolbar.topAnchor, constant: -AppTheme.Spacing.control),
            editorToolbar.leadingAnchor.constraint(equalTo: editorFooter.leadingAnchor, constant: AppTheme.Spacing.section),
            editorToolbar.trailingAnchor.constraint(equalTo: editorFooter.trailingAnchor, constant: -AppTheme.Spacing.section),
            editorToolbar.bottomAnchor.constraint(equalTo: editorFooter.bottomAnchor, constant: -AppTheme.Spacing.control),
            editorToolbarHeightConstraint!
        ])
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.contentView.postsBoundsChangedNotifications = true
        scrollBoundsObserver = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: scrollView.contentView,
            queue: .main
        ) { [weak self] _ in
            self?.updateEditorOverlays()
        }

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
        AppTheme.styleEditor(textView)
        textView.textContainerInset = NSSize(width: AppTheme.Spacing.section, height: AppTheme.Spacing.section)
        textView.textContainer?.lineFragmentPadding = 0
        let editorParagraph = NSMutableParagraphStyle()
        editorParagraph.paragraphSpacing = AppTheme.Spacing.small
        editorParagraph.lineBreakMode = .byWordWrapping
        textView.defaultParagraphStyle = editorParagraph
        textView.typingAttributes[.paragraphStyle] = editorParagraph
        textView.minSize = NSSize(width: 0, height: 96)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 612, height: CGFloat.greatestFiniteMagnitude)
        textView.placeholder = L("输入内容…")
        textView.setAccessibilityLabel(L("Prompt编辑区"))
        textView.setAccessibilityHelp(L("输入需求；空输入时按 / 或随时按 ⌘K 选择模板"))
        scrollView.documentView = textView

        placeholderMinimap.isHidden = true
        placeholderMinimap.onJump = { [weak self] range in
            self?.focusPlaceholder(range)
        }
        editorSurface.addSubview(placeholderMinimap)

        scrollToTopButton.title = ""
        scrollToTopButton.image = NSImage(
            systemSymbolName: "arrow.up.to.line",
            accessibilityDescription: L("回到正文顶部")
        )
        scrollToTopButton.image?.isTemplate = true
        scrollToTopButton.bezelStyle = .circular
        scrollToTopButton.controlSize = .small
        scrollToTopButton.isBordered = true
        scrollToTopButton.contentTintColor = .secondaryLabelColor
        scrollToTopButton.toolTip = L("回到正文顶部")
        scrollToTopButton.setAccessibilityLabel(L("回到正文顶部"))
        scrollToTopButton.target = self
        scrollToTopButton.action = #selector(scrollEditorToTop)
        scrollToTopButton.isHidden = true
        scrollToTopButton.translatesAutoresizingMaskIntoConstraints = false
        editorSurface.addSubview(scrollToTopButton)
        scrollToTopBottomConstraint = scrollToTopButton.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -12)
        scrollToTopAboveMapConstraint = scrollToTopButton.bottomAnchor.constraint(equalTo: placeholderMinimap.topAnchor, constant: -8)
        NSLayoutConstraint.activate([
            placeholderMinimap.trailingAnchor.constraint(equalTo: editorSurface.trailingAnchor, constant: -12),
            placeholderMinimap.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -12),
            placeholderMinimap.widthAnchor.constraint(equalToConstant: 30),
            placeholderMinimap.heightAnchor.constraint(equalToConstant: 104),
            scrollToTopButton.centerXAnchor.constraint(equalTo: placeholderMinimap.centerXAnchor),
            scrollToTopBottomConstraint!,
            scrollToTopButton.widthAnchor.constraint(equalToConstant: 28),
            scrollToTopButton.heightAnchor.constraint(equalToConstant: 28)
        ])
        // The minimap starts hidden; its geometry cannot block the independent
        // return-to-top action when the navigation slot is absent.
        scrollToTopBottomConstraint?.priority = .defaultHigh
        scrollToTopAboveMapConstraint?.priority = .defaultHigh

        contentStack.addArrangedSubview(topBar)
        contentStack.setCustomSpacing(20, after: topBar)
        contentStack.addArrangedSubview(editorSurface)
        rootView.addSubview(contentStack)
    }

    private func configureContextHistory() {
        AppLocalization.observe(self, selector: #selector(refreshLocalization))
        restoreDraftButton.translatesAutoresizingMaskIntoConstraints = false
        restoreDraftButton.target = self
        restoreDraftButton.action = #selector(restoreDraftButtonPressed)
        restoreDraftButton.bezelStyle = .toolbar
        restoreDraftButton.isBordered = false
        restoreDraftButton.font = AppTheme.medium(11)
        restoreDraftButton.image = NSImage(
            systemSymbolName: "arrow.uturn.backward",
            accessibilityDescription: nil
        )
        restoreDraftButton.image?.isTemplate = true
        restoreDraftButton.imagePosition = .imageLeading
        restoreDraftButton.contentTintColor = .secondaryLabelColor
        restoreDraftButton.toolTip = L("恢复最近一次收起的正文、模板来源和全部修改记录")
        restoreDraftButton.setAccessibilityLabel(L("恢复上次草稿"))
        restoreDraftButton.isHidden = true
        contextSummaryButton.translatesAutoresizingMaskIntoConstraints = false
        contextSummaryButton.target = self
        contextSummaryButton.action = #selector(contextSummaryPressed)
        contextSummaryButton.bezelStyle = .toolbar
        contextSummaryButton.isBordered = false
        contextSummaryButton.font = AppTheme.medium(11)
        contextSummaryButton.image = NSImage(systemSymbolName: "clock.arrow.circlepath", accessibilityDescription: nil)
        contextSummaryButton.imagePosition = .imageLeading
        contextSummaryButton.toolTip = L("在独立窗口查看本次编辑的全部输入与结果")
        contextSummaryButton.isHidden = true
        historyController.onClose = { [weak self] in
            guard let self else { return }
            self.window?.makeKeyAndOrderFront(nil)
            self.window?.makeFirstResponder(self.textView)
        }
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

        manageTemplatesButton.image = NSImage(systemSymbolName: "slider.horizontal.3", accessibilityDescription: L("管理我的模板"))
        manageTemplatesButton.image?.isTemplate = true
        manageTemplatesButton.bezelStyle = .rounded
        manageTemplatesButton.controlSize = .regular
        manageTemplatesButton.target = self
        manageTemplatesButton.action = #selector(manageTemplatesPressed)
        manageTemplatesButton.toolTip = L("管理我的模板库")
        manageTemplatesButton.translatesAutoresizingMaskIntoConstraints = false

        let headerSpacer = NSView()
        headerSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        dropdownHeaderStack.orientation = .horizontal
        dropdownHeaderStack.spacing = 8
        dropdownHeaderStack.alignment = .centerY
        dropdownHeaderStack.translatesAutoresizingMaskIntoConstraints = false
        dropdownHeaderStack.addArrangedSubview(modeControl)
        dropdownHeaderStack.addArrangedSubview(headerSpacer)
        manageTemplatesButton.title = L("管理")
        manageTemplatesButton.imagePosition = .imageLeading
        manageTemplatesButton.setAccessibilityLabel(L("管理我的模板"))
        AppTheme.styleButton(manageTemplatesButton)
        librarySearch.preparePlaceholder(L("搜索"))
        librarySearch.setAccessibilityLabel(L("搜索模板"))
        librarySearch.delegate = self
        librarySearch.sendsSearchStringImmediately = true
        librarySearch.target = self
        librarySearch.action = #selector(librarySearchChanged)
        librarySearch.translatesAutoresizingMaskIntoConstraints = false
        librarySearch.setContentHuggingPriority(.defaultLow, for: .horizontal)
        shortcutHelpButton.image = NSImage(
            systemSymbolName: "keyboard",
            accessibilityDescription: nil
        )
        shortcutHelpButton.image?.isTemplate = true
        shortcutHelpButton.imagePosition = .imageOnly
        shortcutHelpButton.bezelStyle = .rounded
        shortcutHelpButton.controlSize = .regular
        shortcutHelpButton.target = self
        shortcutHelpButton.action = #selector(shortcutHelpPressed)
        shortcutHelpButton.toolTip = L("查看模板快捷键")
        shortcutHelpButton.setAccessibilityLabel(L("模板快捷键"))
        shortcutHelpButton.setAccessibilityIdentifier("template-shortcuts")
        shortcutHelpButton.translatesAutoresizingMaskIntoConstraints = false
        librarySearchRow.orientation = .horizontal
        librarySearchRow.alignment = .centerY
        librarySearchRow.spacing = 8
        librarySearchRow.translatesAutoresizingMaskIntoConstraints = false
        librarySearchRow.addArrangedSubview(librarySearch)
        librarySearchRow.addArrangedSubview(shortcutHelpButton)
        templateShortcutPopover.behavior = .transient
        templateShortcutPopover.animates = false
        templateRecommendationView.onIgnore = { [weak self] in self?.ignoreTemplateSuggestion() }
        templateManagementStack.orientation = .horizontal
        templateManagementStack.alignment = .centerY
        templateManagementStack.spacing = 8
        templateManagementStack.detachesHiddenViews = true
        templateManagementStack.translatesAutoresizingMaskIntoConstraints = false
        for (button, action, help) in [
            (saveTemplateButton, #selector(saveTemplateButtonPressed), L("提取可复用模板，预览后保存")),
            (updateTemplateButton, #selector(updateTemplateButtonPressed), L("用当前内容更新来源模板"))
        ] {
            button.target = self
            button.action = action
            button.toolTip = help
            AppTheme.styleButton(button, glass: true)
            templateManagementStack.addArrangedSubview(button)
        }
        let managementSpacer = NSView()
        managementSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        templateManagementStack.addArrangedSubview(managementSpacer)
        templateManagementStack.addArrangedSubview(manageTemplatesButton)
        libraryEmptyLabel.font = AppTheme.regular(13)
        libraryEmptyLabel.textColor = AppTheme.secondaryTextColor
        libraryEmptyLabel.alignment = .center
        libraryEmptyLabel.translatesAutoresizingMaskIntoConstraints = false

        commandListView.orientation = .vertical
        commandListView.spacing = 2
        commandListView.alignment = .leading
        commandListView.distribution = .fill
        commandListView.edgeInsets = NSEdgeInsets(top: 6, left: 6, bottom: 6, right: 6)
        commandListView.translatesAutoresizingMaskIntoConstraints = true
        commandListView.autoresizingMask = [.width]
        commandListView.wantsLayer = true
        commandListView.layer?.cornerRadius = 10

        commandListScrollView.translatesAutoresizingMaskIntoConstraints = false
        AppTheme.configureContentScrollView(commandListScrollView)
        commandListScrollView.borderType = .bezelBorder
        commandListScrollView.hasVerticalScroller = true
        commandListScrollView.hasHorizontalScroller = false
        commandListScrollView.autohidesScrollers = true
        commandListScrollView.documentView = commandListView
        commandListScrollView.contentView.postsBoundsChangedNotifications = true
        templateHoverResetObserver = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: commandListScrollView.contentView,
            queue: .main
        ) { _ in
            CommandRowView.clearAllHover()
        }

        dropdownContainer.addArrangedSubview(templateRecommendationView)
        dropdownContainer.addArrangedSubview(dropdownHeaderStack)
        dropdownContainer.addArrangedSubview(librarySearchRow)
        dropdownContainer.addArrangedSubview(commandListScrollView)
        dropdownContainer.addArrangedSubview(templateManagementStack)
        dropdownContainer.isHidden = false

        let pickerRoot = WindowContentView(frame: NSRect(x: 0, y: 0, width: 620, height: 520))
        pickerRoot.translatesAutoresizingMaskIntoConstraints = false
        pickerRoot.addSubview(dropdownContainer)
        NSLayoutConstraint.activate([
            dropdownContainer.leadingAnchor.constraint(equalTo: pickerRoot.leadingAnchor, constant: 16),
            dropdownContainer.trailingAnchor.constraint(equalTo: pickerRoot.trailingAnchor, constant: -16),
            dropdownContainer.topAnchor.constraint(equalTo: pickerRoot.topAnchor, constant: 16),
            dropdownContainer.bottomAnchor.constraint(equalTo: pickerRoot.bottomAnchor, constant: -16)
        ])
        let pickerController = NSViewController()
        pickerController.view = pickerRoot
        let pickerWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 520),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        pickerWindow.title = L("模板中心")
        pickerWindow.titleVisibility = .visible
        pickerWindow.titlebarAppearsTransparent = false
        pickerWindow.isOpaque = true
        pickerWindow.backgroundColor = AppTheme.windowColor
        pickerWindow.isReleasedWhenClosed = false
        pickerWindow.isRestorable = false
        pickerWindow.level = .floating
        pickerWindow.minSize = NSSize(width: 560, height: 420)
        pickerWindow.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        pickerWindow.contentViewController = pickerController
        pickerWindow.delegate = self
        AppTheme.configureWindow(pickerWindow)
        templatePickerWindow = pickerWindow
    }

    private func configureActions() {
        actionsContainer.orientation = .horizontal
        actionsContainer.spacing = 8
        actionsContainer.alignment = .centerY
        actionsContainer.detachesHiddenViews = true
        actionsContainer.translatesAutoresizingMaskIntoConstraints = false
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        contentMenuButton.title = L("模板")
        contentMenuButton.image = NSImage(systemSymbolName: "chevron.down", accessibilityDescription: nil)
        contentMenuButton.image?.isTemplate = true
        contentMenuButton.imagePosition = .imageTrailing
        contentMenuButton.imageHugsTitle = true
        contentMenuButton.bezelStyle = .toolbar
        contentMenuButton.isBordered = false
        contentMenuButton.font = AppTheme.medium(13)
        contentMenuButton.contentTintColor = .labelColor
        contentMenuButton.alignment = .center
        contentMenuButton.target = self
        contentMenuButton.action = #selector(templatesPressed)
        contentMenuWidthConstraint = contentMenuButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 88)
        contentMenuWidthConstraint?.isActive = true
        contentMenuButton.heightAnchor.constraint(equalToConstant: 34).isActive = true
        contentMenuButton.setAccessibilityLabel(L("模板菜单"))
        contentMenuButton.setAccessibilityIdentifier("template-menu")
        let modes: [(ModeHoverButton, Selector, String, String)] = [
            (refineButton, #selector(refineButtonPressed), "refine", L("保留原意与结构，调整表达（⌘R）")),
            (regenerateButton, #selector(regenerateButtonPressed), "regenerate", L("按当前需求重新组织内容（⌘G）")),
            (clarifyButton, #selector(clarifyButtonPressed), "clarify", L("先回答关键问题，再生成Prompt"))
        ]
        for (button, action, iconName, help) in modes {
            button.target = self; button.action = action
            button.image = AppTheme.modeIcon(named: iconName)
            button.imagePosition = .imageLeading
            button.toolTip = help
            button.setAccessibilityLabel(button.title)
            button.widthAnchor.constraint(equalToConstant: 106).isActive = true
            button.heightAnchor.constraint(equalToConstant: 40).isActive = true
            button.refreshAppearance()
        }
        let modeGroup = NSStackView(views: [refineButton, regenerateButton, clarifyButton])
        modeGroup.orientation = .horizontal
        modeGroup.spacing = 8
        modeGroup.alignment = .centerY
        if #available(macOS 26.0, *) {
            let glassGroup = NSGlassEffectContainerView()
            glassGroup.contentView = modeGroup
            glassGroup.spacing = 8
            glassGroup.translatesAutoresizingMaskIntoConstraints = false
            modeGroup.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                modeGroup.leadingAnchor.constraint(equalTo: glassGroup.leadingAnchor),
                modeGroup.trailingAnchor.constraint(equalTo: glassGroup.trailingAnchor),
                modeGroup.topAnchor.constraint(equalTo: glassGroup.topAnchor),
                modeGroup.bottomAnchor.constraint(equalTo: glassGroup.bottomAnchor)
            ])
            modeGlassContainer = glassGroup
            actionsContainer.addArrangedSubview(glassGroup)
        } else {
            actionsContainer.addArrangedSubview(modeGroup)
        }
        refineButton.keyEquivalent = "r"; refineButton.keyEquivalentModifierMask = .command
        regenerateButton.keyEquivalent = "g"; regenerateButton.keyEquivalentModifierMask = .command
        commitButton.target = self; commitButton.action = #selector(commitButtonPressed)
        commitButton.keyEquivalent = "\r"; commitButton.keyEquivalentModifierMask = .command
        commitButton.toolTip = L("复制当前文字（⌘Return）")
        for button in [commitButton, stopButton] {
            button.widthAnchor.constraint(equalToConstant: 172).isActive = true
            button.heightAnchor.constraint(equalToConstant: 40).isActive = true
            button.imagePosition = .imageLeading
        }
        stopButton.image = AppTheme.primarySymbol(named: "stop.fill")
        stopButton.keepsPrimaryWhenInactive = true
        commitButton.setEmphasis(.neutral)
        stopButton.setEmphasis(.primary)
        commitButton.refreshAppearance()
        stopButton.refreshAppearance()
        for view in [spacer, commitButton, stopButton] { actionsContainer.addArrangedSubview(view) }
        contentStack.addArrangedSubview(actionsContainer)
        feedbackContainer.isHidden = true
        feedbackContainer.orientation = .horizontal
        feedbackContainer.spacing = 8
        feedbackContainer.alignment = .centerY
        feedbackContainer.detachesHiddenViews = true
        feedbackContainer.translatesAutoresizingMaskIntoConstraints = false
        actionsLabel.font = AppTheme.semibold(15)
        actionsLabel.textColor = AppTheme.secondaryTextColor
        actionsLabel.setAccessibilityLabel(L("操作状态"))
        actionsLabel.lineBreakMode = .byTruncatingTail
        actionsLabel.maximumNumberOfLines = 1
        actionsLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        feedbackMessageLabel.font = AppTheme.regular(12)
        feedbackMessageLabel.textColor = AppTheme.secondaryTextColor
        feedbackMessageLabel.setAccessibilityLabel(L("状态说明"))
        feedbackMessageLabel.lineBreakMode = .byWordWrapping
        feedbackMessageLabel.maximumNumberOfLines = 2
        feedbackMessageLabel.preferredMaxLayoutWidth = Self.preferredWindowWidth - 230
        feedbackMessageLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        feedbackMessageLabel.isHidden = true
        feedbackGlyphSlot.translatesAutoresizingMaskIntoConstraints = false
        feedbackGlyphSlot.widthAnchor.constraint(equalToConstant: 18).isActive = true
        feedbackGlyphSlot.heightAnchor.constraint(equalToConstant: 18).isActive = true
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        feedbackSymbol.translatesAutoresizingMaskIntoConstraints = false
        feedbackGlyphSlot.addSubview(activityIndicator)
        feedbackGlyphSlot.addSubview(feedbackSymbol)
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: feedbackGlyphSlot.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: feedbackGlyphSlot.centerYAnchor),
            feedbackSymbol.centerXAnchor.constraint(equalTo: feedbackGlyphSlot.centerXAnchor),
            feedbackSymbol.centerYAnchor.constraint(equalTo: feedbackGlyphSlot.centerYAnchor),
            feedbackSymbol.widthAnchor.constraint(equalToConstant: 16),
            feedbackSymbol.heightAnchor.constraint(equalToConstant: 16)
        ])
        feedbackHeaderStack.orientation = .horizontal
        feedbackHeaderStack.alignment = .centerY
        feedbackHeaderStack.spacing = AppTheme.Spacing.inline
        feedbackHeaderStack.addArrangedSubview(feedbackGlyphSlot)
        feedbackHeaderStack.addArrangedSubview(actionsLabel)
        feedbackTextStack.orientation = .vertical
        feedbackTextStack.alignment = .leading
        feedbackTextStack.spacing = 2
        feedbackTextStack.addArrangedSubview(feedbackHeaderStack)
        feedbackTextStack.addArrangedSubview(feedbackMessageLabel)
        feedbackHeaderStack.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        feedbackTextStack.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        feedbackTextStack.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        feedbackMessageLabel.leadingAnchor.constraint(equalTo: actionsLabel.leadingAnchor).isActive = true
        // The flexible spacer consumes leftover room; the visible status must
        // retain its intrinsic width when a running view is shown again.
        feedbackTextStack.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        feedbackTextStack.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        activityIndicator.style = .spinning
        activityIndicator.controlSize = .small
        activityIndicator.isDisplayedWhenStopped = false
        activityIndicator.setAccessibilityLabel(L("AI 处理中"))
        stopButton.target = self; stopButton.action = #selector(stopAI)
        stopButton.isHidden = true
        for button in [retryButton, errorDetailsButton] {
            button.controlSize = .small
            button.font = AppTheme.medium(12)
            button.translatesAutoresizingMaskIntoConstraints = false
            button.heightAnchor.constraint(equalToConstant: 32).isActive = true
        }
        errorDetailsButton.target = self
        errorDetailsButton.action = #selector(showErrorDetails)
        errorDetailsButton.isHidden = true
        errorDetailsButton.toolTip = L("查看错误原因和技术信息")
        errorDetailsButton.widthAnchor.constraint(equalToConstant: 60).isActive = true
        AppTheme.styleButton(errorDetailsButton, glass: true)
        AppTheme.styleButtonTitle(errorDetailsButton, primary: false)
        retryButton.target = self
        retryButton.action = #selector(retryLastAction)
        retryButton.toolTip = L("重新执行刚才的操作")
        retryButton.isHidden = true
        retryButton.widthAnchor.constraint(equalToConstant: 66).isActive = true
        AppTheme.styleButton(retryButton, primary: true)
        if #available(macOS 26.0, *) {
            retryButton.borderShape = .capsule
            errorDetailsButton.borderShape = .capsule
        }
        let feedbackActions = NSStackView(views: [retryButton, errorDetailsButton])
        feedbackActions.orientation = .horizontal
        feedbackActions.spacing = 6
        feedbackActions.alignment = .centerY
        feedbackActions.setContentHuggingPriority(.required, for: .horizontal)
        feedbackSymbol.isHidden = true
        let feedbackSpacer = NSView()
        feedbackSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        for view in [feedbackTextStack, feedbackSpacer, feedbackActions] {
            feedbackContainer.addArrangedSubview(view)
        }
        contentStack.insertArrangedSubview(feedbackContainer, at: 1)
        setAIControlsEnabled(true)
    }

    private func updateGuidedChrome() {
        let hasResult = !conversationTurns.isEmpty
        feedbackContainer.isHidden = !shouldShowFeedback
        commitButton.isHidden = isRunningAI
        commitButton.title = isShowingCopySuccess ? L("已复制") : L("复制 Prompt  ⌘↵")
        commitButton.image = nil
        commitButton.imagePosition = .noImage
        commitButton.setAccessibilityLabel(commitButton.title)
        commitButton.isEnabled = canCopy
        commitButton.setEmphasis(hasResult ? .primary : .neutral)
        commitButton.surface = hasResult ? .push : .glass
        commitButton.refreshAppearance()
    }

    private func installLayout(in contentView: NSView) {
        editorHeightConstraint = scrollView.heightAnchor.constraint(equalToConstant: 96)
        workspaceEditorMinimumHeightConstraint = scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 160)
        commandListHeightConstraint = commandListScrollView.heightAnchor.constraint(equalToConstant: 0)
        commandListHeightConstraint?.priority = .defaultHigh
        feedbackHeightConstraint = feedbackContainer.heightAnchor.constraint(equalToConstant: 48)
        editorSurface.setContentHuggingPriority(.defaultLow, for: .vertical)
        editorSurface.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

        NSLayoutConstraint.activate([
            rootView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            rootView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            rootView.topAnchor.constraint(equalTo: contentView.topAnchor),
            rootView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            contentStack.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -20),
            contentStack.topAnchor.constraint(equalTo: rootView.topAnchor, constant: 20),
            contentStack.bottomAnchor.constraint(equalTo: rootView.bottomAnchor, constant: -20),

            topBar.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            topBar.heightAnchor.constraint(equalToConstant: 44),

            feedbackContainer.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            contextSummaryButton.heightAnchor.constraint(equalToConstant: 24),

            editorSurface.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            editorHeightConstraint!,

            dropdownHeaderStack.widthAnchor.constraint(equalTo: dropdownContainer.widthAnchor),
            templateRecommendationView.widthAnchor.constraint(equalTo: dropdownContainer.widthAnchor),
            templateRecommendationView.heightAnchor.constraint(equalToConstant: TemplateRecommendationView.height),
            dropdownHeaderStack.heightAnchor.constraint(equalToConstant: 36),
            templateManagementStack.widthAnchor.constraint(equalTo: dropdownContainer.widthAnchor),
            templateManagementStack.heightAnchor.constraint(equalToConstant: 40),
            modeControl.widthAnchor.constraint(equalToConstant: 240),
            manageTemplatesButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 78),
            settingsButton.widthAnchor.constraint(equalToConstant: 34),
            librarySearchRow.widthAnchor.constraint(equalTo: dropdownContainer.widthAnchor),
            librarySearchRow.heightAnchor.constraint(equalToConstant: 32),
            librarySearch.widthAnchor.constraint(equalTo: librarySearchRow.widthAnchor, constant: -40),
            shortcutHelpButton.widthAnchor.constraint(equalToConstant: 32),
            shortcutHelpButton.heightAnchor.constraint(equalToConstant: 32),
            commandListScrollView.widthAnchor.constraint(equalTo: dropdownContainer.widthAnchor),
            commandListHeightConstraint!,

            actionsContainer.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            actionsContainer.heightAnchor.constraint(equalToConstant: 44),
            feedbackHeightConstraint!
        ])
    }

    private func positionWindow(_ window: NSWindow) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main ?? NSScreen.screens.first
        let visibleFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        window.setContentSize(NSSize(width: Self.preferredWindowWidth, height: max(1, window.contentView?.frame.height ?? 1)))
        let size = window.frame.size
        let origin = NSPoint(
            x: visibleFrame.midX - size.width / 2,
            y: visibleFrame.maxY - size.height - 120
        )
        window.setFrameOrigin(origin)
    }

    private func resizeWindowForContent(animated: Bool) {
        guard !clarificationIsActive, let window else { return }
        if isWorkspaceMode {
            updateWorkspaceLayout()
            return
        }
        feedbackHeightConstraint?.constant = feedbackHeight
        let editorHeight = editorHeightConstraint?.constant ?? 34
        let secondaryHeight = normalSecondaryHeight
        let desiredHeight = editorHeight + 104 + editorFooterHeight + (!shouldShowFeedback ? 0 : feedbackHeight + 12) + (secondaryHeight > 0 ? secondaryHeight + 12 : 0)
        var frame = window.frame
        let oldMaxY = frame.maxY
        frame.size.width = isWorkspaceMode ? max(Self.minimumWorkspaceSize.width, frame.width) : Self.preferredWindowWidth
        frame.size.height = isWorkspaceMode ? max(Self.minimumWorkspaceSize.height, frame.height) : desiredHeight
        let visibleFrame = (window.screen ?? NSScreen.main)?.visibleFrame
        if let visibleFrame {
            frame.origin.y = max(visibleFrame.minY + 12, min(oldMaxY - desiredHeight, visibleFrame.maxY - desiredHeight - 12))
        } else {
            frame.origin.y = oldMaxY - desiredHeight
        }

        if animated && !motionPreference() {
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
        true
    }


    private var shouldShowFeedback: Bool {
        !actionsLabel.stringValue.isEmpty && clarificationWindowController?.isPresented != true
    }

    private var feedbackHeight: CGFloat {
        guard !feedbackMessageLabel.isHidden else { return 48 }
        let messageHeight = (feedbackMessageLabel.stringValue as NSString).boundingRect(
            with: NSSize(width: Self.preferredWindowWidth - 230, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: AppTheme.regular(12)]
        ).height
        return max(48, 34 + min(ceil(messageHeight), 32))
    }

    private var normalSecondaryHeight: CGFloat {
        shouldShowActions ? 44 : 0
    }



    private var commandListHeight: CGFloat {
        min(commandDocumentHeight + 4, 300)
    }

    private var commandDocumentHeight: CGFloat {
        let count = CGFloat(visibleLibraryItems.count)
        guard count > 0 else { return 76 }
        return 12 + count * CommandRowView.rowHeight + max(0, count - 1) * commandListView.spacing
    }

    private var showsTemplateRecommendation: Bool {
        guard commandMenuVisible, let pendingTemplateMatch else { return false }
        return currentMode == pendingTemplateMatch.mode
            && librarySearch.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func updateTabs() {
        modeControl.selectedSegment = currentMode.rawValue
        manageTemplatesButton.isHidden = false
    }

    private var editorFooterHeight: CGFloat {
        guard !textView.string.isEmpty else { return 0 }
        return (placeholderHintContainer.isHidden ? 24 : AppTheme.editorToolbarHeight) + 37
    }

    private func updateEditorFooter() {
        editorFooter.isHidden = editorFooterHeight == 0
        editorFooterHeightConstraint?.constant = editorFooterHeight
        editorToolbarHeightConstraint?.constant = placeholderHintContainer.isHidden ? 24 : AppTheme.editorToolbarHeight
    }

    private func updatePlaceholderVisibility() {
        let whole = NSRange(location: 0, length: (textView.string as NSString).length)
        textView.layoutManager?.removeTemporaryAttribute(.foregroundColor, forCharacterRange: whole)
        textView.layoutManager?.removeTemporaryAttribute(.backgroundColor, forCharacterRange: whole)
        let tokens = navigator.tokens(in: textView.string)
        if whole.length > 0, let baseParagraph = textView.defaultParagraphStyle {
            textView.textStorage?.beginEditing()
            textView.textStorage?.addAttribute(.paragraphStyle, value: baseParagraph, range: whole)
            let fieldParagraph = baseParagraph.mutableCopy() as! NSMutableParagraphStyle
            fieldParagraph.paragraphSpacing = AppTheme.Spacing.section
            for token in tokens {
                let fieldRange = NSRange(location: token.range.location,
                                         length: max(token.markerRange.length, NSMaxRange(token.valueRange) - token.range.location))
                let paragraphRange = (textView.string as NSString).paragraphRange(for: fieldRange)
                textView.textStorage?.addAttribute(.paragraphStyle, value: fieldParagraph, range: paragraphRange)
            }
            textView.textStorage?.endEditing()
        }
        for token in tokens {
            textView.layoutManager?.addTemporaryAttributes([
                .foregroundColor: token.isFilled ? AppTheme.secondaryTextColor : AppTheme.placeholderTextColor
            ], forCharacterRange: token.range)
        }
        placeholderHintContainer.isHidden = tokens.isEmpty
        updateEditorFooter()
        textView.needsDisplay = true
        updateEditorOverlays()
    }

    private func stylePlaceholderHint() {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 3
        let text = placeholderHint.stringValue
        let attributed = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: AppTheme.regular(12),
                .foregroundColor: AppTheme.secondaryTextColor,
                .paragraphStyle: paragraph
            ]
        )
        let markerRange = (text as NSString).range(of: "【】")
        if markerRange.location != NSNotFound {
            attributed.addAttributes([
                .font: AppTheme.semibold(12),
                .foregroundColor: AppTheme.placeholderTextColor,
                .backgroundColor: AppTheme.placeholderActiveFillColor
            ], range: markerRange)
        }
        placeholderHint.attributedStringValue = attributed
    }

    private func updateEditorOverlays() {
        guard !updatingEditorOverlays else { return }
        updatingEditorOverlays = true
        defer { updatingEditorOverlays = false }
        let tokens = navigator.tokens(in: textView.string)
        guard let layoutManager = textView.layoutManager, let textContainer = textView.textContainer else { return }
        layoutManager.ensureLayout(for: textContainer)
        var usedHeight = layoutManager.usedRect(for: textContainer).height
        var contentHeight = ceil(usedHeight + textView.textContainerInset.height * 2 + 8)
        let viewportHeight = max(1, scrollView.contentSize.height)
        let canScroll = contentHeight > viewportHeight + 1
        let gutter: CGFloat = canScroll && pendingClarificationRound == nil ? -48 : 0
        if editorScrollTrailingConstraint?.constant != gutter {
            editorScrollTrailingConstraint?.constant = gutter
            rootView.layoutSubtreeIfNeeded()
            adjustEditorHeight(animated: false)
            layoutManager.ensureLayout(for: textContainer)
            usedHeight = layoutManager.usedRect(for: textContainer).height
            contentHeight = ceil(usedHeight + textView.textContainerInset.height * 2 + 8)
        }
        let documentHeight = max(viewportHeight, textView.bounds.height, contentHeight)
        let scrollableHeight = max(0, documentHeight - viewportHeight)
        let viewport = scrollView.contentView.bounds
        let scrollValue = scrollableHeight > 0 ? max(0, min(1, viewport.minY / scrollableHeight)) : 0
        let showsMinimap = !tokens.isEmpty && canScroll && gutter != 0
        placeholderMinimap.isHidden = !showsMinimap
        scrollToTopButton.isHidden = gutter == 0 || scrollValue < 0.95
        scrollToTopBottomConstraint?.isActive = !showsMinimap
        scrollToTopAboveMapConstraint?.isActive = showsMinimap
        guard !placeholderMinimap.isHidden else { return }
        placeholderMinimap.update(
            textView: textView,
            tokens: tokens,
            documentHeight: documentHeight,
            visibleRect: viewport
        )
    }

    private func scheduleEditorOverlayRefresh() {
        DispatchQueue.main.async { [weak self] in
            self?.updateEditorOverlays()
        }
    }

    private func currentEditorSnapshot() -> EditorSnapshot {
        EditorSnapshot(
            text: textView.string,
            origin: activeTemplateOrigin,
            title: activeTemplateTitle,
            selectedRange: textView.selectedRange(),
            context: conversationTurns
        )
    }

    private func editorSnapshot(text: String, origin: TemplateOrigin?, title: String?, selectedRange: NSRange? = nil) -> EditorSnapshot {
        EditorSnapshot(
            text: text,
            origin: origin,
            title: title,
            selectedRange: selectedRange ?? NSRange(location: min((text as NSString).length, textView.selectedRange().location), length: 0),
            context: conversationTurns
        )
    }

    private func snapshotsEqual(_ lhs: EditorSnapshot, _ rhs: EditorSnapshot) -> Bool {
        lhs.text == rhs.text
            && lhs.context == rhs.context
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

        isShowingCopySuccess = false
        isRestoringEditorSnapshot = true
        defer { isRestoringEditorSnapshot = false }
        activeTemplateOrigin = snapshot.origin
        activeTemplateTitle = snapshot.title
        conversationTurns = snapshot.context
        textView.string = snapshot.text
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
        updateEditorOverlays()
    }

    private func performEditorUndo() {
        guard !isRunningAI, !clarificationIsActive else { return }
        guard let snapshot = undoSnapshots.popLast() else {
            NSSound.beep()
            return
        }
        redoSnapshots.append(currentEditorSnapshot())
        applyEditorSnapshot(snapshot, actionName: L("撤销"), registersUndo: false)
        refreshEditorAfterUndoRedo()
    }

    private func performEditorRedo() {
        guard !isRunningAI, !clarificationIsActive else { return }
        guard let snapshot = redoSnapshots.popLast() else {
            NSSound.beep()
            return
        }
        undoSnapshots.append(currentEditorSnapshot())
        applyEditorSnapshot(snapshot, actionName: L("重做"), registersUndo: false)
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
        guard !isRunningAI, !clarificationIsActive else { return }
        registerEditorUndoStep()
        actionsFeedbackWorkItem?.cancel()
        lastError = nil
        isShowingCopySuccess = false
        actionsLabel.stringValue = ""
        actionsLabel.toolTip = nil
        feedbackMessageLabel.stringValue = ""
        feedbackMessageLabel.isHidden = true
        errorDetailsButton.isHidden = true
        selectedIndex = 0
        commandMenuVisible = false
        pendingTemplateMatch = nil
        ignoredTemplateTitles.removeAll()
        templateMatchWorkItem?.cancel()
        resetClarification()
        resetConversationContext()
        applyEditorSnapshot(
            editorSnapshot(text: "", origin: nil, title: nil, selectedRange: NSRange(location: 0, length: 0)),
            actionName: L("清空"), registersUndo: false
        )
    }

    private func refreshMenu() {
        updateTabs()
        rebuildCommandRows()
        refreshSelectionChrome()
        templateRecommendationView.isHidden = !showsTemplateRecommendation
        commandListHeightConstraint?.constant = commandListHeight
        resizeWindowForContent(animated: false)
    }

    private func rebuildCommandRows() {
        CommandRowView.clearAllHover()
        commandRows.forEach { row in
            commandListView.removeArrangedSubview(row)
            row.removeFromSuperview()
        }
        commandRows = []
        if libraryEmptyLabel.superview != nil {
            commandListView.removeArrangedSubview(libraryEmptyLabel)
            libraryEmptyLabel.removeFromSuperview()
        }

        let items = visibleLibraryItems
        if items.isEmpty {
            libraryEmptyLabel.stringValue = librarySearch.stringValue.isEmpty ? L("暂无模板") : L("无匹配")
            commandListView.addArrangedSubview(libraryEmptyLabel)
            libraryEmptyLabel.widthAnchor.constraint(equalTo: commandListView.widthAnchor, constant: -12).isActive = true
            libraryEmptyLabel.heightAnchor.constraint(equalToConstant: 64).isActive = true
        }
        for (index, item) in items.enumerated() {
            let row = CommandRowView()
            row.configure(with: item, isSelected: index == selectedIndex, replacesContent: !textView.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            row.onChoose = { [weak self] in
                self?.selectedIndex = index
                self?.refreshSelectionChrome()
            }
            row.onApply = { [weak self] in
                self?.selectedIndex = index
                self?.insertSelectedTemplate()
            }
            commandListView.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: commandListView.widthAnchor, constant: -12).isActive = true
            commandRows.append(row)
        }
        let pickerContentWidth = max(320, (templatePickerWindow?.contentView?.bounds.width ?? 620) - 32)
        commandListView.setFrameSize(NSSize(width: pickerContentWidth, height: commandDocumentHeight))
        AppLocalization.refresh(commandListView)
        commandListView.layoutSubtreeIfNeeded()
        if commandRows.indices.contains(selectedIndex) {
            commandListView.scrollToVisible(commandRows[selectedIndex].frame)
        }
    }

    private func refreshSelectionChrome() {
        let itemCount = visibleLibraryItems.count
        if selectedIndex < 0 || selectedIndex >= itemCount {
            return
        }
        for (index, row) in commandRows.enumerated() {
            row.setSelected(index == selectedIndex)
        }
        commandListView.scrollToVisible(commandRows[selectedIndex].frame)
    }

    private func showCommandMenu() {
        guard !isRunningAI, !clarificationIsActive else { return }
        if pendingTemplateMatch == nil,
           let match = PromptTemplateMatcher.bestMatch(for: textView.string.trimmingCharacters(in: .whitespacesAndNewlines)),
           !ignoredTemplateTitles.contains(match.item.title) {
            pendingTemplateMatch = match
        }
        librarySearch.stringValue = ""
        commandMenuVisible = true
        templateMatchWorkItem?.cancel()
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        textView.scrollRangeToVisible(NSRange(location: 0, length: 0))
        if let match = pendingTemplateMatch {
            templateRecommendationView.configure(with: match)
            currentMode = match.mode
            let items = PromptStore.items(for: currentMode)
            if let suggestedIndex = items.firstIndex(where: { $0.origin == match.item.origin && $0.title == match.item.title }) {
                selectedIndex = suggestedIndex
            }
        }
        selectedIndex = min(selectedIndex, max(0, PromptStore.items(for: currentMode).count - 1))
        refreshMenu()
        showTemplatePicker()
        updateSecondaryVisibility(animated: false)
        DispatchQueue.main.async { [weak self] in
            self?.templatePickerWindow?.makeFirstResponder(self?.librarySearch)
        }
        scrollView.contentView.scroll(to: .zero)
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    private var templatePickerSize: NSSize {
        let recommendation = showsTemplateRecommendation ? TemplateRecommendationView.height : 0
        let arrangedCount: CGFloat = showsTemplateRecommendation ? 5 : 4
        let content = recommendation + 36 + 32 + commandListHeight + 40
            + 8 * max(0, arrangedCount - 1)
        return NSSize(width: 620, height: min(620, max(360, content + 32)))
    }

    private func showTemplatePicker() {
        guard let parent = window, let picker = templatePickerWindow else { return }
        CommandRowView.clearAllHover()
        picker.setContentSize(templatePickerSize)
        if picker.parent == nil {
            parent.addChildWindow(picker, ordered: .above)
        }
        AppTheme.center(picker, on: parent.screen ?? NSScreen.main)
        picker.makeKeyAndOrderFront(nil)
    }

    private func hideTemplatePicker() {
        guard let picker = templatePickerWindow else { return }
        CommandRowView.clearAllHover()
        picker.orderOut(nil)
        picker.parent?.removeChildWindow(picker)
    }

    private func updateSecondaryVisibility(animated: Bool) {
        adjustEditorHeight(animated: false)
        let showActions = shouldShowActions
        updateTemplateButtonVisibility()
        updateContextHistoryVisibility()
        let changes = {
            self.templateRecommendationView.isHidden = !self.showsTemplateRecommendation
            self.actionsContainer.isHidden = !showActions
            self.feedbackContainer.isHidden = !self.shouldShowFeedback
            self.commandListHeightConstraint?.constant = self.commandMenuVisible ? self.commandListHeight : 0
        }

        if animated && !motionPreference() {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.14
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                changes()
            self.textView.window?.contentView?.layoutSubtreeIfNeeded()
            }
        } else {
            changes()
        }
        setAIControlsEnabled(!isRunningAI, activeTitle: isRunningAI ? activeOperationTitle : nil)
        adjustEditorHeight(animated: animated)
    }

    private func updateContextHistoryVisibility() {
        restoreDraftButton.isHidden = !canRestoreLastDraft
        restoreDraftButton.isEnabled = canRestoreLastDraft
        contextSummaryButton.isHidden = conversationTurns.isEmpty
        contextSummaryButton.title = AppLocalization.isEnglish
            ? "Revision History · \(conversationTurns.count) \(conversationTurns.count == 1 ? "Round" : "Rounds")"
            : AppLocalization.format("修改记录 · %@ 轮", conversationTurns.count)
        contextSummaryButton.setAccessibilityLabel(contextSummaryButton.title)
        historyController.update(conversationTurns.enumerated().map { index, turn in
            HistoryWindowController.Entry(round: index + 1, action: turn.actionTitle, date: turn.createdAt,
                                          input: turn.query, output: turn.result,
                                          clarificationRounds: turn.clarificationSession?.rounds ?? [],
                                          originalQuery: turn.clarificationSession?.originalQuery)
        })
        if conversationTurns.isEmpty { historyController.close() }
    }

    @objc private func refreshLocalization() {
        let feedback = actionsLabel.stringValue
        let feedbackDetail = feedbackMessageLabel.stringValue
        let activeOrigin = activeTemplateOrigin
        AppLocalization.refresh(rootView)
        stylePlaceholderHint()
        if let content = workspaceWindow?.contentView { AppLocalization.refresh(content) }
        if let picker = templatePickerWindow?.contentView {
            AppLocalization.refresh(picker)
        }
        templatePickerWindow?.title = L("模板中心")
        actionsLabel.stringValue = AppLocalization.redisplay(feedback)
        feedbackMessageLabel.stringValue = AppLocalization.redisplay(feedbackDetail)
        actionsLabel.toolTip = actionsLabel.toolTip.map(AppLocalization.redisplay)
        textView.placeholder = L("输入内容…")
        if let activeOrigin,
           let item = PromptStore.items(for: .prompt).first(where: { $0.origin == activeOrigin }) {
            activeTemplateTitle = item.title
        }
        templateRecommendationView.refreshLocalization()
        if commandMenuVisible {
            refreshMenu()
        }
        // Closing the template center may clear this button's title while it
        // is hidden. Restore the semantic title on every language change.
        updateContextHistoryVisibility()
        updateTemplateButtonVisibility()
        updateSecondaryVisibility(animated: false)
    }

    @objc private func contextSummaryPressed() {
        guard !conversationTurns.isEmpty else { return }
        historyController.showLatest(relativeTo: window)
    }

    @objc private func restoreDraftButtonPressed() {
        restoreLastDraft()
    }

    private func updateTemplateButtonVisibility() {
        let hasEditableTemplate = TemplateUpdatePolicy.current.allows(activeTemplateOrigin)
        updateTemplateButton.isHidden = !hasEditableTemplate
        contentMenuButton.contentTintColor = .labelColor
        contentMenuButton.toolTip = L("打开模板中心（⌘K）")
        if let title = activeTemplateTitle, hasEditableTemplate {
            updateTemplateButton.toolTip = AppLocalization.format("用当前内容更新「%@」", title)
        } else {
            updateTemplateButton.toolTip = L("从模板插入后，可用当前内容更新原模板")
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

    @objc private func templatesPressed() { showCommandMenu() }
    @objc private func settingsPressed() { onOpenSettings?() }

    @objc private func shortcutHelpPressed() {
        if templateShortcutPopover.isShown {
            templateShortcutPopover.performClose(nil)
            return
        }
        let container = makeTemplateShortcutPopoverView()
        let controller = NSViewController()
        controller.view = container
        templateShortcutPopover.contentViewController = controller
        templateShortcutPopover.contentSize = container.frame.size
        templateShortcutPopover.show(
            relativeTo: shortcutHelpButton.bounds,
            of: shortcutHelpButton,
            preferredEdge: .maxY
        )
    }

    private func makeTemplateShortcutPopoverView() -> NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 162))
        let heading = NSTextField(labelWithString: L("快捷键"))
        heading.font = AppTheme.semibold(13)
        heading.textColor = .labelColor
        heading.translatesAutoresizingMaskIntoConstraints = false
        let guide = ShortcutGuideView(entries: ShortcutGuideView.templateEntries)
        container.addSubview(heading)
        container.addSubview(guide)
        NSLayoutConstraint.activate([
            heading.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
            heading.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            guide.leadingAnchor.constraint(equalTo: heading.leadingAnchor),
            guide.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),
            guide.topAnchor.constraint(equalTo: heading.bottomAnchor, constant: 8),
            guide.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor, constant: -12)
        ])
        return container
    }

    private var visibleLibraryItems: [LibraryItem] {
        let query = librarySearch.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let all = PromptStore.items(for: currentMode)
        guard !query.isEmpty else { return all }
        return all.filter { [$0.title, $0.detail, $0.body].contains { $0.localizedStandardContains(query) } }
    }
    @objc private func librarySearchChanged() {
        let query = librarySearch.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty, let match = pendingTemplateMatch {
            currentMode = match.mode
            selectedIndex = PromptStore.items(for: currentMode).firstIndex {
                $0.origin == match.item.origin && $0.title == match.item.title
            } ?? 0
        } else {
            selectedIndex = 0
        }
        refreshMenu()
    }
    func controlTextDidChange(_ notification: Notification) {
        if notification.object as? NSSearchField === librarySearch { librarySearchChanged() }
    }
    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        guard control === librarySearch else { return false }
        switch selector {
        case #selector(NSResponder.moveDown(_:)): promptTextViewDidRequestMenuMove(self.textView, delta: 1)
        case #selector(NSResponder.moveUp(_:)): promptTextViewDidRequestMenuMove(self.textView, delta: -1)
        case #selector(NSResponder.insertTab(_:)), #selector(NSResponder.insertBacktab(_:)):
            promptTextViewDidRequestModeSwitch(self.textView)
            window?.makeFirstResponder(librarySearch)
        case #selector(NSResponder.insertNewline(_:)): insertSelectedTemplate()
        case #selector(NSResponder.cancelOperation(_:)): promptTextViewDidRequestClose(self.textView)
        default: return false
        }
        return true
    }

    private func aiContextTurns() -> [AIContextTurn] {
        conversationTurns.suffix(3).map { turn in
            AIContextTurn(actionTitle: turn.actionTitle, query: turn.query, result: turn.result)
        }
    }

    private func appendConversationTurn(query: String, result: String, actionTitle: String,
                                        clarificationSession: ClarificationSession? = nil) {
        conversationTurns.append(ConversationTurn(
            query: query,
            result: result,
            actionTitle: actionTitle,
            createdAt: Date(),
            clarificationSession: clarificationSession
        ))
        updateContextHistoryVisibility()
        if !motionPreference() {
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 0.8; fade.toValue = 1
            let settle = CABasicAnimation(keyPath: "transform.translation.y")
            settle.fromValue = 4; settle.toValue = 0
            let arrival = CAAnimationGroup()
            arrival.animations = [fade, settle]
            arrival.duration = 0.22
            arrival.timingFunction = CAMediaTimingFunction(name: .easeOut)
            editorSurface.layer?.add(arrival, forKey: "resultArrival")
        }
        resizeWindowForContent(animated: true)
    }

    private func resetConversationContext() {
        conversationTurns.removeAll()
        updateContextHistoryVisibility()
    }

    private func startClarification() {
        guard !isRunningAI, !clarificationIsActive else { return }
        let input = textView.string
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            NSSound.beep()
            return
        }
        guard let client = configuredClient() else { return }

        let session = ClarificationSession(originalQuery: input)
        let runID = UUID()
        let sheet = ClarificationWindowController()
        sheet.onSubmit = { [weak self] answer in self?.submitClarificationAnswer(answer) }
        sheet.onUseGeneratedResult = { [weak self] in self?.acceptPendingNoQuestionFinal() }
        sheet.onEnd = { [weak self] in
            guard let self else { return }
            if self.isRunningAI { self.stopAI() } else { self.endClarification() }
        }
        sheet.onDismiss = { [weak self] in self?.endClarification() }

        // Commit the operation gate before AppKit enters the sheet's nested
        // presentation/event path. Otherwise the tail of the original click can
        // start another AI action while the sheet is still loading.
        clarificationWindowController = sheet
        sheet.configureLoading()
        pendingTemplateMatch = nil
        templateMatchWorkItem?.cancel()
        clarificationSession = session
        clarificationClient = client
        pendingClarificationRound = nil
        pendingClarificationQuestionIndex = 0
        pendingClarificationAnswers = []
        clarificationRunID = runID
        textView.isEditable = false
        isRunningAI = true
        setAIControlsEnabled(false, activeTitle: L("正在追问…"))
        // A pending window-size animation would race the container expansion
        // and collapse the host after the sheet has already attached.
        updateSecondaryVisibility(animated: false)
        let expandedHostFrame = prepareClarificationHost()
        let hostWindow = window
        sheet.present(relativeTo: hostWindow)
        if let expandedHostFrame, let hostWindow {
            hostWindow.setFrame(expandedHostFrame, display: true)
            hostWindow.contentView?.layoutSubtreeIfNeeded()
        }
        DispatchQueue.main.async { [weak self] in
            guard let self, self.clarificationRunID == runID, self.clarificationIsActive else { return }
            self.evaluateClarification(session: session, runID: runID, fallbackSession: nil)
        }
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
        clarificationWindowController?.setLoading(true)
        setAIControlsEnabled(false, activeTitle: L("正在追问…"))
        evaluateClarification(session: session, runID: runID, fallbackSession: previousSession)
    }

    private func evaluateClarification(
        session: ClarificationSession,
        runID: UUID,
        fallbackSession: ClarificationSession?
    ) {
        guard let client = clarificationClient else { return }
        let operationID = beginAI(title: L("正在整理追问…"))
        activeAITask = Task { [weak self] in
            do {
                let decision = try await client.runClarification(session: session)
                await MainActor.run {
                    guard let self, self.clarificationRunID == runID, self.finishAI(operationID) else { return }
                    switch decision {
                    case .ask(let round):
                        self.clarificationSession = session
                        self.pendingClarificationRound = round
                        self.pendingClarificationQuestionIndex = 0
                        self.pendingClarificationAnswers = []
                        self.clarificationWindowController?.setLoading(false)
                        self.showPendingClarificationQuestion()
                    case .final(let prompt):
                        if session.completedRounds == 0 {
                            self.showNoQuestionsNeeded(prompt: prompt, session: session)
                        } else {
                            self.completeClarification(prompt: prompt, session: session)
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    guard let self, self.clarificationRunID == runID, self.finishAI(operationID) else { return }
                    if let fallbackSession {
                        self.clarificationSession = fallbackSession
                        let previousAnswer = self.pendingClarificationAnswers.popLast()
                        if let round = self.pendingClarificationRound {
                            self.pendingClarificationQuestionIndex = max(0, round.questions.count - 1)
                        }
                        self.clarificationWindowController?.setLoading(false)
                        self.showPendingClarificationQuestion(restoring: previousAnswer)
                    } else {
                        self.clarificationWindowController?.setLoading(false)
                    }
                    let message = client.requestErrorMessage(for: error as NSError)
                    self.clarificationWindowController?.showError(
                        title: L("追问失败"),
                        message: message
                    ) { [weak self] in
                        guard let self else { return }
                        if self.pendingClarificationRound != nil {
                            self.clarificationWindowController?.panel.submitRestoredAnswer()
                        } else {
                            self.clarificationWindowController?.configureLoading()
                            self.isRunningAI = true
                            self.setAIControlsEnabled(false, activeTitle: L("正在追问…"))
                            self.evaluateClarification(session: session, runID: runID, fallbackSession: nil)
                        }
                    }
                    self.setAIControlsEnabled(!self.clarificationIsActive)
                    self.updateSecondaryVisibility(animated: false)
                }
            }
        }
    }

    private func showPendingClarificationQuestion(restoring answer: ClarificationAnswer? = nil, animated: Bool = true) {
        guard
            let session = clarificationSession,
            let round = pendingClarificationRound,
            round.questions.indices.contains(pendingClarificationQuestionIndex)
        else { return }

        clarificationWindowController?.setLoading(false)
        clarificationWindowController?.configure(
            question: round.questions[pendingClarificationQuestionIndex],
            round: session.nextRoundNumber,
            maximumRounds: ClarificationSession.maximumRounds,
            questionIndex: pendingClarificationQuestionIndex,
            totalQuestions: round.questions.count
        )
        if let answer { clarificationWindowController?.restoreAnswer(answer) }
        actionsLabel.stringValue = ""
        actionsLabel.toolTip = nil
        updateSecondaryVisibility(animated: animated)
        clarificationWindowController?.focusAnswer()
    }

    private func completeClarification(prompt: String, session: ClarificationSession) {
        let historyQuery = session.historyQuery()
        let finalPrompt = prompt
        guard PromptStructureIntegrity.preservesMarkdownBlockStructure(
            original: session.originalQuery,
            generated: finalPrompt
        ) else {
            let runID = clarificationRunID
            clarificationWindowController?.showError(
                title: L("追问失败"),
                message: AIClientError.invalidClarificationStructure.localizedDescription
            ) { [weak self] in
                guard let self, let runID else { return }
                self.clarificationWindowController?.configureLoading()
                self.isRunningAI = true
                self.setAIControlsEnabled(false, activeTitle: L("正在追问…"))
                self.evaluateClarification(session: session, runID: runID, fallbackSession: nil)
            }
            setAIControlsEnabled(false)
            updateSecondaryVisibility(animated: false)
            return
        }
        resetClarification(dismissWindow: true)
        applyEditorSnapshot(
            editorSnapshot(
                text: finalPrompt,
                origin: activeTemplateOrigin,
                title: activeTemplateTitle,
                selectedRange: NSRange(location: 0, length: 0)
            ),
            actionName: L("追问")
        )
        appendConversationTurn(query: historyQuery, result: finalPrompt, actionTitle: L("追问"), clarificationSession: session)
        highlightFirstPlaceholder()
        AppTheme.announce(L("追问已完成"), from: rootView)
        updateSecondaryVisibility(animated: true)
    }

    private func showNoQuestionsNeeded(prompt: String, session: ClarificationSession) {
        pendingNoQuestionFinal = (prompt, session)
        clarificationSession = session
        pendingClarificationRound = nil
        pendingClarificationQuestionIndex = 0
        pendingClarificationAnswers = []
        clarificationWindowController?.configureNoQuestions()
        updateSecondaryVisibility(animated: false)
        clarificationWindowController?.focusAnswer()
    }

    private func acceptPendingNoQuestionFinal() {
        guard let pending = pendingNoQuestionFinal else { return }
        pendingNoQuestionFinal = nil
        completeClarification(prompt: pending.prompt, session: pending.session)
    }

    private func resetClarification(dismissWindow: Bool = true) {
        clarificationRunID = nil
        clarificationSession = nil
        clarificationClient = nil
        pendingNoQuestionFinal = nil
        pendingClarificationRound = nil
        pendingClarificationQuestionIndex = 0
        pendingClarificationAnswers = []
        if dismissWindow {
            clarificationWindowController?.dismissSheet()
            clarificationWindowController = nil
            restoreClarificationHost()
        }
        textView.isEditable = true
    }

    @discardableResult
    private func prepareClarificationHost() -> NSRect? {
        guard clarificationHostFrame == nil, let window else { return nil }
        clarificationHostFrame = window.frame
        let visible = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let available = visible.insetBy(dx: 24, dy: 28)
        var target = window.frame
        target.size.width = min(max(target.width, 760), available.width)
        target.size.height = min(max(target.height, 680), available.height)
        target.origin.x = min(max(available.minX, target.origin.x), available.maxX - target.width)
        let maximumY = window.frame.maxY
        target.origin.y = max(available.minY, min(maximumY - target.height, available.maxY - target.height))
        window.setFrame(target, display: true)
        return target
    }

    private func restoreClarificationHost() {
        guard let saved = clarificationHostFrame, let window else {
            clarificationHostFrame = nil
            return
        }
        clarificationHostFrame = nil
        window.setFrame(saved, display: true)
    }

    private func endClarification() {
        if isRunningAI {
            activeOperationID = nil
            activeOperationTitle = ""
            waitingFeedbackWorkItem?.cancel()
            activeAITask?.cancel()
            activeAITask = nil
            isRunningAI = false
        }
        resetClarification(dismissWindow: true)
        setAIControlsEnabled(true)
        updateSecondaryVisibility(animated: false)
        window?.makeFirstResponder(textView)
    }

    private func runAIAction(_ action: AIAction) {
        guard !isRunningAI, !clarificationIsActive else { return }
        let input = textView.string
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, let client = configuredClient() else { return }
        let inheritedContext = aiContextTurns()
        let operationID = beginAI(title: action.runningTitle)
        activeAITask = Task { [weak self] in
            do {
                let output = try await client.run(action: action, input: input, context: inheritedContext)
                await MainActor.run {
                    guard let self, self.finishAI(operationID) else { return }
                    self.applyEditorSnapshot(
                        self.editorSnapshot(text: output, origin: self.activeTemplateOrigin, title: self.activeTemplateTitle,
                                            selectedRange: NSRange(location: 0, length: 0)),
                        actionName: action.buttonTitle
                    )
                    self.appendConversationTurn(query: input, result: output, actionTitle: action.buttonTitle)
                    self.highlightFirstPlaceholder()
                    AppTheme.announce(action.completedTitle, from: self.rootView)
                    self.updateSecondaryVisibility(animated: true)
                }
            } catch {
                await MainActor.run {
                    guard let self, self.finishAI(operationID) else { return }
                    self.showRequestError(title: action.failureTitle, error: error, client: client) { [weak self] in self?.runAIAction(action) }
                }
            }
        }
    }

    private func runSaveAsTemplate() {
        guard !isRunningAI, !clarificationIsActive else { return }
        let input = textView.string
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, let client = configuredClient() else { return }
        let operationID = beginAI(title: L("正在提取模板…"))
        activeAITask = Task { [weak self] in
            do {
                let draft = try await client.generateTemplateDraft(from: input)
                await MainActor.run {
                    guard let self, self.finishAI(operationID) else { return }
                    self.showTemplatePreview(draft)
                }
            } catch {
                await MainActor.run {
                    guard let self, self.finishAI(operationID) else { return }
                    self.showRequestError(title: L("生成模板失败"), error: error, client: client) { [weak self] in self?.runSaveAsTemplate() }
                }
            }
        }
    }

    private func configuredClient() -> OpenAIClient? {
        if let clientFactory { return clientFactory() }
        let option = AppSettings.modelOption
        if AIProvider.find(option.id)?.requiresAPIKey == false {
            return OpenAIClient(apiKey: "", modelOption: option)
        }
        guard let apiKey = configuredAPIKey() else { return nil }
        return OpenAIClient(apiKey: apiKey, modelOption: option)
    }

    private func beginAI(title: String) -> UUID {
        let id = UUID()
        activeOperationID = id
        activeOperationTitle = title
        pendingTemplateMatch = nil
        templateMatchWorkItem?.cancel()
        commandMenuVisible = false
        isRunningAI = true
        isShowingCopySuccess = false
        actionsFeedbackWorkItem?.cancel()
        lastError = nil
        retryAction = nil; retryButton.isHidden = true
        feedbackSymbol.isHidden = true
        errorDetailsButton.isHidden = true
        waitingFeedbackWorkItem?.cancel()
        let waiting = DispatchWorkItem { [weak self] in
            guard let self, self.activeOperationID == id else { return }
            self.actionsLabel.stringValue = title.replacingOccurrences(of: "…", with: "")
            self.feedbackMessageLabel.stringValue = L("等待 AI 响应…")
            self.feedbackMessageLabel.textColor = AppTheme.accentTextColor
            self.feedbackMessageLabel.isHidden = false
        }
        waitingFeedbackWorkItem = waiting
        DispatchQueue.main.asyncAfter(deadline: .now() + 15, execute: waiting)
        setAIControlsEnabled(false, activeTitle: title)
        updateSecondaryVisibility(animated: true)
        AppTheme.announce(title, from: rootView)
        return id
    }

    private func finishAI(_ id: UUID) -> Bool {
        guard activeOperationID == id else { return false }
        activeOperationID = nil
        activeOperationTitle = ""
        waitingFeedbackWorkItem?.cancel()
        activeAITask = nil
        isRunningAI = false
        actionsLabel.textColor = AppTheme.secondaryTextColor
        actionsLabel.stringValue = ""
        feedbackMessageLabel.stringValue = ""
        feedbackMessageLabel.isHidden = true
        setAIControlsEnabled(!clarificationIsActive)
        return true
    }

    @objc private func stopAI() {
        guard isRunningAI || clarificationIsActive else { return }
        let interruptedRound = isRunningAI && pendingClarificationRound != nil ? clarificationSession : nil
        activeOperationID = nil
        activeOperationTitle = ""
        waitingFeedbackWorkItem?.cancel()
        activeAITask?.cancel()
        activeAITask = nil
        isRunningAI = false
        if let session = interruptedRound {
            clarificationSession = ClarificationSession(originalQuery: session.originalQuery,
                                                        rounds: Array(session.rounds.dropLast()))
            let answer = pendingClarificationAnswers.popLast()
            clarificationWindowController?.setLoading(false)
            showPendingClarificationQuestion(restoring: answer, animated: false)
            setAIControlsEnabled(false)
            updateSecondaryVisibility(animated: false)
            clarificationWindowController?.focusAnswer()
            return
        }
        resetClarification()
        setAIControlsEnabled(true)
        updateSecondaryVisibility(animated: true)
        showActionsFeedback(L("已停止，原文已保留"), isSuccess: false)
    }

    private func showTemplatePreview(_ draft: TemplateDraft) {
        let controller = templatePreviewFactory(draft)
        controller.onSave = { [weak self] template in
            guard let self else { return }
            self.activeTemplateOrigin = .user(id: template.id)
            self.activeTemplateTitle = template.title
            self.onTemplateSaved?()
            self.currentMode = .skill
            self.selectedIndex = 0
            self.refreshMenu()
            self.updateSecondaryVisibility(animated: true)
            self.showActionsFeedback(L("已保存为模板"))
        }
        templatePreviewController = controller
        controller.show(relativeTo: window)
    }

    private func updateCurrentTemplate() {
        guard let origin = activeTemplateOrigin, TemplateUpdatePolicy.current.allows(origin) else {
            NSSound.beep()
            return
        }
        let body = textView.string
        guard !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            NSSound.beep()
            return
        }

        let title: String
        let message: String
        switch origin {
        case .system:
            title = activeTemplateTitle ?? L("系统模板")
            message = AppLocalization.format("用当前内容替换模板「%@」在这台 Mac 上的正文。", title)
        case .user(let templateID):
            guard let existing = UserTemplateStore.all().first(where: { $0.id == templateID }) else {
                clearTemplateSource()
                showAlert(title: L("无法更新模板"), message: L("原模板不存在，可能已在模板库中被删除。"))
                return
            }
            title = existing.title
            message = AppLocalization.format("用当前内容替换模板「%@」的正文。", title)
        }

        guard confirmTemplateUpdate(title: title, message: message) else { return }

        do {
            try updateTemplate(origin: origin, title: title, body: body)
            activeTemplateTitle = title
            onTemplateSaved?()
            refreshMenu()
            updateSecondaryVisibility(animated: true)
            showActionsFeedback(L("模板已更新"))
            window?.makeFirstResponder(textView)
        } catch {
            showAlert(title: L("更新模板失败"), message: error.localizedDescription)
        }
    }

    private func confirmTemplateUpdate(title: String, message: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = L("更新模板？")
        alert.informativeText = message
        alert.addButton(withTitle: L("更新"))
        alert.addButton(withTitle: L("取消"))
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
        let hasInput = !textView.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasResult = !conversationTurns.isEmpty
        let mayEdit = enabled && !clarificationIsActive
        saveTemplateButton.isEnabled = mayEdit && hasInput
        updateTemplateButton.isEnabled = mayEdit && hasInput
        for button in [refineButton, regenerateButton, clarifyButton] {
            button.isEnabled = mayEdit && hasInput
            button.setEmphasis(.neutral)
            button.refreshAppearance()
        }
        clearButton.isEnabled = mayEdit && (!textView.string.isEmpty || hasResult)
        contentMenuButton.isEnabled = mayEdit
        commitButton.isEnabled = enabled && !clarificationIsActive && !textView.string.isEmpty
        commitButton.setEmphasis(hasResult ? .primary : .neutral)
        commitButton.surface = hasResult ? .push : .glass
        commitButton.refreshAppearance()
        settingsButton.isEnabled = enabled
        textView.isEditable = mayEdit
        stopButton.isHidden = !isRunningAI || clarificationIsActive
        stopButton.isEnabled = isRunningAI && !clarificationIsActive
        activityIndicator.isHidden = !isRunningAI || clarificationIsActive
        stopButton.title = L("停止")
        stopButton.image = isRunningAI ? AppTheme.primaryActionSymbol(named: "stop.fill") : nil
        stopButton.setEmphasis(.primary)
        stopButton.refreshAppearance()
        if isRunningAI {
            activityIndicator.startAnimation(nil)
            actionsLabel.textColor = AppTheme.accentTextColor
            actionsLabel.stringValue = activeTitle ?? L("正在处理…")
            actionsLabel.toolTip = actionsLabel.stringValue
            feedbackMessageLabel.stringValue = ""
            feedbackMessageLabel.isHidden = true
            feedbackContainer.tone = .working
            if let activeTitle {
                actionsLabel.stringValue = activeTitle
                actionsLabel.toolTip = actionsLabel.stringValue
            }
        } else { activityIndicator.stopAnimation(nil) }
        updateGuidedChrome()
    }

    private func scheduleTemplateSuggestionEvaluation() {
        templateMatchWorkItem?.cancel()
        let input = textView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !clarificationIsActive,
            input.count >= 6,
            !commandMenuVisible
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
            !clarificationIsActive,
            !input.isEmpty,
            !commandMenuVisible
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
        updateSecondaryVisibility(animated: true)
    }

    private func ignoreTemplateSuggestion() {
        if let match = pendingTemplateMatch {
            ignoredTemplateTitles.insert(match.item.title)
        }
        pendingTemplateMatch = nil
        templateMatchWorkItem?.cancel()
        refreshMenu()
        updateSecondaryVisibility(animated: true)
        window?.makeFirstResponder(librarySearch)
    }

    private func configuredAPIKey() -> String? {
        do {
            guard let value = try KeychainStore.readAPIKey(), !value.isEmpty else {
                showMissingAPIKeyAlert()
                return nil
            }
            return value
        } catch {
            showAlert(title: L("读取 API Key 失败"), message: error.localizedDescription)
            return nil
        }
    }

    private func showMissingAPIKeyAlert() {
        let alert = NSAlert()
        alert.messageText = L("请先设置 API Key")
        alert.informativeText = L("请在“设置”的 AI 服务中填写所选厂商的 API Key。API Key 保存在 macOS 钥匙串中。")
        alert.addButton(withTitle: L("打开设置"))
        alert.addButton(withTitle: L("取消"))
        if alert.runModal() == .alertFirstButtonReturn {
            onOpenSettings?()
        }
    }

    private func showRequestError(title: String, error: Error, client: OpenAIClient, retry: @escaping () -> Void) {
        if isRunningAI {
            activeOperationID = nil
            waitingFeedbackWorkItem?.cancel()
            activeAITask?.cancel()
            activeAITask = nil
            isRunningAI = false
            setAIControlsEnabled(true)
            updateSecondaryVisibility(animated: false)
        }
        let nativeError = error as NSError
        let message = client.requestErrorMessage(for: nativeError)
        let details = requestErrorDetails(for: nativeError, summary: message)
        showAlert(title: title, message: message, details: details)
        retryAction = retry
        retryButton.isHidden = false
    }

    private func requestErrorDetails(for error: NSError, summary: String) -> String {
        var sections = [summary]
        if error.domain == NSURLErrorDomain, error.code == URLError.secureConnectionFailed.rawValue {
            sections.append(L("安全连接在 TLS 握手阶段失败。应用没有自动重发本次推理请求，因此不会产生重复提交。"))
        }
        sections.append("\(error.domain) · \(error.code)")
        var current: NSError? = error
        var seenCodes = Set<String>()
        var depth = 0
        while let item = current, depth < 3 {
            let key = "\(item.domain)|\(item.code)"
            guard seenCodes.insert(key).inserted else { break }
            let text = item.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty, text != summary {
                sections.append(text)
            }
            current = item.userInfo[NSUnderlyingErrorKey] as? NSError
            depth += 1
        }
        return sections.joined(separator: "\n\n")
    }

    @objc private func retryLastAction() { retryAction?() }

    fileprivate func showAlert(title: String, message: String, details: String? = nil) {
        actionsFeedbackWorkItem?.cancel()
        lastError = (title, message, details ?? message)
        retryAction = nil; retryButton.isHidden = true
        feedbackContainer.tone = .error
        feedbackSymbol.image = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: nil)
        feedbackSymbol.contentTintColor = AppTheme.errorTextColor
        feedbackSymbol.isHidden = false
        actionsLabel.stringValue = title
        actionsLabel.toolTip = title + "\n" + message
        actionsLabel.textColor = AppTheme.errorTextColor
        feedbackMessageLabel.stringValue = message
        feedbackMessageLabel.textColor = AppTheme.secondaryTextColor
        feedbackMessageLabel.isHidden = false
        errorDetailsButton.isHidden = false
        AppTheme.announce(title + "，" + message, from: rootView)
        updateSecondaryVisibility(animated: true)
    }

    @objc private func showErrorDetails() {
        guard let lastError else { return }
        let alert = NSAlert()
        alert.messageText = lastError.title
        alert.informativeText = lastError.details
        alert.addButton(withTitle: L("好"))
        alert.runModal()
    }

    private func insertSelectedTemplate() {
        let items = visibleLibraryItems
        guard items.indices.contains(selectedIndex) else { return }
        let item = items[selectedIndex]
        let isSuggested = pendingTemplateMatch.map {
            $0.item.origin == item.origin && $0.item.title == item.title
        } ?? false
        let body = isSuggested
            ? PromptTemplateMatcher.filledTemplate(from: item, userInput: textView.string, navigator: navigator)
            : item.body
        pendingTemplateMatch = nil
        templateMatchWorkItem?.cancel()
        applyEditorSnapshot(
            editorSnapshot(text: body, origin: item.origin, title: item.title, selectedRange: NSRange(location: 0, length: 0)),
            actionName: isSuggested ? L("套用模板") : L("插入模板")
        )
        if isSuggested { ignoredTemplateTitles.insert(item.title) }
        commandMenuVisible = false
        updateSecondaryVisibility(animated: true)
        highlightFirstPlaceholder()
    }

    private func highlightFirstPlaceholder() {
        guard let first = navigator.ranges(in: textView.string).first else { return }
        focusPlaceholder(first)
    }

    private func jumpToNextPlaceholder(backwards: Bool = false) {
        guard let next = navigator.nextRange(in: textView.string, after: textView.selectedRange(), backwards: backwards) else {
            NSSound.beep()
            return
        }
        focusPlaceholder(next)
    }

    private func focusPlaceholder(_ range: NSRange) {
        guard let token = navigator.tokens(in: textView.string).first(where: { $0.range == range }) else { return }
        textView.setSelectedRange(NSRange(location: token.insertionLocation, length: 0))
        textView.scrollRangeToVisible(token.markerRange)
        window?.makeFirstResponder(textView)
        updateEditorOverlays()
        scheduleEditorOverlayRefresh()
    }

    @objc private func scrollEditorToTop() {
        textView.scrollRangeToVisible(NSRange(location: 0, length: 0))
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        window?.makeFirstResponder(textView)
        updateEditorOverlays()
    }

    private func adjustEditorHeight(animated: Bool) {
        guard let layoutManager = textView.layoutManager, let textContainer = textView.textContainer else { return }
        updateEditorFooter()
        let availableWidth = scrollView.contentSize.width > 0 ? scrollView.contentSize.width : 680
        textView.frame.size.width = availableWidth
        textContainer.containerSize = NSSize(width: max(1, availableWidth - textView.textContainerInset.width * 2), height: CGFloat.greatestFiniteMagnitude)
        layoutManager.ensureLayout(for: textContainer)
        let usedRect = layoutManager.usedRect(for: textContainer)
        let lineHeight = ceil(layoutManager.defaultLineHeight(for: textView.font ?? AppTheme.regular(AppTheme.editorFontSize)))
        let explicitLineCount = max(1, textView.string.components(separatedBy: .newlines).count)
        let lineEstimate = CGFloat(explicitLineCount) * lineHeight + textView.textContainerInset.height * 2 + 12
        let rawHeight = ceil(usedRect.height + textView.textContainerInset.height * 2 + 8)
        let screenHeight = window?.screen?.visibleFrame.height ?? 900
        let otherHeight: CGFloat = 234
        let minimumHeight = minimumEditorHeight
        let maximumHeight = max(minimumHeight, min(320, screenHeight - otherHeight - 80))
        let targetHeight = max(minimumHeight, min(maximumHeight, max(rawHeight, lineEstimate)))
        if !isWorkspaceMode { editorHeightConstraint?.constant = targetHeight }
        textView.frame.size.height = max(targetHeight, usedRect.height + textView.textContainerInset.height * 2 + 24)

        let changes = {
            self.textView.window?.contentView?.layoutSubtreeIfNeeded()
            self.resizeWindowForContent(animated: false)
        }
        if animated && !motionPreference() {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                changes()
            }
        } else {
            changes()
        }
        updateEditorOverlays()
        scheduleEditorOverlayRefresh()
    }

    private func copyPromptToClipboard() {
        guard !isRunningAI, !clarificationIsActive else { return }
        let output = textView.string
        guard !output.isEmpty else {
            NSSound.beep()
            return
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.declareTypes([.string], owner: nil)
        let copied = pasteboard.setString(output, forType: .string) || pasteboard.writeObjects([output as NSString])
        guard copied else {
            showAlert(title: L("复制失败"), message: L("系统剪贴板暂时不可用，请稍后重试。"))
            return
        }
        showCopySuccessFeedback()
    }

    private func showCopySuccessFeedback() {
        showActionsFeedback(L("复制成功"))
    }

    private func showActionsFeedback(_ message: String, isSuccess: Bool = true, animated: Bool = true) {
        actionsFeedbackWorkItem?.cancel()
        lastError = nil
        errorDetailsButton.isHidden = true
        retryAction = nil; retryButton.isHidden = true
        feedbackContainer.tone = .neutral
        feedbackSymbol.image = NSImage(systemSymbolName: "stop.circle", accessibilityDescription: nil)
        feedbackSymbol.contentTintColor = AppTheme.secondaryTextColor
        feedbackSymbol.isHidden = isSuccess
        actionsLabel.textColor = isSuccess ? .labelColor : AppTheme.secondaryTextColor
        feedbackMessageLabel.stringValue = ""
        feedbackMessageLabel.isHidden = true
        isShowingCopySuccess = message == L("复制成功")
        actionsLabel.stringValue = isShowingCopySuccess ? "" : message
        actionsLabel.toolTip = isShowingCopySuccess ? nil : message
        AppTheme.announce(message, from: rootView)
        window?.makeFirstResponder(textView)

        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard !self.isRunningAI, self.lastError == nil else { return }
            self.isShowingCopySuccess = false
            self.actionsLabel.textColor = AppTheme.secondaryTextColor
            self.actionsLabel.stringValue = ""
            self.actionsLabel.toolTip = nil
            self.feedbackMessageLabel.stringValue = ""
            self.feedbackMessageLabel.isHidden = true
            self.updateSecondaryVisibility(animated: true)
        }
        actionsFeedbackWorkItem = item
        updateSecondaryVisibility(animated: animated)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4, execute: item)
    }

    var canRunAI: Bool { !isRunningAI && !clarificationIsActive && !textView.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var canCancelAI: Bool { isRunningAI || clarificationIsActive }
    var canCopy: Bool { !isRunningAI && !clarificationIsActive && !textView.string.isEmpty }
    var canChooseTemplate: Bool { !isRunningAI && !clarificationIsActive }
    var canSwitchWorkspace: Bool { clarificationWindowController == nil }
    var canShowHistory: Bool {
        !conversationTurns.isEmpty || !(recoverableDraft?.context.isEmpty ?? true)
    }
    var hasConversationHistory: Bool { !conversationTurns.isEmpty }
    var shortcutHelpButtonForTesting: NSButton { shortcutHelpButton }
    func templateShortcutPopoverViewForTesting() -> NSView { makeTemplateShortcutPopoverView() }
    var templateEntryButtonForTesting: NSButton { contentMenuButton }
    var templatePickerWindowForTesting: NSWindow? { templatePickerWindow }
    var templatePickerViewForTesting: NSView? { templatePickerWindow?.contentView }
    var clarificationPanelForTesting: ClarificationPanelView? { clarificationWindowController?.panel }
    var clarificationSheetWindowForTesting: NSWindow? { clarificationWindowController?.window }
    func canCloseTemplatePreview() -> Bool {
        guard let preview = templatePreviewController, let window = preview.window, window.isVisible else { return true }
        return preview.windowShouldClose(window)
    }
    func performStopAI() { stopAI() }
    func performShowTemplates() {
        guard canChooseTemplate else { return }
        show()
        showCommandMenu()
    }

    func performRefine() {
        guard canRunAI else { return }
        show()
        runAIAction(.refine)
    }

    func performRegenerate() {
        guard canRunAI else { return }
        show()
        runAIAction(.regenerate)
    }

    func performClarification() {
        guard canRunAI else { return }
        show()
        startClarification()
    }

    var clarificationIsActiveForTesting: Bool {
        clarificationIsActive
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
        if !self.textView.isHandlingComposition { registerEditorUndoStep() }
        return true
    }

    func textViewDidChangeSelection(_ notification: Notification) {
        textView.needsDisplay = true
    }

    func textDidChange(_ notification: Notification) {
        guard !isRestoringEditorSnapshot else { return }
        if isShowingCopySuccess { isShowingCopySuccess = false; actionsFeedbackWorkItem?.cancel() }
        textView.needsDisplay = true
        updatePlaceholderVisibility()
        commandMenuVisible = false
        if let match = pendingTemplateMatch {
            ignoredTemplateTitles.insert(match.item.title)
            pendingTemplateMatch = nil
        }
        if !clarificationIsActive {
            scheduleTemplateSuggestionEvaluation()
        }
        adjustEditorHeight(animated: true)
        updateSecondaryVisibility(animated: true)
        updateEditorOverlays()
        scheduleEditorOverlayRefresh()
    }

    func promptTextViewDidRequestMenu(_ textView: PromptTextView) {
        showCommandMenu()
    }

    func promptTextViewDidRequestModeSwitch(_ textView: PromptTextView) {
        currentMode = currentMode == .prompt ? .skill : .prompt
        selectedIndex = 0
        refreshMenu()
    }

    func promptTextViewDidRequestPlaceholderJump(_ textView: PromptTextView, backwards: Bool) {
        jumpToNextPlaceholder(backwards: backwards)
    }

    func promptTextView(_ textView: PromptTextView, focusPlaceholder range: NSRange) {
        focusPlaceholder(range)
    }

    func promptTextViewWillBeginComposition(_ textView: PromptTextView) {
        registerEditorUndoStep()
    }

    func promptTextViewDidEndComposition(_ textView: PromptTextView) {
        textDidChange(Notification(name: NSText.didChangeNotification, object: textView))
    }

    func promptTextViewDidRequestSelection(_ textView: PromptTextView) {
        insertSelectedTemplate()
    }

    func promptTextViewDidRequestMenuMove(_ textView: PromptTextView, delta: Int) {
        let count = visibleLibraryItems.count
        guard count > 0 else { return }
        selectedIndex = (selectedIndex + delta + count) % count
        refreshSelectionChrome()
    }

    func promptTextViewDidRequestClose(_ textView: PromptTextView) {
        if commandMenuVisible {
            commandMenuVisible = false
            updateSecondaryVisibility(animated: true)
            window?.makeFirstResponder(textView)
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
    private let registerShortcut: (UnsafeMutablePointer<EventHotKeyRef?>) -> OSStatus

    init(registerShortcut: @escaping (UnsafeMutablePointer<EventHotKeyRef?>) -> OSStatus = { ref in
        RegisterEventHotKey(UInt32(kVK_Space), AppIdentity.current.hotKeyModifiers,
                            EventHotKeyID(signature: 0x504C4942, id: 1), GetApplicationEventTarget(), 0, ref)
    }, onPressed: @escaping () -> Void) {
        self.registerShortcut = registerShortcut
        self.onPressed = onPressed
    }

    func register() -> OSStatus {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()

        let handlerStatus = InstallEventHandler(
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
        guard handlerStatus == noErr else { return handlerStatus }
        let status = registerShortcut(&hotKeyRef)
        if status != noErr, let handlerRef {
            RemoveEventHandler(handlerRef)
            self.handlerRef = nil
        }
        return status
    }

    deinit {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let handlerRef {
            RemoveEventHandler(handlerRef)
        }
    }

}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    private var statusBarController: StatusBarController?
    private var promptController: PromptWindowController?
    private var settingsController: SettingsWindowController?
    private var templateManagerController: TemplateManagerWindowController?
    private var usageHelpController: UsageHelpWindowController?
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
        if let option = CommandLine.arguments.firstIndex(of: "--restore-update-session"),
           CommandLine.arguments.indices.contains(option + 1) {
            do {
                let url = URL(fileURLWithPath: CommandLine.arguments[option + 1])
                controller.restoreUpdateSession(try UpdateSession.read(from: url))
            } catch {
                controller.showAlert(title: L("会话恢复未完成"), message: error.localizedDescription)
            }
        }
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
        AppLocalization.observe(self, selector: #selector(refreshLocalization))
        hotKey = GlobalHotKey { [weak controller] in
            controller?.toggle()
        }
        if let status = hotKey?.register(), status != noErr {
            controller.showAlert(title: L("全局快捷键未启用"), message: AppLocalization.format("无法启用 %@（错误 %@）。你仍可从菜单栏或 Dock 打开 Talis。", AppIdentity.current.shortcutLabel, status))
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            controller.show()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        promptController?.show()
        return true
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func configureStatusItem(controller: PromptWindowController) {
        let status = StatusBarController()
        status.onToggle = { [weak controller] in controller?.toggle() }
        status.onNewPrompt = { [weak controller] in controller?.performNewPrompt() }
        status.onRestoreLastDraft = { [weak controller] in controller?.restoreLastDraft() }
        status.onShowHistory = { [weak controller] in controller?.performShowHistory() }
        status.onShowTemplates = { [weak self] in self?.showTemplatePicker() }
        status.onShowSettings = { [weak self] in self?.showSettings() }
        status.onShowAbout = { [weak self] in self?.showAbout() }
        status.onQuit = { [weak self] in self?.quit() }
        status.promptIsVisible = { [weak controller] in controller?.hasVisibleSession ?? false }
        status.canRestoreDraft = { [weak controller] in controller?.canRestoreLastDraft ?? false }
        status.canShowHistory = { [weak controller] in controller?.canShowHistory ?? false }
        status.canChooseTemplate = { [weak controller] in controller?.canChooseTemplate ?? false }
        statusBarController = status
    }

    func mainMenuCommandsForTesting() -> [String: [String]] {
        configureMainMenu()
        return Dictionary(uniqueKeysWithValues: (NSApp.mainMenu?.items ?? []).compactMap { item in
            guard let submenu = item.submenu else { return nil }
            return (submenu.title, submenu.items.map(\.title).filter { !$0.isEmpty })
        })
    }

    @objc private func refreshLocalization() { configureMainMenu() }

    private func configureMainMenu() {
        let mainMenu = NSMenu(title: "Main Menu")

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu(title: AppIdentity.current.displayName)
        appMenu.addItem(makeMenuItem(AppLocalization.format("关于 %@", AppIdentity.current.displayName), action: #selector(showAbout), key: ""))
        appMenu.addItem(.separator())
        appMenu.addItem(makeMenuItem(L("设置…"), action: #selector(showSettings), key: ","))
        let servicesItem = NSMenuItem(title: L("系统服务"), action: nil, keyEquivalent: "")
        let servicesMenu = NSMenu(title: L("系统服务"))
        servicesItem.submenu = servicesMenu
        appMenu.addItem(servicesItem)
        NSApp.servicesMenu = servicesMenu
        appMenu.addItem(.separator())
        appMenu.addItem(makeMenuItem(AppLocalization.format("隐藏 %@", AppIdentity.current.displayName), action: #selector(NSApplication.hide(_:)), key: "h", target: NSApp))
        appMenu.addItem(makeMenuItem(AppLocalization.format("退出 %@", AppIdentity.current.displayName), action: #selector(quit), key: "q"))
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let fileMenuItem = NSMenuItem()
        let fileMenu = NSMenu(title: L("文件"))
        fileMenu.addItem(makeMenuItem(L("新建 Prompt"), action: #selector(newPrompt), key: "n"))
        fileMenu.addItem(makeMenuItem(L("关闭窗口"), action: #selector(closePromptWindow), key: "w"))
        fileMenuItem.submenu = fileMenu
        mainMenu.addItem(fileMenuItem)

        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: L("编辑"))
        editMenu.addItem(makeResponderMenuItem(L("撤销"), action: #selector(PromptTextView.undo(_:)), key: "z"))
        editMenu.addItem(makeResponderMenuItem(L("重做"), action: #selector(PromptTextView.redo(_:)), key: "Z"))
        editMenu.addItem(.separator())
        editMenu.addItem(makeResponderMenuItem(L("剪切"), action: #selector(NSText.cut(_:)), key: "x"))
        editMenu.addItem(makeResponderMenuItem(L("复制"), action: #selector(NSText.copy(_:)), key: "c"))
        editMenu.addItem(makeResponderMenuItem(L("粘贴"), action: #selector(NSText.paste(_:)), key: "v"))
        editMenu.addItem(makeResponderMenuItem(L("全选"), action: #selector(NSText.selectAll(_:)), key: "a"))
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        let promptMenuItem = NSMenuItem()
        let promptMenu = NSMenu(title: "Prompt")
        promptMenu.addItem(makeMenuItem(L("选择模板…"), action: #selector(showTemplatePicker), key: "k"))
        promptMenu.addItem(makeMenuItem(L("管理我的模板…"), action: #selector(showTemplateManager), key: ""))
        promptMenu.addItem(makeMenuItem(L("恢复上次草稿"), action: #selector(restoreLastDraft), key: ""))
        promptMenu.addItem(makeMenuItem(L("修改记录"), action: #selector(showHistory), key: ""))
        promptMenu.addItem(.separator())
        promptMenu.addItem(makeMenuItem(L("唤起输入框"), action: #selector(showPromptWindow), key: "p"))
        promptMenu.addItem(makeMenuItem(L("微调"), action: #selector(refineCurrentPrompt), key: "r"))
        promptMenu.addItem(makeMenuItem(L("重构"), action: #selector(regenerateCurrentPrompt), key: "g"))
        promptMenu.addItem(makeMenuItem(L("追问"), action: #selector(clarifyCurrentPrompt), key: ""))
        promptMenu.addItem(makeMenuItem(L("停止 AI 操作"), action: #selector(stopCurrentAI), key: "."))
        promptMenu.addItem(makeMenuItem(L("复制 Prompt"), action: #selector(pasteBackToPreviousApp), key: "\r"))
        promptMenu.addItem(.separator())
        promptMenu.addItem(makeMenuItem(L("设置…"), action: #selector(showSettings), key: ""))
        promptMenuItem.submenu = promptMenu
        mainMenu.addItem(promptMenuItem)

        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: L("窗口"))
        let workspaceMenuItem = makeMenuItem(L("在独立工作窗口中打开"), action: #selector(PromptWindowController.toggleWorkspaceWindow), key: "d", target: promptController)
        workspaceMenuItem.tag = 1
        windowMenu.addItem(workspaceMenuItem)
        windowMenu.addItem(.separator())
        windowMenu.addItem(makeResponderMenuItem(L("最小化"), action: #selector(NSWindow.miniaturize(_:)), key: "m"))
        windowMenu.addItem(makeResponderMenuItem(L("缩放窗口"), action: #selector(NSWindow.performZoom(_:)), key: ""))
        windowMenu.addItem(makeMenuItem(AppLocalization.format("显示 %@", AppIdentity.current.displayName), action: #selector(showPromptWindow), key: "0"))
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)

        let helpMenuItem = NSMenuItem()
        let helpMenu = NSMenu(title: L("帮助"))
        helpMenu.addItem(makeMenuItem(L("使用说明"), action: #selector(showUsageHelp), key: "?"))
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

    @objc private func newPrompt() {
        promptController?.performNewPrompt()
    }

    @objc private func restoreLastDraft() {
        promptController?.restoreLastDraft()
    }

    @objc private func showHistory() {
        promptController?.performShowHistory()
    }

    @objc private func closePromptWindow() {
        if let keyWindow = NSApp.keyWindow, keyWindow !== promptController?.window {
            keyWindow.performClose(nil)
        } else {
            promptController?.hide()
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if let manager = templateManagerController, manager.window?.isVisible == true,
           !manager.confirmDiscardIfNeeded() { return .terminateCancel }
        if promptController?.canCloseTemplatePreview() == false { return .terminateCancel }
        return .terminateNow
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard let action = menuItem.action else { return true }
        if action == #selector(PromptWindowController.toggleWorkspaceWindow) {
            menuItem.title = promptController?.isInWorkspaceMode == true ? L("返回快速浮窗") : L("在独立工作窗口中打开")
        }
        if action == #selector(stopCurrentAI) { return promptController?.canCancelAI ?? false }
        if action == #selector(showTemplatePicker) { return promptController?.canChooseTemplate ?? false }
        if action == #selector(PromptWindowController.toggleWorkspaceWindow) {
            return promptController?.canSwitchWorkspace ?? false
        }
        if action == #selector(restoreLastDraft) { return promptController?.canRestoreLastDraft ?? false }
        if action == #selector(showHistory) { return promptController?.canShowHistory ?? false }
        if action == #selector(pasteBackToPreviousApp) { return promptController?.canCopy ?? false }
        if [#selector(refineCurrentPrompt), #selector(regenerateCurrentPrompt), #selector(clarifyCurrentPrompt)].contains(action) {
            return promptController?.canRunAI ?? false
        }
        return true
    }
    @objc private func stopCurrentAI() { promptController?.performStopAI() }

    @objc private func showTemplatePicker() { promptController?.performShowTemplates() }

    @objc private func showSettings() {
        settingsController?.show(relativeTo: promptController?.window)
    }

    @objc private func showTemplateManager() {
        templateManagerController?.show(relativeTo: promptController?.window)
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
            .applicationVersion: AppIdentity.current.isV1Preview ? "v1-preview" :
                Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0",
            .credits: NSAttributedString(string: L("全局 Prompt 输入框，支持结构化模板、占位符跳转和 AI 微调。"))
        ])
    }

    @objc private func showUsageHelp() {
        if usageHelpController == nil {
            usageHelpController = UsageHelpWindowController()
        }
        usageHelpController?.show(relativeTo: promptController?.window)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

// Explicit local provisioning runs inside the installed app's own Keychain
// identity. Read the secret from the child environment, never command arguments.
if CommandLine.arguments.contains("--configure-openai-from-env") {
    guard let key = ProcessInfo.processInfo.environment["OPENAI_API_KEY"],
          !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        fputs("OpenAI setup requires OPENAI_API_KEY in the process environment.\n", stderr)
        exit(2)
    }
    do {
        try KeychainStore.saveAPIKey(key, provider: "openai")
        guard try KeychainStore.readAPIKey(provider: "openai") == key.trimmingCharacters(in: .whitespacesAndNewlines) else {
            throw CredentialVaultError.verificationFailed
        }
        AppSettings.modelID = "openai"
        UserDefaults.standard.set("https://api.openai.com/v1", forKey: "ai.endpoint.openai")
        UserDefaults.standard.synchronize()
        print("Configured OpenAI: \(OpenAIClient.modelOption(for: "openai").model); Keychain verified.")
        exit(0)
    } catch {
        fputs("OpenAI setup failed. The provider selection was not changed.\n", stderr)
        exit(1)
    }
}

if CommandLine.arguments.contains("--import-preview-credentials") {
    guard AppIdentity.current.isV1Preview else {
        fputs("Credential import is available only in Talis v1 Preview.\n", stderr)
        exit(2)
    }
    do {
        let copied = try PreviewCredentialImport.copy(
            providers: AIProvider.all.map(\.id),
            from: SystemKeychainStorage(service: "local.prompt-library.overlay.openai"),
            to: SystemKeychainStorage(service: AppIdentity.current.keychainService))
        print("Copied \(copied) provider credentials into the preview Keychain. Source unchanged.")
        exit(0)
    } catch {
        if case KeychainError.unhandledStatus(let status) = error {
            fputs("Preview credential import stopped: Keychain status \(status). Source unchanged.\n", stderr)
        } else {
            fputs("Preview credential import did not complete. Source unchanged.\n", stderr)
        }
        exit(1)
    }
}

AppTheme.registerBundledFonts()

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
