import Foundation

private struct ContextTurn: Equatable {
    let actionTitle: String
    let query: String
    let result: String
}

private final class ConversationContextHarness {
    private(set) var turns: [ContextTurn] = []

    func append(actionTitle: String, query: String, result: String) {
        turns.append(ContextTurn(actionTitle: actionTitle, query: query, result: result))
        if turns.count > 3 {
            turns.removeFirst(turns.count - 3)
        }
    }

    func reset() {
        turns.removeAll()
    }

    func userContent(input: String) -> String {
        guard !turns.isEmpty else {
            return "待处理内容：\n\(input)"
        }

        let contextText = turns.enumerated().map { index, turn in
            """
            第 \(index + 1) 轮
            操作：\(turn.actionTitle)
            用户查询：
            \(turn.query)
            模型结果：
            \(turn.result)
            """
        }.joined(separator: "\n\n---\n\n")

        return """
        以下是最近最多 3 轮历史上下文。请只在它能提升当前任务连贯性和准确性时参考，不要机械复述历史结果。

        \(contextText)

        当前待处理内容：
        \(input)
        """
    }
}

private func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

private let context = ConversationContextHarness()
expect(context.userContent(input: "第一次输入") == "待处理内容：\n第一次输入", "empty context should keep legacy user content")

context.append(actionTitle: "AI 微调", query: "第一轮查询", result: "第一轮结果")
context.append(actionTitle: "重新生成", query: "第二轮查询", result: "第二轮结果")
context.append(actionTitle: "AI 微调", query: "第三轮查询", result: "第三轮结果")
context.append(actionTitle: "重新生成", query: "第四轮查询", result: "第四轮结果")

expect(context.turns.count == 3, "context should keep at most three turns")
expect(context.turns.first?.query == "第二轮查询", "oldest turn should be dropped after exceeding limit")
expect(context.turns.last?.result == "第四轮结果", "latest result should be retained")

let secondRoundMessage = context.userContent(input: "第五轮当前输入")
expect(secondRoundMessage.contains("以下是最近最多 3 轮历史上下文"), "contextual message should include history heading")
expect(secondRoundMessage.contains("第二轮查询"), "contextual message should include retained query")
expect(secondRoundMessage.contains("第四轮结果"), "contextual message should include latest result")
expect(secondRoundMessage.contains("当前待处理内容：\n第五轮当前输入"), "contextual message should include current input")
expect(!secondRoundMessage.contains("第一轮查询"), "dropped turns should not be injected")

context.reset()
expect(context.turns.isEmpty, "reset should clear context turns")
expect(context.userContent(input: "全新查询") == "待处理内容：\n全新查询", "reset should restore context-free request body")

print("context logic tests passed")
