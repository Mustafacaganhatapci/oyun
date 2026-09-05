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
    /// Her sesin ne zaman biteceği. Sıra sıra dolaşmak yerine BOŞ olan düğüm
    /// seçilsin diye tutuluyor; yoksa hâlâ tınlayan bir nota kesiliyor.
    private var sfxFreeAt: [CFAbsoluteTime] = []
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

    /// A minör pentatonik, bir buçuk oktav — kombo perdeleri.
    ///
    /// Dizi bilerek KISA. Üç oktavlık uzun bir merdiven denendi: perde on altıncı
    /// atlayışa kadar tırmandığı için bölümler bitmeden tepeye varılmıyor, iniş
    /// hiç duyulmuyordu. Bölümlerde 5–15 halka var; sekiz notalık merdiven
    /// sekizinci atlayışta tepeye çıkıp geri iniyor, yani orta uzunlukta bir
    /// bölümde bile dalganın tamamı duyuluyor. Üst uç da böylece cırlak değil.
    private let pluckScale: [Double] = [220, 261.63, 293.66, 329.63,
                                        392, 440, 523.25, 587.33]
    private var pluckBuffers: [AVAudioPCMBuffer] = []
    private var collectBuffer: AVAudioPCMBuffer?
    private var failBuffer: AVAudioPCMBuffer?
    private var lifeLostBuffer: AVAudioPCMBuffer?
    private var winBuffer: AVAudioPCMBuffer?
    private var gateBuffer: AVAudioPCMBuffer?

    /// Premium oyuncunun kendi kaydettiği sesler. Doluysa sentetik olanın
    /// yerine geçer; boş bırakılan yuvalar sentetik kalmaya devam eder.
    private var custom = CustomSoundSet()

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

        // Ayarlar burada YENİDEN uygulanır. SettingsStore açılışta kayıtlı
        // tercihi yazıyor ama o an mikserler henüz motora bağlı değil ve
        // outputVolume kayboluyordu: müziği kapatıp uygulamayı yeniden açan
        // oyuncu, anahtar "kapalı" görünürken müziği duyuyordu.
        musicMixer.outputVolume = musicEnabled ? 1 : 0
        sfxMixer.outputVolume = sfxEnabled ? 1 : 0

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

        // Sekiz ses. Dördü yetmiyordu: pluck 0.45 sn sürüyor, hızlı bir
        // komboda dördüncü atlayıştan sonra sıra başa dönüp HÂLÂ ÇALAN notayı
        // kesiyordu. Üstüne lumen, dokunuş ve kazanma sesleri de aynı havuzu
        // paylaşınca ses "tıkanıyor" gibi duyuluyordu.
        for _ in 0..<8 {
            let p = AVAudioPlayerNode()
            engine.attach(p)
            engine.connect(p, to: sfxMixer, format: format)
            sfxPlayers.append(p)
            sfxFreeAt.append(0)
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

    /// Kombo boyunca perde önce yükselir, sekizinci atlayışta tepeye varır ve
    /// aynı yoldan iner; sonra baştan. Eskiden tepede son beş nota dönüyordu,
    /// ardından merdiven o kadar uzadı ki iniş pratikte hiç duyulmuyordu.
    /// Üçgen dalga hem hiç durmuyor hem de bir bölüm içinde tamamlanıyor.
    func playHop(combo: Int) {
        let ladder = custom.hopLadder.isEmpty ? pluckBuffers : custom.hopLadder
        guard sfxEnabled, !ladder.isEmpty else { return }
        play(ladder[Self.ladderIndex(combo: combo, count: ladder.count)])
    }

    /// 0 → tavan → 1 → tavan … (uçlar tekrarlanmadan)
    static func ladderIndex(combo: Int, count: Int) -> Int {
        guard count > 1 else { return 0 }
        let period = (count - 1) * 2
        let p = max(combo - 1, 0) % period
        return p < count ? p : period - p
    }

    func playCollect() { if let b = custom.collect ?? collectBuffer { play(b) } }
    func playLifeLost() { if let b = custom.lifeLost ?? lifeLostBuffer { play(b) } }
    func playFail() { if let b = custom.fail ?? failBuffer { play(b) } }
    func playWin() { if let b = custom.win ?? winBuffer { play(b) } }

    /// Kapı açıldı. Bölüm bitirme sesinden AYRI: ikisi de aynı yükselen
    /// arpej olunca "kapı açıldı" ile "bölüm bitti" aynı şey sanılıyordu.
    /// Kaydedilebilir kendi yuvası da var — ses ayrıysa kaydı da ayrı olmalı.
    func playGate() { if let b = custom.gate ?? gateBuffer { play(b) } }

    // MARK: Premium — kendi sesin

    /// Ayarlardaki "dinle" düğmesi: ses kapalı olsa bile duyulsun ki oyuncu
    /// kaydını denetleyebilsin.
    func playPreview(_ buffer: AVAudioPCMBuffer) {
        guard started, !sfxPlayers.isEmpty else { return }
        let duration = Double(buffer.frameLength) / sampleRate
        // Efektler kapalıysa mikser susturulmuş olur; dinletme boyunca açılır
        if !sfxEnabled {
            sfxMixer.outputVolume = 1
            DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.1) { [weak self] in
                guard let self, !self.sfxEnabled else { return }
                self.sfxMixer.outputVolume = 0
            }
        }
        let now = CFAbsoluteTimeGetCurrent()
        let index = sfxFreeAt.firstIndex(where: { $0 <= now }) ?? 0
        sfxFreeAt[index] = now + duration
        sfxPlayers[index].scheduleBuffer(buffer, at: nil, options: .interrupts)
    }

    func applyCustomSounds(_ set: CustomSoundSet) { custom = set }

    func clearCustomSounds() { custom = CustomSoundSet() }

    /// Bir kaydı pentatonik dizinin perde oranlarında yeniden örnekler.
    /// Örnekleme hızını değiştirmek sesi hem inceltir hem kısaltır — bant
    /// hızlandırma etkisi; kombo yükseldikçe oyuncunun kendi "hop"u tizleşir.
    func pitchLadder(from buffer: AVAudioPCMBuffer) -> [AVAudioPCMBuffer] {
        guard let base = pluckScale.first, base > 0 else { return [] }
        return pluckScale.compactMap { resample(buffer, ratio: $0 / base) }
    }

    /// Doğrusal aradeğerlemeli yeniden örnekleme. ratio > 1 = daha hızlı/tiz.
    private func resample(_ buffer: AVAudioPCMBuffer, ratio: Double) -> AVAudioPCMBuffer? {
        guard let src = buffer.floatChannelData?[0] else { return nil }
        let n = Int(buffer.frameLength)
        guard n > 1 else { return nil }
        if abs(ratio - 1) < 0.0001 { return buffer }
        let outCount = max(2, Int(Double(n) / ratio))
        guard let out = AVAudioPCMBuffer(pcmFormat: format,
                                         frameCapacity: AVAudioFrameCount(outCount)),
              let dst = out.floatChannelData?[0] else { return nil }
        out.frameLength = AVAudioFrameCount(outCount)
        for i in 0..<outCount {
            let pos = Double(i) * ratio
            let i0 = Int(pos)
            if i0 >= n - 1 { dst[i] = src[n - 1]; continue }
            let frac = Float(pos - Double(i0))
            dst[i] = src[i0] * (1 - frac) + src[i0 + 1] * frac
        }
        return out
    }
    func playTap() {
        guard let b = pluckBuffers.first else { return }
        play(b)
    }

    /// Sesi BOŞ bir düğüme verir. Hepsi doluysa en erken bitecek olanı seçer
    /// ve yalnızca o zaman keser — sırayla dolaşmak, kesilecek notayı rastgele
    /// seçtiği için tam duyulan notayı kırpabiliyordu.
    private func play(_ buffer: AVAudioPCMBuffer) {
        guard started, sfxEnabled, !sfxPlayers.isEmpty else { return }
        let now = CFAbsoluteTimeGetCurrent()
        let duration = Double(buffer.frameLength) / sampleRate

        var index = 0
        var interrupt = true
        if let free = sfxFreeAt.firstIndex(where: { $0 <= now }) {
            index = free
            interrupt = false
        } else {
            // Hepsi çalıyor: en erken bitecek olanı ödünç al
            index = sfxFreeAt.enumerated().min(by: { $0.element < $1.element })?.offset ?? 0
        }
        sfxFreeAt[index] = now + duration
        sfxPlayers[index].scheduleBuffer(buffer, at: nil,
                                         options: interrupt ? .interrupts : [])
    }

    // MARK: Sentez

    private func buildBuffers() {
        pluckBuffers = pluckScale.map { makePluck(freq: $0, duration: 0.45, volume: 0.5) }
        collectBuffer = makeSparkle()
        failBuffer = makeFail()
        lifeLostBuffer = makeLifeLost()
        winBuffer = makeWinArpeggio()
        gateBuffer = makeGateOpen()
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

    /// Can eksildi: iki notalık aşağı düşen ikili + kısa bir "kalp atışı"
    /// gümbürtüsü. Ölüm sesi gibi bitmiyor (tur devam ediyor) ama kazanma
    /// sesi gibi de değil — bir şey KAYBEDİLDİĞİ duyuluyor.
    private func makeLifeLost() -> AVAudioPCMBuffer {
        let (buffer, data, n) = makeBuffer(duration: 0.5)
        let notes: [(Double, Double)] = [(659.26, 0.0), (493.88, 0.13)]   // E5 → B4
        for (f, offset) in notes {
            let start = Int(offset * sampleRate)
            for i in 0..<Int(0.34 * sampleRate) where start + i < n {
                let t = Double(i) / sampleRate
                let env = exp(-t * 11)
                let s = sin(2 * .pi * f * t) * 0.55 + sin(2 * .pi * f * 2 * t) * 0.12
                data[start + i] += Float(s * env * 0.42)
            }
        }
        // Altta yumuşak bir vuruş: kaybın ağırlığı
        for i in 0..<Int(0.26 * sampleRate) where i < n {
            let t = Double(i) / sampleRate
            let env = exp(-t * 14)
            data[i] += Float(sin(2 * .pi * 110 * t) * env * 0.30)
        }
        return buffer
    }

    /// Bölüm sonu: A minör pentatonik yükselen arpej
    /// Kapının açılışı: önce kısa ve alçak bir "bırakma", ardından yavaşça
    /// açılan bir beşli. Bitiş arpejinin dört notalı zaferi değil, tek bir
    /// olay — bir şey açıldı. Alçak başlaması, aynı anda çalan yıldız
    /// sesinin parlaklığıyla çakışmamasını da sağlıyor.
    private func makeGateOpen() -> AVAudioPCMBuffer {
        let total = 1.1
        let (buffer, data, n) = makeBuffer(duration: total)

        // 1) Mandal: 220 Hz'den 150'ye hızlı iniş, 90 ms
        let clickFrames = Int(0.09 * sampleRate)
        var phase = 0.0
        for i in 0..<clickFrames where i < n {
            let t = Double(i) / sampleRate
            let f = 220 - 70 * (t / 0.09)
            phase += 2 * .pi * f / sampleRate
            let env = exp(-t * 26)
            data[i] += Float(sin(phase) * env * 0.32)
        }

        // 2) Açılan beşli: sol + re, yumuşak girişle bloom
        let start = Int(0.06 * sampleRate)
        for f in [392.0, 587.33] {
            for i in 0..<(n - start) {
                let t = Double(i) / sampleRate
                // Yavaş giriş (attack) + uzun kuyruk: "açılıyor" hissi
                let attack = min(t / 0.16, 1.0)
                let env = attack * exp(-t * 2.6)
                let s = sin(2 * .pi * f * t) * 0.5 + sin(2 * .pi * f * 3 * t) * 0.08
                data[start + i] += Float(s * env * 0.22)
            }
        }
        return buffer
    }

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
