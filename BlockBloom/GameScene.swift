import SpriteKit
import UIKit
import AVFoundation

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
    private var livesLabel: SKLabelNode!
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
        let topOffset = safeTop + 12

        let cardW  = (size.width - 48) / 2   // iki kart yan yana
        let cardH: CGFloat = 72
        let cardY  = size.height - topOffset - cardH / 2
        let cardR: CGFloat = 16

        // Sol kart: EN YÜKSEK
        let leftCard = SKShapeNode(rectOf: CGSize(width: cardW, height: cardH), cornerRadius: cardR)
        leftCard.fillColor   = UIColor(white: 1, alpha: 0.07)
        leftCard.strokeColor = UIColor(white: 1, alpha: 0.10)
        leftCard.position    = CGPoint(x: 16 + cardW / 2, y: cardY)
        leftCard.zPosition   = 10
        addChild(leftCard)

        let crownLabel = SKLabelNode(text: "👑")
        crownLabel.fontSize              = 13
        crownLabel.position              = CGPoint(x: 16 + cardW / 2 - cardW * 0.28, y: cardY + 14)
        crownLabel.zPosition             = 11
        crownLabel.horizontalAlignmentMode = .left
        addChild(crownLabel)

        let bestTag = SKLabelNode(fontNamed: "AvenirNext-Bold")
        bestTag.text      = "EN YÜKSEK"
        bestTag.fontSize  = 9
        bestTag.fontColor = UIColor(white: 1, alpha: 0.45)
        bestTag.position  = CGPoint(x: 16 + cardW / 2 - cardW * 0.12, y: cardY + 16)
        bestTag.zPosition = 11
        bestTag.horizontalAlignmentMode = .left
        addChild(bestTag)

        highLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        highLabel.fontSize   = 26
        highLabel.fontColor  = .white
        highLabel.position   = CGPoint(x: 16 + cardW / 2, y: cardY - 20)
        highLabel.zPosition  = 11
        highLabel.horizontalAlignmentMode = .center
        addChild(highLabel)

        // Sağ kart: SCORE
        let rightCard = SKShapeNode(rectOf: CGSize(width: cardW, height: cardH), cornerRadius: cardR)
        rightCard.fillColor   = UIColor(white: 1, alpha: 0.07)
        rightCard.strokeColor = UIColor(white: 1, alpha: 0.10)
        rightCard.position    = CGPoint(x: size.width - 16 - cardW / 2, y: cardY)
        rightCard.zPosition   = 10
        addChild(rightCard)

        let starLabel = SKLabelNode(text: "✦")
        starLabel.fontSize               = 11
        starLabel.fontColor              = UIColor(hex: "#F5C842")
        starLabel.position               = CGPoint(x: size.width - 16 - cardW / 2 - cardW * 0.28, y: cardY + 14)
        starLabel.zPosition              = 11
        starLabel.horizontalAlignmentMode = .left
        addChild(starLabel)

        let scoreTag = SKLabelNode(fontNamed: "AvenirNext-Bold")
        scoreTag.text      = "SCORE"
        scoreTag.fontSize  = 9
        scoreTag.fontColor = UIColor(white: 1, alpha: 0.45)
        scoreTag.position  = CGPoint(x: size.width - 16 - cardW / 2 - cardW * 0.12, y: cardY + 16)
        scoreTag.zPosition = 11
        scoreTag.horizontalAlignmentMode = .left
        addChild(scoreTag)

        scoreLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        scoreLabel.fontSize  = 26
        scoreLabel.fontColor = UIColor(hex: "#F5C842")
        scoreLabel.position  = CGPoint(x: size.width - 16 - cardW / 2, y: cardY - 20)
        scoreLabel.zPosition = 11
        scoreLabel.horizontalAlignmentMode = .center
        addChild(scoreLabel)

        scoreManager.onScoreChanged = { [weak self] score, high in
            self?.scoreLabel.text = Self.formatted(score)
            self?.highLabel.text  = Self.formatted(high)
        }

        // Can göstergesi — kartların altında ortada
        livesLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        livesLabel.fontSize  = 13
        livesLabel.zPosition = 11
        livesLabel.position  = CGPoint(x: size.width / 2, y: cardY - cardH / 2 - 18)
        addChild(livesLabel)
        updateLivesLabel()

        LivesManager.shared.onLivesChanged = { [weak self] _ in
            self?.updateLivesLabel()
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
                SoundManager.shared.playTriple()
            } else if lines == 2 {
                self.impactMedium.impactOccurred()
                SoundManager.shared.playDouble()
            } else {
                self.impactMedium.impactOccurred()
                SoundManager.shared.playSingle()
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
        var usedColors: [BlockColor] = []
        for i in 0..<3 {
            let shape = BlockShape.weighted()
            let color = BlockColor.randomExcluding(usedColors)
            usedColors.append(color)
            let piece = TrayPiece(
                shape: shape, color: color,
                cellSize: cellSize,
                slotPosition: CGPoint(x: slotXs[i], y: trayHeight / 2)
            )
            piece.node.zPosition = 6
            addChild(piece.node)
            trayPieces.append(piece)
        }

        // Yeni tray geldiğinde hiçbir parça sığmıyorsa oyun biter
        if !board.anyShapeFits(trayPieces.map { $0.shape }) {
            showStuckWarning(pieces: trayPieces) {
                self.triggerGameOver()
            }
        }
    }

    // MARK: - Touch

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let loc = touch.location(in: self)

        if isGameOver {
            let names = nodes(at: loc).compactMap { $0.name }
            if names.contains("lifeBtn") {
                if LivesManager.shared.useLife() {
                    gameOverNode?.removeFromParent()
                    gameOverNode = nil
                    isGameOver = false
                    clearBoardWithAnimation {
                        self.spawnTray()
                    }
                }
                return
            }
            if names.contains("adBtn") {
                guard let vc = view?.window?.rootViewController else { return }
                AdManager.shared.showRewardedAd(from: vc) {
                    LivesManager.shared.addLife()
                }
                return
            }
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
            SoundManager.shared.playSnapBack()
            piece.snapBack(); return
        }

        board.place(shape: piece.shape, atRow: placement.row, col: placement.col, color: piece.color)
        scoreManager.addPlacement(cellCount: piece.shape.cells.count)
        impactLight.impactOccurred()
        SoundManager.shared.playPlace()
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
        let previousHigh = UserDefaults.standard.integer(forKey: "BB_HighScore")
        let isNewRecord  = scoreManager.score > previousHigh && scoreManager.score > 0
        scoreManager.saveHighScore()
        notif.notificationOccurred(.error)
        SoundManager.shared.playGameOver()

        let cx = size.width / 2
        let cy = size.height / 2
        let gold   = UIColor(hex: "#F5C842")
        let btnW: CGFloat = size.width * 0.72
        let btnH: CGFloat = 58

        let overlay = SKNode()
        overlay.zPosition = 50

        let dim = SKShapeNode(rectOf: CGSize(width: size.width, height: size.height))
        dim.fillColor   = UIColor(hex: "#1B2157").withAlphaComponent(0.96)
        dim.strokeColor = .clear
        dim.position    = CGPoint(x: cx, y: cy)
        overlay.addChild(dim)

        if isNewRecord {
            // ── YENİ REKOR ekranı ──────────────────────────────
            // Mini bloom logosu
            let bloomCX = cx
            let bloomCY = cy + 230
            let bs: CGFloat = 18; let step: CGFloat = 23
            let bloomPetals: [(dx:Int,dy:Int,color:BlockColor,a:CGFloat)] = [
                (0,0,.yellow,1.0),(0,-1,.red,1.0),(1,0,.green,1.0),
                (0,1,.purple,1.0),(-1,0,.blue,1.0),(1,-1,.cyan,0.7),(-1,-1,.cyan,0.7)
            ]
            for p in bloomPetals {
                let b = makeBlockNode(cellSize: bs, color: p.color)
                b.position   = CGPoint(x: bloomCX + CGFloat(p.dx)*step, y: bloomCY + CGFloat(p.dy)*step)
                b.alpha      = p.a
                b.zPosition  = 51
                overlay.addChild(b)
            }
            // Arka glow
            let glow = SKShapeNode(circleOfRadius: 52)
            glow.fillColor   = gold.withAlphaComponent(0.18)
            glow.strokeColor = .clear
            glow.position    = CGPoint(x: bloomCX, y: bloomCY)
            glow.zPosition   = 50
            overlay.addChild(glow)

            // YENİ REKOR badge
            let badgeW: CGFloat = 180; let badgeH: CGFloat = 34
            let badge = SKShapeNode(rectOf: CGSize(width: badgeW, height: badgeH), cornerRadius: 17)
            badge.fillColor   = gold
            badge.strokeColor = .clear
            badge.position    = CGPoint(x: cx, y: cy + 155)
            badge.zPosition   = 51
            overlay.addChild(badge)
            let badgeTxt = SKLabelNode(fontNamed: "AvenirNext-Heavy")
            badgeTxt.text                  = "🏆  YENİ REKOR"
            badgeTxt.fontSize              = 14
            badgeTxt.fontColor             = UIColor(hex: "#1B2157")
            badgeTxt.verticalAlignmentMode = .center
            badgeTxt.zPosition             = 52
            badge.addChild(badgeTxt)

            // Büyük skor
            overlay.addChild(label(Self.formatted(scoreManager.score), font: "AvenirNext-Heavy",
                                   size: 72, color: gold,
                                   at: CGPoint(x: cx, y: cy + 60)))

            // Önceki en yüksek
            overlay.addChild(label("ÖNCEKİ EN YÜKSEK  ·  \(Self.formatted(previousHigh))",
                                   font: "AvenirNext-Bold", size: 12,
                                   color: UIColor(white: 1, alpha: 0.4),
                                   at: CGPoint(x: cx, y: cy + 10)))

            // Butonlar
            addGameOverButtons(to: overlay, cx: cx, cy: cy - 60, btnW: btnW, btnH: btnH)

        } else {
            // ── NORMAL game over ekranı ──────────────────────────
            // Yukarıdan aşağıya: BLOOM ENDED → skor → EN YÜKSEK → stat kutusu → butonlar
            let bloomEndedY  = cy + 200
            let scoreY       = cy + 128   // font 60pt → ~40pt yarıçap
            let highLabelY   = cy + 80
            let statBoxH: CGFloat = 148
            let statCenterY  = cy - 24    // top: cy+50 → highLabelY ile 30pt boşluk
            let btnCenterY   = cy - 152   // top btn center; stat bottom: cy-98 → 54pt boşluk

            overlay.addChild(label("BLOOM ENDED", font: "AvenirNext-Bold", size: 13,
                                   color: UIColor(white: 1, alpha: 0.45),
                                   at: CGPoint(x: cx, y: bloomEndedY)))

            overlay.addChild(label(Self.formatted(scoreManager.score), font: "AvenirNext-Heavy",
                                   size: 60, color: gold,
                                   at: CGPoint(x: cx, y: scoreY)))

            overlay.addChild(label("EN YÜKSEK  ·  \(Self.formatted(scoreManager.highScore))",
                                   font: "AvenirNext-Bold", size: 12,
                                   color: UIColor(white: 1, alpha: 0.4),
                                   at: CGPoint(x: cx, y: highLabelY)))

            // İstatistik kutusu
            let statBoxW = size.width - 48
            let statBox = SKShapeNode(rectOf: CGSize(width: statBoxW, height: statBoxH), cornerRadius: 18)
            statBox.fillColor   = UIColor(white: 1, alpha: 0.06)
            statBox.strokeColor = UIColor(white: 1, alpha: 0.09)
            statBox.position    = CGPoint(x: cx, y: statCenterY)
            statBox.zPosition   = 51
            overlay.addChild(statBox)

            let bestBloomText: String
            switch scoreManager.bestBloom {
            case 1:    bestBloomText = "SINGLE"
            case 2:    bestBloomText = "DOUBLE!"
            case 3:    bestBloomText = "TRIPLE!"
            case 4...: bestBloomText = "INSANE!!"
            default:   bestBloomText = "-"
            }

            let stats: [(label: String, value: String)] = [
                ("Yerleştirilen",    "\(scoreManager.totalPlaced)"),
                ("Temizlenen Satır", "\(scoreManager.totalLinesCleared)"),
                ("En Büyük Combo",   "×\(scoreManager.maxCombo)"),
                ("En İyi Bloom",     bestBloomText),
            ]
            let rowH = statBoxH / CGFloat(stats.count)
            for (i, stat) in stats.enumerated() {
                let rowY = statCenterY + statBoxH/2 - rowH * (CGFloat(i) + 0.62)
                let lbl = SKLabelNode(fontNamed: "AvenirNext-Medium")
                lbl.text      = stat.label
                lbl.fontSize  = 14
                lbl.fontColor = UIColor(white: 1, alpha: 0.6)
                lbl.position  = CGPoint(x: cx - statBoxW/2 + 20, y: rowY)
                lbl.horizontalAlignmentMode = .left
                lbl.zPosition = 52
                overlay.addChild(lbl)

                let val = SKLabelNode(fontNamed: "AvenirNext-Heavy")
                val.text      = stat.value
                val.fontSize  = 14
                val.fontColor = .white
                val.position  = CGPoint(x: cx + statBoxW/2 - 20, y: rowY)
                val.horizontalAlignmentMode = .right
                val.zPosition = 52
                overlay.addChild(val)

                if i < stats.count - 1 {
                    let sep = SKShapeNode(rectOf: CGSize(width: statBoxW - 32, height: 0.5))
                    sep.fillColor   = UIColor(white: 1, alpha: 0.08)
                    sep.strokeColor = .clear
                    sep.position    = CGPoint(x: cx, y: rowY - rowH * 0.42)
                    sep.zPosition   = 52
                    overlay.addChild(sep)
                }
            }

            addGameOverButtons(to: overlay, cx: cx, cy: btnCenterY, btnW: btnW, btnH: btnH)
        }

        addChild(overlay)
        gameOverNode = overlay
        overlay.alpha = 0
        overlay.run(SKAction.fadeIn(withDuration: 0.35))
    }

    private func addGameOverButtons(to overlay: SKNode, cx: CGFloat, cy: CGFloat,
                                    btnW: CGFloat, btnH: CGFloat) {
        let gold    = UIColor(hex: "#F5C842")
        let hasLife = LivesManager.shared.hasLives
        var topY    = cy

        // CAN KULLAN (varsa)
        if hasLife {
            let livesCount = LivesManager.shared.lives
            let lifeBtn = SKShapeNode(rectOf: CGSize(width: btnW, height: btnH), cornerRadius: btnH / 2)
            lifeBtn.fillColor   = UIColor(hex: "#E84040")
            lifeBtn.strokeColor = .clear
            lifeBtn.position    = CGPoint(x: cx, y: topY)
            lifeBtn.name        = "lifeBtn"
            lifeBtn.zPosition   = 51
            overlay.addChild(lifeBtn)

            let lifeTxt = SKLabelNode(fontNamed: "AvenirNext-Heavy")
            lifeTxt.text                  = "❤️  CAN KULLAN  (\(livesCount))"
            lifeTxt.fontSize              = 16
            lifeTxt.fontColor             = .white
            lifeTxt.verticalAlignmentMode = .center
            lifeTxt.name                  = "lifeBtn"
            lifeBtn.addChild(lifeTxt)

            topY -= btnH + 12
        }

        // REKLAM İZLE → CAN KAZAN
        let adBtn = SKShapeNode(rectOf: CGSize(width: btnW, height: btnH), cornerRadius: btnH / 2)
        adBtn.fillColor   = UIColor(hex: "#9C27B0").withAlphaComponent(0.85)
        adBtn.strokeColor = .clear
        adBtn.position    = CGPoint(x: cx, y: topY)
        adBtn.name        = "adBtn"
        adBtn.zPosition   = 51
        overlay.addChild(adBtn)

        let adTxt = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        adTxt.text                  = "📺  CAN KAZAN"
        adTxt.fontSize              = 16
        adTxt.fontColor             = .white
        adTxt.verticalAlignmentMode = .center
        adTxt.name                  = "adBtn"
        adBtn.addChild(adTxt)

        topY -= btnH + 12

        // TEKRAR OYNA
        let restartBtn = SKShapeNode(rectOf: CGSize(width: btnW, height: btnH), cornerRadius: btnH / 2)
        restartBtn.fillColor   = gold
        restartBtn.strokeColor = .clear
        restartBtn.position    = CGPoint(x: cx, y: topY)
        restartBtn.name        = "restartBtn"
        restartBtn.zPosition   = 51
        overlay.addChild(restartBtn)

        let restartTxt = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        restartTxt.text                  = "TEKRAR OYNA"
        restartTxt.fontSize              = 17
        restartTxt.fontColor             = UIColor(hex: "#1B2157")
        restartTxt.verticalAlignmentMode = .center
        restartTxt.name                  = "restartBtn"
        restartBtn.addChild(restartTxt)

        // MENÜYE DÖN
        let menuBtn = SKShapeNode(rectOf: CGSize(width: btnW, height: btnH), cornerRadius: btnH / 2)
        menuBtn.fillColor   = UIColor(white: 1, alpha: 0.08)
        menuBtn.strokeColor = UIColor(white: 1, alpha: 0.18)
        menuBtn.position    = CGPoint(x: cx, y: topY - btnH - 12)
        menuBtn.name        = "menuBtn"
        menuBtn.zPosition   = 51
        overlay.addChild(menuBtn)

        let menuTxt = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        menuTxt.text                  = "MENÜYE DÖN"
        menuTxt.fontSize              = 17
        menuTxt.fontColor             = UIColor(white: 1, alpha: 0.85)
        menuTxt.verticalAlignmentMode = .center
        menuTxt.name                  = "menuBtn"
        menuBtn.addChild(menuTxt)
    }

    // MARK: - Feedback

    private func showLineClearFeedback(lines: Int) {
        let combo = scoreManager.combo
        let pts   = lines * 100 + (combo > 1 ? 50 * (combo - 1) : 0)
        let cx    = size.width / 2
        let cy    = size.height / 2

        struct Style {
            let title: String?     // nil = sadece puan göster (single)
            let titleSize: CGFloat
            let titleColor: UIColor
            let ptsColor: UIColor
            let subtitle: String
        }

        let gold   = UIColor(hex: "#F5C842")
        let orange = UIColor(hex: "#FF8C00")
        let red    = UIColor(hex: "#E84040")

        let style: Style
        switch lines {
        case 1:
            style = Style(title: nil, titleSize: 0, titleColor: .clear,
                          ptsColor: gold, subtitle: "1 satır — sade altın puan")
        case 2:
            style = Style(title: "DOUBLE!", titleSize: 44, titleColor: gold,
                          ptsColor: orange, subtitle: "2 satır — DOUBLE")
        case 3:
            style = Style(title: "TRIPLE\nBLOOM", titleSize: 44, titleColor: orange,
                          ptsColor: red, subtitle: "3+ satır — TRIPLE")
        default:
            style = Style(title: "TRIPLE\nBLOOM", titleSize: 44, titleColor: red,
                          ptsColor: red, subtitle: "3+ satır — INSANE/TRIPLE")
        }

        let container = SKNode()
        container.position = CGPoint(x: cx, y: cy)
        container.zPosition = 30
        container.alpha = 0
        container.setScale(0.7)
        addChild(container)

        var totalHeight: CGFloat = 0

        // Başlık (single için yok)
        if let title = style.title {
            let titleLbl = SKLabelNode(fontNamed: "AvenirNext-Heavy")
            titleLbl.text                   = title
            titleLbl.fontSize               = style.titleSize
            titleLbl.fontColor              = style.titleColor
            titleLbl.numberOfLines          = 2
            titleLbl.verticalAlignmentMode  = .center
            titleLbl.horizontalAlignmentMode = .center
            titleLbl.position               = CGPoint(x: 0, y: 40)
            container.addChild(titleLbl)
            totalHeight += style.titleSize * 2 + 8
        }

        // Puan
        let ptsLbl = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        ptsLbl.text      = "+\(Self.formatted(pts))"
        ptsLbl.fontSize  = lines == 1 ? 48 : 28
        ptsLbl.fontColor = style.ptsColor
        ptsLbl.position  = CGPoint(x: 0, y: lines == 1 ? 10 : -42)
        container.addChild(ptsLbl)

        // Alt açıklama
        let subLbl = SKLabelNode(fontNamed: "AvenirNext-Medium")
        subLbl.text      = style.subtitle
        subLbl.fontSize  = 12
        subLbl.fontColor = UIColor(white: 1, alpha: 0.35)
        subLbl.position  = CGPoint(x: 0, y: lines == 1 ? -18 : -66)
        container.addChild(subLbl)

        container.run(SKAction.sequence([
            SKAction.group([
                SKAction.fadeIn(withDuration: 0.14),
                SKAction.scale(to: 1.05, duration: 0.14)
            ]),
            SKAction.scale(to: 1.0, duration: 0.08),
            SKAction.wait(forDuration: 0.55),
            SKAction.group([
                SKAction.moveBy(x: 0, y: 70, duration: 0.40),
                SKAction.fadeOut(withDuration: 0.40)
            ]),
            SKAction.removeFromParent()
        ]))
    }

    private func updateLivesLabel() {
        let count = LivesManager.shared.lives
        if count > 0 {
            livesLabel.text      = String(repeating: "❤️", count: min(count, 5))
            livesLabel.alpha     = 1
        } else {
            livesLabel.text      = "❤️"
            livesLabel.alpha     = 0.2
        }
    }

    /// Tüm tahtayı patlatır (can kullanıldığında). Skor korunur.
    private func clearBoardWithAnimation(completion: @escaping () -> Void) {
        impactHeavy.impactOccurred()
        SoundManager.shared.playSingle()
        board.clearAllWithAnimation()
        run(SKAction.sequence([
            SKAction.wait(forDuration: 0.8),
            SKAction.run(completion)
        ]))
    }

    private func label(_ text: String, font: String, size: CGFloat,
                        color: UIColor, at pos: CGPoint) -> SKLabelNode {
        let l = SKLabelNode(fontNamed: font)
        l.text      = text
        l.fontSize  = size
        l.fontColor = color
        l.position  = pos
        l.zPosition = 51
        return l
    }

    /// Binlik ayraçlı sayı formatı: 12480 → "12,480"
    static func formatted(_ n: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }
}

// MARK: - SoundManager

/// Gerçek .wav dosyalarını AVAudioPlayer ile çalar.
class SoundManager {
    static let shared = SoundManager()

    private var players: [String: AVAudioPlayer] = [:]

    private init() {
        let files: [(key: String, name: String)] = [
            ("place",    "mixkit-game-ball-tap-2073"),
            ("single",   "mixkit-video-game-retro-click-237"),
            ("multi",    "mixkit-extra-bonus-in-a-video-game-2045"),
            ("gameOver", "mixkit-musical-game-over-959"),
        ]
        for f in files {
            guard let url = Bundle.main.url(forResource: f.name, withExtension: "wav"),
                  let player = try? AVAudioPlayer(contentsOf: url) else { continue }
            player.prepareToPlay()
            players[f.key] = player
        }
    }

    private func play(_ key: String, volume: Float = 1.0) {
        guard let player = players[key] else { return }
        player.volume = volume
        player.currentTime = 0
        player.play()
    }

    func playPlace()    { play("place",    volume: 0.9) }
    func playSnapBack() { }
    func playSingle()   { play("single",   volume: 1.0) }
    func playDouble()   { play("multi",    volume: 1.0) }
    func playTriple()   { play("multi",    volume: 1.0) }
    func playGameOver() { play("gameOver", volume: 1.0) }
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
