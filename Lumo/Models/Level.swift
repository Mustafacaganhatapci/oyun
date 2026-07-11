import CoreGraphics
import Foundation

// MARK: - Bölüm tanımları
// Tüm koordinatlar normalize uzaydadır: x ∈ [0,1] ekran genişliği,
// y ∈ [0,1] oynanabilir alan yüksekliği (0 = alt). Yarıçaplar genişlik oranıdır.

struct MovingSpec: Equatable {
    enum Axis { case horizontal, vertical }
    var axis: Axis
    var amplitude: CGFloat   // normalize
    var period: CGFloat      // saniye
    var phase: CGFloat       // radyan
}

struct RingSpec: Equatable {
    var center: CGPoint
    var radius: CGFloat
    var orbitSpeed: CGFloat        // radyan/sn (top halkadayken açısal hız)
    var direction: CGFloat         // 1 = saat yönünün tersi, -1 = saat yönü
    var hazardArcs: [ClosedRange<CGFloat>] = []   // halka-yerel radyan aralıkları
    var hazardRotationSpeed: CGFloat = 0          // radyan/sn (tehlike yayları döner)
    var moving: MovingSpec? = nil
    var isGate: Bool = false
}

struct LumenSpec: Equatable {
    var position: CGPoint
}

enum LevelKind: Equatable {
    case normal
    case bonus     // süreli lumen toplama turu — tehlike yok, kapı yok
}

struct Level: Identifiable, Equatable {
    let id: Int              // 1...count
    let kind: LevelKind
    let rings: [RingSpec]
    let lumens: [LumenSpec]
    var timeLimit: TimeInterval? = nil   // süreli bölüm: kapıya bu sürede ulaş (deneme başına)
    var startRing: Int { 0 }
    var bonusDuration: TimeInterval { 25 }
}

// MARK: - Deterministik RNG (bölümler her cihazda birebir aynı olsun diye)

struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
    mutating func cg(in range: ClosedRange<CGFloat>) -> CGFloat {
        CGFloat.random(in: range, using: &self)
    }
}

// MARK: - Bölüm kütüphanesi
// 48 düğüm: her 6. bölüm bonus turu (6, 12, 18, ...), aralarda 40 normal bölüm.

enum LevelLibrary {
    static let count = 120
    static let adFreeLevels = 10        // ilk 10 bölümde asla reklam yok

    static func isBonus(_ id: Int) -> Bool { id > 0 && id % 6 == 0 }

    /// İlk açılışta oynatılan "nasıl oynanır" antrenman bölümü (id 0).
    /// Haritada görünmez, ilerlemeye yazılmaz.
    static let tutorialID = 0

    static var tutorialLevel: Level {
        // Geniş, yavaş, 4 halkalı el yapımı sahne: fırlat → yıldız topla →
        // kırmızı yaydan kaç → kapıya ulaş
        var rings: [RingSpec] = []
        rings.append(RingSpec(center: CGPoint(x: 0.50, y: 0.12), radius: 0.10, orbitSpeed: 1.6, direction: 1))
        rings.append(RingSpec(center: CGPoint(x: 0.32, y: 0.38), radius: 0.10, orbitSpeed: 1.7, direction: -1))

        var hazardRing = RingSpec(center: CGPoint(x: 0.62, y: 0.60), radius: 0.10, orbitSpeed: 1.8, direction: 1)
        hazardRing.hazardArcs = [0...(.pi * 0.5)]        // dar, yavaş dönen kırmızı yay
        hazardRing.hazardRotationSpeed = 0.5
        rings.append(hazardRing)

        var gate = RingSpec(center: CGPoint(x: 0.42, y: 0.85), radius: 0.10, orbitSpeed: 1.6, direction: -1)
        gate.isGate = true
        rings.append(gate)

        // Yıldızlar tam uçuş hattının üzerinde — oynarken kendiliğinden toplanır
        func between(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
            CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
        }
        let lumens = [
            LumenSpec(position: between(rings[0].center, rings[1].center)),
            LumenSpec(position: between(rings[1].center, rings[2].center)),
            LumenSpec(position: between(rings[2].center, rings[3].center))
        ]
        return Level(id: tutorialID, kind: .normal, rings: rings, lumens: lumens)
    }

    /// Speed Run: ilk 10 normal bölüm (bonuslar atlanır)
    static var speedrunLevels: [Int] {
        var result: [Int] = []
        var id = 1
        while result.count < 10 {
            if !isBonus(id) { result.append(id) }
            id += 1
        }
        return result
    }

    /// id'nin kaçıncı NORMAL bölüm olduğu (zorluk eğrisi bunun üzerinden yürür)
    static func normalIndex(_ id: Int) -> Int { id - id / 6 }

    /// Süreli bölümler: 12. normal bölümden itibaren her 4 normal bölümde bir.
    /// (Speed Run ilk 10 normal bölümü kullandığından oraya hiç denk gelmez.)
    static func isTimed(_ id: Int) -> Bool {
        guard !isBonus(id) else { return false }
        let n = normalIndex(id)
        return n >= 12 && n % 4 == 0
    }

    static func level(_ id: Int) -> Level {
        if id == tutorialID { return tutorialLevel }
        return isBonus(id) ? bonusLevel(id) : normalLevel(id)
    }

    // MARK: Normal bölüm üretimi

    private static func normalLevel(_ id: Int) -> Level {
        let d = difficulty(for: id)
        var rng = SplitMix64(seed: 0xC0FFEE &+ UInt64(id) &* 7919)

        var rings: [RingSpec] = []
        var cursor = CGPoint(x: 0.5, y: 0.10)
        rings.append(RingSpec(center: cursor,
                              radius: d.radiusRange.lowerBound + 0.01,
                              orbitSpeed: d.speedRange.lowerBound,
                              direction: 1))

        buildChain(rings: &rings, cursor: &cursor, rng: &rng, difficulty: d)

        // 3 lumen: ardışık halka çiftlerinin arasına, uçuş hattına yakın
        var lumens: [LumenSpec] = []
        let pairCount = rings.count - 1
        var pairIndices = Array(0..<pairCount).shuffled(using: &rng)
        pairIndices = Array(pairIndices.prefix(3))
        for p in pairIndices.sorted() {
            let a = rings[p].center, b = rings[p + 1].center
            let t = rng.cg(in: 0.42...0.58)
            lumens.append(LumenSpec(position: CGPoint(x: a.x + (b.x - a.x) * t,
                                                      y: a.y + (b.y - a.y) * t)))
        }
        while lumens.count < 3 {
            lumens.append(LumenSpec(position: CGPoint(x: rng.cg(in: 0.3...0.7), y: rng.cg(in: 0.3...0.7))))
        }

        // Süreli bölüm: halka başına tanınan süre ilerledikçe kısalır (~4s → ~2.6s)
        var timeLimit: TimeInterval? = nil
        if isTimed(id) {
            let totalNormal = max(1, count - count / 6)
            let t = Double(normalIndex(id) - 1) / Double(max(1, totalNormal - 1))
            timeLimit = (Double(rings.count) * (4.0 - 1.4 * t)).rounded()
        }

        return Level(id: id, kind: .normal, rings: rings, lumens: lumens, timeLimit: timeLimit)
    }

    // MARK: Bonus turu üretimi — tehlike yok, bol lumen, süre sınırlı

    private static func bonusLevel(_ id: Int) -> Level {
        var rng = SplitMix64(seed: 0xB0B0 &+ UInt64(id) &* 104729)
        let d = Difficulty(ringCount: 6,
                           radiusRange: 0.085...0.105,
                           speedRange: 2.1...2.7,
                           gapRange: 0.24...0.32,
                           hazardChance: 0, hazardSpan: 0...0, hazardsRotate: false,
                           movingChance: 0, movingAmplitude: 0)

        var rings: [RingSpec] = []
        var cursor = CGPoint(x: 0.5, y: 0.10)
        rings.append(RingSpec(center: cursor, radius: 0.095, orbitSpeed: 2.2, direction: 1))
        buildChain(rings: &rings, cursor: &cursor, rng: &rng, difficulty: d)
        rings[rings.count - 1].isGate = false   // bonusta kapı yok; tur süreyle biter

        // 9 lumen: her halka çifti arasına 1 + halkaların çevresine ekstralar
        var lumens: [LumenSpec] = []
        for p in 0..<(rings.count - 1) {
            let a = rings[p].center, b = rings[p + 1].center
            let t = rng.cg(in: 0.40...0.60)
            lumens.append(LumenSpec(position: CGPoint(x: a.x + (b.x - a.x) * t,
                                                      y: a.y + (b.y - a.y) * t)))
        }
        while lumens.count < 9 {
            let ring = rings[Int(rng.cg(in: 0...CGFloat(rings.count - 1)).rounded())]
            let angle = rng.cg(in: 0...(2 * .pi))
            let dist = ring.radius + rng.cg(in: 0.035...0.06)
            var p = CGPoint(x: ring.center.x + cos(angle) * dist,
                            y: ring.center.y + sin(angle) * dist)
            p.x = min(max(p.x, 0.08), 0.92)
            p.y = min(max(p.y, 0.05), 0.95)
            lumens.append(LumenSpec(position: p))
        }

        return Level(id: id, kind: .bonus, rings: rings, lumens: lumens)
    }

    // MARK: Ortak zincir kurucu

    private static func buildChain(rings: inout [RingSpec],
                                   cursor: inout CGPoint,
                                   rng: inout SplitMix64,
                                   difficulty d: Difficulty) {
        let margin: CGFloat = 0.05   // halkalar arası asgari boşluk (normalize)

        for i in 1..<d.ringCount {
            let markGate = (i == d.ringCount - 1)
            let radius = rng.cg(in: d.radiusRange)

            var candidate = CGPoint(x: 0.5, y: 0.5)
            var bestClearance = -CGFloat.greatestFiniteMagnitude
            var attempts = 0
            repeat {
                let angle = rng.cg(in: (.pi * 0.22)...(.pi * 0.78))
                let dist = rng.cg(in: d.gapRange)
                var p = CGPoint(x: cursor.x + cos(angle) * dist * 0.9,
                                y: cursor.y + sin(angle) * dist)
                p.x = min(max(p.x, 0.15), 0.85)
                p.y = min(max(p.y, 0.08), 0.92)
                let c = clearance(p, radius: radius, rings: rings)
                if c > bestClearance { bestClearance = c; candidate = p }
                attempts += 1
            } while bestClearance < margin && attempts < 40

            if bestClearance < margin {
                var bestScore = -CGFloat.greatestFiniteMagnitude
                for gx in stride(from: CGFloat(0.15), through: 0.85, by: 0.04) {
                    for gy in stride(from: CGFloat(0.08), through: 0.92, by: 0.04) {
                        let p = CGPoint(x: gx, y: gy)
                        guard clearance(p, radius: radius, rings: rings) >= margin else { continue }
                        let dx = p.x - cursor.x
                        let dy = p.y - cursor.y
                        let score = -abs(sqrt(dx * dx + dy * dy) - 0.30)
                        if score > bestScore { bestScore = score; candidate = p }
                    }
                }
            }

            let dir: CGFloat = rng.cg(in: 0...1) < 0.5 ? 1 : -1
            var spec = RingSpec(center: candidate,
                                radius: radius,
                                orbitSpeed: rng.cg(in: d.speedRange),
                                direction: dir,
                                isGate: markGate)

            // Tehlike yayları (kapıya ve ilk iki halkaya asla koyma)
            if !markGate, i > 1, rng.cg(in: 0...1) < d.hazardChance {
                let span = rng.cg(in: d.hazardSpan)
                let start = rng.cg(in: 0...(2 * .pi))
                spec.hazardArcs = [start...(start + span)]
                if d.hazardsRotate {
                    spec.hazardRotationSpeed = rng.cg(in: 0.4...1.0) * (rng.cg(in: 0...1) < 0.5 ? 1 : -1)
                }
            }

            // Hareketli halkalar — genlik komşulara çarpmayacak kadar kırpılır
            if !markGate, i > 1, rng.cg(in: 0...1) < d.movingChance {
                let clear = clearance(candidate, radius: radius, rings: rings)
                let amplitude = min(rng.cg(in: 0.05...max(0.051, d.movingAmplitude)),
                                    max(0.03, clear - 0.02))
                spec.moving = MovingSpec(axis: rng.cg(in: 0...1) < 0.6 ? .horizontal : .vertical,
                                         amplitude: amplitude,
                                         period: rng.cg(in: 2.2...4.0),
                                         phase: rng.cg(in: 0...(2 * .pi)))
            }

            rings.append(spec)
            cursor = candidate
        }
    }

    /// Adayın mevcut halkalara olan en dar boşluğu (negatifse örtüşüyor demektir)
    private static func clearance(_ center: CGPoint, radius: CGFloat, rings: [RingSpec]) -> CGFloat {
        var minClearance = CGFloat.greatestFiniteMagnitude
        for r in rings {
            let dx = r.center.x - center.x
            let dy = r.center.y - center.y
            minClearance = min(minClearance, sqrt(dx * dx + dy * dy) - (r.radius + radius))
        }
        return minClearance
    }

    // MARK: Zorluk eğrisi — 40 normal bölüm üzerinden akort edilir
    // Oyuncu geri bildirimi: erken bölümler fazla kolaydı; tehlikeler artık
    // 3. normal bölümde başlar, hızlar genel olarak yükseltildi.

    struct Difficulty {
        var ringCount: Int
        var radiusRange: ClosedRange<CGFloat>
        var speedRange: ClosedRange<CGFloat>   // radyan/sn
        var gapRange: ClosedRange<CGFloat>
        var hazardChance: CGFloat
        var hazardSpan: ClosedRange<CGFloat>
        var hazardsRotate: Bool
        var movingChance: CGFloat
        var movingAmplitude: CGFloat
    }

    static func difficulty(for id: Int) -> Difficulty {
        let n = normalIndex(id)              // 1...(normal bölüm sayısı)
        let totalNormal = max(1, count - count / 6)
        let t = CGFloat(n - 1) / CGFloat(max(1, totalNormal - 1))   // 0...1
        switch n {
        case 1...2:   // öğretici — ama uyutmayan
            return Difficulty(ringCount: 5,
                              radiusRange: 0.088...0.105, speedRange: 1.9...2.3,
                              gapRange: 0.26...0.32,
                              hazardChance: 0, hazardSpan: 0...0, hazardsRotate: false,
                              movingChance: 0, movingAmplitude: 0)
        case 3...5:   // tehlikeler hemen başlar
            return Difficulty(ringCount: 6,
                              radiusRange: 0.08...0.10, speedRange: 2.2...2.8,
                              gapRange: 0.25...0.33,
                              hazardChance: 0.4, hazardSpan: (.pi * 0.20)...(.pi * 0.35), hazardsRotate: false,
                              movingChance: 0, movingAmplitude: 0)
        case 6...10:
            return Difficulty(ringCount: 6,
                              radiusRange: 0.075...0.095, speedRange: 2.5...3.1,
                              gapRange: 0.24...0.34,
                              hazardChance: 0.55, hazardSpan: (.pi * 0.24)...(.pi * 0.42), hazardsRotate: true,
                              movingChance: 0.25, movingAmplitude: 0.08)
        case 11...18:
            return Difficulty(ringCount: 7,
                              radiusRange: 0.07...0.09, speedRange: 2.8...3.5,
                              gapRange: 0.23...0.34,
                              hazardChance: 0.62, hazardSpan: (.pi * 0.28)...(.pi * 0.48), hazardsRotate: true,
                              movingChance: 0.4, movingAmplitude: 0.10)
        case 19...28:
            return Difficulty(ringCount: 7,
                              radiusRange: 0.065...0.085, speedRange: 3.0...3.9,
                              gapRange: 0.22...0.35,
                              hazardChance: 0.72, hazardSpan: (.pi * 0.30)...(.pi * 0.52), hazardsRotate: true,
                              movingChance: 0.5, movingAmplitude: 0.11)
        default:      // 29+ — ustalık; halka sayısı, hız ve tehlikeler sona doğru sertleşir
            let ringCount = 8 + Int(max(0, t - 0.28) * 5.6)   // 8 → 12 arası
            return Difficulty(ringCount: min(max(ringCount, 8), 12),
                              radiusRange: (0.05 - 0.008 * t)...(0.08 - 0.014 * t),
                              speedRange: (3.2 + 0.9 * t)...(4.0 + 1.6 * t),
                              gapRange: 0.20...0.33,
                              hazardChance: min(0.8 + 0.15 * t, 0.95),
                              hazardSpan: (.pi * 0.32)...(.pi * (0.6 + 0.2 * t)), hazardsRotate: true,
                              movingChance: min(0.6 + 0.3 * t, 0.9), movingAmplitude: 0.12 + 0.03 * t)
        }
    }
}
