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
        for cell in shape.cells {
            let r = row + cell.row
            let c = col + cell.col
            grid[r][c]      = true
            colorGrid[r][c] = color

            let node = makeBlockNode(cellSize: cellSize, color: color)
            node.position  = cellCenter(row: r, col: c)
            node.zPosition = 2
            scene?.addChild(node)
            cellNodes[r][c] = node
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
        for c in 0..<GameBoard.cols { clearCell(row: row, col: c) }
    }

    private func clearCol(_ col: Int) {
        for r in 0..<GameBoard.rows { clearCell(row: r, col: col) }
    }

    private func clearCell(row: Int, col: Int) {
        guard grid[row][col] else { return }
        grid[row][col]      = false
        colorGrid[row][col] = nil

        // Flash and remove block node
        let node = cellNodes[row][col]
        let flash = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.8, duration: 0.05),
            SKAction.fadeAlpha(to: 0, duration: 0.1),
            SKAction.removeFromParent()
        ])
        node.run(flash)

        // Replace with empty cell bg
        let bg = SKShapeNode(rectOf: CGSize(width: cellSize, height: cellSize), cornerRadius: cellSize * 0.12)
        bg.fillColor   = UIColor(white: 1, alpha: 0.06)
        bg.strokeColor = .clear
        bg.position    = cellCenter(row: row, col: col)
        bg.zPosition   = 1
        scene?.addChild(bg)
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
