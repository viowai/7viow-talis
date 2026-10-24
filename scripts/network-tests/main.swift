import Foundation
import TalisCore

// The production client is compiled unchanged; all HTTP is intercepted here.
final class StubProtocol: URLProtocol {
    static var responseCode = 200
    static var body = ""
    static var failure: URLError.Code?
    static var received: URLRequest?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.received = request
        if let failure = Self.failure {
            client?.urlProtocol(self, didFailWithError: URLError(failure))
            return
        }
        let response = HTTPURLResponse(url: request.url!, statusCode: Self.responseCode, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(Self.body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

struct TemplateDraft { var title: String; var detail: String; var body: String }
let config = URLSessionConfiguration.ephemeral
config.protocolClasses = [StubProtocol.self]
let session = URLSession(configuration: config)
let client = OpenAIClient(apiKey: "fake-test-key", modelOption: .init(id: "fixture", title: "Fixture", model: "fixture", baseURL: URL(string: "https://talis.invalid/v1")!), urlSession: session)
var completed = false
var failureMessage: String?
var checks = 0
func expect(_ value: Bool, _ label: String) {
    if !value { failureMessage = label }
    checks += 1
}
Task {
    for (status, body, expected) in [
        (401, "{\"error\":{\"message\":\"Invalid test credential\"}}", "Invalid test credential"),
        (429, "{}", "HTTP 429"),
        (500, "service unavailable", "HTTP 500"),
        (200, "not json", "模型没有返回可用内容"),
        (200, "{\"choices\":[{\"message\":{\"content\":\"   \"}}]}", "模型没有返回可用内容")
    ] {
        StubProtocol.responseCode = status; StubProtocol.body = body; StubProtocol.failure = nil
        do { _ = try await client.run(action: .refine, input: "fictional prompt"); expect(false, "expected error \(status)") }
        catch { expect(error.localizedDescription.contains(expected), "error classification \(status)") }
    }
    for code in [URLError.notConnectedToInternet, .timedOut, .cancelled] {
        StubProtocol.failure = code
        do { _ = try await client.run(action: .regenerate, input: "fictional prompt"); expect(false, "expected transport error") }
        catch { expect((error as? URLError)?.code == code, "transport error preserved") }
    }
    StubProtocol.failure = nil; StubProtocol.responseCode = 200
    StubProtocol.body = "{\"choices\":[{\"message\":{\"content\":\"recovered\"}}]}"
    do {
        expect(try await client.run(action: .refine, input: "fictional prompt") == "recovered", "subsequent request succeeds")
        expect(StubProtocol.received?.timeoutInterval == 60, "request timeout is bounded")
        expect(StubProtocol.received?.url?.host == "talis.invalid", "only test endpoint requested")
    } catch { failureMessage = "recovery request failed" }
    completed = true
}
let deadline = Date().addingTimeInterval(15)
while !completed && Date() < deadline { RunLoop.current.run(until: Date().addingTimeInterval(0.01)) }
guard completed, failureMessage == nil else {
    fputs("FAIL: \(failureMessage ?? "timeout")\n", stderr); exit(1)
}
print("PASS: \(checks) network failure/recovery checks; intercepted HTTP, fake key, no provider calls")
