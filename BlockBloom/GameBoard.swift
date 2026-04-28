import SpriteKit

class GameBoard {
    static let rows = 8
    static let cols = 8

    let cellSize: CGFloat
    let gap: CGFloat = 3
    let origin: CGPoint  // bottom-left corner of the grid in scene coords

    private var grid = Array(repeating: Array(repeating: false, count: cols), count: rows)
    private var colorGrid = Array(repeating: Array(repeating: BlockColor?.none, count: cols), count: rows)

    // Visual cell nodes [row][col]
    private var cellNodes: [[SKNode]] = []
    private var ghostNodes: [SKNode] = []
    private weak var scene: SKScene?

    var onLinesCleared: ((Int) -> Void)?

    init(cellSize: CGFloat, center: CGPoint, scene: SKScene) {
        self.cellSize  = cellSize
        self.scene     = scene

        let totalW = CGFloat(GameBoard.cols) * (cellSize + gap) - gap
        let totalH = CGFloat(GameBoard.rows) * (cellSize + gap) - gap
        self.origin = CGPoint(x: center.x - totalW / 2, y: center.y - totalH / 2)

        buildGrid()
    }

    // MARK: - Build Visual Grid

    private func buildGrid() {
        for row in 0..<GameBoard.rows {
            var rowNodes: [SKNode] = []
            for col in 0..<GameBoard.cols {
                let bg = SKShapeNode(rectOf: CGSize(width: cellSize, height: cellSize), cornerRadius: cellSize * 0.12)
                bg.fillColor   = UIColor(white: 1, alpha: 0.06)
                bg.strokeColor = .clear
                bg.position    = cellCenter(row: row, col: col)
                bg.zPosition   = 1
                scene?.addChild(bg)
                rowNodes.append(bg)
            }
            cellNodes.append(rowNodes)
        }
    }

    // MARK: - Coordinate Helpers

    func cellCenter(row: Int, col: Int) -> CGPoint {
        CGPoint(
            x: origin.x + CGFloat(col) * (cellSize + gap) + cellSize / 2,
            y: origin.y + CGFloat(row) * (cellSize + gap) + cellSize / 2
        )
    }

    /// Returns the nearest (row, col) to a scene point, or nil if too far.
    func nearestCell(to point: CGPoint) -> (row: Int, col: Int)? {
        var best: (row: Int, col: Int)? = nil
        var bestDist = CGFloat.infinity
        let threshold = (cellSize + gap) * 2.5

        for row in 0..<GameBoard.rows {
            for col in 0..<GameBoard.cols {
                let d = point.distance(to: cellCenter(row: row, col: col))
                if d < bestDist { bestDist = d; best = (row, col) }
            }
        }
        // bestPlacement'ta zaten grid dışı kontrol var; burada sadece en yakını ver
        return bestDist <= threshold * 2 ? best : nil
    }

    // MARK: - Placement Logic

    func canPlace(shape: BlockShape, atRow row: Int, col: Int) -> Bool {
        for cell in shape.cells {
            let r = row + cell.row
            let c = col + cell.col
            guard r >= 0, r < GameBoard.rows, c >= 0, c < GameBoard.cols else { return false }
            if grid[r][c] { return false }
        }
        return true
    }

    func place(shape: BlockShape, atRow row: Int, col: Int, color: BlockColor) {
        for (i, cell) in shape.cells.enumerated() {
            let r = row + cell.row
            let c = col + cell.col
            grid[r][c]      = true
            colorGrid[r][c] = color

            let node = makeBlockNode(cellSize: cellSize, color: color)
            node.position  = cellCenter(row: r, col: c)
            node.zPosition = 2
            node.setScale(0.7)
            scene?.addChild(node)
            cellNodes[r][c] = node

            // Yerleştirme pulse — hafif stagger
            let delay = TimeInterval(i) * 0.018
            node.run(SKAction.sequence([
                SKAction.wait(forDuration: delay),
                SKAction.scale(to: 1.12, duration: 0.08),
                SKAction.scale(to: 1.0,  duration: 0.08)
            ]))
        }

        let cleared = clearFullLines()
        if cleared > 0 { onLinesCleared?(cleared) }
    }

    private func clearFullLines() -> Int {
        var fullRows = [Int]()
        var fullCols = [Int]()

        for r in 0..<GameBoard.rows {
            if (0..<GameBoard.cols).allSatisfy({ grid[r][$0] }) { fullRows.append(r) }
        }
        for c in 0..<GameBoard.cols {
            if (0..<GameBoard.rows).allSatisfy({ grid[$0][c] }) { fullCols.append(c) }
        }

        for r in fullRows { clearRow(r) }
        for c in fullCols { clearCol(c) }

        return fullRows.count + fullCols.count
    }

    private func clearRow(_ row: Int) {
        sweepLine(isRow: true, index: row)
        for c in 0..<GameBoard.cols {
            clearCell(row: row, col: c, delay: TimeInterval(c) * 0.025)
        }
        // Flower bloom: line'ın merkezinde bir bloom çiçeği aç
        let centerCol = GameBoard.cols / 2
        let center = CGPoint(
            x: (cellCenter(row: row, col: centerCol - 1).x + cellCenter(row: row, col: centerCol).x) / 2,
            y: cellCenter(row: row, col: 0).y
        )
        let totalDelay = TimeInterval(GameBoard.cols) * 0.025
        spawnFlowerBloom(at: center, delay: totalDelay + 0.05)
    }

    private func clearCol(_ col: Int) {
        sweepLine(isRow: false, index: col)
        for r in 0..<GameBoard.rows {
            clearCell(row: r, col: col, delay: TimeInterval(r) * 0.025)
        }
        // Flower bloom: line'ın merkezinde bir bloom çiçeği aç
        let centerRow = GameBoard.rows / 2
        let center = CGPoint(
            x: cellCenter(row: 0, col: col).x,
            y: (cellCenter(row: centerRow - 1, col: col).y + cellCenter(row: centerRow, col: col).y) / 2
        )
        let totalDelay = TimeInterval(GameBoard.rows) * 0.025
        spawnFlowerBloom(at: center, delay: totalDelay + 0.05)
    }

    // MARK: - Flower Bloom Effect
    //
    // Line-clear sonrası line'ın merkezinde bir bloom çiçeği açar.
    // Markanın "Bloom" anlamını gameplay'e bağlar — line cleared = bloom!

    private func spawnFlowerBloom(at center: CGPoint, delay: TimeInterval) {
        let petalSize = cellSize * 0.55
        let petalGap  = cellSize * 0.08
        let step = petalSize + petalGap

        // Merkez (gold) + 4 yön petal — Bloom logosunun küçük versiyonu
        struct Petal {
            let dx: CGFloat
            let dy: CGFloat
            let color: BlockColor
            let scale: CGFloat
            let rotateOffset: CGFloat
        }

        let petals: [Petal] = [
            .init(dx:  0, dy:  0, color: .yellow, scale: 1.15, rotateOffset: 0),
            .init(dx:  0, dy:  1, color: .red,    scale: 1.0,  rotateOffset: 0.05),
            .init(dx:  1, dy:  0, color: .green,  scale: 1.0,  rotateOffset: 0.08),
            .init(dx:  0, dy: -1, color: .purple, scale: 1.0,  rotateOffset: 0.11),
            .init(dx: -1, dy:  0, color: .blue,   scale: 1.0,  rotateOffset: 0.14)
        ]

        for p in petals {
            let petal = makeBlockNode(cellSize: petalSize * p.scale, color: p.color)
            petal.position = CGPoint(
                x: center.x + p.dx * step,
                y: center.y + p.dy * step
            )
            petal.zPosition = 9
            petal.alpha     = 0
            petal.setScale(0)
            scene?.addChild(petal)

            petal.run(SKAction.sequence([
                SKAction.wait(forDuration: delay + p.rotateOffset),
                SKAction.group([
                    SKAction.fadeAlpha(to: 1.0, duration: 0.18),
                    SKAction.sequence([
                        SKAction.scale(to: 1.20, duration: 0.20),
                        SKAction.scale(to: 1.00, duration: 0.10)
                    ])
                ]),
                SKAction.wait(forDuration: 0.18),
                SKAction.group([
                    SKAction.fadeAlpha(to: 0, duration: 0.30),
                    SKAction.scale(to: 0.7, duration: 0.30)
                ]),
                SKAction.removeFromParent()
            ]))
        }

        // Altın glow — petals açarken arkada hafif bir parıltı
        let glow = SKShapeNode(circleOfRadius: petalSize * 1.5)
        glow.fillColor   = UIColor(hex: "#F5C842").withAlphaComponent(0.35)
        glow.strokeColor = .clear
        glow.position    = center
        glow.zPosition   = 8
        glow.alpha       = 0
        glow.setScale(0.3)
        scene?.addChild(glow)
        glow.run(SKAction.sequence([
            SKAction.wait(forDuration: delay),
            SKAction.group([
                SKAction.fadeAlpha(to: 1, duration: 0.15),
                SKAction.scale(to: 1.6, duration: 0.45)
            ]),
            SKAction.fadeAlpha(to: 0, duration: 0.25),
            SKAction.removeFromParent()
        ]))

        // Partikül — 12 küçük altın nokta dağılır
        for i in 0..<12 {
            let angle = (CGFloat(i) / 12.0) * .pi * 2
            let particle = SKShapeNode(circleOfRadius: cellSize * 0.06)
            particle.fillColor   = UIColor(hex: "#FFE066")
            particle.strokeColor = .clear
            particle.position    = center
            particle.zPosition   = 10
            particle.alpha       = 0
            scene?.addChild(particle)

            let dist = cellSize * 1.8
            let target = CGPoint(
                x: center.x + cos(angle) * dist,
                y: center.y + sin(angle) * dist
            )

            particle.run(SKAction.sequence([
                SKAction.wait(forDuration: delay + 0.10),
                SKAction.fadeAlpha(to: 1, duration: 0.05),
                SKAction.group([
                    SKAction.move(to: target, duration: 0.55),
                    SKAction.sequence([
                        SKAction.wait(forDuration: 0.25),
                        SKAction.fadeAlpha(to: 0, duration: 0.30)
                    ]),
                    SKAction.scale(to: 0.3, duration: 0.55)
                ]),
                SKAction.removeFromParent()
            ]))
        }
    }

    /// Satır/sütun boyunca parlak bir tarama çizgisi geçirir
    private func sweepLine(isRow: Bool, index: Int) {
        let start: CGPoint
        let end:   CGPoint
        let length: CGFloat

        if isRow {
            let y = cellCenter(row: index, col: 0).y
            start  = CGPoint(x: origin.x, y: y)
            end    = CGPoint(x: origin.x + CGFloat(GameBoard.cols) * (cellSize + gap), y: y)
            length = CGFloat(GameBoard.cols) * (cellSize + gap)
        } else {
            let x = cellCenter(row: 0, col: index).x
            start  = CGPoint(x: x, y: origin.y)
            end    = CGPoint(x: x, y: origin.y + CGFloat(GameBoard.rows) * (cellSize + gap))
            length = CGFloat(GameBoard.rows) * (cellSize + gap)
        }

        let size = isRow
            ? CGSize(width: length, height: cellSize * 0.4)
            : CGSize(width: cellSize * 0.4, height: length)

        let sweep = SKShapeNode(rectOf: size, cornerRadius: 4)
        sweep.fillColor   = UIColor.white.withAlphaComponent(0.85)
        sweep.strokeColor = .clear
        sweep.position    = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
        sweep.zPosition   = 8
        sweep.alpha       = 0
        scene?.addChild(sweep)

        let totalDelay = TimeInterval(GameBoard.cols) * 0.025
        sweep.run(SKAction.sequence([
            SKAction.fadeIn(withDuration: 0.05),
            SKAction.wait(forDuration: totalDelay),
            SKAction.fadeOut(withDuration: 0.12),
            SKAction.removeFromParent()
        ]))
    }

    private func clearCell(row: Int, col: Int, delay: TimeInterval = 0) {
        guard grid[row][col] else { return }
        grid[row][col]      = false
        colorGrid[row][col] = nil

        let node = cellNodes[row][col]
        let burst = SKAction.sequence([
            SKAction.wait(forDuration: delay),
            SKAction.group([
                SKAction.sequence([
                    SKAction.fadeAlpha(to: 1.0, duration: 0.04),
                    SKAction.fadeAlpha(to: 0,   duration: 0.14)
                ]),
                SKAction.sequence([
                    SKAction.scale(to: 1.25, duration: 0.04),
                    SKAction.scale(to: 0.1,  duration: 0.14)
                ])
            ]),
            SKAction.removeFromParent()
        ])
        node.run(burst)

        // Boş hücre arka planını hemen yerleştir
        let bg = SKShapeNode(rectOf: CGSize(width: cellSize, height: cellSize), cornerRadius: cellSize * 0.12)
        bg.fillColor   = UIColor(white: 1, alpha: 0.06)
        bg.strokeColor = .clear
        bg.position    = cellCenter(row: row, col: col)
        bg.zPosition   = 1
        bg.alpha        = 0
        scene?.addChild(bg)
        bg.run(SKAction.sequence([
            SKAction.wait(forDuration: delay + 0.15),
            SKAction.fadeAlpha(to: 1, duration: 0.1)
        ]))
        cellNodes[row][col] = bg
    }

    // MARK: - Ghost Preview

    /// Her shape hücresinin scene konumunu verir (node pozisyonu + ölçekli offset).
    /// cellScenePositions: shape.cells ile aynı sırada, her hücrenin scene koordinatı.
    /// Parçanın hücrelerinin gerçek scene konumları ile tüm geçerli grid pozisyonlarını karşılaştırır.
    /// En az toplam mesafeli, koyulabilir pozisyonu döndürür.
    func bestPlacement(shape: BlockShape, cellScenePositions: [CGPoint]) -> (row: Int, col: Int)? {
        guard cellScenePositions.count == shape.cells.count else { return nil }

        var bestScore = CGFloat.infinity
        var result: (row: Int, col: Int)? = nil

        for baseRow in 0..<GameBoard.rows {
            for baseCol in 0..<GameBoard.cols {
                guard canPlace(shape: shape, atRow: baseRow, col: baseCol) else { continue }

                // Bu pozisyon için her hücrenin mesafesini topla
                var score: CGFloat = 0
                for (i, scenePos) in cellScenePositions.enumerated() {
                    let r = baseRow + shape.cells[i].row
                    let c = baseCol + shape.cells[i].col
                    score += scenePos.distance(to: cellCenter(row: r, col: c))
                }

                if score < bestScore {
                    bestScore = score
                    result = (baseRow, baseCol)
                }
            }
        }

        // Parça grid'e çok uzaksa (ortalama hücre başına 2.5 cellSize'dan fazla) yerleştirme
        // Hücre başına ortalama ~3 cellSize mesafe kabul edilebilir
        let maxScore = CGFloat(shape.cells.count) * cellSize * 3.0
        return bestScore < maxScore ? result : nil
    }

    func showGhost(shape: BlockShape, atRow row: Int, col: Int, color: BlockColor) {
        clearGhost()
        let goldFill   = UIColor(hex: "#F5C842").withAlphaComponent(0.22)
        let goldStroke = UIColor(hex: "#FFE066").withAlphaComponent(0.70)
        for cell in shape.cells {
            let r = row + cell.row
            let c = col + cell.col
            guard r >= 0, r < GameBoard.rows, c >= 0, c < GameBoard.cols else {
                clearGhost(); return
            }
            let ghost = SKShapeNode(
                rectOf: CGSize(width: cellSize - 2, height: cellSize - 2),
                cornerRadius: cellSize * 0.12
            )
            ghost.fillColor   = goldFill
            ghost.strokeColor = goldStroke
            ghost.lineWidth   = 2
            ghost.position    = cellCenter(row: r, col: c)
            ghost.zPosition   = 3
            scene?.addChild(ghost)
            ghostNodes.append(ghost)
        }
    }

    func clearGhost() {
        ghostNodes.forEach { $0.removeFromParent() }
        ghostNodes.removeAll()
    }

    // MARK: - Game-Over Check

    func anyShapeFits(_ shapes: [BlockShape]) -> Bool {
        for shape in shapes {
            for r in 0..<GameBoard.rows {
                for c in 0..<GameBoard.cols {
                    if canPlace(shape: shape, atRow: r, col: c) { return true }
                }
            }
        }
        return false
    }

    // MARK: - Reset

    func reset() {
        // Clear all block nodes
        for row in 0..<GameBoard.rows {
            for col in 0..<GameBoard.cols {
                if grid[row][col] {
                    cellNodes[row][col].removeFromParent()
                    // Restore empty bg
                    let bg = SKShapeNode(rectOf: CGSize(width: cellSize, height: cellSize), cornerRadius: cellSize * 0.12)
                    bg.fillColor   = UIColor(white: 1, alpha: 0.06)
                    bg.strokeColor = .clear
                    bg.position    = cellCenter(row: row, col: col)
                    bg.zPosition   = 1
                    scene?.addChild(bg)
                    cellNodes[row][col] = bg
                }
                grid[row][col]      = false
                colorGrid[row][col] = nil
            }
        }
    }
}

// MARK: - CGPoint Helper

extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat {
        sqrt(pow(x - other.x, 2) + pow(y - other.y, 2))
    }
}
