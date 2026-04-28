import SpriteKit
import UIKit
import AudioToolbox

class GameScene: SKScene {

    // MARK: - Haptics
    private let impactLight  = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy  = UIImpactFeedbackGenerator(style: .heavy)
    private let notif        = UINotificationFeedbackGenerator()

    // MARK: - Layout

    private var cellSize: CGFloat { floor((size.width * 0.88) / CGFloat(GameBoard.cols)) }
    private let trayHeight: CGFloat = 180
    private let bgColor = UIColor(hex: "#1B2157")

    // MARK: - State

    private var board: GameBoard!
    private var scoreManager = ScoreManager()
    private var trayPieces: [TrayPiece] = []
    private var dragging: TrayPiece?
    private var dragOffset = CGPoint.zero
    private var isGameOver = false

    // MARK: - UI

    private var scoreLabel: SKLabelNode!
    private var highLabel: SKLabelNode!
    private var gameOverNode: SKNode?

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = bgColor
        // Haptic generatorları ön belleğe al
        impactLight.prepare()
        impactMedium.prepare()
        impactHeavy.prepare()
        notif.prepare()
        setupUI()
        setupBoard()
        startGame()
    }

    // MARK: - UI Setup

    private func setupUI() {
        let safeTop = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.keyWindow?.safeAreaInsets.top ?? 59
        let topOffset = safeTop + 10

        let topBg = SKShapeNode(rectOf: CGSize(width: size.width, height: 70))
        topBg.fillColor   = UIColor(white: 0, alpha: 0.2)
        topBg.strokeColor = .clear
        topBg.position    = CGPoint(x: size.width / 2, y: size.height - topOffset - 25)
        topBg.zPosition   = 10
        addChild(topBg)

        let pad: CGFloat = 20
        let iconY  = size.height - topOffset - 28
        let numY   = size.height - topOffset - 52

        // Sol panel: 👑 + rekor (dijital görünüm)
        let crownLabel = SKLabelNode(text: "👑")
        crownLabel.fontSize  = 14
        crownLabel.position  = CGPoint(x: pad + 10, y: iconY)
        crownLabel.zPosition = 11
        crownLabel.horizontalAlignmentMode = .left
        addChild(crownLabel)

        let bestTag = SKLabelNode(fontNamed: "AvenirNext-Bold")
        bestTag.text      = "BEST"
        bestTag.fontSize  = 10
        bestTag.fontColor = UIColor(white: 1, alpha: 0.45)
        bestTag.position  = CGPoint(x: pad + 28, y: iconY + 1)
        bestTag.zPosition = 11
        bestTag.horizontalAlignmentMode = .left
        addChild(bestTag)

        highLabel = SKLabelNode(fontNamed: "Courier-Bold")
        highLabel.fontSize  = 28
        highLabel.fontColor = UIColor(white: 1, alpha: 0.9)
        highLabel.position  = CGPoint(x: pad, y: numY)
        highLabel.zPosition = 11
        highLabel.horizontalAlignmentMode = .left
        addChild(highLabel)

        // Sağ panel: ★ + skor (dijital görünüm)
        let starLabel = SKLabelNode(text: "★")
        starLabel.fontSize   = 14
        starLabel.fontColor  = UIColor(hex: "#F5C842")
        starLabel.position   = CGPoint(x: size.width - pad - 10, y: iconY)
        starLabel.zPosition  = 11
        starLabel.horizontalAlignmentMode = .right
        addChild(starLabel)

        let scoreTag = SKLabelNode(fontNamed: "AvenirNext-Bold")
        scoreTag.text      = "SCORE"
        scoreTag.fontSize  = 10
        scoreTag.fontColor = UIColor(white: 1, alpha: 0.45)
        scoreTag.position  = CGPoint(x: size.width - pad - 28, y: iconY + 1)
        scoreTag.zPosition = 11
        scoreTag.horizontalAlignmentMode = .right
        addChild(scoreTag)

        scoreLabel = SKLabelNode(fontNamed: "Courier-Bold")
        scoreLabel.fontSize  = 28
        scoreLabel.fontColor = UIColor(hex: "#F5C842")
        scoreLabel.position  = CGPoint(x: size.width - pad, y: numY)
        scoreLabel.zPosition = 11
        scoreLabel.horizontalAlignmentMode = .right
        addChild(scoreLabel)

        scoreManager.onScoreChanged = { [weak self] score, high in
            self?.scoreLabel.text = "\(score)"
            self?.highLabel.text  = "\(high)"
        }

        let trayBg = SKShapeNode(rectOf: CGSize(width: size.width, height: trayHeight))
        trayBg.fillColor   = UIColor(white: 0, alpha: 0.18)
        trayBg.strokeColor = .clear
        trayBg.position    = CGPoint(x: size.width / 2, y: trayHeight / 2)
        trayBg.zPosition   = 5
        addChild(trayBg)
    }

    private func setupBoard() {
        let gridCenterY = trayHeight + (size.height - trayHeight - 95) / 2 + 10
        board = GameBoard(
            cellSize: cellSize,
            center: CGPoint(x: size.width / 2, y: gridCenterY),
            scene: self
        )
        board.onLinesCleared = { [weak self] lines in
            guard let self else { return }
            self.scoreManager.addLineClear(lines: lines)
            self.showLineClearFeedback(lines: lines)
            // Çizgi sayısına göre artan haptic + ses
            if lines >= 3 {
                self.impactHeavy.impactOccurred()
                AudioServicesPlaySystemSound(1025)  // fanfare — triple+
            } else if lines == 2 {
                self.impactMedium.impactOccurred()
                AudioServicesPlaySystemSound(1013)  // glass chime — double
            } else {
                self.impactMedium.impactOccurred()
                AudioServicesPlaySystemSound(1003)  // ding — single
            }
        }
    }

    // MARK: - Game Flow

    private func startGame() {
        isGameOver = false
        gameOverNode?.removeFromParent()
        gameOverNode = nil
        board.reset()
        scoreManager.reset()
        spawnTray()
    }

    private func goToMenu() {
        let menu = MenuScene()
        menu.scaleMode = .resizeFill
        view?.presentScene(menu, transition: SKTransition.fade(
            with: UIColor(hex: "#1B2157"), duration: 0.4))
    }

    private func spawnTray() {
        trayPieces.forEach { $0.node.removeFromParent() }
        trayPieces.removeAll()

        let slotXs: [CGFloat] = [size.width * 0.18, size.width * 0.5, size.width * 0.82]
        for i in 0..<3 {
            let shape = BlockShape.all.randomElement()!
            let color = BlockColor.random()
            let piece = TrayPiece(
                shape: shape, color: color,
                cellSize: cellSize,
                slotPosition: CGPoint(x: slotXs[i], y: trayHeight / 2)
            )
            piece.node.zPosition = 6
            addChild(piece.node)
            trayPieces.append(piece)
        }
    }

    // MARK: - Touch

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let loc = touch.location(in: self)

        if isGameOver {
            let names = nodes(at: loc).compactMap { $0.name }
            if names.contains("restartBtn") { startGame() }
            if names.contains("menuBtn")    { goToMenu() }
            return
        }

        for piece in trayPieces where !piece.isPlaced {
            let expanded = piece.node.calculateAccumulatedFrame().insetBy(dx: -24, dy: -24)
            if expanded.contains(loc) {
                dragging = piece
                piece.node.zPosition = 20
                // Scale-up ilk gerçek hareketle başlar (touchesMoved'da)
                return
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let piece = dragging else { return }
        let loc = touch.location(in: self)

        // İlk harekette grid boyutuna büyüt
        if piece.node.xScale < 1.5 {
            piece.node.run(SKAction.scale(to: 1.0 / 0.6, duration: 0.10))
        }

        piece.node.position = CGPoint(x: loc.x, y: loc.y + 55)
        updateGhost(for: piece)
    }

    /// Parçanın her shape hücresinin şu anki scene konumunu hesaplar.
    /// node ölçeklenmiş olsa da doğru çalışır.
    /// Her shape hücresinin tahmini scene konumunu grid aralığına göre hesaplar.
    /// Piece'in iç scale'i değil, grid step'i (cellSize+gap) kullanılır → doğru snap.
    private func cellScenePositions(for piece: TrayPiece) -> [CGPoint] {
        let step = cellSize + 3             // grid ile aynı aralık
        let n  = CGFloat(piece.shape.cells.count)
        let cx = piece.shape.cells.map { CGFloat($0.col) }.reduce(0, +) / n * step
        let cy = piece.shape.cells.map { CGFloat($0.row) }.reduce(0, +) / n * step

        return piece.shape.cells.map { cell in
            CGPoint(
                x: piece.node.position.x + CGFloat(cell.col) * step - cx,
                y: piece.node.position.y + CGFloat(cell.row) * step - cy
            )
        }
    }

    private func updateGhost(for piece: TrayPiece) {
        let positions = cellScenePositions(for: piece)
        if let placement = board.bestPlacement(shape: piece.shape, cellScenePositions: positions) {
            board.showGhost(shape: piece.shape, atRow: placement.row, col: placement.col, color: piece.color)
        } else {
            board.clearGhost()
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard touches.first != nil, let piece = dragging else {
            // Drag olmadan bırakıldı — scale'i geri al
            trayPieces.forEach {
                if !$0.isPlaced { $0.node.run(SKAction.scale(to: 1.0, duration: 0.1)) }
            }
            return
        }
        dragging = nil
        board.clearGhost()
        piece.node.run(SKAction.scale(to: 1.0, duration: 0.08))
        piece.node.zPosition = 6
        tryPlace(piece: piece)
    }

    private func tryPlace(piece: TrayPiece) {
        let positions = cellScenePositions(for: piece)
        guard let placement = board.bestPlacement(shape: piece.shape, cellScenePositions: positions) else {
            AudioServicesPlaySystemSound(1053)  // yerleştirilemiyor — negatif tık
            piece.snapBack(); return
        }

        board.place(shape: piece.shape, atRow: placement.row, col: placement.col, color: piece.color)
        scoreManager.addPlacement(cellCount: piece.shape.cells.count)
        impactLight.impactOccurred()
        AudioServicesPlaySystemSound(1104)  // blok bırakma tık
        piece.markPlaced()

        let remaining = trayPieces.filter { !$0.isPlaced }
        if remaining.isEmpty {
            spawnTray()
        } else if !board.anyShapeFits(remaining.map { $0.shape }) {
            showStuckWarning(pieces: remaining) {
                self.triggerGameOver()
            }
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        board.clearGhost()
        dragging?.node.run(SKAction.scale(to: 1.0, duration: 0.15))
        dragging?.snapBack()
        dragging?.node.zPosition = 6
        dragging = nil
    }

    // MARK: - Game Over

    /// Kalan parçaları kırmızıya boyar, sonra completion'ı çağırır.
    private func showStuckWarning(pieces: [TrayPiece], completion: @escaping () -> Void) {
        isGameOver = true   // dokunuşları kapat
        impactHeavy.impactOccurred()

        for piece in pieces {
            // Her child block düğümüne kırmızı overlay ekle
            piece.node.children.forEach { child in
                guard let shape = child as? SKShapeNode else { return }
                let originalColor = shape.fillColor
                shape.run(SKAction.sequence([
                    SKAction.colorize(with: .red, colorBlendFactor: 0.75, duration: 0.12),
                    SKAction.colorize(with: originalColor, colorBlendFactor: 0, duration: 0.12),
                    SKAction.colorize(with: .red, colorBlendFactor: 0.75, duration: 0.12),
                    SKAction.colorize(with: originalColor, colorBlendFactor: 0, duration: 0.12),
                ]))
            }
        }

        run(SKAction.sequence([
            SKAction.wait(forDuration: 0.55),
            SKAction.run(completion)
        ]))
    }

    private func triggerGameOver() {
        isGameOver = true
        scoreManager.saveHighScore()
        notif.notificationOccurred(.error)
        AudioServicesPlaySystemSound(1073)  // oyun sonu — düşük ton

        let overlay = SKNode()
        overlay.zPosition = 50

        let dim = SKShapeNode(rectOf: CGSize(width: size.width, height: size.height))
        dim.fillColor   = UIColor(hex: "#1B2157").withAlphaComponent(0.88)
        dim.strokeColor = .clear
        dim.position    = CGPoint(x: size.width / 2, y: size.height / 2)
        overlay.addChild(dim)

        // Başlık
        overlay.addChild(label("OYUN BİTTİ", font: "AvenirNext-Heavy", size: 38, color: .white,
                               at: CGPoint(x: size.width / 2, y: size.height / 2 + 110)))

        // Skor kutusu
        let scoreBox = SKShapeNode(rectOf: CGSize(width: 260, height: 80), cornerRadius: 16)
        scoreBox.fillColor   = UIColor(white: 1, alpha: 0.08)
        scoreBox.strokeColor = UIColor(white: 1, alpha: 0.15)
        scoreBox.position    = CGPoint(x: size.width / 2, y: size.height / 2 + 30)
        overlay.addChild(scoreBox)

        overlay.addChild(label("SKOR", font: "AvenirNext-Bold", size: 11,
                               color: UIColor(white: 1, alpha: 0.45),
                               at: CGPoint(x: size.width / 2, y: size.height / 2 + 55)))
        overlay.addChild(label("\(scoreManager.score)", font: "Courier-Bold", size: 40,
                               color: UIColor(hex: "#F5C842"),
                               at: CGPoint(x: size.width / 2, y: size.height / 2 + 18)))

        // En yüksek skor
        let isNewRecord = scoreManager.score >= scoreManager.highScore && scoreManager.score > 0
        if isNewRecord {
            overlay.addChild(label("🏆 YENİ REKOR!", font: "AvenirNext-Heavy", size: 16,
                                   color: UIColor(hex: "#F5C842"),
                                   at: CGPoint(x: size.width / 2, y: size.height / 2 - 20)))
        } else {
            overlay.addChild(label("En Yüksek: \(scoreManager.highScore)", font: "AvenirNext-Bold", size: 15,
                                   color: UIColor(white: 1, alpha: 0.5),
                                   at: CGPoint(x: size.width / 2, y: size.height / 2 - 20)))
        }

        // Tekrar Oyna butonu
        let restartBtn = SKShapeNode(rectOf: CGSize(width: 200, height: 56), cornerRadius: 28)
        restartBtn.fillColor   = UIColor(hex: "#F5C842")
        restartBtn.strokeColor = .clear
        restartBtn.position    = CGPoint(x: size.width / 2, y: size.height / 2 - 90)
        restartBtn.name        = "restartBtn"
        overlay.addChild(restartBtn)

        let restartTxt = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        restartTxt.text                  = "TEKRAR OYNA"
        restartTxt.fontSize              = 18
        restartTxt.fontColor             = UIColor(hex: "#1B2157")
        restartTxt.verticalAlignmentMode = .center
        restartTxt.name                  = "restartBtn"
        restartBtn.addChild(restartTxt)

        // Menüye dön butonu
        let menuBtn = SKShapeNode(rectOf: CGSize(width: 200, height: 56), cornerRadius: 28)
        menuBtn.fillColor   = UIColor(white: 1, alpha: 0.1)
        menuBtn.strokeColor = UIColor(white: 1, alpha: 0.25)
        menuBtn.position    = CGPoint(x: size.width / 2, y: size.height / 2 - 160)
        menuBtn.name        = "menuBtn"
        overlay.addChild(menuBtn)

        let menuTxt = SKLabelNode(fontNamed: "AvenirNext-Bold")
        menuTxt.text                  = "MENÜYE DÖN"
        menuTxt.fontSize              = 18
        menuTxt.fontColor             = UIColor(white: 1, alpha: 0.8)
        menuTxt.verticalAlignmentMode = .center
        menuTxt.name                  = "menuBtn"
        menuBtn.addChild(menuTxt)

        addChild(overlay)
        gameOverNode = overlay
        overlay.alpha = 0
        overlay.run(SKAction.fadeIn(withDuration: 0.35))
    }

    // MARK: - Feedback

    private func showLineClearFeedback(lines: Int) {
        let combo = scoreManager.combo
        let pts   = lines * 100 + (combo > 1 ? 50 * (combo - 1) : 0)

        let text: String
        let color: UIColor
        switch lines {
        case 1:
            text  = "+\(pts)"
            color = UIColor(hex: "#F5C842")
        case 2:
            text  = "DOUBLE!  +\(pts)"
            color = UIColor(hex: "#FF8C00")
        case 3:
            text  = "TRIPLE! 🔥  +\(pts)"
            color = UIColor(hex: "#E84040")
        default:
            text  = "INSANE!! 💥  +\(pts)"
            color = UIColor(hex: "#E84040")
        }

        let lbl = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        lbl.text      = text
        lbl.fontSize  = lines > 1 ? 32 : 24
        lbl.fontColor = color
        lbl.position  = CGPoint(x: size.width / 2, y: size.height / 2)
        lbl.zPosition = 30
        lbl.alpha     = 0
        lbl.setScale(0.6)
        addChild(lbl)

        lbl.run(SKAction.sequence([
            SKAction.group([
                SKAction.fadeIn(withDuration: 0.12),
                SKAction.scale(to: 1.1, duration: 0.12)
            ]),
            SKAction.scale(to: 1.0, duration: 0.08),
            SKAction.wait(forDuration: 0.45),
            SKAction.group([
                SKAction.moveBy(x: 0, y: 60, duration: 0.35),
                SKAction.fadeOut(withDuration: 0.35)
            ]),
            SKAction.removeFromParent()
        ]))
    }

    private func label(_ text: String, font: String, size: CGFloat,
                        color: UIColor, at pos: CGPoint) -> SKLabelNode {
        let l = SKLabelNode(fontNamed: font)
        l.text      = text
        l.fontSize  = size
        l.fontColor = color
        l.position  = pos
        return l
    }
}

// MARK: - TrayPiece

class TrayPiece {
    let shape: BlockShape
    let color: BlockColor
    let node: SKNode
    let anchorOffset: CGPoint       // scene-space offset: node origin → shape (col=0,row=0) cell center
    private let slotPosition: CGPoint
    private(set) var isPlaced = false

    init(shape: BlockShape, color: BlockColor, cellSize: CGFloat, slotPosition: CGPoint) {
        self.shape        = shape
        self.color        = color
        self.slotPosition = slotPosition

        let scale: CGFloat = 0.6
        let sc  = cellSize * scale
        let gap: CGFloat   = 3

        node = SKNode()
        node.position = slotPosition

        // Visual center of shape cells
        let n        = CGFloat(shape.cells.count)
        let sumCol   = shape.cells.map { CGFloat($0.col) }.reduce(0, +)
        let sumRow   = shape.cells.map { CGFloat($0.row) }.reduce(0, +)
        let cx       = sumCol / n * (sc + gap)
        let cy       = sumRow / n * (sc + gap)

        for cell in shape.cells {
            let block = makeBlockNode(cellSize: sc, color: color)
            block.position = CGPoint(
                x: CGFloat(cell.col) * (sc + gap) - cx,
                y: CGFloat(cell.row) * (sc + gap) - cy
            )
            node.addChild(block)
        }

        // Anchor offset: from node origin to cell (0,0) position within the piece
        anchorOffset = CGPoint(x: -cx, y: -cy)
    }

    func markPlaced() {
        isPlaced = true
        node.removeFromParent()
    }

    func snapBack() {
        node.run(SKAction.group([
            SKAction.move(to: slotPosition, duration: 0.18),
            SKAction.scale(to: 1.0, duration: 0.18)
        ]))
    }
}
