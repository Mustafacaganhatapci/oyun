import Foundation

/// Haftalık tablo boş başlamasın diye eklenen doldurma oyuncuları.
///
/// Pazartesi sabahı tablo bomboş açılıyor; kimse boş bir sıralamaya oynamıyor.
/// Burası o boşluğu dolduruyor ama iki kural var:
///
///  1. Hepsi aynı anda belirmez. Her birinin haftanın içinde kendi görünme anı
///     var; tablo hafta boyunca doluyor, tek seferde patlamıyor.
///  2. Gerçek oyunculara dokunulmaz. Doldurmalar yalnızca ilk 50'de boş kalan
///     yere girer, ve şampiyonluk ödülü hesabı onları hiç saymaz — kimse
///     gerçek bir insanın yıldızını kapmaz.
///
/// Sayılar Firestore'daki `config/leaderboard` belgesinden ayarlanır; kod
/// sabitleri yalnızca o belge yoksa kullanılır.
enum LeaderboardSeed {

    /// `config/leaderboard` alanları
    struct Config {
        var enabled = true
        var target = 50          // ilk kaç sırayı dolu tutmaya çalışalım
        var endlessBest = 33     // en iyi doldurmanın skoru
        var endlessWorst = 6     // en kötüsü
        var speedrunBest = 52.0  // saniye — hız turunda düşük olan iyi
        var speedrunWorst = 145.0

        static let `default` = Config()
    }

    /// Türkçe ve yabancı adlar karışık. Gerçek bir kişiyi işaret etmesin diye
    /// hepsi tek kelime, yaygın ad ya da takma ad.
    static let names: [String] = [
        "Deniz", "Kerem", "Elif", "Barış", "Zeynep", "Emre", "Selin", "Mert",
        "Aslı", "Tuna", "Ceren", "Yiğit", "Ece", "Berk", "Sude", "Kaan",
        "Melis", "Arda", "Nehir", "Doruk", "Bade", "Efe", "İpek", "Sarp",
        "Mika", "Luca", "Nora", "Theo", "Ines", "Kai", "Alma", "Ravi",
        "Sora", "Milo", "Yuki", "Iva", "Otto", "Nina", "Leo", "Zara",
        "Anton", "Mira", "Elias", "Sena", "Noa", "Bruno", "Lina", "Hugo",
        "Aylin", "Cem", "Duru", "Kuzey", "Rüzgar", "Alp", "Sıla", "Toprak"
    ]

    /// Bir doldurmanın kimliği. `bot_` önekiyle başlar: konsolda ayırt
    /// edilebilsin, gerçek playerID'lerle asla çakışmasın.
    static func documentID(week: Int, index: Int) -> String {
        String(format: "bot_w%d_%02d", week, index)
    }

    static func isSeed(_ documentID: String) -> Bool { documentID.hasPrefix("bot_") }

    /// Bu hafta, ŞU ANA KADAR görünmesi gereken doldurmalar.
    ///
    /// Üretim tamamen hafta numarasından türetiliyor: her cihaz aynı adı, aynı
    /// skoru ve aynı görünme anını hesaplıyor. Böylece kim önce açarsa açsın
    /// tablo herkeste aynı görünüyor ve aynı belge iki kez yazılmıyor.
    static func due(week: Int, mode: LeaderboardMode, config: Config,
                    weekStart: TimeInterval, weekLength: TimeInterval,
                    now: TimeInterval = Date().timeIntervalSince1970) -> [(id: String, name: String, value: Double)] {
        guard config.enabled, config.target > 0 else { return [] }

        var out: [(id: String, name: String, value: Double)] = []
        for i in 0..<config.target {
            var rng = SplitMix64(seed: UInt64(bitPattern: Int64(week &* 7919 &+ i &* 104729))
                                 ^ (mode == .endless ? 0x51ED : 0xA37F))

            // Görünme anı: haftanın ilk %90'ına yayılır. Son gün kimse
            // belirmesin — hafta biterken tabloya yeni ad düşmesi tuhaf durur.
            let at = weekStart + Double(rng.unit()) * weekLength * 0.90
            guard now >= at else { continue }

            let name = names[Int(rng.unit() * Double(names.count)) % names.count]
            let t = Double(rng.unit())
            let value: Double
            switch mode {
            case .endless:
                // Yüksek skorlar seyrek: t'yi kareleyerek dağılımı aşağı çekiyoruz
                let span = Double(config.endlessBest - config.endlessWorst)
                value = (Double(config.endlessWorst) + span * (t * t)).rounded()
            case .speedrun:
                let span = config.speedrunWorst - config.speedrunBest
                value = config.speedrunWorst - span * (t * t)
            }
            out.append((documentID(week: week, index: i), name, value))
        }
        return out
    }
}
