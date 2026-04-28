import Foundation

class ScoreManager {
    private let highScoreKey = "BB_HighScore"

    private(set) var score: Int = 0
    private(set) var highScore: Int
    private(set) var combo: Int = 0

    var onScoreChanged: ((Int, Int) -> Void)? // (score, highScore)

    init() {
        highScore = UserDefaults.standard.integer(forKey: highScoreKey)
    }

    func addPlacement(cellCount: Int) {
        add(cellCount * 10)
    }

    func addLineClear(lines: Int) {
        combo += 1
        let bonus = combo > 1 ? 50 * (combo - 1) : 0
        add(lines * 100 + bonus)
    }

    func resetCombo() {
        combo = 0
    }

    func saveHighScore() {
        if score > highScore {
            highScore = score
            UserDefaults.standard.set(highScore, forKey: highScoreKey)
        }
    }

    func reset() {
        score = 0
        combo = 0
        onScoreChanged?(score, highScore)
    }

    private func add(_ pts: Int) {
        score += pts
        if score > highScore { highScore = score }
        onScoreChanged?(score, highScore)
    }
}
