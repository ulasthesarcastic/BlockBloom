import SpriteKit

class GameScene: SKScene {

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
            self?.scoreManager.addLineClear(lines: lines)
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
            if nodes(at: loc).contains(where: { $0.name == "restartBtn" }) { startGame() }
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
            piece.snapBack(); return
        }

        board.place(shape: piece.shape, atRow: placement.row, col: placement.col, color: piece.color)
        scoreManager.addPlacement(cellCount: piece.shape.cells.count)
        piece.markPlaced()

        let remaining = trayPieces.filter { !$0.isPlaced }
        if remaining.isEmpty {
            spawnTray()
        } else if !board.anyShapeFits(remaining.map { $0.shape }) {
            triggerGameOver()
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

    private func triggerGameOver() {
        isGameOver = true
        scoreManager.saveHighScore()

        let overlay = SKNode()
        overlay.zPosition = 50

        let dim = SKShapeNode(rectOf: CGSize(width: size.width, height: size.height))
        dim.fillColor   = UIColor(hex: "#1B2157").withAlphaComponent(0.88)
        dim.strokeColor = .clear
        dim.position    = CGPoint(x: size.width / 2, y: size.height / 2)
        overlay.addChild(dim)

        let title = label("Oyun Bitti", font: "AvenirNext-Heavy", size: 42, color: .white,
                          at: CGPoint(x: size.width / 2, y: size.height / 2 + 90))
        overlay.addChild(title)

        overlay.addChild(label("Skor: \(scoreManager.score)", font: "AvenirNext-Bold", size: 28,
                               color: .white, at: CGPoint(x: size.width / 2, y: size.height / 2 + 30)))
        overlay.addChild(label("En Yüksek: \(scoreManager.highScore)", font: "AvenirNext-Bold", size: 22,
                               color: UIColor(white: 1, alpha: 0.7),
                               at: CGPoint(x: size.width / 2, y: size.height / 2 - 10)))

        let btn = SKShapeNode(rectOf: CGSize(width: 230, height: 62), cornerRadius: 31)
        btn.fillColor   = UIColor(hex: "#4CAF50")
        btn.strokeColor = .clear
        btn.position    = CGPoint(x: size.width / 2, y: size.height / 2 - 90)
        btn.name        = "restartBtn"
        overlay.addChild(btn)

        let btnTxt = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        btnTxt.text     = "Tekrar Oyna"
        btnTxt.fontSize = 22
        btnTxt.fontColor = .white
        btnTxt.verticalAlignmentMode = .center
        btnTxt.name     = "restartBtn"
        btn.addChild(btnTxt)

        addChild(overlay)
        gameOverNode = overlay
        overlay.alpha = 0
        overlay.run(SKAction.fadeIn(withDuration: 0.3))
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
