import Foundation

class ScoreManager {
    private let highScoreKey = "BB_HighScore"

    private(set) var score: Int = 0
    private(set) var highScore: Int
    private(set) var combo: Int = 0

    // İstatistikler
    private(set) var totalPlaced: Int = 0
    private(set) var totalLinesCleared: Int = 0
    private(set) var maxCombo: Int = 0
    private(set) var bestBloom: Int = 0   // tek seferlik en yüksek line clear sayısı

    var onScoreChanged: ((Int, Int) -> Void)?

    init() {
        highScore = UserDefaults.standard.integer(forKey: highScoreKey)
    }

    func addPlacement(cellCount: Int) {
        totalPlaced += cellCount
        add(cellCount * 10)
    }

    func addLineClear(lines: Int) {
        combo += 1
        totalLinesCleared += lines
        if combo > maxCombo { maxCombo = combo }
        if lines > bestBloom { bestBloom = lines }
        let bonus = combo > 1 ? 50 * (combo - 1) : 0
        add(lines * 100 + bonus)
    }

    func resetCombo() {
        combo = 0
    }

    func saveHighScore() {
        // highScore zaten add() içinde güncellendi, direkt kaydediyoruz
        UserDefaults.standard.set(highScore, forKey: highScoreKey)
        UserDefaults.standard.synchronize()
    }

    func reset() {
        score = 0
        combo = 0
        totalPlaced = 0
        totalLinesCleared = 0
        maxCombo = 0
        bestBloom = 0
        onScoreChanged?(score, highScore)
    }

    private func add(_ pts: Int) {
        score += pts
        if score > highScore { highScore = score }
        onScoreChanged?(score, highScore)
    }
}
