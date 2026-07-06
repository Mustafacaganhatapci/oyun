import Foundation
import GameKit
import UIKit

/// Game Center: dünya sıralaması (sonsuz mod skoru + speed run süresi).
/// Kimlik doğrulama başarısız olursa oyun sessizce çevrimdışı devam eder.
@MainActor
final class GameCenterService: NSObject, ObservableObject {
    static let endlessLeaderboardID = "lumo.endless"
    static let speedrunLeaderboardID = "lumo.speedrun"

    @Published private(set) var isAuthenticated = false
    private var didStartAuth = false

    func authenticate() {
        guard !didStartAuth else { return }   // handler yalnızca bir kez kurulur
        didStartAuth = true
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, _ in
            Task { @MainActor in
                if let viewController {
                    Self.rootViewController()?.present(viewController, animated: true)
                } else {
                    self?.isAuthenticated = GKLocalPlayer.local.isAuthenticated
                }
            }
        }
    }

    /// Sonsuz mod skoru gönder
    func submitEndless(score: Int) {
        guard isAuthenticated, score > 0 else { return }
        Task {
            try? await GKLeaderboard.submitScore(score, context: 0, player: GKLocalPlayer.local,
                                                 leaderboardIDs: [Self.endlessLeaderboardID])
        }
    }

    /// Speed run süresi gönder (Game Center'da saniyenin yüzde biri cinsinden saklanır)
    func submitSpeedrun(seconds: Double) {
        guard isAuthenticated, seconds > 0 else { return }
        Task {
            try? await GKLeaderboard.submitScore(Int(seconds * 100), context: 0, player: GKLocalPlayer.local,
                                                 leaderboardIDs: [Self.speedrunLeaderboardID])
        }
    }

    /// Dünya sıralaması ekranını aç.
    /// Oyuncu Game Center'a giriş yapmamışsa (ör. ücretsiz geliştirici hesabında
    /// Game Center kapalıysa) önce girişi dener, açık değilse sessizce hiçbir şey yapmaz.
    func showLeaderboards() {
        guard isAuthenticated else {
            authenticate()
            return
        }
        let vc = GKGameCenterViewController(state: .leaderboards)
        vc.gameCenterDelegate = self
        Self.rootViewController()?.present(vc, animated: true)
    }

    private static func rootViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow?.rootViewController }
            .first
    }
}

extension GameCenterService: GKGameCenterControllerDelegate {
    func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        gameCenterViewController.dismiss(animated: true)
    }
}
