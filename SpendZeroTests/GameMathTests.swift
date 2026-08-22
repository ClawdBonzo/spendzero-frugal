import Testing
import Foundation
@testable import SpendZero

@MainActor
struct GameMathTests {
    @Test func progressBarStartsAtZeroAndGrowsLinearly() {
        let gp = GameProfile()
        gp.currentLevel = 1
        gp.currentXP = 0
        #expect(gp.progressToNextLevel == 0)
        gp.currentXP = gp.xpThresholdForNextLevel / 2
        #expect(abs(gp.progressToNextLevel - 0.5) < 0.01)
    }

    @Test func levelUpCarriesRemainderAndCaps() {
        let gp = GameProfile()
        gp.currentLevel = 1
        gp.currentXP = 0
        let needed = gp.xpThresholdForNextLevel
        _ = GameStateManager.shared.grantXP(amount: needed + 10, to: gp)
        #expect(gp.currentLevel == 2)
        #expect(gp.currentXP == 10)

        gp.currentLevel = GameProfile.maxLevel
        gp.currentXP = 0
        _ = GameStateManager.shared.grantXP(amount: 1_000_000, to: gp)
        #expect(gp.currentLevel == GameProfile.maxLevel)
    }
}
