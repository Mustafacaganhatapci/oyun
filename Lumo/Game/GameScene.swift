import SpriteKit
import UIKit

enum GameEvent {
    case hop(combo: Int)
    case collect(total: Int)
    case fail
    case win(stars: Int)
    case bonusTick(remaining: Int)
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
    private let captureGrace: TimeInterval = 0.35   // halkaya oturduktan sonra tehlike bağışıklığı
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

    private var level: Level?
    private(set) var lumenTotal = 0
    private var ringSpecs: [RingSpec] = []
    private var ringNodes: [SKNode] = []
    private var ringCircles: [SKShapeNode] = []
    private var hazardNodes: [SKNode?] = []
    private var lumenNodes: [SKShapeNode] = []
    private var lumenCollected: [Bool] = []

    private var orbState: OrbState = .dead
    private var orbNode: SKNode!
    private var orbCore: SKShapeNode?
    private var trailEmitter: SKEmitterNode!
    private var lastRing = 0
    private var exitedLastRing = true
    private var flightTime: TimeInterval = 0
    private var attachTime: TimeInterval = 0
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
            if isBonus { bonusDeadline = lvl.bonusDuration }
            buildRings(lvl.rings)
            buildLumens(lvl.lumens)
            respawn(animated: false)
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

        let circle = SKShapeNode(circleOfRadius: r)
        circle.strokeColor = (spec.isGate ? theme.gate : theme.ring).uiColor
        circle.lineWidth = 3
        circle.glowWidth = spec.isGate ? 10 : 6
        circle.alpha = 0.9
        circle.fillColor = .clear
        container.addChild(circle)

        if spec.isGate {
            let dashed = SKShapeNode(path: CGPath(ellipseIn: CGRect(x: -r - 8, y: -r - 8,
                                                                    width: (r + 8) * 2, height: (r + 8) * 2),
                                                  transform: nil).copy(dashingWithPhase: 0, lengths: [8, 10]))
            dashed.strokeColor = theme.gate.uiColor
            dashed.lineWidth = 2
            dashed.alpha = 0.7
            dashed.run(.repeatForever(.rotate(byAngle: .pi * 2, duration: 14)))
            container.addChild(dashed)
        }

        circle.run(.repeatForever(.sequence([
            .scale(to: 1.03, duration: 1.6),
            .scale(to: 0.99, duration: 1.6)
        ])))

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

    private func buildLumens(_ specs: [LumenSpec]) {
        lumenTotal = specs.count
        for spec in specs {
            let node = SKShapeNode(circleOfRadius: 7)
            node.fillColor = theme.lumen.uiColor
            node.strokeColor = .clear
            node.glowWidth = 8
            node.position = scenePoint(spec.position)
            node.zPosition = 15
            node.run(.repeatForever(.sequence([
                .group([.scale(to: 1.25, duration: 0.8), .fadeAlpha(to: 1.0, duration: 0.8)]),
                .group([.scale(to: 0.9, duration: 0.8), .fadeAlpha(to: 0.75, duration: 0.8)])
            ])))
            addChild(node)
            lumenNodes.append(node)
            lumenCollected.append(false)
        }
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

    // MARK: Girdi — tek dokunuş, tüm ekran

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        switch orbState {
        case .attached(let ring, let angle, let direction):
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

        case .dead:
            // Güvenlik ağı: yeniden doğma herhangi bir nedenle gecikirse
            // dokunuş anında canlandırır — oyun asla "takılı" kalmaz
            if let since = deadSince, elapsed - since > 0.9, mode != .endless {
                respawn(animated: true)
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

        switch orbState {
        case .attached(let ring, var angle, let direction):
            let spec = ringSpecs[ring]
            angle += spec.orbitSpeed * direction * CGFloat(dt)
            orbState = .attached(ring: ring, angle: angle, direction: direction)
            let c = ringCenter(ring, at: elapsed)
            let r = ringRadius(ring)
            orbNode.position = CGPoint(x: c.x + cos(angle) * r, y: c.y + sin(angle) * r)
            checkHazard(ring: ring, angle: angle, time: currentTime)
            checkLumens()

        case .flying(let v):
            flightTime += dt
            orbNode.position = CGPoint(x: orbNode.position.x + v.dx * CGFloat(dt),
                                       y: orbNode.position.y + v.dy * CGFloat(dt))
            checkCapture(velocity: v)
            checkLumens()
            checkBounds()
            if flightTime > maxFlightTime { fail() }

        case .dead:
            // Yeniden doğma zamanlaması SKAction yerine burada işlenir:
            // sahne duraklatılsa/aksiyon kaybolsa bile bu yol her zaman çalışır
            if let since = deadSince, elapsed - since >= respawnDelay {
                if case .endless = mode {
                    if !endlessOverSent {
                        endlessOverSent = true
                        onEvent?(.endlessGameOver(score: endlessScore))
                    }
                } else if !finished {
                    respawn(animated: true)
                }
            }

        case .won:
            break
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
            let cross = dx * v.dy - dy * v.dx
            let direction: CGFloat = cross >= 0 ? 1 : -1
            orbState = .attached(ring: i, angle: angle, direction: direction)
            attachTime = lastUpdate
            combo += 1

            ringCircles[i].run(.sequence([.scale(to: 1.15, duration: 0.1), .scale(to: 1.0, duration: 0.25)]))
            burst(at: orbNode.position, color: theme.accent.uiColor, count: 10)

            if ringSpecs[i].isGate {
                win()
            } else {
                onEvent?(.hop(combo: combo))
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

    private func checkHazard(ring: Int, angle: CGFloat, time: TimeInterval) {
        let spec = ringSpecs[ring]
        guard !spec.hazardArcs.isEmpty, time - attachTime > captureGrace else { return }
        let rot = CGFloat(elapsed) * spec.hazardRotationSpeed
        for arc in spec.hazardArcs {
            var rel = (angle - rot - arc.lowerBound).truncatingRemainder(dividingBy: 2 * .pi)
            if rel < 0 { rel += 2 * .pi }
            if rel <= (arc.upperBound - arc.lowerBound) {
                fail()
                return
            }
        }
    }

    private func checkLumens() {
        for i in lumenNodes.indices where !lumenCollected[i] {
            let n = lumenNodes[i]
            let dx = n.position.x - orbNode.position.x
            let dy = n.position.y - orbNode.position.y
            if sqrt(dx * dx + dy * dy) < collectDistance {
                lumenCollected[i] = true
                burst(at: n.position, color: theme.lumen.uiColor, count: 16)
                n.run(.sequence([.group([.scale(to: 1.8, duration: 0.18), .fadeOut(withDuration: 0.18)]),
                                 .removeFromParent()]))
                onEvent?(.collect(total: lumenCollected.filter { $0 }.count))
                if isBonus, lumenCollected.allSatisfy({ $0 }) {
                    finishBonus()   // hepsi toplandıysa erken bitir
                }
            }
        }
    }

    private func checkBounds() {
        var frame = CGRect(origin: .zero, size: size).insetBy(dx: -60, dy: -60)
        if let cam = cameraNode {
            frame = CGRect(x: -60, y: cam.position.y - size.height / 2 - 80,
                           width: size.width + 120, height: size.height + 160)
        }
        if !frame.contains(orbNode.position) { fail() }
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
        attachTime = lastUpdate
        exitedLastRing = true
        if animated {
            orbNode.setScale(0.2)
            orbNode.run(.scale(to: 1.0, duration: 0.25))
            // Göz oraya çekilsin diye başlangıç halkası belirgin şekilde parlar
            ringCircles[start].run(.sequence([.scale(to: 1.3, duration: 0.15), .scale(to: 1.0, duration: 0.3)]))
        }
    }

    private func win() {
        guard !finished else { return }
        finished = true
        orbState = .won
        let stars = lumenCollected.filter { $0 }.count
        if let gateIndex = ringSpecs.firstIndex(where: { $0.isGate }) {
            ringCircles[gateIndex].run(.sequence([.scale(to: 1.4, duration: 0.3), .scale(to: 1.0, duration: 0.3)]))
        }
        burst(at: orbNode.position, color: theme.gate.uiColor, count: 40)
        run(.wait(forDuration: 0.7)) { [weak self] in
            guard let self else { return }
            self.onEvent?(.win(stars: stars))
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
