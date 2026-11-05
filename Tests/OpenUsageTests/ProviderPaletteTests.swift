import XCTest
@testable import OpenUsage

final class ProviderPaletteTests: XCTestCase {
    func testAccountCardsUseTheirFamilyBrandColor() {
        XCTAssertEqual(ProviderPalette.color(for: "claude@4941d001"), ProviderPalette.color(for: "claude"))
        XCTAssertEqual(ProviderPalette.color(for: "codex@8147aacb"), ProviderPalette.color(for: "codex"))
    }
}
