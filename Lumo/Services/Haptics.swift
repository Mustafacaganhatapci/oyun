import CoreHaptics
import UIKit

/// Dokunsal geri bildirim: her atlayış parmak ucunda hissedilir.
/// CoreHaptics varsa zengin desenler, yoksa UIKit jeneratörlerine düşer.
final class Haptics {
    static let shared = Haptics()

    var enabled = true

    private var engine: CHHapticEngine?
    /// Motor ŞU AN çalışıyor mu. iOS motoru boşta kalınca ya da uygulama arka
    /// plana gidince durduruyor; eskiden yalnızca init'te bir kez start()
    /// çağrılıyordu, ilk arka plan dönüşünden sonra titreşim tamamen kesiliyordu.
    private var running = false
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notification = UINotificationFeedbackGenerator()

    private init() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        engine = try? CHHapticEngine()
        // Ses oturumu `.ambient` ve kullanıcının kendi müziğiyle karışıyor;
        // motor ses üretmeye kalkarsa oturumla çakışır.
        engine?.playsHapticsOnly = true
        engine?.isAutoShutdownEnabled = true
        // `running` yalnızca ana iş parçacığından yazılır; bu geri çağrımlar
        // rastgele bir kuyruktan gelebiliyor.
        engine?.resetHandler = { [weak self] in
            DispatchQueue.main.async { self?.running = false }
        }
        engine?.stoppedHandler = { [weak self] _ in
            DispatchQueue.main.async { self?.running = false }
        }
        impactLight.prepare()
        impactHeavy.prepare()
        notification.prepare()
    }

    /// Motoru gerektiği anda başlatır. Açılışta bir kez başlatmak yetmiyordu:
    /// uygulama daha etkin değilken start() sessizce başarısız olabiliyor.
    private func ensureRunning() -> Bool {
        guard let engine else { return false }
        if running { return true }
        do {
            try engine.start()
            running = true
            return true
        } catch {
            running = false
            return false
        }
    }

    func hop() {
        guard enabled else { return }
        playTransient(intensity: 0.5, sharpness: 0.65) { self.impactLight.impactOccurred() }
    }

    func collect() {
        guard enabled else { return }
        playTransient(intensity: 0.7, sharpness: 0.9) { self.impactLight.impactOccurred(intensity: 0.8) }
    }

    func fail() {
        guard enabled else { return }
        let events = [
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
            ], relativeTime: 0),
            CHHapticEvent(eventType: .hapticContinuous, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
            ], relativeTime: 0.02, duration: 0.16)
        ]
        play(events: events) { self.impactHeavy.impactOccurred() }
    }

    func win() {
        guard enabled else { return }
        let events = (0..<3).map { i in
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6 + Float(i) * 0.2),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7)
            ], relativeTime: Double(i) * 0.09)
        }
        play(events: events) { self.notification.notificationOccurred(.success) }
    }

    private func playTransient(intensity: Float, sharpness: Float, fallback: () -> Void) {
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
        ], relativeTime: 0)
        play(events: [event], fallback: fallback)
    }

    private func play(events: [CHHapticEvent], fallback: () -> Void) {
        guard ensureRunning(), let engine else { fallback(); return }
        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            // Motor arada durmuş olabilir: bir kez tazeleyip yeniden dene,
            // yine olmazsa UIKit jeneratörüne düş.
            running = false
            if ensureRunning(),
               let pattern = try? CHHapticPattern(events: events, parameters: []),
               let player = try? engine.makePlayer(with: pattern),
               (try? player.start(atTime: 0)) != nil {
                return
            }
            fallback()
        }
    }
}
