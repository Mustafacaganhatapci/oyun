import SpriteKit
import UIKit

enum GameEvent {
    case hop(combo: Int)
    case attached(hasHazard: Bool, isMoving: Bool)   // öğretici koçu bu bilgiyle tetiklenir
    case collect(total: Int)
    case gateUnlocked                  // topla-bitir: son lumen toplandı, kapı açıldı
    case fail
    case win(stars: Int)
    case bonusTick(remaining: Int)
    case timeTick(remaining: Int)      // süreli bölüm geri sayımı
    case endlessScore(Int)
    case endlessGameOver(score: Int)
}

/// Tek dokunuşla oynanan yörünge oyununun SpriteKit sahnesi.
/// Fizik motoru kullanılmaz; hareket deterministik matematiktir — his her cihazda aynıdır.
final class GameScene: SKScene {

    enum Mode: Equatable {
        case level(Int)
        case endless
    }

    // MARK: Ayar sabitleri
    private let flightSpeedFactor: CGFloat = 1.55   // ekran genişliği / sn
    private let orbRadius: CGFloat = 9
    private let collectDistance: CGFloat = 26
    private let maxFlightTime: TimeInterval = 4.0
    private let respawnDelay: TimeInterval = 0.55

    // MARK: Durum
    private enum OrbState {
        case attached(ring: Int, angle: CGFloat, direction: CGFloat)
        case flying(velocity: CGVector)
        case dead
        case won
    }

    let mode: Mode
    private let theme: Theme
    private let orbStyle: OrbStyle
    private let orbPhoto: UIImage?
    var onEvent: ((GameEvent) -> Void)?

    /// Öğretici dondurması: true iken simülasyon ve dokunuş girdisi durur;
    /// SwiftUI tarafındaki koç kaplaması açıklamayı gösterir.
    var coachFrozen = false

    private var level: Level?
    private(set) var lumenTotal = 0
    private var ringSpecs: [RingSpec] = []
    private var ringNodes: [SKNode] = []
    private var ringCircles: [SKShapeNode] = []
    private var hazardNodes: [SKNode?] = []
    private var lumenNodes: [SKShapeNode] = []
    private var lumenCollected: [Bool] = []
    private var lumenValues: [Int] = []          // her lumenin yıldız değeri (normal 1, büyük 4)
    private var lumenSpecs: [LumenSpec] = []     // topla-bitir bölümünde yeniden kurmak için
    private var gateNeedsAllLumens = false
    private var restartsOnDeath = false
    private weak var gateDashed: SKShapeNode?

    private var orbState: OrbState = .dead
    private var orbNode: SKNode!
    private var orbCore: SKShapeNode?
    private var trailEmitter: SKEmitterNode!
    private var lastRing = 0
    private var exitedLastRing = true
    private var flightTime: TimeInterval = 0
    private var elapsed: TimeInterval = 0
    private var lastUpdate: TimeInterval = 0
    private var combo = 0

    // Ölüm/yeniden doğma — SKAction'a değil, update döngüsüne bağlıdır
    // ("kaybedince bazen başlamıyor" hatasının kesin çözümü)
    private var deadSince: TimeInterval?
    private var endlessOverSent = false
    private var finished = false

    // Bonus turu
    private var isBonus = false
    private var bonusDeadline: TimeInterval = 0
    private var lastBonusTick = Int.max

    // Süreli bölüm — süre deneme başınadır; ölünce yeniden doğuşta tazelenir
    private var timedDeadline: TimeInterval?
    private var lastTimeTickSent = Int.max

    // Bağışlayıcı sınırlar: öğrenme bölümlerinde ekran dışına çıkan küre
    // elenmez, fırlatıldığı halkaya geri döner. İleri bölümlerde kaçırmak elenmektir.
    private var forgivingBounds = false

    // "Devam et ya da düş": ileri bölümlerde bir halkada fazla oyalanınca ölürsün.
    // Halka çevresindeki azalan yay kalan süreyi gösterir; her atlayışta sıfırlanır.
    private var dwellLimit: TimeInterval?
    private var dwellStart: TimeInterval = 0
    private var dwellArc: SKShapeNode?

    // Antrenman bölümü görselleri: yazı yerine göstererek öğretir
    private var isTutorial: Bool { mode == .level(LevelLibrary.tutorialID) }
    private var aimLine: SKShapeNode?
    private var tapHint: SKNode?

    // Sonsuz mod
    private var endlessScore = 0
    private var cameraNode: SKCameraNode?
    private var endlessRNG = SplitMix64(seed: UInt64(Date().timeIntervalSince1970 * 1000))

    // Oynanabilir alan (HUD boşlukları)
    private var playRect: CGRect {
        CGRect(x: 0, y: 40, width: size.width, height: size.height - 150)
    }

    // MARK: Kurulum

    init(size: CGSize, mode: Mode, theme: Theme, orbStyle: OrbStyle, orbPhoto: UIImage? = nil) {
        self.mode = mode
        self.theme = theme
        self.orbStyle = orbStyle
        self.orbPhoto = orbPhoto
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = theme.bgBottom.uiColor
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) kullanılmaz") }

    override func didMove(to view: SKView) {
        setupBackground()
        setupOrb()
        switch mode {
        case .level(let id):
            let lvl = LevelLibrary.level(id)
            level = lvl
            isBonus = lvl.kind == .bonus
            dwellLimit = lvl.dwellLimit
            forgivingBounds = LevelLibrary.isForgiving(id)
            gateNeedsAllLumens = lvl.gateNeedsAllLumens
            restartsOnDeath = lvl.restartsOnDeath
            lumenSpecs = lvl.lumens
            if isBonus { bonusDeadline = lvl.bonusDuration }
            buildRings(lvl.rings)
            buildLumens(lvl.lumens)
            respawn(animated: false)
            if isTutorial { setupTutorialVisuals() }
        case .endless:
            let cam = SKCameraNode()
            cameraNode = cam
            cam.position = CGPoint(x: size.width / 2, y: size.height / 2)
            addChild(cam)
            camera = cam
            if let stars = childNode(withName: "stars") {
                stars.removeFromParent()
                stars.position = .zero
                cam.addChild(stars)
            }
            seedEndless()
            respawn(animated: false)
        }
    }

    private func setupBackground() {
        let bg = SKSpriteNode(texture: Self.gradientTexture(size: size,
                                                            top: theme.bgTop.uiColor,
                                                            bottom: theme.bgBottom.uiColor))
        bg.anchorPoint = .zero
        bg.position = .zero
        bg.zPosition = -100
        bg.name = "bg"
        addChild(bg)

        let stars = SKEmitterNode()
        stars.particleTexture = Self.glowTexture
        stars.particleBirthRate = 2.5
        stars.particleLifetime = 14
        stars.particleLifetimeRange = 6
        stars.particlePositionRange = CGVector(dx: size.width, dy: size.height)
        stars.position = CGPoint(x: size.width / 2, y: size.height / 2)
        stars.particleAlpha = 0.25
        stars.particleAlphaRange = 0.15
        stars.particleScale = 0.05
        stars.particleScaleRange = 0.04
        stars.particleSpeed = 6
        stars.emissionAngle = .pi / 2
        stars.particleColor = theme.ring.uiColor
        stars.particleColorBlendFactor = 1
        stars.particleBlendMode = .add
        stars.zPosition = -90
        stars.name = "stars"
        stars.advanceSimulationTime(15)
        addChild(stars)
    }

    // MARK: Küre — seçilen stile göre kurulur

    private func setupOrb() {
        let container = SKNode()
        container.zPosition = 20

        let glow = SKSpriteNode(texture: Self.glowTexture)
        glow.size = CGSize(width: orbRadius * 7, height: orbRadius * 7)
        glow.color = theme.orb.uiColor
        glow.colorBlendFactor = 1
        glow.alpha = 0.55
        glow.blendMode = .add
        container.addChild(glow)

        switch orbStyle.kind {
        case .classic:
            let core = SKShapeNode(circleOfRadius: orbRadius)
            core.fillColor = theme.orb.uiColor
            core.strokeColor = .clear
            container.addChild(core)
            orbCore = core

        case .star:
            let core = SKShapeNode(path: Self.starPath(radius: orbRadius * 1.5))
            core.fillColor = theme.lumen.uiColor
            core.strokeColor = .clear
            core.run(.repeatForever(.rotate(byAngle: .pi * 2, duration: 3.5)))
            container.addChild(core)
            orbCore = core

        case .crystal:
            let core = SKShapeNode(path: Self.polygonPath(sides: 6, radius: orbRadius * 1.35))
            core.fillColor = theme.gate.uiColor.withAlphaComponent(0.85)
            core.strokeColor = .white
            core.lineWidth = 1.5
            core.run(.repeatForever(.rotate(byAngle: .pi * 2, duration: 6)))
            container.addChild(core)
            orbCore = core

        case .comet:
            let core = SKShapeNode(circleOfRadius: orbRadius * 0.85)
            core.fillColor = .white
            core.strokeColor = .clear
            container.addChild(core)
            orbCore = core

        case .rainbow:
            let core = SKShapeNode(circleOfRadius: orbRadius)
            core.fillColor = .white   // her karede update() renklendirir
            core.strokeColor = .clear
            container.addChild(core)
            orbCore = core

        case .ring:
            let core = SKShapeNode(circleOfRadius: orbRadius * 1.15)
            core.fillColor = .clear
            core.strokeColor = theme.orb.uiColor
            core.lineWidth = 3.5
            core.glowWidth = 3
            container.addChild(core)
            orbCore = core

        case .diamond:
            let core = SKShapeNode(path: Self.polygonPath(sides: 4, radius: orbRadius * 1.4))
            core.fillColor = theme.accent.uiColor
            core.strokeColor = .white
            core.lineWidth = 1.5
            core.run(.repeatForever(.rotate(byAngle: .pi * 2, duration: 4.5)))
            container.addChild(core)
            orbCore = core

        case .flame:
            let core = SKShapeNode(circleOfRadius: orbRadius)
            core.fillColor = theme.hazard.uiColor
            core.strokeColor = .clear
            core.run(.repeatForever(.sequence([
                .scale(to: 1.2, duration: 0.35), .scale(to: 0.85, duration: 0.35)
            ])))
            container.addChild(core)
            orbCore = core

        case .pixel:
            let s = orbRadius * 1.7
            let core = SKShapeNode(rect: CGRect(x: -s/2, y: -s/2, width: s, height: s), cornerRadius: 1)
            core.fillColor = theme.gate.uiColor
            core.strokeColor = .white
            core.lineWidth = 1
            container.addChild(core)
            orbCore = core

        case .bubble:
            let core = SKShapeNode(circleOfRadius: orbRadius * 1.1)
            core.fillColor = UIColor.white.withAlphaComponent(0.32)
            core.strokeColor = UIColor.white.withAlphaComponent(0.8)
            core.lineWidth = 1.5
            core.glowWidth = 5
            core.run(.repeatForever(.sequence([
                .group([.scaleX(to: 1.1, y: 0.92, duration: 1.1), .fadeAlpha(to: 0.85, duration: 1.1)]),
                .group([.scaleX(to: 0.92, y: 1.1, duration: 1.1), .fadeAlpha(to: 1.0, duration: 1.1)])
            ])))
            container.addChild(core)
            orbCore = core

        case .heart:
            let core = SKShapeNode(path: Self.heartPath(radius: orbRadius * 1.3))
            core.fillColor = .systemPink
            core.strokeColor = .clear
            core.run(.repeatForever(.sequence([
                .scale(to: 1.18, duration: 0.12),
                .scale(to: 1.0, duration: 0.16),
                .scale(to: 1.12, duration: 0.10),
                .scale(to: 1.0, duration: 0.18),
                .wait(forDuration: 0.55)
            ])))
            container.addChild(core)
            orbCore = core

        case .firefly:
            let body = SKShapeNode(circleOfRadius: orbRadius * 0.75)
            body.fillColor = UIColor(red: 0.16, green: 0.12, blue: 0.08, alpha: 1)
            body.strokeColor = .clear
            container.addChild(body)
            let tail = SKShapeNode(circleOfRadius: orbRadius * 0.45)
            tail.fillColor = UIColor(red: 0.75, green: 1.0, blue: 0.4, alpha: 1)
            tail.strokeColor = .clear
            tail.glowWidth = 10
            tail.position = CGPoint(x: 0, y: -orbRadius * 0.65)
            tail.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.15, duration: 0.5),
                .wait(forDuration: 0.25),
                .fadeAlpha(to: 1.0, duration: 0.35),
                .wait(forDuration: 0.9)
            ])))
            container.addChild(tail)
            orbCore = body

        case .cloud:
            let puffColor = UIColor.white.withAlphaComponent(0.95)
            let puff1 = SKShapeNode(circleOfRadius: orbRadius * 0.85)
            puff1.fillColor = puffColor; puff1.strokeColor = .clear
            puff1.position = CGPoint(x: -orbRadius * 0.55, y: -orbRadius * 0.15)
            let puff2 = SKShapeNode(circleOfRadius: orbRadius * 1.05)
            puff2.fillColor = puffColor; puff2.strokeColor = .clear
            puff2.position = CGPoint(x: 0, y: orbRadius * 0.1)
            let puff3 = SKShapeNode(circleOfRadius: orbRadius * 0.8)
            puff3.fillColor = puffColor; puff3.strokeColor = .clear
            puff3.position = CGPoint(x: orbRadius * 0.6, y: -orbRadius * 0.1)
            for p in [puff1, puff2, puff3] { container.addChild(p) }
            puff2.run(.repeatForever(.sequence([
                .moveBy(x: 0, y: 3, duration: 1.4),
                .moveBy(x: 0, y: -3, duration: 1.4)
            ])))
            orbCore = puff2

        case .photo:
            if let photo = orbPhoto {
                let crop = SKCropNode()
                let mask = SKShapeNode(circleOfRadius: orbRadius * 1.6)
                mask.fillColor = .white
                mask.strokeColor = .clear
                crop.maskNode = mask
                let sprite = SKSpriteNode(texture: SKTexture(image: photo))
                sprite.size = CGSize(width: orbRadius * 3.2, height: orbRadius * 3.2)
                crop.addChild(sprite)
                container.addChild(crop)
                let ring = SKShapeNode(circleOfRadius: orbRadius * 1.6)
                ring.strokeColor = theme.orb.uiColor
                ring.lineWidth = 2
                ring.glowWidth = 4
                container.addChild(ring)
            } else {
                let core = SKShapeNode(circleOfRadius: orbRadius)
                core.fillColor = theme.orb.uiColor
                core.strokeColor = .clear
                container.addChild(core)
                orbCore = core
            }
        }

        let trail = SKEmitterNode()
        trail.particleTexture = Self.glowTexture
        trail.particleBirthRate = orbStyle.kind == .comet ? 260 : 110
        trail.particleLifetime = orbStyle.kind == .comet ? 0.9 : 0.45
        trail.particleAlpha = 0.5
        trail.particleAlphaSpeed = orbStyle.kind == .comet ? -0.55 : -1.1
        trail.particleScale = orbStyle.kind == .comet ? 0.3 : 0.24
        trail.particleScaleSpeed = -0.45
        trail.particleColor = theme.accent.uiColor
        trail.particleColorBlendFactor = 1
        trail.particleBlendMode = .add
        trail.zPosition = -1
        container.addChild(trail)
        trailEmitter = trail

        addChild(container)
        orbNode = container
        trail.targetNode = self
    }

    // MARK: Halkalar

    private func buildRings(_ specs: [RingSpec]) {
        ringSpecs = specs
        for (i, spec) in specs.enumerated() {
            addRingNode(spec, index: i)
        }
    }

    @discardableResult
    private func addRingNode(_ spec: RingSpec, index: Int) -> SKNode {
        let r = spec.radius * size.width
        let container = SKNode()
        container.position = scenePoint(spec.center)
        container.zPosition = 10

        // Antrenman bölümünde hedef halka bariz YEŞİL — "buraya atacaksın"
        let gateColor = isTutorial ? UIColor.systemGreen : theme.gate.uiColor

        // Topla-bitir bölümünde kapı, her şey toplanana kadar sönük durur —
        // "buraya gelmek yetmiyor" bilgisi renkten okunsun
        let locked = spec.isGate && gateNeedsAllLumens

        let circle = SKShapeNode(circleOfRadius: r)
        circle.strokeColor = spec.isGate ? gateColor : theme.ring.uiColor
        circle.lineWidth = 3
        circle.glowWidth = spec.isGate ? 10 : 6
        circle.alpha = locked ? 0.35 : 0.9
        circle.fillColor = .clear
        container.addChild(circle)

        if spec.isGate {
            let dashed = SKShapeNode(path: CGPath(ellipseIn: CGRect(x: -r - 8, y: -r - 8,
                                                                    width: (r + 8) * 2, height: (r + 8) * 2),
                                                  transform: nil).copy(dashingWithPhase: 0, lengths: [8, 10]))
            dashed.strokeColor = gateColor
            dashed.lineWidth = 2
            dashed.alpha = locked ? 0.25 : 0.7
            dashed.run(.repeatForever(.rotate(byAngle: .pi * 2, duration: locked ? 26 : 14)))
            container.addChild(dashed)
            if locked { gateDashed = dashed }

            if isTutorial {
                // Hedef yeşil halka belirgin nefes alsın — göz oraya gitsin
                circle.run(.repeatForever(.sequence([
                    .group([.scale(to: 1.10, duration: 0.7), .fadeAlpha(to: 1.0, duration: 0.7)]),
                    .group([.scale(to: 0.98, duration: 0.7), .fadeAlpha(to: 0.75, duration: 0.7)])
                ])))
            }
        }

        if !(spec.isGate && isTutorial) {   // öğretici kapısının kendi nabzı var
            circle.run(.repeatForever(.sequence([
                .scale(to: 1.03, duration: 1.6),
                .scale(to: 0.99, duration: 1.6)
            ])))
        }

        var hazardNode: SKNode? = nil
        if !spec.hazardArcs.isEmpty {
            let hz = SKNode()
            for arc in spec.hazardArcs {
                let path = CGMutablePath()
                path.addArc(center: .zero, radius: r,
                            startAngle: arc.lowerBound, endAngle: arc.upperBound, clockwise: false)
                let shape = SKShapeNode(path: path)
                shape.strokeColor = theme.hazard.uiColor
                shape.lineWidth = 7
                shape.lineCap = .round
                shape.glowWidth = 6
                hz.addChild(shape)
            }
            container.addChild(hz)
            hazardNode = hz
        }

        addChild(container)
        if index < ringNodes.count {
            ringNodes[index] = container
            ringCircles[index] = circle
            hazardNodes[index] = hazardNode
        } else {
            ringNodes.append(container)
            ringCircles.append(circle)
            hazardNodes.append(hazardNode)
        }
        return container
    }

    // MARK: Antrenman görselleri — yazı yok, göstererek öğretir

    private func setupTutorialVisuals() {
        // Nişan çizgisi: küre O AN fırlatılırsa gideceği yönü canlı gösterir.
        // Çizgi yeşil halkayı kestiği anda dokunmak = doğru zamanlama.
        let length = size.width * 0.5
        let path = CGMutablePath()
        path.move(to: .zero)
        path.addLine(to: CGPoint(x: length, y: 0))
        let line = SKShapeNode(path: path.copy(dashingWithPhase: 0, lengths: [10, 9]))
        line.strokeColor = UIColor.white.withAlphaComponent(0.7)
        line.lineWidth = 3
        line.lineCap = .round
        line.glowWidth = 2
        line.zPosition = 30
        addChild(line)
        aimLine = line

        // Dokunuş ipucu: nabız gibi genişleyen halka + el simgesi.
        // Halkaların YANINA konur (üstlerine değil) — "halkaya bas" izlenimi
        // vermesin, "ekranın herhangi bir yerine dokun" hissi versin.
        let hint = SKNode()
        hint.position = CGPoint(x: size.width * 0.80, y: size.height * 0.32)
        hint.zPosition = 40

        if let img = UIImage(systemName: "hand.tap.fill",
                             withConfiguration: UIImage.SymbolConfiguration(pointSize: 36, weight: .semibold))?
            .withTintColor(.white, renderingMode: .alwaysOriginal) {
            let sprite = SKSpriteNode(texture: SKTexture(image: img))
            sprite.run(.repeatForever(.sequence([
                .scale(to: 0.85, duration: 0.35),
                .scale(to: 1.0, duration: 0.55)
            ])))
            hint.addChild(sprite)
        }
        let ripple = SKShapeNode(circleOfRadius: 34)
        ripple.strokeColor = UIColor.white.withAlphaComponent(0.8)
        ripple.lineWidth = 2
        ripple.fillColor = .clear
        ripple.run(.repeatForever(.sequence([
            .group([.scale(to: 2.0, duration: 1.1), .fadeAlpha(to: 0, duration: 1.1)]),
            .scale(to: 1, duration: 0),
            .fadeAlpha(to: 0.8, duration: 0)
        ])))
        hint.addChild(ripple)
        addChild(hint)
        tapHint = hint
    }

    /// İlk fırlatmadan sonra dokunuş ipucu kaybolur (görevini yaptı)
    private func dismissTapHint() {
        guard let hint = tapHint else { return }
        tapHint = nil
        hint.run(.sequence([.fadeOut(withDuration: 0.3), .removeFromParent()]))
    }

    private func buildLumens(_ specs: [LumenSpec]) {
        lumenTotal = specs.count
        lumenValues = specs.map { $0.value }
        for spec in specs {
            // Büyük yıldız 4 eder; bunu tek bakışta anlatması için hem iri
            // hem de daire yerine beş köşeli yıldız olarak çizilir.
            let node: SKShapeNode
            if spec.isGrand {
                node = SKShapeNode(path: Self.starPath(outer: 17, inner: 7.4))
                node.glowWidth = 14
            } else {
                node = SKShapeNode(circleOfRadius: 7)
                node.glowWidth = 8
            }
            node.fillColor = theme.lumen.uiColor
            node.strokeColor = .clear
            node.position = scenePoint(spec.position)
            node.zPosition = 15
            let beat = spec.isGrand ? 0.55 : 0.8
            node.run(.repeatForever(.sequence([
                .group([.scale(to: 1.25, duration: beat), .fadeAlpha(to: 1.0, duration: beat)]),
                .group([.scale(to: 0.9, duration: beat), .fadeAlpha(to: 0.75, duration: beat)])
            ])))
            if spec.isGrand {
                node.run(.repeatForever(.rotate(byAngle: .pi * 2, duration: 6)))
            }
            addChild(node)
            lumenNodes.append(node)
            lumenCollected.append(false)
        }
    }

    /// Beş köşeli yıldız yolu — büyük lumen için
    private static func starPath(outer: CGFloat, inner: CGFloat) -> CGPath {
        let path = CGMutablePath()
        for i in 0..<10 {
            let r = i % 2 == 0 ? outer : inner
            let a = -CGFloat.pi / 2 + CGFloat(i) * .pi / 5
            let p = CGPoint(x: cos(a) * r, y: sin(a) * r)
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.closeSubpath()
        return path
    }

    // MARK: Koordinatlar

    private func scenePoint(_ p: CGPoint) -> CGPoint {
        CGPoint(x: p.x * playRect.width + playRect.minX,
                y: p.y * playRect.height + playRect.minY)
    }

    private func ringCenter(_ i: Int, at t: TimeInterval) -> CGPoint {
        let spec = ringSpecs[i]
        var c = scenePoint(spec.center)
        if let m = spec.moving {
            let offset = sin(CGFloat(t) * 2 * .pi / m.period + m.phase) * m.amplitude * size.width
            switch m.axis {
            case .horizontal: c.x += offset
            case .vertical: c.y += offset
            }
        }
        return c
    }

    private func ringRadius(_ i: Int) -> CGFloat {
        ringSpecs[i].radius * size.width
    }

    // MARK: Fırlatma

    /// Küreyi halkadan teğet yönünde fırlatır. Hem dokunuşla hem de oyalanma
    /// süresi dolduğunda (otomatik fırlatma) buradan geçilir.
    private func launch(from ring: Int, angle: CGFloat, direction: CGFloat) {
        let c = ringCenter(ring, at: elapsed)
        let r = ringRadius(ring)
        let pos = CGPoint(x: c.x + cos(angle) * r, y: c.y + sin(angle) * r)
        let tangent = CGVector(dx: -sin(angle) * direction, dy: cos(angle) * direction)
        let speed = flightSpeedFactor * size.width
        orbNode.position = pos
        orbState = .flying(velocity: CGVector(dx: tangent.dx * speed, dy: tangent.dy * speed))
        lastRing = ring
        exitedLastRing = false
        flightTime = 0
        ringCircles[ring].run(.sequence([.scale(to: 0.92, duration: 0.08), .scale(to: 1.0, duration: 0.18)]))
    }

    // MARK: Girdi — tek dokunuş, tüm ekran

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !coachFrozen else { return }
        switch orbState {
        case .attached(let ring, let angle, let direction):
            dismissTapHint()
            launch(from: ring, angle: angle, direction: direction)

        case .dead:
            // Güvenlik ağı: yeniden doğma herhangi bir nedenle gecikirse
            // dokunuş anında canlandırır — oyun asla "takılı" kalmaz
            if let since = deadSince, elapsed - since > 0.9, mode != .endless {
                restartsOnDeath ? restartLevel() : respawn(animated: true)
            }

        case .flying, .won:
            break
        }
    }

    // MARK: Ana döngü

    override func update(_ currentTime: TimeInterval) {
        var dt = lastUpdate == 0 ? 1.0 / 60.0 : currentTime - lastUpdate
        lastUpdate = currentTime
        dt = min(dt, 1.0 / 30.0)

        // Öğretici dondurması — sahne olduğu yerde bekler; `elapsed` ilerlemediği
        // için süreler kaymaz, tehlikeler ve geri sayımlar donuk kalır
        if coachFrozen { return }

        elapsed += dt

        updateRings()

        // Gökkuşağı küre: rengi sürekli akar
        if orbStyle.kind == .rainbow, let core = orbCore {
            let hue = CGFloat(elapsed.truncatingRemainder(dividingBy: 4) / 4)
            core.fillColor = UIColor(hue: hue, saturation: 0.7, brightness: 1, alpha: 1)
            trailEmitter.particleColor = core.fillColor
        }

        // Bonus geri sayımı (ölüyken de akmaya devam eder)
        if isBonus, !finished {
            let remaining = Int(ceil(bonusDeadline - elapsed))
            if remaining != lastBonusTick, remaining >= 0 {
                lastBonusTick = remaining
                onEvent?(.bonusTick(remaining: remaining))
            }
            if elapsed >= bonusDeadline {
                finishBonus()
            }
        }

        // Süreli bölüm geri sayımı — yalnızca küre oyundayken işler
        if let deadline = timedDeadline, !finished {
            let active: Bool
            switch orbState {
            case .attached, .flying: active = true
            default: active = false
            }
            if active {
                let remaining = Int(ceil(deadline - elapsed))
                if remaining != lastTimeTickSent, remaining >= 0 {
                    lastTimeTickSent = remaining
                    onEvent?(.timeTick(remaining: remaining))
                }
                if elapsed >= deadline { fail() }   // süre doldu — deneme yandı
            }
        }

        switch orbState {
        case .attached(let ring, var angle, let direction):
            let spec = ringSpecs[ring]
            angle += spec.orbitSpeed * direction * CGFloat(dt)
            orbState = .attached(ring: ring, angle: angle, direction: direction)
            let c = ringCenter(ring, at: elapsed)
            let r = ringRadius(ring)
            orbNode.position = CGPoint(x: c.x + cos(angle) * r, y: c.y + sin(angle) * r)
            // Antrenman: nişan çizgisi kürenin fırlatma yönünü canlı takip eder
            if let aim = aimLine {
                aim.isHidden = false
                aim.position = orbNode.position
                aim.zRotation = atan2(cos(angle) * direction, -sin(angle) * direction)
            }
            checkHazard(ring: ring, angle: angle)
            checkLumens()
            // "Devam et ya da düş" — bu halkada fazla oyalanınca süre dolar
            // Süre dolunca ceza yok: küre kendiliğinden fırlar. Yayın son
            // üçte biri kırmızıya döndüğünde oyuncu bunun geldiğini görür ve
            // isterse daha iyi bir açıda kendi fırlatır.
            if let limit = dwellLimit, !spec.isGate {
                let frac = max(0, 1 - CGFloat((elapsed - dwellStart) / limit))
                updateDwellArc(ring: ring, fraction: frac)
                if frac <= 0 {
                    dwellArc?.isHidden = true
                    dismissTapHint()
                    launch(from: ring, angle: angle, direction: direction)
                }
            } else {
                dwellArc?.isHidden = true
            }

        case .flying(let v):
            aimLine?.isHidden = true
            dwellArc?.isHidden = true
            flightTime += dt
            orbNode.position = CGPoint(x: orbNode.position.x + v.dx * CGFloat(dt),
                                       y: orbNode.position.y + v.dy * CGFloat(dt))
            checkCapture(velocity: v)
            checkLumens()
            checkBounds()
            if flightTime > maxFlightTime { missedShot() }

        case .dead:
            aimLine?.isHidden = true
            dwellArc?.isHidden = true
            // Yeniden doğma zamanlaması SKAction yerine burada işlenir:
            // sahne duraklatılsa/aksiyon kaybolsa bile bu yol her zaman çalışır
            if let since = deadSince, elapsed - since >= respawnDelay {
                if case .endless = mode {
                    if !endlessOverSent {
                        endlessOverSent = true
                        onEvent?(.endlessGameOver(score: endlessScore))
                    }
                } else if !finished {
                    restartsOnDeath ? restartLevel() : respawn(animated: true)
                }
            }

        case .won:
            aimLine?.isHidden = true
            dwellArc?.isHidden = true
        }

        if case .endless = mode { updateEndlessCamera(dt: dt) }
    }

    private func updateRings() {
        for i in ringSpecs.indices {
            ringNodes[i].position = ringCenter(i, at: elapsed)
            if let hz = hazardNodes[i], ringSpecs[i].hazardRotationSpeed != 0 {
                hz.zRotation = CGFloat(elapsed) * ringSpecs[i].hazardRotationSpeed
            }
        }
    }

    // MARK: Yakalama, tehlike, ödül

    private func checkCapture(velocity v: CGVector) {
        for i in ringSpecs.indices {
            let c = ringCenter(i, at: elapsed)
            let dx = orbNode.position.x - c.x
            let dy = orbNode.position.y - c.y
            let dist = sqrt(dx * dx + dy * dy)
            let r = ringRadius(i)

            if i == lastRing && !exitedLastRing {
                if dist > r + orbRadius * 2 { exitedLastRing = true }
                continue
            }
            guard dist <= r else { continue }

            let angle = atan2(dy, dx)
            // Kırmızı yayın üstüne konmak da ölümdür — kırmızıya temas HER ZAMAN öldürür
            if hazardContains(ring: i, angle: angle) {
                fail()
                return
            }
            let cross = dx * v.dy - dy * v.dx
            let direction: CGFloat = cross >= 0 ? 1 : -1
            orbState = .attached(ring: i, angle: angle, direction: direction)
            dwellStart = elapsed
            combo += 1

            ringCircles[i].run(.sequence([.scale(to: 1.15, duration: 0.1), .scale(to: 1.0, duration: 0.25)]))
            burst(at: orbNode.position, color: theme.accent.uiColor, count: 10)

            if ringSpecs[i].isGate, gateOpen {
                win()
            } else {
                onEvent?(.hop(combo: combo))
                onEvent?(.attached(hasHazard: !ringSpecs[i].hazardArcs.isEmpty,
                                   isMoving: ringSpecs[i].moving != nil))
                if case .endless = mode {
                    if i > endlessScore {
                        endlessScore = i
                        onEvent?(.endlessScore(endlessScore))
                        extendEndlessIfNeeded(reached: i)
                    }
                }
            }
            return
        }
    }

    /// Kırmızıya temas her zaman öldürür — bağışıklık/koruma süresi yoktur.
    private func checkHazard(ring: Int, angle: CGFloat) {
        if hazardContains(ring: ring, angle: angle) { fail() }
    }

    /// Verilen açı, halkanın kırmızı yaylarından birinin üstünde mi?
    private func hazardContains(ring: Int, angle: CGFloat) -> Bool {
        let spec = ringSpecs[ring]
        guard !spec.hazardArcs.isEmpty else { return false }
        let rot = CGFloat(elapsed) * spec.hazardRotationSpeed
        for arc in spec.hazardArcs {
            var rel = (angle - rot - arc.lowerBound).truncatingRemainder(dividingBy: 2 * .pi)
            if rel < 0 { rel += 2 * .pi }
            if rel <= (arc.upperBound - arc.lowerBound) { return true }
        }
        return false
    }

    private func checkLumens() {
        for i in lumenNodes.indices where !lumenCollected[i] {
            let n = lumenNodes[i]
            let dx = n.position.x - orbNode.position.x
            let dy = n.position.y - orbNode.position.y
            // Büyük yıldız daha iri çizildiği için toplama yarıçapı da geniş
            let reach = lumenValues[i] > 1 ? collectDistance * 1.3 : collectDistance
            if sqrt(dx * dx + dy * dy) < reach {
                lumenCollected[i] = true
                burst(at: n.position, color: theme.lumen.uiColor, count: lumenValues[i] > 1 ? 26 : 16)
                n.run(.sequence([.group([.scale(to: 1.8, duration: 0.18), .fadeOut(withDuration: 0.18)]),
                                 .removeFromParent()]))
                onEvent?(.collect(total: collectedStars))
                if isBonus, lumenCollected.allSatisfy({ $0 }) {
                    finishBonus()   // hepsi toplandıysa erken bitir
                }
                // Topla-bitir: son lumen kapıyı açar. Küre zaten kapının
                // üstünde dönüyorsa bölüm o anda biter; değilse kapı yanıp
                // söner ve oyuncu oraya dönebilir.
                if gateNeedsAllLumens, gateOpen {
                    if case .attached(let ring, _, _) = orbState, ringSpecs[ring].isGate {
                        win()
                    } else {
                        flashGateUnlocked()
                    }
                }
            }
        }
    }

    /// Son lumen toplandı: sönük duran kapı canlanır ve bir kez atar.
    private func flashGateUnlocked() {
        guard let gateIndex = ringSpecs.firstIndex(where: { $0.isGate }) else { return }
        let circle = ringCircles[gateIndex]
        circle.removeAllActions()
        circle.run(.group([
            .fadeAlpha(to: 0.95, duration: 0.2),
            .sequence([.scale(to: 1.3, duration: 0.22), .scale(to: 1.0, duration: 0.28)])
        ]))
        circle.run(.repeatForever(.sequence([
            .group([.scale(to: 1.10, duration: 0.7), .fadeAlpha(to: 1.0, duration: 0.7)]),
            .group([.scale(to: 0.98, duration: 0.7), .fadeAlpha(to: 0.8, duration: 0.7)])
        ])))
        gateDashed?.run(.fadeAlpha(to: 0.75, duration: 0.25))
        burst(at: ringCenter(gateIndex, at: elapsed), color: theme.gate.uiColor, count: 22)
        onEvent?(.gateUnlocked)
    }

    /// Topla-bitir bölümünde ölüm: bölüm sıfırdan kurulur, toplanan bütün
    /// lumenler geri gelir. Yarım kalmış bir turu kurtarmak yok — baştan.
    private func restartLevel() {
        deadSince = nil
        combo = 0
        finished = false
        orbNode.isHidden = false

        for node in lumenNodes { node.removeFromParent() }
        lumenNodes.removeAll()
        lumenCollected.removeAll()
        lumenValues.removeAll()
        buildLumens(lumenSpecs)

        // Kapı yeniden kilitlenir
        if let gateIndex = ringSpecs.firstIndex(where: { $0.isGate }) {
            let circle = ringCircles[gateIndex]
            circle.removeAllActions()
            circle.setScale(1.0)
            circle.alpha = 0.35
            circle.run(.repeatForever(.sequence([
                .scale(to: 1.03, duration: 1.6),
                .scale(to: 0.99, duration: 1.6)
            ])))
            gateDashed?.run(.fadeAlpha(to: 0.25, duration: 0.2))
        }

        onEvent?(.collect(total: 0))
        respawn(animated: true)
    }

    private func checkBounds() {
        var frame = CGRect(origin: .zero, size: size).insetBy(dx: -60, dy: -60)
        if let cam = cameraNode {
            frame = CGRect(x: -60, y: cam.position.y - size.height / 2 - 80,
                           width: size.width + 120, height: size.height + 160)
        }
        if !frame.contains(orbNode.position) { missedShot() }
    }

    /// Kaçırılan atış (ekran dışı / boşa uçuş): öğrenme bölümlerinde küre
    /// fırlatıldığı halkaya geri döner — ceza yok. İleri bölümlerde elenirsin.
    private func missedShot() {
        forgivingBounds ? softReturn() : fail()
    }

    /// Küreyi son fırlatıldığı halkaya nazikçe geri oturtur (bağışlayıcı bölümler)
    private func softReturn() {
        guard lastRing < ringSpecs.count else { fail(); return }
        combo = 0
        let c = ringCenter(lastRing, at: elapsed)
        let r = ringRadius(lastRing)
        // Kürenin kaçtığı yöne bakan açıdan geri oturt; orası kırmızıysa
        // güvenli bir açıya kaydır
        var angle = atan2(orbNode.position.y - c.y, orbNode.position.x - c.x)
        var tries = 0
        while hazardContains(ring: lastRing, angle: angle), tries < 21 {
            angle += 0.3
            tries += 1
        }
        orbState = .attached(ring: lastRing, angle: angle, direction: ringSpecs[lastRing].direction)
        dwellStart = elapsed
        exitedLastRing = true
        orbNode.position = CGPoint(x: c.x + cos(angle) * r, y: c.y + sin(angle) * r)
        orbNode.setScale(0.2)
        orbNode.run(.scale(to: 1.0, duration: 0.25))
        ringCircles[lastRing].run(.sequence([.scale(to: 1.12, duration: 0.12), .scale(to: 1.0, duration: 0.25)]))
    }

    /// Sonsuz modda ödüllü reklam izlendikten sonra çağrılır: skor korunur,
    /// küre son tutunduğu halkaya güvenli bir açıdan geri oturur.
    ///
    /// Başarılı olduysa true döner. Arayüz bitiş ekranını yalnızca bu true
    /// ise kapatır — aksi hâlde oyuncu ne turuna dönebildiği ne de bir düğme
    /// görebildiği boş bir ekranda kalıyordu.
    @discardableResult
    func reviveEndless() -> Bool {
        guard case .endless = mode, !ringSpecs.isEmpty else { return false }
        endlessOverSent = false
        deadSince = nil
        finished = false
        flightTime = 0

        // softReturn son halkaya oturtur; halka indeksi bir şekilde geçersizse
        // kendi içinde fail() çağırıp yine ölü duruma düşerdi. Burada indeksi
        // önce sınır içine çekiyoruz ki canlanma her hâlükârda tutsun.
        lastRing = min(max(lastRing, 0), ringSpecs.count - 1)
        softReturn()
        if case .attached = orbState {
            makeOrbVisible()
            snapEndlessCameraToOrb()
            return true
        }
        // Son çare: başlangıç halkasına oturt
        respawn(animated: true)
        guard case .attached = orbState else { return false }
        makeOrbVisible()
        snapEndlessCameraToOrb()
        return true
    }

    /// Küreyi kesin olarak görünür kılar.
    ///
    /// Hem `softReturn` hem `respawn` küreyi 0.2 ölçekte bırakıp büyüme
    /// animasyonu çalıştırıyor. Reklamdan dönerken sahne bir an duraklamış
    /// olabildiği için bu animasyon çalışmayabiliyor ve küre ekranda görünmez
    /// kalıyordu — bu yüzden ölçek ve görünürlük burada elle sabitlenir.
    private func makeOrbVisible() {
        orbNode.removeAllActions()
        orbNode.isHidden = false
        orbNode.alpha = 1
        orbNode.setScale(1.0)
    }

    /// Kamerayı küreye ışınlar.
    ///
    /// `updateEndlessCamera` kamerayı yalnızca YUKARI taşır — tırmanışta geri
    /// kaymasın diye. Ama küre yukarıda ölüp aşağıdaki halkasına döndürülünce
    /// kamera ölüm yüksekliğinde asılı kalıyordu: küre görüş alanının altında
    /// kaldığı için ekranda hiç görünmüyor, dokunulup fırlatıldığı anda da
    /// `checkBounds` onu sınır dışı sayıp anında öldürüyordu. Canlanmadan sonra
    /// kamera bu yüzden elle küreye çekiliyor.
    private func snapEndlessCameraToOrb() {
        guard let cam = cameraNode else { return }
        cam.position.y = max(orbNode.position.y + size.height * 0.18, size.height / 2)
        if let bg = childNode(withName: "bg") {
            bg.position.y = cam.position.y - size.height / 2
        }
    }

    /// Aktif halkanın çevresinde kalan oyalanma süresini gösteren azalan yay.
    /// Üstten başlar, saat yönünde tükenir; süre azaldıkça kırmızıya döner.
    private func updateDwellArc(ring: Int, fraction: CGFloat) {
        let arc: SKShapeNode
        if let existing = dwellArc {
            arc = existing
        } else {
            let n = SKShapeNode()
            n.lineWidth = 4
            n.lineCap = .round
            n.glowWidth = 4
            n.zPosition = 16
            n.fillColor = .clear
            addChild(n)
            dwellArc = n
            arc = n
        }
        arc.isHidden = false
        arc.position = ringCenter(ring, at: elapsed)
        let r = ringRadius(ring) + 7
        let start = CGFloat.pi / 2
        let end = start - max(0.0001, fraction) * 2 * .pi
        let path = CGMutablePath()
        path.addArc(center: .zero, radius: r, startAngle: start, endAngle: end, clockwise: true)
        arc.path = path
        let low = fraction < 0.34
        arc.strokeColor = low ? theme.hazard.uiColor : theme.accent.uiColor
        arc.alpha = low ? 0.95 : 0.7
    }

    // MARK: Kazanma / kaybetme

    private func fail() {
        if case .dead = orbState { return }
        if case .won = orbState { return }
        if finished { return }
        orbState = .dead
        deadSince = elapsed
        combo = 0
        burst(at: orbNode.position, color: theme.hazard.uiColor, count: 26)
        orbNode.isHidden = true
        shake()
        onEvent?(.fail)
    }

    private func respawn(animated: Bool) {
        guard !ringSpecs.isEmpty, !finished else { return }
        let start = level?.startRing ?? 0
        deadSince = nil
        orbNode.isHidden = false
        orbState = .attached(ring: start, angle: -.pi / 2, direction: ringSpecs[start].direction)
        dwellStart = elapsed
        dwellArc?.isHidden = true
        exitedLastRing = true
        // Süreli bölümde her deneme dolu süreyle başlar
        if let limit = level?.timeLimit {
            timedDeadline = elapsed + limit
            lastTimeTickSent = Int.max
        }
        if animated {
            orbNode.setScale(0.2)
            orbNode.run(.scale(to: 1.0, duration: 0.25))
            // Göz oraya çekilsin diye başlangıç halkası belirgin şekilde parlar
            ringCircles[start].run(.sequence([.scale(to: 1.3, duration: 0.15), .scale(to: 1.0, duration: 0.3)]))
        }
    }

    /// Toplanan lumenlerin yıldız değeri toplamı (büyük yıldız 4 eder)
    private var collectedStars: Int {
        lumenCollected.indices.reduce(0) { $0 + (lumenCollected[$1] ? lumenValues[$1] : 0) }
    }

    /// Topla-bitir bölümünde kapı, her lumen toplanana kadar kapalıdır.
    private var gateOpen: Bool {
        !gateNeedsAllLumens || lumenCollected.allSatisfy { $0 }
    }

    private func win() {
        guard !finished else { return }
        finished = true
        orbState = .won
        let stars = collectedStars
        if let gateIndex = ringSpecs.firstIndex(where: { $0.isGate }) {
            ringCircles[gateIndex].run(.sequence([.scale(to: 1.4, duration: 0.3), .scale(to: 1.0, duration: 0.3)]))
        }
        burst(at: orbNode.position, color: theme.gate.uiColor, count: 40)
        if stars >= (level?.maxStars ?? 3) { celebrationCascade() }
        run(.wait(forDuration: 0.7)) { [weak self] in
            guard let self else { return }
            self.onEvent?(.win(stars: stars))
        }
    }

    /// 3/3 yıldız kutlaması: ekrana yayılan renkli havai fişek şelalesi
    private func celebrationCascade() {
        let palette = [theme.lumen.uiColor, theme.gate.uiColor, theme.accent.uiColor, theme.orb.uiColor]
        for i in 0..<12 {
            run(.sequence([
                .wait(forDuration: 0.06 * Double(i)),
                .run { [weak self] in
                    guard let self else { return }
                    let p = CGPoint(x: .random(in: self.size.width * 0.15...self.size.width * 0.85),
                                    y: .random(in: self.size.height * 0.30...self.size.height * 0.85))
                    self.burst(at: p, color: palette[i % palette.count], count: 22)
                }
            ]))
        }
    }

    /// Bonus turu sonu: yıldız sayısı toplanan lumen oranına göre
    private func finishBonus() {
        guard !finished else { return }
        finished = true
        orbState = .won
        let collected = lumenCollected.filter { $0 }.count
        let stars: Int
        switch collected {
        case lumenTotal...: stars = 3
        case Int(Double(lumenTotal) * 0.66)...: stars = 2
        case Int(Double(lumenTotal) * 0.33)...: stars = 1
        default: stars = 0
        }
        burst(at: orbNode.position, color: theme.lumen.uiColor, count: 40)
        if stars >= 3 { celebrationCascade() }
        run(.wait(forDuration: 0.5)) { [weak self] in
            self?.onEvent?(.win(stars: stars))
        }
    }

    // MARK: Sonsuz mod

    private func seedEndless() {
        ringSpecs = [RingSpec(center: CGPoint(x: 0.5, y: 0.15), radius: 0.10, orbitSpeed: 1.8, direction: 1)]
        addRingNode(ringSpecs[0], index: 0)
        extendEndlessIfNeeded(reached: 0)
    }

    private func extendEndlessIfNeeded(reached: Int) {
        while ringSpecs.count < reached + 5 {
            let prev = ringSpecs[ringSpecs.count - 1]
            let n = ringSpecs.count
            let hardness = min(CGFloat(n) / 40.0, 1.0)
            let radius = 0.10 - 0.035 * hardness + endlessRNG.cg(in: -0.008...0.008)
            let angle = endlessRNG.cg(in: (.pi * 0.3)...(.pi * 0.7))
            let dist = endlessRNG.cg(in: 0.26...0.34)
            var c = CGPoint(x: prev.center.x + cos(angle) * dist,
                            y: prev.center.y + sin(angle) * dist)
            c.x = min(max(c.x, 0.18), 0.82)
            var spec = RingSpec(center: c,
                                radius: radius,
                                orbitSpeed: 1.8 + 1.8 * hardness + endlessRNG.cg(in: -0.2...0.2),
                                direction: endlessRNG.cg(in: 0...1) < 0.5 ? 1 : -1)
            if n > 8, endlessRNG.cg(in: 0...1) < 0.3 + 0.3 * hardness {
                let span = endlessRNG.cg(in: (.pi * 0.22)...(.pi * (0.3 + 0.2 * hardness)))
                let start = endlessRNG.cg(in: 0...(2 * .pi))
                spec.hazardArcs = [start...(start + span)]
                if endlessRNG.cg(in: 0...1) < 0.5 {
                    spec.hazardRotationSpeed = endlessRNG.cg(in: 0.4...0.9)
                }
            }
            ringSpecs.append(spec)
            addRingNode(spec, index: ringSpecs.count - 1)
        }
    }

    private func updateEndlessCamera(dt: TimeInterval) {
        guard let cam = cameraNode else { return }
        let targetY = max(orbNode.position.y + size.height * 0.18, size.height / 2)
        if targetY > cam.position.y {
            cam.position.y += (targetY - cam.position.y) * CGFloat(min(1, dt * 4))
        }
        if let bg = childNode(withName: "bg") {
            bg.position.y = cam.position.y - size.height / 2
        }
    }

    // MARK: Efektler

    private func burst(at point: CGPoint, color: UIColor, count: Int) {
        let e = SKEmitterNode()
        e.particleTexture = Self.glowTexture
        e.numParticlesToEmit = count
        e.particleBirthRate = 400
        e.particleLifetime = 0.5
        e.particleLifetimeRange = 0.25
        e.particleSpeed = 130
        e.particleSpeedRange = 90
        e.emissionAngleRange = .pi * 2
        e.particleAlpha = 0.9
        e.particleAlphaSpeed = -1.8
        e.particleScale = 0.2
        e.particleScaleSpeed = -0.3
        e.particleColor = color
        e.particleColorBlendFactor = 1
        e.particleBlendMode = .add
        e.position = point
        e.zPosition = 30
        addChild(e)
        e.run(.sequence([.wait(forDuration: 1.2), .removeFromParent()]))
    }

    private func shake() {
        let node = cameraNode ?? self
        let amount: CGFloat = 8
        node.run(.sequence([
            .moveBy(x: amount, y: 0, duration: 0.04),
            .moveBy(x: -amount * 2, y: 0, duration: 0.06),
            .moveBy(x: amount, y: 0, duration: 0.05)
        ]))
    }

    // MARK: Dokular ve yollar

    static let glowTexture: SKTexture = {
        let side: CGFloat = 64
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        let image = renderer.image { ctx in
            let colors = [UIColor.white.cgColor, UIColor.white.withAlphaComponent(0).cgColor] as CFArray
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                      colors: colors, locations: [0, 1])!
            ctx.cgContext.drawRadialGradient(gradient,
                                             startCenter: CGPoint(x: side / 2, y: side / 2), startRadius: 0,
                                             endCenter: CGPoint(x: side / 2, y: side / 2), endRadius: side / 2,
                                             options: [])
        }
        return SKTexture(image: image)
    }()

    static func gradientTexture(size: CGSize, top: UIColor, bottom: UIColor) -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let colors = [bottom.cgColor, top.cgColor] as CFArray
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                      colors: colors, locations: [0, 1])!
            ctx.cgContext.drawLinearGradient(gradient,
                                             start: CGPoint(x: 0, y: size.height), end: .zero,
                                             options: [])
        }
        return SKTexture(image: image)
    }

    static func starPath(radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let points = 5
        for i in 0..<(points * 2) {
            let r = i % 2 == 0 ? radius : radius * 0.45
            let a = CGFloat(i) * .pi / CGFloat(points) - .pi / 2
            let p = CGPoint(x: cos(a) * r, y: sin(a) * r)
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.closeSubpath()
        return path
    }

    static func heartPath(radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let s = radius
        path.move(to: CGPoint(x: 0, y: -s * 0.8))
        path.addCurve(to: CGPoint(x: -s, y: s * 0.35),
                      control1: CGPoint(x: -s * 0.4, y: -s * 1.3),
                      control2: CGPoint(x: -s, y: -s * 0.2))
        path.addArc(center: CGPoint(x: -s * 0.5, y: s * 0.35), radius: s * 0.5,
                    startAngle: .pi, endAngle: 0, clockwise: false)
        path.addArc(center: CGPoint(x: s * 0.5, y: s * 0.35), radius: s * 0.5,
                    startAngle: .pi, endAngle: 0, clockwise: false)
        path.addCurve(to: CGPoint(x: 0, y: -s * 0.8),
                      control1: CGPoint(x: s, y: -s * 0.2),
                      control2: CGPoint(x: s * 0.4, y: -s * 1.3))
        path.closeSubpath()
        return path
    }

    static func polygonPath(sides: Int, radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        for i in 0..<sides {
            let a = CGFloat(i) * 2 * .pi / CGFloat(sides) - .pi / 2
            let p = CGPoint(x: cos(a) * radius, y: sin(a) * radius)
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.closeSubpath()
        return path
    }
}
