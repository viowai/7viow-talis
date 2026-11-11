import XCTest
@testable import TalisCore

final class ClarificationFlowTests: XCTestCase {
    func testQuestionNormalizesAndCapsOptionsAtFour() {
        let question = ClarificationQuestion(
            question: "  你希望面向谁？  ",
            options: ["设计师", "开发者", "设计师", "管理者", "学生", "其他"]
        )
        XCTAssertEqual(question.question, "你希望面向谁？")
        XCTAssertEqual(question.options, ["设计师", "开发者", "管理者", "学生"])
    }

    func testSessionKeepsAtMostFiveRoundsAndForcesFinal() {
        var session = ClarificationSession(originalQuery: "帮我写一个方案")
        for index in 1...6 {
            session.appendRound(answers: [
                ClarificationAnswer(question: "问题\(index)", answer: "回答\(index)")
            ])
        }
        XCTAssertEqual(session.completedRounds, 5)
        XCTAssertTrue(session.mustGenerateFinal)
        XCTAssertFalse(session.requestContent().contains("问题6"))
        XCTAssertTrue(session.requestContent().contains("不得继续提问"))
    }

    func testSkippedAnswerIsExplicitAndNotInvented() {
        var session = ClarificationSession(originalQuery: "生成发布计划")
        session.appendRound(answers: [
            ClarificationAnswer(question: "发布日期是什么？", answer: "", skipped: true)
        ])
        let content = session.requestContent()
        XCTAssertTrue(content.contains("跳过（用户未提供信息）"))
        XCTAssertFalse(content.contains("用户回答：\n"))
    }

    func testRequestContainsOriginalQueryAndEveryAnswer() {
        var session = ClarificationSession(originalQuery: "设计登录流程")
        session.appendRound(answers: [
            ClarificationAnswer(question: "平台？", answer: "iOS")
        ])
        session.appendRound(answers: [
            ClarificationAnswer(question: "登录方式？", answer: "手机号和 Apple")
        ])
        let content = session.requestContent()
        XCTAssertTrue(content.contains("设计登录流程"))
        XCTAssertTrue(content.contains("平台？"))
        XCTAssertTrue(content.contains("iOS"))
        XCTAssertTrue(content.contains("登录方式？"))
        XCTAssertTrue(content.contains("手机号和 Apple"))
    }

    func testParserReadsAskAndLimitsOptions() {
        let raw = """
        ```json
        {"status":"ask","question":"目标读者是谁？","options":["A","B","C","D","E"]}
        ```
        """
        XCTAssertEqual(
            ClarificationResponseParser.parse(raw),
            .ask(ClarificationRound(questions: [
                ClarificationQuestion(question: "目标读者是谁？", options: ["A", "B", "C", "D"])
            ]))
        )
    }

    func testParserReadsFinalAndRejectsQuestionWithoutEnoughOptions() {
        XCTAssertEqual(
            ClarificationResponseParser.parse("{\"status\":\"final\",\"prompt\":\"输出最终内容\"}"),
            .final("输出最终内容")
        )
        XCTAssertNil(
            ClarificationResponseParser.parse("{\"status\":\"ask\",\"question\":\"选哪个？\",\"options\":[\"A\"]}")
        )
    }

    func testNonJSONResponseFallsBackToFinalPrompt() {
        XCTAssertEqual(
            ClarificationResponseParser.parse("请输出一份结构清晰的产品方案。"),
            .final("请输出一份结构清晰的产品方案。")
        )
    }
}
