import AVFoundation
import Combine

/// Premium oyuncunun kendi sesiyle değiştirebildiği efekt yuvaları.
/// Atlayış sesi oyunun ritmini taşıdığı için ayrı ele alınır: kayıt, kombo
/// yükseldikçe hızlandırılıp inceltilir — sentetik pentatonik dizinin yaptığını
/// oyuncunun kendi "hop"u yapar.
enum CustomSoundSlot: String, CaseIterable, Identifiable {
    case hop, collect, gate, lifeLost, fail, win

    var id: String { rawValue }

    /// Ayarlar ekranındaki başlık (yerelleştirme anahtarı)
    var title: String {
        switch self {
        case .hop:      return "Hop"
        case .collect:  return "Star"
        case .gate:     return "Gate"
        case .lifeLost: return "Life lost"
        case .fail:     return "Death"
        case .win:      return "Level finish"
        }
    }

    var hint: String {
        switch self {
        case .hop:      return "Rises in pitch as your combo grows."
        case .collect:  return "Plays when you pick up a star."
        case .gate:     return "Plays when the gate opens."
        case .lifeLost: return "Plays when an extra life is spent."
        case .fail:     return "Plays when the orb is lost."
        case .win:      return "Plays when a level is finished."
        }
    }

    var icon: String {
        switch self {
        case .hop:      return "arrow.up.forward"
        case .collect:  return "star.fill"
        case .gate:     return "lock.open.fill"
        case .lifeLost: return "heart.slash.fill"
        case .fail:     return "xmark.circle.fill"
        case .win:      return "flag.checkered"
        }
    }

    /// Kaydın azami süresi. "Hop" bir hece kadar olmalı; kombo hızlandığında
    /// uzun bir kayıt üst üste binip çamura dönüyor.
    var maxDuration: TimeInterval { (self == .hop || self == .collect) ? 0.9 : 2.0 }
}

/// Kayıtları diskte tutar, oyunun ses motoruna hazır tampon olarak verir.
/// Kayıtlar YALNIZCA cihazda kalır; hiçbir yere yüklenmez.
final class CustomSoundStore: NSObject, ObservableObject {
    static let shared = CustomSoundStore()

    /// Kaydı olan yuvalar
    @Published private(set) var recorded: Set<CustomSoundSlot> = []
    /// Şu an kayıt alınan yuva (nil = kayıt yok)
    @Published private(set) var recording: CustomSoundSlot?
    /// Geri sayımı süren yuva. Mikrofona basar basmaz kayıt başlayınca kimse
    /// yetişemiyordu; önce üçten geri sayıyoruz.
    @Published private(set) var arming: CustomSoundSlot?
    /// 3 → 2 → 1; kayıt başlayınca 0
    @Published private(set) var countdown = 0
    /// Kayıtlar oyunda kullanılsın mı (premium bitse bile kayıtlar silinmez)
    @Published var enabled: Bool {
        didSet {
            UserDefaults.standard.set(enabled, forKey: Self.enabledKey)
            applyToEngine()
        }
    }
    /// Mikrofon izni reddedildiyse ayarlarda uyarı gösterilir
    @Published private(set) var micDenied = false
    /// StoreManager'dan beslenir; premium bitince kayıtlar devre dışı kalır
    /// (dosyalar silinmez — abonelik dönerse yerinde durur).
    var premiumActive = false { didSet { if premiumActive != oldValue { applyToEngine() } } }

    private static let enabledKey = "customSoundsEnabled"
    private var recorder: AVAudioRecorder?
    private var stopWork: DispatchWorkItem?
    private var countdownWork: [DispatchWorkItem] = []
    /// Geri sayımın adım aralığı — bir metronom vuruşu kadar
    private let tick: TimeInterval = 0.8

    private let sampleRate: Double = 44_100
    private lazy var format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!

    private var folder: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("CustomSFX", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private func url(for slot: CustomSoundSlot) -> URL {
        folder.appendingPathComponent("\(slot.rawValue).caf")
    }

    private override init() {
        let defaults = UserDefaults.standard
        // Varsayılan açık: kayıt yoksa zaten hiçbir şey değişmiyor
        enabled = defaults.object(forKey: Self.enabledKey) as? Bool ?? true
        super.init()
        refreshRecorded()
    }

    private func refreshRecorded() {
        recorded = Set(CustomSoundSlot.allCases.filter {
            FileManager.default.fileExists(atPath: url(for: $0).path)
        })
    }

    // MARK: Kayıt

    /// Mikrofon izni ister; verilirse üçten geri sayıp kaydı başlatır. Süre
    /// dolunca kendiliğinden durur — oyuncunun "dur" demeyi unutması bir yana,
    /// uzun kayıt zaten işe yaramıyor.
    func startRecording(_ slot: CustomSoundSlot) {
        guard recording == nil, arming == nil else { return }
        requestPermission { [weak self] granted in
            guard let self else { return }
            guard granted else {
                self.micDenied = true
                return
            }
            self.micDenied = false
            self.armRecording(slot)
        }
    }

    /// 3 → 2 → 1 → kayıt. Her adımda kısa bir tık çalar; ekrana bakmadan da
    /// ne zaman başlayacağı belli olsun diye.
    private func armRecording(_ slot: CustomSoundSlot) {
        arming = slot
        countdown = 3
        AudioEngine.shared.playTap()
        for step in 1...3 {
            let work = DispatchWorkItem { [weak self] in
                guard let self, self.arming == slot else { return }
                let left = 3 - step
                self.countdown = left
                if left > 0 {
                    AudioEngine.shared.playTap()
                } else {
                    self.arming = nil
                    self.beginRecording(slot)
                }
            }
            countdownWork.append(work)
            DispatchQueue.main.asyncAfter(deadline: .now() + tick * Double(step), execute: work)
        }
    }

    /// Geri sayarken vazgeçildi
    func cancelArming() {
        countdownWork.forEach { $0.cancel() }
        countdownWork = []
        arming = nil
        countdown = 0
    }

    private func requestPermission(_ done: @escaping (Bool) -> Void) {
        let handler: (Bool) -> Void = { granted in
            DispatchQueue.main.async { done(granted) }
        }
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission(completionHandler: handler)
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission(handler)
        }
    }

    private func beginRecording(_ slot: CustomSoundSlot) {
        countdownWork = []
        countdown = 0
        // Ambient pad mikrofona sızmasın diye motor kayıt boyunca duraklatılır
        AudioEngine.shared.stop()

        let session = AVAudioSession.sharedInstance()
        // Kayıt için oturumu geçici olarak playAndRecord'a alırız; biter bitmez
        // oyunun saygılı `.ambient` kategorisine geri dönülür.
        do {
            try session.setCategory(.playAndRecord, options: [.defaultToSpeaker, .mixWithOthers])
            try session.setActive(true)
        } catch {
            restoreSession()
            return
        }

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsBigEndianKey: false
        ]
        guard let rec = try? AVAudioRecorder(url: url(for: slot), settings: settings) else {
            restoreSession()
            return
        }
        recorder = rec
        recording = slot
        rec.record(forDuration: slot.maxDuration)

        // record(forDuration:) delegate'i her cihazda güvenilir tetiklemiyor;
        // kendi zamanlayıcımız durumu her hâlükârda temizler.
        let work = DispatchWorkItem { [weak self] in self?.finishRecording() }
        stopWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + slot.maxDuration + 0.15, execute: work)
    }

    /// Oyuncu "dur"a bastı — geri sayım sürüyorsa kayıt hiç başlamaz
    func stopRecording() {
        if arming != nil {
            cancelArming()
            return
        }
        guard recording != nil else { return }
        finishRecording()
    }

    private func finishRecording() {
        stopWork?.cancel()
        stopWork = nil
        recorder?.stop()
        recorder = nil
        recording = nil
        restoreSession()
        refreshRecorded()
        applyToEngine()
    }

    private func restoreSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, options: [.mixWithOthers])
        try? session.setActive(true)
        AudioEngine.shared.resume()
    }

    func delete(_ slot: CustomSoundSlot) {
        try? FileManager.default.removeItem(at: url(for: slot))
        refreshRecorded()
        applyToEngine()
    }

    func hasRecording(_ slot: CustomSoundSlot) -> Bool { recorded.contains(slot) }

    /// Ayarlar ekranındaki "dinle" düğmesi
    func preview(_ slot: CustomSoundSlot) {
        guard let buffer = loadBuffer(slot) else { return }
        AudioEngine.shared.playPreview(buffer)
    }

    // MARK: Motora aktarma

    /// Kayıtları (premium ve açıksa) ses motoruna yükler. Premium biterse
    /// motordaki tamponlar boşaltılır ama dosyalar diskte kalır.
    func applyToEngine() {
        guard premiumActive, enabled else {
            AudioEngine.shared.clearCustomSounds()
            return
        }
        var set = CustomSoundSet()
        if let hop = loadBuffer(.hop) {
            set.hopLadder = AudioEngine.shared.pitchLadder(from: hop)
        }
        set.collect = loadBuffer(.collect)
        set.gate = loadBuffer(.gate)
        set.lifeLost = loadBuffer(.lifeLost)
        set.fail = loadBuffer(.fail)
        set.win = loadBuffer(.win)
        AudioEngine.shared.applyCustomSounds(set)
    }

    /// Dosyayı okur, sessiz baş/sonu kırpar, tepe seviyesini eşitler ve uçlara
    /// kısa bir yumuşatma koyar — ham kayıtta tık ve boşluk çok belirgin oluyor.
    private func loadBuffer(_ slot: CustomSoundSlot) -> AVAudioPCMBuffer? {
        let fileURL = url(for: slot)
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let file = try? AVAudioFile(forReading: fileURL) else { return nil }
        let frames = AVAudioFrameCount(file.length)
        guard frames > 0,
              let raw = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: frames),
              (try? file.read(into: raw)) != nil,
              let src = raw.floatChannelData?[0] else { return nil }

        let n = Int(raw.frameLength)
        var samples = [Float](repeating: 0, count: n)
        // Çok kanallı kaydı tek kanala indir (kayıt mono ama cihaz zorlayabiliyor)
        let channels = Int(raw.format.channelCount)
        if channels > 1, let data = raw.floatChannelData {
            for i in 0..<n {
                var sum: Float = 0
                for c in 0..<channels { sum += data[c][i] }
                samples[i] = sum / Float(channels)
            }
        } else {
            for i in 0..<n { samples[i] = src[i] }
        }

        // Sessizlik kırpma
        let threshold: Float = 0.02
        var start = 0
        while start < n, abs(samples[start]) < threshold { start += 1 }
        var end = n - 1
        while end > start, abs(samples[end]) < threshold { end -= 1 }
        guard end > start + 64 else { return nil }
        var trimmed = Array(samples[start...end])

        // Tepe eşitleme
        let peak = trimmed.reduce(Float(0)) { max($0, abs($1)) }
        if peak > 0.0001 {
            let gain = 0.85 / peak
            for i in trimmed.indices { trimmed[i] *= gain }
        }

        // Uçlara rampa (tık sesi olmasın)
        let ramp = min(256, trimmed.count / 4)
        for i in 0..<ramp {
            let g = Float(i) / Float(ramp)
            trimmed[i] *= g
            trimmed[trimmed.count - 1 - i] *= g
        }

        guard let out = AVAudioPCMBuffer(pcmFormat: format,
                                         frameCapacity: AVAudioFrameCount(trimmed.count)),
              let dst = out.floatChannelData?[0] else { return nil }
        out.frameLength = AVAudioFrameCount(trimmed.count)
        for i in trimmed.indices { dst[i] = trimmed[i] }
        return out
    }
}

/// Motora verilen hazır tamponlar
struct CustomSoundSet {
    /// Komboyla tizleşen atlayış sesleri (sentetik dizinin perde oranlarında)
    var hopLadder: [AVAudioPCMBuffer] = []
    var collect: AVAudioPCMBuffer?
    var gate: AVAudioPCMBuffer?
    var lifeLost: AVAudioPCMBuffer?
    var fail: AVAudioPCMBuffer?
    var win: AVAudioPCMBuffer?
}
