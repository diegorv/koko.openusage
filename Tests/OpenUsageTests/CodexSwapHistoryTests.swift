import XCTest
@testable import OpenUsage

final class CodexSwapHistoryTests: XCTestCase {
    func testSharedAndCopiedRolloutsCountOnceForOneAccount() async throws {
        let now = Date()
        let line = CodexLogFixture.tokenCount(timestamp: OpenUsageISO8601.string(from: now),
            last: CodexLogFixture.usage(input: 100, output: 50), model: "gpt-5.2")
        let original = try CodexLogFixture.makeHome(files: ["sessions/original.jsonl": line])
        let copied = try CodexLogFixture.makeHome(files: ["sessions/copy.jsonl": line])
        let shared = original.appendingPathComponent("linked-home")
        try FileManager.default.createDirectory(at: shared, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: shared.appendingPathComponent("sessions"),
                                                   withDestinationURL: original.appendingPathComponent("sessions"))
        defer {
            try? FileManager.default.removeItem(at: original)
            try? FileManager.default.removeItem(at: copied)
        }
        let environment = FakeEnvironment(["CODEX_HOME": original.path])
        let single = CodexLogUsageScanner(environment: environment,
            incrementalScanner: IncrementalJSONLScanner<CodexLogUsageScanner.Event>(),
            additionalHomes: [shared.path, copied.path])
        let counted = await single.scan(now: now, pricing: TestPricing.bundled)
        XCTAssertEqual(counted?.series.daily.reduce(0) { $0 + $1.totalTokens }, 150)
    }

}
