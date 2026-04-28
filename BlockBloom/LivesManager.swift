import Foundation

class LivesManager {
    static let shared = LivesManager()

    private let key = "BB_Lives"
    private let maxLives = 5

    private init() {}

    var lives: Int {
        get { UserDefaults.standard.integer(forKey: key) }
        set {
            UserDefaults.standard.set(max(0, min(newValue, maxLives)), forKey: key)
            UserDefaults.standard.synchronize()
            onLivesChanged?(lives)
        }
    }

    var hasLives: Bool { lives > 0 }

    var onLivesChanged: ((Int) -> Void)?

    func addLife() {
        lives += 1
    }

    func useLife() -> Bool {
        guard hasLives else { return false }
        lives -= 1
        return true
    }
}
