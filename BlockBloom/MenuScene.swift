import SpriteKit

class MenuScene: SKScene {

    private let bgColor   = UIColor(hex: "#1B2157")
    private let accentColor = UIColor(hex: "#F5C842")

    override func didMove(to view: SKView) {
        backgroundColor = bgColor
        buildUI()
    }

    private func buildUI() {
        let safeTop = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.keyWindow?.safeAreaInsets.top ?? 59

        let cx = size.width / 2
        let cy = size.height / 2

        // MARK: Arka plan süsü — mini grid nokta deseni
        for row in 0..<10 {
            for col in 0..<8 {
                let dot = SKShapeNode(circleOfRadius: 2)
                dot.fillColor   = UIColor(white: 1, alpha: 0.07)
                dot.strokeColor = .clear
                dot.position    = CGPoint(
                    x: size.width * 0.1 + CGFloat(col) * size.width * 0.115,
                    y: size.height * 0.15 + CGFloat(row) * size.height * 0.085
                )
                addChild(dot)
            }
        }

        // Yukarıdan aşağıya yerleşim
        let logoY  = size.height - safeTop - 160
        let titleY = logoY - 128
        let subY   = titleY - 30
        let hsY    = subY - 68
        let btnY   = hsY - 80

        // MARK: BlockBloom Bloom logosu
        addBloomLogo(centerX: cx, centerY: logoY)

        // MARK: Oyun adı
        let titleLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        titleLabel.text      = "BLOCKBLOOM"
        titleLabel.fontSize  = 36
        titleLabel.fontColor = .white
        titleLabel.position  = CGPoint(x: cx, y: titleY)
        addChild(titleLabel)

        let subLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        subLabel.text      = "Blokları yerleştir, satırları temizle"
        subLabel.fontSize  = 14
        subLabel.fontColor = UIColor(white: 1, alpha: 0.45)
        subLabel.position  = CGPoint(x: cx, y: subY)
        addChild(subLabel)

        // MARK: En yüksek skor
        let highScore = UserDefaults.standard.integer(forKey: "BB_HighScore")
        if highScore > 0 {
            let hsBox = SKShapeNode(rectOf: CGSize(width: 200, height: 52), cornerRadius: 14)
            hsBox.fillColor   = UIColor(white: 1, alpha: 0.07)
            hsBox.strokeColor = UIColor(white: 1, alpha: 0.12)
            hsBox.position    = CGPoint(x: cx, y: hsY)
            addChild(hsBox)

            let crown = SKLabelNode(text: "👑")
            crown.fontSize = 15
            crown.position = CGPoint(x: cx - 68, y: hsY - 6)
            addChild(crown)

            let bestTag = SKLabelNode(fontNamed: "AvenirNext-Bold")
            bestTag.text      = "EN YÜKSEK"
            bestTag.fontSize  = 9
            bestTag.fontColor = UIColor(white: 1, alpha: 0.4)
            bestTag.position  = CGPoint(x: cx - 46, y: hsY + 9)
            bestTag.horizontalAlignmentMode = .left
            addChild(bestTag)

            let hsLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
            hsLabel.text      = formatScore(highScore)
            hsLabel.fontSize  = 24
            hsLabel.fontColor = UIColor(white: 1, alpha: 0.9)
            hsLabel.position  = CGPoint(x: cx - 46, y: hsY - 10)
            hsLabel.horizontalAlignmentMode = .left
            addChild(hsLabel)
        }

        // MARK: OYNA butonu
        let btnNode = SKNode()
        btnNode.name = "playBtn"
        btnNode.position = CGPoint(x: cx, y: highScore > 0 ? btnY : subY - 80)

        let btn = SKShapeNode(rectOf: CGSize(width: 220, height: 64), cornerRadius: 32)
        btn.fillColor   = accentColor
        btn.strokeColor = .clear
        btn.name        = "playBtn"

        let btnGlow = SKShapeNode(rectOf: CGSize(width: 220, height: 64), cornerRadius: 32)
        btnGlow.fillColor   = .clear
        btnGlow.strokeColor = UIColor.white.withAlphaComponent(0.35)
        btnGlow.lineWidth   = 1.5
        btnGlow.name        = "playBtn"

        let btnTxt = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        btnTxt.text                 = "OYNA"
        btnTxt.fontSize             = 26
        btnTxt.fontColor            = UIColor(hex: "#1B2157")
        btnTxt.verticalAlignmentMode = .center
        btnTxt.name                 = "playBtn"

        btnNode.addChild(btn)
        btnNode.addChild(btnGlow)
        btnNode.addChild(btnTxt)
        addChild(btnNode)

        btnNode.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.scale(to: 1.04, duration: 0.9),
            SKAction.scale(to: 1.00, duration: 0.9)
        ])))

        // MARK: Alt bilgi
        let versionLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        versionLabel.text      = "v1.0"
        versionLabel.fontSize  = 11
        versionLabel.fontColor = UIColor(white: 1, alpha: 0.2)
        versionLabel.position  = CGPoint(x: cx, y: 30)
        addChild(versionLabel)

        // Giriş animasyonu
        self.alpha = 0
        self.run(SKAction.fadeIn(withDuration: 0.4))
    }

    // MARK: - Bloom Logo
    /// 4 yöne uzanan renkli petaller + altın merkez + diyagonal aksanlar.
    /// Her petal sırayla içeri pop'lar (stagger animasyon).
    private func addBloomLogo(centerX: CGFloat, centerY: CGFloat) {
        let bs: CGFloat  = 22       // blok boyutu
        let gap: CGFloat = 5
        let step = bs + gap

        struct Petal {
            let dx: Int
            let dy: Int
            let color: BlockColor
            let alpha: CGFloat
            let scale: CGFloat
        }

        // SpriteKit'te Y yukarı pozitif. dy negatif = yukarı petal.
        let petals: [Petal] = [
            // Merkez (biraz büyük altın)
            .init(dx:  0, dy:  0, color: .yellow, alpha: 1.0,  scale: 1.05),
            // Üst petal: red → orange
            .init(dx:  0, dy: -1, color: .red,    alpha: 1.0,  scale: 1.0),
            .init(dx:  0, dy: -2, color: .orange, alpha: 0.92, scale: 1.0),
            // Sağ petal: green → cyan
            .init(dx:  1, dy:  0, color: .green,  alpha: 1.0,  scale: 1.0),
            .init(dx:  2, dy:  0, color: .cyan,   alpha: 0.92, scale: 1.0),
            // Alt petal: purple → blue
            .init(dx:  0, dy:  1, color: .purple, alpha: 1.0,  scale: 1.0),
            .init(dx:  0, dy:  2, color: .blue,   alpha: 0.92, scale: 1.0),
            // Sol petal: blue → cyan
            .init(dx: -1, dy:  0, color: .blue,   alpha: 1.0,  scale: 1.0),
            .init(dx: -2, dy:  0, color: .cyan,   alpha: 0.92, scale: 1.0),
            // Diyagonal altın aksanlar
            .init(dx:  1, dy: -1, color: .yellow, alpha: 0.6,  scale: 1.0),
            .init(dx: -1, dy:  1, color: .yellow, alpha: 0.6,  scale: 1.0),
            .init(dx: -1, dy: -1, color: .yellow, alpha: 0.6,  scale: 1.0),
            .init(dx:  1, dy:  1, color: .yellow, alpha: 0.6,  scale: 1.0),
        ]

        for (i, p) in petals.enumerated() {
            let block = makeBlockNode(cellSize: bs * p.scale, color: p.color)
            // dy ters çevriliyor: sahne koordinatı yukarı pozitif
            block.position = CGPoint(
                x: centerX + CGFloat(p.dx) * step,
                y: centerY - CGFloat(p.dy) * step
            )
            block.alpha = 0
            block.setScale(0.3)
            let delay = TimeInterval(i) * 0.04
            block.run(SKAction.sequence([
                SKAction.wait(forDuration: delay),
                SKAction.group([
                    SKAction.fadeAlpha(to: p.alpha, duration: 0.22),
                    SKAction.scale(to: 1.0, duration: 0.22)
                ])
            ]))
            addChild(block)
        }
    }

    private func formatScore(_ n: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    // MARK: - Touch
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let loc = touch.location(in: self)
        if nodes(at: loc).contains(where: { $0.name == "playBtn" }) {
            startGame()
        }
    }

    private func startGame() {
        let game = GameScene()
        game.scaleMode = .resizeFill
        view?.presentScene(game, transition: SKTransition.fade(with: UIColor(hex: "#1B2157"), duration: 0.4))
    }
}
