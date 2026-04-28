import SpriteKit
import UIKit

// MARK: - Shape Definitions

struct BlockShape {
    let cells: [(col: Int, row: Int)]

    // 5'li düz çizgiler kaldırıldı (sinir bozucu, nadiren sığıyor)
    // 3x3 ayrı tutuldu — nadir gelsin diye weighted random'da az ağırlık verilir
    static let common: [BlockShape] = [
        // Single
        BlockShape(cells: [(0,0)]),
        // Dominoes
        BlockShape(cells: [(0,0),(1,0)]),
        BlockShape(cells: [(0,0),(0,1)]),
        // Triominoes
        BlockShape(cells: [(0,0),(1,0),(2,0)]),
        BlockShape(cells: [(0,0),(0,1),(0,2)]),
        BlockShape(cells: [(0,0),(1,0),(0,1)]),
        BlockShape(cells: [(0,0),(1,0),(1,1)]),
        BlockShape(cells: [(0,1),(1,0),(1,1)]),
        BlockShape(cells: [(0,0),(0,1),(1,1)]),
        // Square 2x2
        BlockShape(cells: [(0,0),(1,0),(0,1),(1,1)]),
        // Tetrominoes
        BlockShape(cells: [(0,0),(1,0),(2,0),(3,0)]),
        BlockShape(cells: [(0,0),(0,1),(0,2),(0,3)]),
        BlockShape(cells: [(0,0),(1,0),(2,0),(2,1)]),
        BlockShape(cells: [(0,0),(1,0),(2,0),(0,1)]),
        BlockShape(cells: [(0,1),(1,1),(2,1),(2,0)]),
        BlockShape(cells: [(0,0),(0,1),(0,2),(1,2)]),
        BlockShape(cells: [(0,0),(1,0),(1,1),(1,2)]),
        BlockShape(cells: [(0,2),(1,0),(1,1),(1,2)]),
    ]

    static let rare: [BlockShape] = [
        // 3x3 kare — nadir gelsin
        BlockShape(cells: [(0,0),(1,0),(2,0),(0,1),(1,1),(2,1),(0,2),(1,2),(2,2)]),
    ]

    // Geriye dönük uyumluluk için (anyShapeFits vs.)
    static let all: [BlockShape] = common + rare

    /// Ağırlıklı rastgele: 3x3 yaklaşık %8 ihtimalle gelir
    static func weighted() -> BlockShape {
        let roll = Int.random(in: 0..<100)
        if roll < 8, let r = rare.randomElement() { return r }
        return common.randomElement()!
    }
}

// MARK: - Colors

enum BlockColor: CaseIterable {
    case red, blue, green, yellow, purple, cyan, orange

    var fill: UIColor {
        switch self {
        case .red:    return UIColor(hex: "#E84040")
        case .blue:   return UIColor(hex: "#3B8FE8")
        case .green:  return UIColor(hex: "#4CAF50")
        case .yellow: return UIColor(hex: "#F5C842")
        case .purple: return UIColor(hex: "#9C27B0")
        case .cyan:   return UIColor(hex: "#26C6DA")
        case .orange: return UIColor(hex: "#FF8C00")
        }
    }

    var highlight: UIColor { fill.lighter(by: 0.4) }
    var shadow: UIColor    { fill.darker(by: 0.25) }

    static func random() -> BlockColor {
        BlockColor.allCases.randomElement()!
    }

    /// Verilen renkleri hariç tutarak rastgele seçer — tray'de 3 farklı renk için.
    static func randomExcluding(_ excluded: [BlockColor]) -> BlockColor {
        let pool = BlockColor.allCases.filter { !excluded.contains($0) }
        return (pool.isEmpty ? BlockColor.allCases : pool).randomElement()!
    }
}

// MARK: - Block Node Factory
//
// Bloom-style block: gloss base + içinde 5 yapraklı (merkez + 4 yön) mini bloom motifi.
// Her hücre, oyunun ana logosunun küçük bir yankısı.

func makeBlockNode(cellSize: CGFloat, color: BlockColor) -> SKNode {
    let container = SKNode()
    let r = cellSize * 0.22   // daha yuvarlak köşe

    // Shadow layer
    let shadow = SKShapeNode(rectOf: CGSize(width: cellSize - 2, height: cellSize - 2), cornerRadius: r)
    shadow.fillColor   = color.shadow
    shadow.strokeColor = .clear
    shadow.position    = CGPoint(x: 2, y: -2)
    container.addChild(shadow)

    // Main block
    let main = SKShapeNode(rectOf: CGSize(width: cellSize - 2, height: cellSize - 2), cornerRadius: r)
    main.fillColor   = color.fill
    main.strokeColor = .clear
    container.addChild(main)

    // Mini bloom motif — + şeklinde 5 kare, bloğun kendi renginin açık tonu
    if cellSize >= 16 {
        let petal  = cellSize * 0.20          // her kare büyüklüğü
        let step   = cellSize * 0.265         // merkez → komşu mesafesi
        let pr     = petal * 0.35             // köşe yarıçapı
        let pColor = color.highlight.withAlphaComponent(0.55)

        let positions: [(CGFloat, CGFloat)] = [
            (0, 0), (0, 1), (1, 0), (0, -1), (-1, 0)
        ]
        for (dx, dy) in positions {
            let leaf = SKShapeNode(rectOf: CGSize(width: petal, height: petal), cornerRadius: pr)
            leaf.fillColor   = pColor
            leaf.strokeColor = .clear
            leaf.position    = CGPoint(x: dx * step, y: dy * step)
            container.addChild(leaf)
        }
    }

    // Üst-sol köşe gloss highlight
    let hw = cellSize * 0.50
    let hh = cellSize * 0.22
    let highlight = SKShapeNode(rectOf: CGSize(width: hw, height: hh), cornerRadius: r * 0.5)
    highlight.fillColor   = UIColor.white.withAlphaComponent(0.30)
    highlight.strokeColor = .clear
    highlight.position    = CGPoint(x: -(cellSize - hw) * 0.22, y: (cellSize - hh) * 0.28)
    container.addChild(highlight)

    return container
}

// MARK: - UIColor Helpers

extension UIColor {
    convenience init(hex: String) {
        var h = hex.trimmingCharacters(in: .init(charactersIn: "#"))
        if h.count == 6 { h += "ff" }
        var val: UInt64 = 0
        Scanner(string: h).scanHexInt64(&val)
        let r = CGFloat((val >> 24) & 0xff) / 255
        let g = CGFloat((val >> 16) & 0xff) / 255
        let b = CGFloat((val >> 8)  & 0xff) / 255
        let a = CGFloat( val        & 0xff) / 255
        self.init(red: r, green: g, blue: b, alpha: a)
    }

    func lighter(by pct: CGFloat) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return UIColor(red: min(r + pct, 1), green: min(g + pct, 1), blue: min(b + pct, 1), alpha: a)
    }

    func darker(by pct: CGFloat) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return UIColor(red: max(r - pct, 0), green: max(g - pct, 0), blue: max(b - pct, 0), alpha: a)
    }
}
