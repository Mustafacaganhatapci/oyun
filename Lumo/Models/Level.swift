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

struct Level: Identifiable, Equatable {
    let id: Int              // 1...30
    let rings: [RingSpec]
    let lumens: [LumenSpec]
    var startRing: Int { 0 }
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
// 30 bölüm, her biri sabit tohumlu üreteçle kurulur; zorluk parametreleri
// bölüm numarasına göre elle akort edilmiştir.

enum LevelLibrary {
    static let count = 30
    static let adFreeLevels = 10   // ilk 10 bölümde asla reklam yok

    static func level(_ id: Int) -> Level {
        let d = difficulty(for: id)
        var rng = SplitMix64(seed: 0xC0FFEE &+ UInt64(id) &* 7919)

        var rings: [RingSpec] = []
        // Başlangıç halkası: alt-orta
        var cursor = CGPoint(x: 0.5, y: 0.12)
        rings.append(RingSpec(center: cursor,
                              radius: d.radiusRange.lowerBound + 0.01,
                              orbitSpeed: d.speedRange.lowerBound,
                              direction: 1))

        for i in 1..<d.ringCount {
            let isGate = (i == d.ringCount - 1)
            let radius = rng.cg(in: d.radiusRange)
            var candidate = CGPoint.zero
            var attempts = 0
            repeat {
                let angle = rng.cg(in: (.pi * 0.22)...(.pi * 0.78)) // yukarı doğru yelpaze
                let dist = rng.cg(in: d.gapRange)
                candidate = CGPoint(x: cursor.x + cos(angle) * dist * 0.9,
                                    y: cursor.y + sin(angle) * dist)
                candidate.x = min(max(candidate.x, 0.16), 0.84)
                candidate.y = min(max(candidate.y, 0.10), 0.90)
                attempts += 1
            } while overlaps(candidate, radius: radius, rings: rings) && attempts < 40

            let dir: CGFloat = rng.cg(in: 0...1) < 0.5 ? 1 : -1
            var spec = RingSpec(center: candidate,
                                radius: radius,
                                orbitSpeed: rng.cg(in: d.speedRange),
                                direction: dir,
                                isGate: isGate)

            // Tehlike yayları (kapı halkasına asla koyma — bitiş adil olsun)
            if !isGate, i > 1, rng.cg(in: 0...1) < d.hazardChance {
                let span = rng.cg(in: d.hazardSpan)
                let start = rng.cg(in: 0...(2 * .pi))
                spec.hazardArcs = [start...(start + span)]
                if d.hazardsRotate {
                    spec.hazardRotationSpeed = rng.cg(in: 0.4...0.9) * (rng.cg(in: 0...1) < 0.5 ? 1 : -1)
                }
            }

            // Hareketli halkalar
            if !isGate, i > 1, rng.cg(in: 0...1) < d.movingChance {
                spec.moving = MovingSpec(axis: rng.cg(in: 0...1) < 0.6 ? .horizontal : .vertical,
                                         amplitude: rng.cg(in: 0.05...d.movingAmplitude),
                                         period: rng.cg(in: 2.4...4.2),
                                         phase: rng.cg(in: 0...(2 * .pi)))
            }

            rings.append(spec)
            cursor = candidate
        }

        // 3 lumen: ardışık halka çiftlerinin arasına, uçuş hattına yakın yerleştir
        var lumens: [LumenSpec] = []
        let pairCount = rings.count - 1
        var pairIndices = Array(0..<pairCount).shuffled(using: &rng)
        pairIndices = Array(pairIndices.prefix(3))
        for p in pairIndices.sorted() {
            let a = rings[p].center, b = rings[p + 1].center
            let t = rng.cg(in: 0.42...0.58)
            let mid = CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
            lumens.append(LumenSpec(position: mid))
        }
        while lumens.count < 3 {
            lumens.append(LumenSpec(position: CGPoint(x: rng.cg(in: 0.3...0.7), y: rng.cg(in: 0.3...0.7))))
        }

        return Level(id: id, rings: rings, lumens: lumens)
    }

    private static func overlaps(_ center: CGPoint, radius: CGFloat, rings: [RingSpec]) -> Bool {
        for r in rings {
            let dx = r.center.x - center.x
            let dy = r.center.y - center.y
            if sqrt(dx * dx + dy * dy) < (r.radius + radius + 0.05) { return true }
        }
        return false
    }

    // MARK: Zorluk eğrisi

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
        let t = CGFloat(id - 1) / CGFloat(count - 1)   // 0...1
        switch id {
        case 1...3:
            return Difficulty(ringCount: 4,
                              radiusRange: 0.09...0.11, speedRange: 1.5...1.9,
                              gapRange: 0.26...0.32,
                              hazardChance: 0, hazardSpan: 0...0, hazardsRotate: false,
                              movingChance: 0, movingAmplitude: 0)
        case 4...6:
            return Difficulty(ringCount: 5,
                              radiusRange: 0.08...0.105, speedRange: 1.8...2.4,
                              gapRange: 0.25...0.33,
                              hazardChance: 0, hazardSpan: 0...0, hazardsRotate: false,
                              movingChance: 0, movingAmplitude: 0)
        case 7...10:
            return Difficulty(ringCount: 5,
                              radiusRange: 0.075...0.10, speedRange: 2.0...2.7,
                              gapRange: 0.24...0.34,
                              hazardChance: 0.45, hazardSpan: (.pi * 0.22)...(.pi * 0.38), hazardsRotate: false,
                              movingChance: 0, movingAmplitude: 0)
        case 11...15:
            return Difficulty(ringCount: 6,
                              radiusRange: 0.07...0.095, speedRange: 2.2...3.0,
                              gapRange: 0.24...0.34,
                              hazardChance: 0.55, hazardSpan: (.pi * 0.25)...(.pi * 0.45), hazardsRotate: true,
                              movingChance: 0.35, movingAmplitude: 0.08)
        case 16...22:
            return Difficulty(ringCount: 6,
                              radiusRange: 0.065...0.09, speedRange: 2.5...3.4,
                              gapRange: 0.23...0.35,
                              hazardChance: 0.65, hazardSpan: (.pi * 0.3)...(.pi * 0.5), hazardsRotate: true,
                              movingChance: 0.45, movingAmplitude: 0.10)
        default: // 23...30
            return Difficulty(ringCount: 7,
                              radiusRange: 0.06...0.085, speedRange: 2.8...(3.4 + t),
                              gapRange: 0.22...0.34,
                              hazardChance: 0.75, hazardSpan: (.pi * 0.32)...(.pi * 0.55), hazardsRotate: true,
                              movingChance: 0.55, movingAmplitude: 0.12)
        }
    }
}
