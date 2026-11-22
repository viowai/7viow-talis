import Foundation

private func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let question = ClarificationQuestion(
    question: "  你希望面向谁？  ",
    options: ["设计师", "开发者", "设计师", "管理者", "学生", "其他"]
)
expect(question.question == "你希望面向谁？", "question should be trimmed")
expect(question.options == ["设计师", "开发者", "管理者", "学生"], "options should be unique and capped at four")

var cappedSession = ClarificationSession(originalQuery: "帮我写一个方案")
for index in 1...6 {
    cappedSession.appendRound(answers: [
        ClarificationAnswer(question: "问题\(index)", answer: "回答\(index)")
    ])
}
expect(cappedSession.completedRounds == 5, "session should keep at most five rounds")
expect(cappedSession.mustGenerateFinal, "five completed rounds should force final generation")
expect(!cappedSession.requestContent().contains("问题6"), "sixth round must be ignored")
expect(cappedSession.requestContent().contains("不得继续提问"), "max-round request must forbid another question")

var skippedSession = ClarificationSession(originalQuery: "生成发布计划")
skippedSession.appendRound(answers: [
    ClarificationAnswer(question: "发布日期是什么？", answer: "（用户跳过）", skipped: true)
])
expect(skippedSession.requestContent().contains("跳过（用户未提供信息）"), "skipped answer should remain explicit")

var completeSession = ClarificationSession(originalQuery: "设计登录流程")
completeSession.appendRound(answers: [
    ClarificationAnswer(question: "平台？", answer: "iOS"),
    ClarificationAnswer(question: "登录方式？", answer: "手机号和 Apple")
])
let completeRequest = completeSession.requestContent()
for expected in ["设计登录流程", "平台？", "iOS", "登录方式？", "手机号和 Apple"] {
    expect(completeRequest.contains(expected), "request should contain: \(expected)")
}

let askRaw = """
```json
{"status":"ask","questions":[
  {"question":"目标读者是谁？","options":["A","B","C","D","E"]},
  {"question":"交付物是什么？","options":["文档","演示"]},
  {"question":"使用场景？","options":["内部","外部"]},
  {"question":"这个问题不应保留","options":["是","否"]}
]}
```
"""
expect(
    ClarificationResponseParser.parse(askRaw) == .ask(
        ClarificationRound(questions: [
            ClarificationQuestion(question: "目标读者是谁？", options: ["A", "B", "C", "D"]),
            ClarificationQuestion(question: "交付物是什么？", options: ["文档", "演示"]),
            ClarificationQuestion(question: "使用场景？", options: ["内部", "外部"])
        ])
    ),
    "parser should read ask response, cap options at four, and cap questions at three"
)
expect(
    ClarificationResponseParser.parse("{\"status\":\"final\",\"prompt\":\"输出最终内容\"}") == .final("输出最终内容"),
    "parser should read final response"
)
expect(
    ClarificationResponseParser.parse("{\"status\":\"ask\",\"question\":\"选哪个？\",\"options\":[\"A\"]}") == nil,
    "question with fewer than two options should be rejected"
)
expect(
    ClarificationResponseParser.parse("请输出一份结构清晰的产品方案。") == .final("请输出一份结构清晰的产品方案。"),
    "plain text should safely fall back to a final prompt"
)
let literalFinal = "  【目标:】::\n【受众】\n  "
let literalData = try! JSONSerialization.data(withJSONObject: ["status":"final", "prompt":literalFinal])
expect(ClarificationResponseParser.parse(String(data:literalData,encoding:.utf8)!) == .final(literalFinal),
       "clarification JSON preserves placeholder punctuation and outer whitespace exactly")
expect(ClarificationResponseParser.parse("{\"status\":\"final\",\"prompt\":\"没有占位符的正文\"}") == .final("没有占位符的正文"),
       "a final Prompt is not required to contain a placeholder")
expect(!ClarificationSession(originalQuery: "【可删除】：").requestContent().contains("结构保护："),
       "clarification does not impose a second mandatory placeholder schema")
expect(ClarificationAnswer(question: "问题", answer: "  【答案】::\n  ").answer == "  【答案】::\n  ", "custom answers retain literal punctuation and whitespace")
let structuredPrompt = """
# 项目简报

## 输入
- 【项目名称】：
- 【目标受众】：

## 输出
1. 总结【核心进展】：
2. 列出风险
"""
let structurallyExpandedPrompt = """
# 项目简报

## 输入
- 【项目名称】：
- 【目标受众】：

## 输出
1. 总结【核心进展】：
2. 列出风险与负责人
"""
let flattenedPrompt = """
请根据【项目名称】、【目标受众】和【核心进展】整理项目简报，并列出风险与负责人。
"""
let reorderedPrompt = """
# 项目简报

## 输出
- 【项目名称】：
- 【目标受众】：

## 输入
1. 总结【核心进展】：
2. 列出风险
"""
expect(
    PromptStructureIntegrity.preservesMarkdownBlockStructure(
        original: structuredPrompt,
        generated: structurallyExpandedPrompt
    ),
    "clarification may add useful content while preserving heading, list and placeholder order"
)
expect(
    !PromptStructureIntegrity.preservesMarkdownBlockStructure(
        original: structuredPrompt,
        generated: flattenedPrompt
    ),
    "clarification rejects a final prompt flattened from structured Markdown into prose"
)
expect(
    !PromptStructureIntegrity.preservesMarkdownBlockStructure(
        original: structuredPrompt,
        generated: reorderedPrompt
    ),
    "clarification rejects reordered headings, list types or placeholders"
)
expect(
    !PromptStructureIntegrity.preservesMarkdownBlockStructure(
        original: structuredPrompt,
        generated: structurallyExpandedPrompt.replacingOccurrences(of: "- 【目标受众】：\n", with: "")
    ),
    "clarification rejects a removed original list item"
)
expect(
    PromptStructureIntegrity.preservesMarkdownBlockStructure(
        original: structuredPrompt,
        generated: structurallyExpandedPrompt.replacingOccurrences(of: "- 【目标受众】：", with: "- 目标受众")
    ),
    "the separate placeholder contract does not misclassify a missing placeholder as lost Markdown layout"
)
expect(
    ClarificationSession(originalQuery: structuredPrompt)
        .structureRepairContent(rejectedPrompt: flattenedPrompt)
        .contains(flattenedPrompt),
    "structure repair includes the rejected model output as evidence"
)
let preservedOriginal = "  # 原始\n\n【受众:】:\n  "
expect(
    ClarificationSession(originalQuery: preservedOriginal).originalQuery == preservedOriginal,
    "the clarification session preserves the exact structured original instead of trimming it"
)

let normalInstruction = ClarificationPromptBuilder.systemInstruction(forceFinal: false)
let forcedInstruction = ClarificationPromptBuilder.systemInstruction(forceFinal: true)
let englishInstruction = ClarificationPromptBuilder.systemInstruction(
    forceFinal: false,
    responseLanguage: .english
)
expect(normalInstruction.contains("否则只追问"), "normal instruction should allow clarification")
expect(normalInstruction.contains("1 至 3 个"), "normal instruction should allow up to three related questions")
expect(forcedInstruction.contains("只能返回 final"), "forced instruction should prohibit further questions")
expect(ClarificationPromptBuilder.inferContentLanguage(from: "帮我写一段介绍", fallback: .english) == .simplifiedChinese,
       "Chinese input should keep Chinese follow-up content")
expect(ClarificationPromptBuilder.inferContentLanguage(from: "Write a product introduction", fallback: .simplifiedChinese) == .english,
       "English input should produce English follow-up content")
expect(ClarificationPromptBuilder.inferContentLanguage(from: "123", fallback: .english) == .english,
       "Language detection falls back to the app language for neutral input")
expect(englishInstruction.contains("English") && englishInstruction.contains("不要重复询问"),
       "English clarification instruction carries language and question-quality rules")
expect(
    !normalInstruction.contains("必须保留原名称、原数量和原顺序")
        && normalInstruction.contains("可编辑的普通文字标记")
        && normalInstruction.contains("不能改写成连续散文"),
    "model instructions keep the independent Markdown contract without locking placeholder syntax"
)
expect(
    ClarificationPromptBuilder.structureRepairInstruction().contains("结构修复")
        && ClarificationPromptBuilder.structureRepairInstruction().contains("不得再次提问"),
    "repair instruction is scoped to structure restoration and prohibits another question"
)

print("clarification logic tests passed")
