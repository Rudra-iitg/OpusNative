import XCTest
@testable import OpusNative

@MainActor
final class AIManagerTests: XCTestCase {

    private var sut: AIManager!
    private var keychain: KeychainService!

    override func setUp() {
        super.setUp()
        keychain = KeychainService()
        // Clear any saved provider preference so we get the default
        UserDefaults.standard.removeObject(forKey: "activeProviderID")
        sut = AIManager(keychain: keychain)
    }

    override func tearDown() {
        sut = nil
        keychain = nil
        UserDefaults.standard.removeObject(forKey: "activeProviderID")
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testDefaultProviderIsAnthropic() {
        XCTAssertEqual(sut.activeProviderID, "anthropic",
                       "AIManager should default to 'anthropic' provider")
    }

    func testInitRegistersDefaultProviders() {
        XCTAssertGreaterThanOrEqual(sut.providers.count, 7,
                                    "AIManager should register at least 7 default providers")
    }

    func testActiveProviderReturnsCorrectInstance() {
        let activeProvider = sut.activeProvider
        XCTAssertNotNil(activeProvider, "Active provider should not be nil after init")
        XCTAssertEqual(activeProvider?.id, "anthropic",
                       "Active provider should be Anthropic by default")
    }

    // MARK: - Provider Switching Tests

    func testSwitchToOpenAI() {
        sut.switchProvider(to: "openai")
        XCTAssertEqual(sut.activeProviderID, "openai")
    }

    func testSwitchToOllama() {
        sut.switchProvider(to: "ollama")
        XCTAssertEqual(sut.activeProviderID, "ollama")
    }

    func testSwitchToHuggingFace() {
        sut.switchProvider(to: "huggingface")
        XCTAssertEqual(sut.activeProviderID, "huggingface")
    }

    func testSwitchToBedrock() {
        sut.switchProvider(to: "bedrock")
        XCTAssertEqual(sut.activeProviderID, "bedrock")
    }

    func testSwitchBackToAnthropic() {
        sut.switchProvider(to: "openai")
        sut.switchProvider(to: "anthropic")
        XCTAssertEqual(sut.activeProviderID, "anthropic")
    }

    func testSwitchProviderDoesNotClearProvidersList() {
        let initialCount = sut.providers.count
        sut.switchProvider(to: "openai")
        XCTAssertEqual(sut.providers.count, initialCount,
                       "Switching provider should not remove any registered providers")
    }

    func testSwitchProviderPersistsSelection() {
        sut.switchProvider(to: "openai")
        let saved = UserDefaults.standard.string(forKey: "activeProviderID")
        XCTAssertEqual(saved, "openai",
                       "Provider selection should be persisted to UserDefaults")
    }

    // MARK: - Provider Registration Tests

    func testRegisterCustomProvider() {
        let mock = MockAIProvider(id: "custom-test", displayName: "Custom Test")
        sut.register(provider: mock)
        XCTAssertTrue(sut.providers.contains(where: { $0.id == "custom-test" }),
                      "Custom provider should be registered")
    }

    func testRegisterDuplicateProviderIsIgnored() {
        let mock = MockAIProvider(id: "anthropic", displayName: "Duplicate")
        let countBefore = sut.providers.count
        sut.register(provider: mock)
        XCTAssertEqual(sut.providers.count, countBefore,
                       "Duplicate provider registration should be ignored")
    }

    func testUnregisterProvider() {
        let mock = MockAIProvider(id: "temporary", displayName: "Temp")
        sut.register(provider: mock)
        XCTAssertTrue(sut.providers.contains(where: { $0.id == "temporary" }))
        sut.unregister(providerID: "temporary")
        XCTAssertFalse(sut.providers.contains(where: { $0.id == "temporary" }),
                       "Provider should be removed after unregistering")
    }

    // MARK: - Provider Lookup Tests

    func testProviderForIDReturnsCorrectProvider() {
        let provider = sut.provider(for: "openai")
        XCTAssertNotNil(provider)
        XCTAssertEqual(provider?.id, "openai")
    }

    func testProviderForInvalidIDReturnsNil() {
        let provider = sut.provider(for: "nonexistent")
        XCTAssertNil(provider, "Unknown provider ID should return nil")
    }
}
