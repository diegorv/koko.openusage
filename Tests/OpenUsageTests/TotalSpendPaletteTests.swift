import XCTest
@testable import OpenUsage

final class TotalSpendPaletteTests: XCTestCase {
    func testAccountCardsUseTheirFamilyBrandColor() {
        XCTAssertEqual(TotalSpendPalette.color(for: "claude@4941d001"), TotalSpendPalette.color(for: "claude"))
        XCTAssertEqual(TotalSpendPalette.color(for: "codex@8147aacb"), TotalSpendPalette.color(for: "codex"))
    }
}
