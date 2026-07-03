import CoreHaptics
import UIKit

/// Dokunsal geri bildirim: her atlayış parmak ucunda hissedilir.
/// CoreHaptics varsa zengin desenler, yoksa UIKit jeneratörlerine düşer.
final class Haptics {
    static let shared = Haptics()

    var enabled = true

    private var engine: CHHapticEngine?
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notification = UINotificationFeedbackGenerator()

    private init() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        engine = try? CHHapticEngine()
        engine?.resetHandler = { [weak self] in try? self?.engine?.start() }
        try? engine?.start()
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
        if engine != nil {
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
        } else {
            impactHeavy.impactOccurred()
        }
    }

    func win() {
        guard enabled else { return }
        if engine != nil {
            let events = (0..<3).map { i in
                CHHapticEvent(eventType: .hapticTransient, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6 + Float(i) * 0.2),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7)
                ], relativeTime: Double(i) * 0.09)
            }
            play(events: events) { self.notification.notificationOccurred(.success) }
        } else {
            notification.notificationOccurred(.success)
        }
    }

    private func playTransient(intensity: Float, sharpness: Float, fallback: () -> Void) {
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
        ], relativeTime: 0)
        play(events: [event], fallback: fallback)
    }

    private func play(events: [CHHapticEvent], fallback: () -> Void) {
        guard let engine else { fallback(); return }
        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            fallback()
        }
    }
}
