import AVFoundation

/// Orbeon'un tüm sesi koddan üretilir — hiç ses dosyası yoktur.
/// Müzik: yavaşça akor değiştiren, portamentolu ambient pad (AVAudioSourceNode).
/// Efektler: pentatonik dizide tınlayan sentetik "pluck" notaları; her başarılı
/// atlayışta kombo ile perde yükselir — oyuncu farkında olmadan melodi çalar.
final class AudioEngine {
    static let shared = AudioEngine()

    private let engine = AVAudioEngine()
    private let musicMixer = AVAudioMixerNode()
    private let sfxMixer = AVAudioMixerNode()
    private var sfxPlayers: [AVAudioPlayerNode] = []
    private var nextPlayer = 0
    private var started = false        // startIfNeeded çağrıldı (kurulum başladı/bitti)
    private var configured = false     // grafik kuruldu; engine.start() güvenli

    private let sampleRate: Double = 44_100
    private lazy var format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!

    // MARK: Pad durumu (yalnızca render iş parçacığında okunur/yazılır sayılan basit alanlar)
    // 3 ses, orta register (boomy bas YOK = "uğultu" hissi yok), üstler kısık.
    private var padPhases = [Double](repeating: 0, count: 3)
    private var padFreqs: [Double] = [220, 261.63, 329.63]
    private var padTargets: [Double] = [220, 261.63, 329.63]
    private var padTime: Double = 0
    private var chordIndex = 0
    private var musicVolume: Float = 0
    private var padLP: Double = 0                            // alçak geçiren süzgeç durumu (yumuşatma)
    private let padVoiceGains: [Double] = [1.0, 0.8, 0.55]  // üst sesler kısık = kulağa yumuşak

    /// A minör etrafında dingin akor yürüyüşü: Am — F — C — G.
    /// Sub-bas notaları çıkarıldı; hepsi orta register (220–392 Hz) — sürekli
    /// alçak drone/uğultu yerine hafif, havadar bir doku.
    private let chords: [[Double]] = [
        [220.00, 261.63, 329.63],  // Am: A3 C4 E4
        [220.00, 261.63, 349.23],  // F:  A3 C4 F4
        [261.63, 329.63, 392.00],  // C:  C4 E4 G4
        [246.94, 293.66, 392.00]   // G:  B3 D4 G4
    ]

    /// A minör pentatonik, iki oktav — kombo perdeleri
    private let pluckScale: [Double] = [220, 261.63, 293.66, 329.63, 392,
                                        440, 523.25, 587.33, 659.26, 784, 880]

    private var pluckBuffers: [AVAudioPCMBuffer] = []
    private var collectBuffer: AVAudioPCMBuffer?
    private var failBuffer: AVAudioPCMBuffer?
    private var winBuffer: AVAudioPCMBuffer?

    var musicEnabled = true { didSet { musicMixer.outputVolume = musicEnabled ? 1 : 0 } }
    var sfxEnabled = true { didSet { sfxMixer.outputVolume = sfxEnabled ? 1 : 0 } }

    private init() {}

    // MARK: Başlatma

    func startIfNeeded() {
        guard !started else { return }
        started = true
        // Tüm ses kurulumu arka planda yapılır: setActive/prepare/start ana
        // thread'de çağrılınca UI'yi kilitleyebiliyor (AVAudioSession uyarısı).
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            setupAudio()
        }
    }

    /// Ses oturumunu etkinleştirir; başarısız olursa kısa süre içinde birkaç kez dener.
    /// (Açılışta oturum bazen hemen aktifleşmez → çıkış formatı 0 Hz → engine hata verir)
    @discardableResult
    private func activateSession() -> Bool {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, options: [.mixWithOthers])
        for _ in 0..<3 {
            do {
                try session.setActive(true)
                if session.sampleRate > 0 { return true }
            } catch {
                Thread.sleep(forTimeInterval: 0.1)
            }
        }
        return session.sampleRate > 0
    }

    private func setupAudio() {
        // Saygılı ses: kullanıcının kendi müziğiyle karışır, sessize alma anahtarına uyar
        activateSession()

        // Oturum kesintisi / donanım rotası değişince (kulaklık, başka uygulama,
        // titreşim motoru vb.) engine durabilir; bu bildirimlerle yeniden başlatılır
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleInterruption(_:)),
            name: AVAudioSession.interruptionNotification, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleConfigChange),
            name: .AVAudioEngineConfigurationChange, object: engine)

        engine.attach(musicMixer)
        engine.attach(sfxMixer)
        engine.connect(musicMixer, to: engine.mainMixerNode, format: format)
        engine.connect(sfxMixer, to: engine.mainMixerNode, format: format)

        let pad = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self else { return noErr }
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            guard let buf = ablPointer.first?.mData?.assumingMemoryBound(to: Float.self) else { return noErr }
            let dt = 1.0 / self.sampleRate
            for frame in 0..<Int(frameCount) {
                self.padTime += dt
                // 12 saniyede bir akor değiştir
                let targetChord = Int(self.padTime / 12) % self.chords.count
                if targetChord != self.chordIndex {
                    self.chordIndex = targetChord
                    self.padTargets = self.chords[targetChord]
                }
                var sample: Double = 0
                for v in 0..<3 {
                    // Portamento: frekans hedefe doğru yumuşakça kayar
                    self.padFreqs[v] += (self.padTargets[v] - self.padFreqs[v]) * dt * 1.2
                    self.padPhases[v] += 2 * .pi * self.padFreqs[v] * dt
                    if self.padPhases[v] > 2 * .pi { self.padPhases[v] -= 2 * .pi }
                    // Üst sesler kısılmış + detune inceltilmiş = sert değil, sıcak pad
                    let g = self.padVoiceGains[v]
                    sample += sin(self.padPhases[v]) * 0.5 * g
                    sample += sin(self.padPhases[v] * 1.004) * 0.16 * g
                }
                // Tek kutuplu alçak geçiren süzgeç: keskin/tiz tepe frekanslarını yuvarlar
                self.padLP += (sample - self.padLP) * 0.06
                sample = self.padLP
                // DERİN, yavaş nefes: genlik neredeyse sessizliğe iner ve yükselir —
                // sürekli "uğultu" değil, hafif dalgalar halinde bir ambiyans.
                let lfo = max(0, 0.40 + 0.42 * sin(self.padTime * 0.34))
                // Açılışta yumuşak fade-in (tık sesi olmasın); genel seviye daha kısık
                if self.musicVolume < 0.026 { self.musicVolume += 0.0000030 }
                buf[frame] = Float(sample * lfo) * self.musicVolume
            }
            return noErr
        }
        engine.attach(pad)
        engine.connect(pad, to: musicMixer, format: format)

        for _ in 0..<4 {
            let p = AVAudioPlayerNode()
            engine.attach(p)
            engine.connect(p, to: sfxMixer, format: format)
            sfxPlayers.append(p)
        }

        buildBuffers()
        configured = true
        startEngine()

        // Kullanıcı kendi müziğini dinliyorsa pad'i sustur
        if AVAudioSession.sharedInstance().secondaryAudioShouldBeSilencedHint {
            musicMixer.outputVolume = 0
        }
    }

    /// Engine'i başlatır; başarısız olursa oturumu tazeleyip birkaç kez dener.
    private func startEngine() {
        guard configured, !engine.isRunning else {
            if engine.isRunning { sfxPlayers.forEach { if !$0.isPlaying { $0.play() } } }
            return
        }
        for attempt in 0..<3 {
            engine.prepare()
            do {
                try engine.start()
                sfxPlayers.forEach { $0.play() }
                return
            } catch {
                // Çıkış formatı 0 Hz ise oturum henüz hazır değil — tazeleyip yeniden dene
                activateSession()
                Thread.sleep(forTimeInterval: Double(attempt + 1) * 0.15)
            }
        }
    }

    @objc private func handleInterruption(_ note: Notification) {
        guard let info = note.userInfo,
              let raw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
        if type == .ended {
            DispatchQueue.global(qos: .userInitiated).async { [self] in
                activateSession()
                startEngine()
            }
        }
    }

    @objc private func handleConfigChange() {
        guard configured else { return }
        DispatchQueue.global(qos: .userInitiated).async { [self] in startEngine() }
    }

    func stop() {
        guard started else { return }
        engine.pause()
    }

    func resume() {
        // Kurulum bitmeden engine.start() çağırma — yarı kurulu grafik 0 Hz hatası verir
        guard started, configured else { return }
        DispatchQueue.global(qos: .userInitiated).async { [self] in startEngine() }
    }

    // MARK: Efekt tetikleyicileri

    func playHop(combo: Int) {
        guard sfxEnabled, !pluckBuffers.isEmpty else { return }
        let index = min(max(combo - 1, 0), pluckBuffers.count - 1)
        play(pluckBuffers[index])
    }

    func playCollect() { if let b = collectBuffer { play(b) } }
    func playFail() { if let b = failBuffer { play(b) } }
    func playWin() { if let b = winBuffer { play(b) } }
    func playTap() {
        guard let b = pluckBuffers.first else { return }
        play(b)
    }

    private func play(_ buffer: AVAudioPCMBuffer) {
        guard started, sfxEnabled else { return }
        let player = sfxPlayers[nextPlayer]
        nextPlayer = (nextPlayer + 1) % sfxPlayers.count
        player.scheduleBuffer(buffer, at: nil, options: .interrupts)
    }

    // MARK: Sentez

    private func buildBuffers() {
        pluckBuffers = pluckScale.map { makePluck(freq: $0, duration: 0.45, volume: 0.5) }
        collectBuffer = makeSparkle()
        failBuffer = makeFail()
        winBuffer = makeWinArpeggio()
    }

    private func makeBuffer(duration: Double) -> (AVAudioPCMBuffer, UnsafeMutablePointer<Float>, Int) {
        let frames = AVAudioFrameCount(duration * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        return (buffer, buffer.floatChannelData![0], Int(frames))
    }

    /// Tek nota: sinüs + 2. harmonik, üstel sönümlü — sıcak bir "pluck"
    private func makePluck(freq: Double, duration: Double, volume: Double) -> AVAudioPCMBuffer {
        let (buffer, data, n) = makeBuffer(duration: duration)
        for i in 0..<n {
            let t = Double(i) / sampleRate
            let env = exp(-t * 9)
            let s = sin(2 * .pi * freq * t) * 0.7
                  + sin(2 * .pi * freq * 2 * t) * 0.2
                  + sin(2 * .pi * freq * 3 * t) * 0.06
            data[i] = Float(s * env * volume)
        }
        return buffer
    }

    /// Lumen toplama: yüksek, parlak çift sinüs kıvılcımı
    private func makeSparkle() -> AVAudioPCMBuffer {
        let (buffer, data, n) = makeBuffer(duration: 0.22)
        for i in 0..<n {
            let t = Double(i) / sampleRate
            let env = exp(-t * 16)
            let s = sin(2 * .pi * 1568 * t) * 0.5 + sin(2 * .pi * 2093 * t) * 0.4
            data[i] = Float(s * env * 0.4)
        }
        return buffer
    }

    /// Düşüş: aşağı kayan yumuşak ton — ceza gibi değil, "tekrar dene" gibi
    private func makeFail() -> AVAudioPCMBuffer {
        let (buffer, data, n) = makeBuffer(duration: 0.35)
        for i in 0..<n {
            let t = Double(i) / sampleRate
            let env = exp(-t * 7)
            let freq = 340.0 - 190.0 * (t / 0.35)
            let s = sin(2 * .pi * freq * t) * 0.6 + sin(2 * .pi * freq * 0.5 * t) * 0.3
            data[i] = Float(s * env * 0.45)
        }
        return buffer
    }

    /// Bölüm sonu: A minör pentatonik yükselen arpej
    private func makeWinArpeggio() -> AVAudioPCMBuffer {
        let notes: [Double] = [440, 523.25, 659.26, 880]
        let step = 0.13
        let total = step * Double(notes.count) + 0.5
        let (buffer, data, n) = makeBuffer(duration: total)
        for (k, f) in notes.enumerated() {
            let startFrame = Int(Double(k) * step * sampleRate)
            let noteFrames = Int(0.6 * sampleRate)
            for i in 0..<noteFrames where startFrame + i < n {
                let t = Double(i) / sampleRate
                let env = exp(-t * 6)
                let s = sin(2 * .pi * f * t) * 0.6 + sin(2 * .pi * f * 2 * t) * 0.15
                data[startFrame + i] += Float(s * env * 0.4)
            }
        }
        return buffer
    }
}
