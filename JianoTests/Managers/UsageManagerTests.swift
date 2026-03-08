import XCTest
@testable import OpusNative

final class UsageManagerTests: XCTestCase {

    private var sut: UsageManager!

    override func setUp() {
        super.setUp()
        // Create a fresh instance — sessionUsage always starts at .zero
        sut = UsageManager()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Initial State Tests

    func testSessionUsageStartsAtZero() {
        XCTAssertEqual(sut.sessionUsage.totalTokens, 0,
                       "Session total tokens should start at 0")
        XCTAssertEqual(sut.sessionUsage.inputTokens, 0,
                       "Session input tokens should start at 0")
        XCTAssertEqual(sut.sessionUsage.outputTokens, 0,
                       "Session output tokens should start at 0")
        XCTAssertEqual(sut.sessionUsage.requestCount, 0,
                       "Session request count should start at 0")
    }

    func testSessionCostStartsAtZero() {
        XCTAssertEqual(sut.sessionUsage.totalCost, 0,
                       "Session cost should start at 0")
    }

    // MARK: - Token Tracking Tests

    func testTrackResponseIncrementsTokenCounts() {
        let response = AIResponse(
            content: "Hello, world!",
            inputTokenCount: 50,
            outputTokenCount: 100,
            latencyMs: 200,
            model: "gpt-4o",
            providerID: "openai",
            finishReason: "stop"
        )

        sut.track(response: response)

        XCTAssertEqual(sut.sessionUsage.inputTokens, 50,
                       "Input tokens should match tracked response")
        XCTAssertEqual(sut.sessionUsage.outputTokens, 100,
                       "Output tokens should match tracked response")
        XCTAssertEqual(sut.sessionUsage.totalTokens, 150,
                       "Total tokens should be sum of input + output")
        XCTAssertEqual(sut.sessionUsage.requestCount, 1,
                       "Request count should increment by 1")
    }

    func testTrackMultipleResponsesAccumulatesTokens() {
        let response1 = AIResponse(
            content: "First",
            inputTokenCount: 10,
            outputTokenCount: 20,
            model: "gpt-4o",
            providerID: "openai"
        )
        let response2 = AIResponse(
            content: "Second",
            inputTokenCount: 30,
            outputTokenCount: 40,
            model: "gpt-4o",
            providerID: "openai"
        )

        sut.track(response: response1)
        sut.track(response: response2)

        XCTAssertEqual(sut.sessionUsage.inputTokens, 40,
                       "Input tokens should accumulate across responses")
        XCTAssertEqual(sut.sessionUsage.outputTokens, 60,
                       "Output tokens should accumulate across responses")
        XCTAssertEqual(sut.sessionUsage.requestCount, 2,
                       "Request count should reflect total tracked responses")
    }

    // MARK: - Cost Calculation Tests

    func testCostCalculationReturnsNonNegativeValue() {
        let cost = sut.calculateCost(input: 1000, output: 500, model: "gpt-4o")
        XCTAssertGreaterThanOrEqual(cost, 0,
                                    "Cost should never be negative")
    }

    func testCostCalculationForKnownModel() {
        // gpt-4o pricing: input $2.50/1M, output $10.00/1M
        let cost = sut.calculateCost(input: 1_000_000, output: 1_000_000, model: "gpt-4o")
        XCTAssertGreaterThan(cost, 0,
                             "Cost for known model with tokens should be > 0")
    }

    func testCostCalculationForUnknownModelReturnsZero() {
        let cost = sut.calculateCost(input: 100, output: 100, model: "unknown-model-xyz")
        XCTAssertEqual(cost, 0,
                       "Unknown model should return 0 cost (no pricing data)")
    }

    func testCostCalculationForFreeLocalModel() {
        let cost = sut.calculateCost(input: 5000, output: 5000, model: "llama3")
        XCTAssertEqual(cost, 0,
                       "Local models should have zero cost")
    }
}
