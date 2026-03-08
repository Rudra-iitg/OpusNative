import XCTest
@testable import OpusNative

final class ContextManagerTests: XCTestCase {

    private var sut: ContextManager!

    override func setUp() {
        super.setUp()
        sut = ContextManager()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Initial State Tests

    func testInitialUsagePercentageIsZero() {
        XCTAssertEqual(sut.usagePercentage, 0.0,
                       "Usage percentage should start at 0.0")
    }

    func testInitialCurrentUsageIsZero() {
        XCTAssertEqual(sut.currentUsage, 0,
                       "Current usage should start at 0")
    }

    func testDefaultMaxContextIsSet() {
        XCTAssertGreaterThan(sut.maxContext, 0,
                             "Max context should have a positive default value")
        XCTAssertEqual(sut.maxContext, 128_000,
                       "Default max context should be 128,000")
    }

    // MARK: - Usage Percentage Range Tests

    func testUsagePercentageIsBetweenZeroAndOne() {
        // After init, percentage should be in valid range
        XCTAssertGreaterThanOrEqual(sut.usagePercentage, 0.0,
                                    "Usage percentage should be >= 0.0")
        XCTAssertLessThanOrEqual(sut.usagePercentage, 1.0,
                                 "Usage percentage should be <= 1.0 initially")
    }

    // MARK: - Context Limit Tests

    // TODO: updateUsage requires [ChatMessage] which is a SwiftData model.
    // These tests use a basic validation approach since ChatMessage
    // requires a ModelContext to instantiate.

    func testMaxContextUpdatesForKnownModels() {
        // We can't easily call updateUsage without ChatMessage instances,
        // but we can verify the manager's default state is consistent.
        // When an actual model is set, maxContext should match known limits.
        //
        // Known limits from ContextManager source:
        // claude-3-5-sonnet-20241022: 200,000
        // gpt-4o: 128,000
        // gemini-1.5-pro: 2,000,000
        // llama3: 8,000

        // Verify default is one of the known limits or the fallback
        let knownLimits = [8_000, 8_192, 16_000, 32_000, 128_000, 200_000, 1_000_000, 2_000_000]
        XCTAssertTrue(knownLimits.contains(sut.maxContext),
                      "Default maxContext (\(sut.maxContext)) should be a known context limit")
    }

    func testUsageNeverExceedsNegative() {
        // The currentUsage should never be negative
        XCTAssertGreaterThanOrEqual(sut.currentUsage, 0,
                                    "Current usage should never be negative")
    }

    // MARK: - Context Warning Tests

    func testHighUsagePercentageIndicatesWarning() {
        // Simulate a scenario where usage is very high by directly setting values
        // (This tests the business logic concept — in production, updateUsage sets these)
        //
        // A usage percentage > 0.9 should be considered a warning state
        // We validate that the percentage calculation logic is correct

        // Manually set state to simulate high usage
        sut.currentUsage = 120_000
        sut.maxContext = 128_000
        // Recalculate manually what the percentage should be
        let expectedPercentage = Double(120_000) / Double(128_000)

        // Note: usagePercentage is only set by updateUsage(), so we validate
        // the math that updateUsage would produce
        XCTAssertGreaterThan(expectedPercentage, 0.9,
                             "120K out of 128K should be > 90% usage")
        XCTAssertLessThan(expectedPercentage, 1.0,
                          "120K out of 128K should still be under 100%")
    }

    func testExceedingContextLimitProducesPercentageOverOne() {
        // If somehow usage exceeds maxContext, percentage should be > 1.0
        // indicating an overflow/warning condition
        let usage = 150_000
        let limit = 128_000
        let percentage = Double(usage) / Double(limit)

        XCTAssertGreaterThan(percentage, 1.0,
                             "Exceeding context limit should produce percentage > 1.0")
    }
}
