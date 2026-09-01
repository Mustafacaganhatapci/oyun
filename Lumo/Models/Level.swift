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
    /// Kaç yıldız değerinde. Normal lumen 1; "büyük yıldız" 4 eder ve
    /// ekranda belirgin şekilde daha iri çizilir.
    var value: Int = 1
    var isGrand: Bool { value > 1 }
}

enum LevelKind: Equatable {
    case normal
    case bonus     // süreli lumen toplama turu — tehlike yok, kapı yok
    case collect   // kapı, tüm lumenler toplanana kadar kilitli; ölünce bölüm baştan
}

struct Level: Identifiable, Equatable {
    let id: Int              // 1...count
    let kind: LevelKind
    let rings: [RingSpec]
    let lumens: [LumenSpec]
    var timeLimit: TimeInterval? = nil   // süreli bölüm: kapıya bu sürede ulaş (deneme başına)
    var dwellLimit: TimeInterval? = nil  // "devam et ya da düş": bir halkada bu süre dolunca küre kendiliğinden fırlar
    var startRing: Int { 0 }
    var bonusDuration: TimeInterval { 25 }

    /// Bu bölümden alınabilecek azami yıldız (lumen değerlerinin toplamı).
    var maxStars: Int { lumens.reduce(0) { $0 + $1.value } }

    /// Kapı yalnızca her şey toplandığında açılır mı?
    var gateNeedsAllLumens: Bool { kind == .collect }

    /// Ölünce son halkaya değil, bölümün başına dönülür ve lumenler geri gelir.
    var restartsOnDeath: Bool { kind == .collect }
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
    /// 0..<1 — sıralama doldurmaları bunu kullanıyor
    mutating func unit() -> Double { Double(next() >> 11) / Double(1 << 53) }
}

// MARK: - Bölüm kütüphanesi
// 48 düğüm: her 6. bölüm bonus turu (6, 12, 18, ...), aralarda 40 normal bölüm.

enum LevelLibrary {
    static let count = 257
    static let adFreeLevels = 10        // ilk 10 bölümde asla reklam yok

    /// Kampanya 120'den 150'ye çıkarıldığında 1...120'nin AYNEN aynı kalması
    /// gerekiyordu: kayıtlı ilerleme bu bölümlerin düzenine göre kazanılmış.
    /// Zorluk eğrisi bölüm sayısına bölünerek hesaplandığı için, payda burada
    /// eski değere (120 bölümde 100 normal bölüm) sabitlenir. Yeni bölümler
    /// eğrinin sonunda, en yüksek zorlukta oturur.
    static let legacyCount = 120
    private static let curveNormalCount = legacyCount - legacyCount / 6   // 100

    /// Kampanyanın bir önceki uzunluğu. 121...150 de artık yayında olduğu
    /// için o aralık da olduğu gibi korunuyor; yeni kurallar buradan sonrası
    /// için geçerli.
    static let priorCount = 150

    static func isBonus(_ id: Int) -> Bool { id > 0 && id % 6 == 0 }

    /// Yeni bölüm türleri kampanyanın ikinci yarısında başlar. 60...120
    /// arasında yedide bir serpiştirilir (çeşitlilik), 120'den sonra üçte bire
    /// çıkar (yeni bölümlerin kimliği bu türler).
    static let kindsFrom = 60

    /// Kapı tüm lumenler toplanana kadar açılmaz, ölünce bölüm baştan başlar.
    static func isCollect(_ id: Int) -> Bool {
        guard id >= kindsFrom, !isBonus(id) else { return false }
        return id > legacyCount ? (id % 3 == 1) : (id % 7 == 4)
    }

    /// "Büyük yıldız" bölümleri: 3 küçük lumen yerine 4 eden tek bir iri lumen.
    ///
    /// 150'den sonra seyrekliyor (üçte birden dörtte bire) ve topla-bitir
    /// bölümleriyle çakışmıyor: tek lumenli bir topla-bitir bölümü, kapıyı
    /// tek yıldızla açmak demek olurdu — bölüm türünün anlamı kalmazdı.
    /// Sayı ayrıca kampanyanın toplamını tam 806 yıldıza oturtuyor.
    static func hasGrandStar(_ id: Int) -> Bool {
        guard id >= kindsFrom, !isBonus(id) else { return false }
        if id <= legacyCount { return id % 7 == 1 }
        if id <= priorCount { return id % 3 == 2 }
        return id % 4 == 1 && !isCollect(id)
    }

    /// Zorluk eğrisinin 0...1 konumu. 100. normal bölümden sonra 1'de durur.
    private static func curveT(_ n: Int) -> CGFloat {
        let t = CGFloat(n - 1) / CGFloat(max(1, curveNormalCount - 1))
        return min(max(t, 0), 1)
    }

    /// Tehlike müsamahasının başladığı bölüm. Buradan sonra (ve sonsuz modda)
    /// tehlikeli bir halkaya tutunan küre, o halka etrafında bir tam tur
    /// dönene kadar yanmaz; yayın üstündeki yeşil kaplama o süre boyunca erir.
    ///
    /// Geç bölümlerde halkalar küçülüp hızlandığı ve tehlike yayları
    /// genişlediği için oyuncu ineceği yeri okuyamadan ölüyordu. Bir tur,
    /// haritayı görmeye yetecek kadar zaman veriyor ama zamanlamayı ortadan
    /// kaldırmıyor: tur dolduğunda kırmızı geri geliyor.
    static let hazardGraceFrom = 67

    static func hasHazardGrace(_ id: Int) -> Bool { id >= hazardGraceFrom }

    /// Bölümün azami yıldızı — bölüm seçme ekranı bunu üretmeden bilmek ister.
    static func maxStars(for id: Int) -> Int {
        if isBonus(id) { return 3 }
        return hasGrandStar(id) ? 4 : 3
    }

    /// Kampanyadan toplanabilecek toplam yıldız (ana menüdeki "x / y")
    static let totalStarsAvailable: Int = (1...count).reduce(0) { $0 + maxStars(for: $1) }

    /// İlk açılışta oynatılan "nasıl oynanır" antrenman bölümü (id 0).
    /// Haritada görünmez, ilerlemeye yazılmaz.
    static let tutorialID = 0

    static var tutorialLevel: Level {
        // 3 büyük, yavaş halka: alt (başlangıç) → orta (normal) → üst (YEŞİL hedef).
        // İki atlayış = "adım adım ilerle, halkaya dokunarak fırla" öğretilir.
        // Aralara sarı yıldızlar: uçuş hattı doğal olarak içlerinden geçer.
        var rings: [RingSpec] = []
        rings.append(RingSpec(center: CGPoint(x: 0.50, y: 0.15), radius: 0.105, orbitSpeed: 1.3, direction: 1))
        rings.append(RingSpec(center: CGPoint(x: 0.50, y: 0.42), radius: 0.105, orbitSpeed: 1.3, direction: -1))

        var gate = RingSpec(center: CGPoint(x: 0.50, y: 0.69), radius: 0.105, orbitSpeed: 1.3, direction: 1)
        gate.isGate = true
        rings.append(gate)

        // 2 yıldız koridorlarda (uçuş hattında), 1 yıldız orta halkanın
        // ÇEMBERİNDE — top dönerken üzerinden geçip toplar ("dönerken de
        // toplanır"ı öğretir). Merkeze koyma: oraya top asla ulaşamaz!
        let lumens = [
            LumenSpec(position: CGPoint(x: 0.50, y: 0.285)),
            LumenSpec(position: CGPoint(x: 0.50, y: 0.555)),
            LumenSpec(position: CGPoint(x: 0.605, y: 0.42))
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

    /// HUD geri sayımı göstermeli mi? `isTimed` tek başına yetmiyor:
    /// topla-bitir bölümlerinde süre baskısı BİLEREK kaldırılıyor (bkz.
    /// `normalLevel`), ama gösterge yine de çiziliyordu ve süresiz bir
    /// bölümde 0'da donmuş bir sayaç gibi duruyordu.
    static func hasTimer(_ id: Int) -> Bool { isTimed(id) && !isCollect(id) }

    /// Öğrenme bölgesi: ilk bölümlerde (ve öğreticide/bonusta) top ekrandan
    /// çıkarsa elenmek yerine fırlatıldığı halkaya geri döner. 11. normal
    /// bölümden itibaren kaçırmak = elenmek.
    static func isForgiving(_ id: Int) -> Bool {
        if id == tutorialID || isBonus(id) { return true }
        return normalIndex(id) < 11
    }

    /// "Devam et ya da düş" mekaniği: 15. normal bölümden itibaren, süreli
    /// olmayan normal bölümlerde her halkada oyalanma süresi vardır. Süre
    /// ilerledikçe kısalır (~3.4s → ~2.2s). Halka çevresindeki azalan yay
    /// oyuncuya kalan süreyi gösterir; süre biterse o deneme yanar.
    static func dwellLimit(for id: Int) -> TimeInterval? {
        guard !isBonus(id), !isTimed(id) else { return nil }
        let n = normalIndex(id)
        guard n >= 15 else { return nil }
        return max(2.2, 3.6 - 1.4 * Double(curveT(n)))
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

        // "Büyük yıldız" bölümü: 3 küçük lumen yerine 4 eden tek bir iri lumen.
        // Zincirin ortasındaki halka çiftinin arasına, uçuş hattının biraz
        // dışına konur — bedavaya gelmesin, sapmayı hak etsin.
        if hasGrandStar(id) {
            let mid = max(0, (rings.count - 1) / 2)
            let a = rings[mid].center, b = rings[mid + 1].center
            let off = rng.cg(in: 0.06...0.10) * (rng.cg(in: 0...1) < 0.5 ? 1 : -1)
            var p = CGPoint(x: (a.x + b.x) / 2 - (b.y - a.y) * off * 2,
                            y: (a.y + b.y) / 2 + (b.x - a.x) * off * 2)
            p.x = min(max(p.x, 0.08), 0.92)
            p.y = min(max(p.y, 0.06), 0.94)
            lumens = [LumenSpec(position: p, value: 4)]
        }

        // Süreli bölüm: halka başına tanınan süre ilerledikçe kısalır (~4s → ~2.6s)
        var timeLimit: TimeInterval? = nil
        if isTimed(id) {
            let t = Double(curveT(normalIndex(id)))
            timeLimit = (Double(rings.count) * (4.0 - 1.4 * t)).rounded()
        }

        // Topla-bitir bölümlerinde süre baskısı yok: asıl meydan okuma kapıyı
        // açmak için haritayı süpürmek. İkisi üst üste binerse ceza olur.
        let collect = isCollect(id)
        return Level(id: id,
                     kind: collect ? .collect : .normal,
                     rings: rings,
                     lumens: lumens,
                     timeLimit: collect ? nil : timeLimit,
                     dwellLimit: collect ? nil : dwellLimit(for: id))
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
        let t = curveT(n)                    // 0...1, 100. normal bölümde doyar
        // 100. normal bölümden SONRAKİ ikinci yükseliş. n <= 100 iken sıfırdır,
        // yani 1...120 arası bölümlere hiç dokunmaz.
        let t2 = min(max(CGFloat(n - curveNormalCount) / 25, 0), 1)
        switch n {
        case 1...2:   // öğretici — ama uyutmayan
            return Difficulty(ringCount: 5,
                              radiusRange: 0.088...0.105, speedRange: 1.9...2.3,
                              gapRange: 0.26...0.32,
                              hazardChance: 0, hazardSpan: 0...0, hazardsRotate: false,
                              movingChance: 0, movingAmplitude: 0)
        case 3...5:   // tehlikeler hemen başlar — artık dönen yaylarla
            return Difficulty(ringCount: 6,
                              radiusRange: 0.078...0.098, speedRange: 2.5...3.1,
                              gapRange: 0.25...0.33,
                              hazardChance: 0.52, hazardSpan: (.pi * 0.22)...(.pi * 0.38), hazardsRotate: true,
                              movingChance: 0.15, movingAmplitude: 0.07)
        case 6...10:
            return Difficulty(ringCount: 7,
                              radiusRange: 0.072...0.092, speedRange: 2.8...3.4,
                              gapRange: 0.24...0.34,
                              hazardChance: 0.62, hazardSpan: (.pi * 0.26)...(.pi * 0.46), hazardsRotate: true,
                              movingChance: 0.35, movingAmplitude: 0.09)
        case 11...18:
            return Difficulty(ringCount: 7,
                              radiusRange: 0.067...0.087, speedRange: 3.1...3.8,
                              gapRange: 0.23...0.34,
                              hazardChance: 0.7, hazardSpan: (.pi * 0.30)...(.pi * 0.52), hazardsRotate: true,
                              movingChance: 0.5, movingAmplitude: 0.11)
        case 19...28:
            return Difficulty(ringCount: 8,
                              radiusRange: 0.062...0.082, speedRange: 3.3...4.2,
                              gapRange: 0.22...0.35,
                              hazardChance: 0.8, hazardSpan: (.pi * 0.32)...(.pi * 0.56), hazardsRotate: true,
                              movingChance: 0.62, movingAmplitude: 0.12)
        default:      // 29+ — ustalık; halka sayısı, hız ve tehlikeler sona doğru sertleşir
            let ringCount = 9 + Int(max(0, t - 0.28) * 6.4)   // 9 → 13 arası
            return Difficulty(ringCount: min(max(ringCount, 9), 13) + Int((t2 * 2).rounded()),
                              radiusRange: (0.048 - 0.008 * t - 0.005 * t2)...(0.078 - 0.014 * t - 0.008 * t2),
                              speedRange: (3.5 + 1.0 * t + 0.5 * t2)...(4.3 + 1.8 * t + 0.9 * t2),
                              gapRange: 0.20...0.33,
                              hazardChance: min(0.85 + 0.13 * t, 0.97),
                              hazardSpan: (.pi * 0.34)...(.pi * (0.64 + 0.22 * t + 0.12 * t2)), hazardsRotate: true,
                              movingChance: min(min(0.7 + 0.28 * t, 0.92) + 0.05 * t2, 0.97),
                              movingAmplitude: 0.13 + 0.03 * t + 0.02 * t2)
        }
    }
}
