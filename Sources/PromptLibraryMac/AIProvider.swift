import Foundation

enum AIProtocol: String {
    case chatCompletions
    case anthropicMessages
    case openAIResponses
}

struct AIEndpoint: Equatable {
    let nameKey: String
    let url: URL
    var name: String { L(nameKey) }
    init(_ nameKey: String, _ url: String) { self.nameKey = nameKey; self.url = URL(string: url)! }
}

struct AIModelCandidate {
    let id: String
    var created: Double = 0
    var active = true
    var textOutput = true
    var line: String? = nil
}

struct AIModelVersion: Comparable {
    let version: [Int]
    let snapshot: [Int]
    static func < (left: Self, right: Self) -> Bool {
        for index in 0..<max(left.version.count, right.version.count) {
            let a = index < left.version.count ? left.version[index] : 0
            let b = index < right.version.count ? right.version[index] : 0
            if a != b { return a < b }
        }
        return left.snapshot.lexicographicallyPrecedes(right.snapshot)
    }
}

struct AIProvider {
    static let codexSubscriptionID = "codex-subscription"

    let id: String
    let nameKey: String
    let initialModel: String
    let pattern: String
    let endpoints: [AIEndpoint]
    let keyURL: URL
    var apiProtocol: AIProtocol = .chatCompletions
    var rollingAlias: String? = nil
    var requiresAPIKey: Bool = true
    var chatReasoningEffort: String? = nil
    // Some vendors publish their current model list as a public document.
    // These requests never carry the user's API Key or prompt.
    var catalogDocument: URL? = nil

    var name: String { L(nameKey) }
    static func find(_ id: String) -> AIProvider? {
        all.first { $0.id == id } ?? AILocalSubscriptionCatalog.provider(for: id)
    }

    func select(_ candidates: [AIModelCandidate], excluding: String? = nil) -> String? {
        let eligible = candidates.filter { candidate in
            candidate.id != excluding && candidate.active && candidate.textOutput && rank(candidate.id) != nil &&
            (id != "anthropic" || candidate.line == nil || candidate.line == "haiku")
        }
        if let alias = rollingAlias, eligible.contains(where: { $0.id == alias }) { return alias }
        return eligible.max { left, right in
            let a = rank(left.id)!, b = rank(right.id)!
            if a != b { return a < b }
            if left.created != right.created { return left.created < right.created }
            return left.id < right.id
        }?.id
    }

    func rank(_ model: String) -> AIModelVersion? {
        if model == rollingAlias { return AIModelVersion(version: [], snapshot: []) }
        let lower = model.lowercased()
        guard !["preview", "experimental", "highspeed", "flashx"].contains(where: lower.contains),
              let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: model, range: NSRange(model.startIndex..., in: model)) else { return nil }
        func numbers(_ index: Int) -> [Int] {
            guard index < match.numberOfRanges else { return [] }
            guard let range = Range(match.range(at: index), in: model) else { return [] }
            return model[range].split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
        }
        var version = numbers(1)
        while version.last == 0 { version.removeLast() }
        return AIModelVersion(version: version, snapshot: numbers(2))
    }

    static let all: [AIProvider] = [
        AIProvider(id: "deepseek", nameKey: "DeepSeek", initialModel: "deepseek-flash",
                   pattern: #"^deepseek-v?(\d+(?:[.]\d+)*)-flash(?:-(\d+))?$"#,
                   endpoints: [AIEndpoint("官方接口", "https://api.deepseek.com")],
                   keyURL: URL(string: "https://platform.deepseek.com/api_keys")!, rollingAlias: "deepseek-flash",
                   chatReasoningEffort: "low"),
        AIProvider(id: "kimi", nameKey: "Kimi", initialModel: "kimi-k3.1-pro",
                   pattern: #"^kimi-k(\d+(?:[.]\d+)*)(?:-pro)?$"#,
                   endpoints: [AIEndpoint("国际站", "https://api.moonshot.ai/v1"), AIEndpoint("中国站", "https://api.moonshot.cn/v1")],
                   keyURL: URL(string: "https://platform.kimi.ai/console/api-keys")!,
                   chatReasoningEffort: "low"),
        AIProvider(id: "minimax", nameKey: "MiniMax", initialModel: "MiniMax-M3.1-Flash",
                   pattern: #"^minimax-m(\d+(?:[.]\d+)*)-flash$"#,
                   endpoints: [AIEndpoint("中国站", "https://api.minimaxi.com/v1"), AIEndpoint("国际站", "https://api.minimax.io/v1")],
                   keyURL: URL(string: "https://platform.minimaxi.com/user-center/basic-information/interface-key")!,
                   chatReasoningEffort: "low",
                   catalogDocument: URL(string: "https://platform.minimaxi.com/docs/guides/models-intro.md")!),
        AIProvider(id: "openai", nameKey: "OpenAI API", initialModel: "gpt-6.1-terra",
                   pattern: #"^gpt-(\d+(?:[.]\d+)*)-terra(?:-(\d{4}-\d{2}-\d{2}))?$"#,
                   endpoints: [AIEndpoint("官方接口", "https://api.openai.com/v1")],
                   keyURL: URL(string: "https://platform.openai.com/api-keys")!,
                   chatReasoningEffort: "low"),
        AIProvider(id: codexSubscriptionID, nameKey: "Codex", initialModel: "codex/gpt-6.1-terra",
                   pattern: #"^codex/gpt-(\d+(?:[.]\d+)*)-(?:terra|astra|sol)(?:-(\d{4}-\d{2}-\d{2}))?$"#,
                   endpoints: [AIEndpoint("本机订阅", "http://127.0.0.1:3425/v1")],
                   keyURL: URL(string: "https://openai.com/codex/")!,
                   apiProtocol: .openAIResponses, requiresAPIKey: false),
        AIProvider(id: "anthropic", nameKey: "Anthropic", initialModel: "claude-haiku-5-5",
                   pattern: #"^claude-haiku-(\d+(?:[.-]\d{1,2})?)(?:-(\d{8}))?(?:-latest)?$"#,
                   endpoints: [AIEndpoint("官方接口", "https://api.anthropic.com/v1")],
                   keyURL: URL(string: "https://platform.claude.com/settings/keys")!, apiProtocol: .anthropicMessages),
        AIProvider(id: "google", nameKey: "Google", initialModel: "gemini-3.5-flash-lite",
                   pattern: #"^gemini-(\d+(?:[.]\d+)*)-flash-lite(?:-(\d+))?$"#,
                   endpoints: [AIEndpoint("Gemini API", "https://generativelanguage.googleapis.com/v1beta/openai")],
                   keyURL: URL(string: "https://aistudio.google.com/api-keys")!),
        AIProvider(id: "xai", nameKey: "xAI", initialModel: "grok-4.7",
                   pattern: #"^grok-(\d+(?:[.]\d+)*)(?:-non-reasoning)?$"#,
                   endpoints: [AIEndpoint("官方接口", "https://api.x.ai/v1")],
                   keyURL: URL(string: "https://console.x.ai/")!),
        AIProvider(id: "tencent", nameKey: "腾讯混元", initialModel: "hy3",
                   pattern: #"^hy(\d+(?:[.]\d+)*)(?:-lite)?$"#,
                   endpoints: [AIEndpoint("中国站", "https://tokenhub.tencentcloudmaas.com/v1"), AIEndpoint("国际站", "https://tokenhub-intl.tencentcloudmaas.com/v1")],
                   keyURL: URL(string: "https://console.cloud.tencent.com/tokenhub/apikey")!),
        AIProvider(id: "baidu", nameKey: "百度文心", initialModel: "ernie-4.5-turbo-128k",
                   pattern: #"^ernie-(\d+(?:[.]\d+)*)-turbo(?:-(\d+)k)?$"#,
                   endpoints: [AIEndpoint("千帆 API", "https://qianfan.baidubce.com/v2")],
                   keyURL: URL(string: "https://console.bce.baidu.com/iam/#/iam/apikey")!),
        AIProvider(id: "alibaba", nameKey: "阿里通义", initialModel: "qwen3.8-flash",
                   pattern: #"^qwen(\d+(?:[.]\d+)*)-flash(?:-(\d{4}-\d{2}-\d{2}))?$"#,
                   endpoints: [AIEndpoint("中国站", "https://dashscope.aliyuncs.com/compatible-mode/v1"), AIEndpoint("国际站", "https://dashscope-intl.aliyuncs.com/compatible-mode/v1")],
                   keyURL: URL(string: "https://bailian.console.aliyun.com/?tab=model#/api-key")!),
        AIProvider(id: "bytedance", nameKey: "字节豆包", initialModel: "doubao-seed-2-1-lite-260915",
                   pattern: #"^doubao-seed-(\d+(?:[.-]\d+)?)-lite-(\d{6})$"#,
                   endpoints: [AIEndpoint("火山方舟", "https://ark.cn-beijing.volces.com/api/v3")],
                   keyURL: URL(string: "https://console.volcengine.com/ark/region:cn-beijing/apiKey")!,
                   catalogDocument: URL(string: "https://ark.volcengine.com/region:cn-beijing/docs/model-list.md")!),
        AIProvider(id: "zhipu", nameKey: "智谱 GLM", initialModel: "glm-5.3-flash",
                   pattern: #"^glm-(\d+(?:[.]\d+)*)-flash$"#,
                   endpoints: [AIEndpoint("中国站", "https://open.bigmodel.cn/api/paas/v4"), AIEndpoint("国际站", "https://api.z.ai/api/paas/v4")],
                   keyURL: URL(string: "https://open.bigmodel.cn/usercenter/proj-mgmt/apikeys")!,
                   catalogDocument: URL(string: "https://docs.bigmodel.cn/cn/guide/start/model-overview.md")!)
    ]
}
