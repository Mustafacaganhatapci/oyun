import Foundation

/// Haftalık tablo boş başlamasın diye eklenen doldurma oyuncuları.
///
/// Pazartesi sabahı tablo bomboş açılıyor; kimse boş bir sıralamaya oynamıyor.
/// Burası o boşluğu dolduruyor ama dört kural var:
///
///  1. Hepsi aynı anda belirmez. Her birinin haftanın içinde kendi görünme anı
///     var; tablo hafta boyunca doluyor, tek seferde patlamıyor.
///  2. Gerçek oyunculara dokunulmaz. Şampiyonluk ödülü hesabı doldurmaları
///     hiç saymaz — kimse gerçek bir insanın yıldızını kapmaz.
///  3. Her hafta ve her modda başka insanlar. Adlar da skorlar da hafta
///     numarasıyla moddan türetiliyor; ne geçen haftanın listesi tekrar
///     ediyor ne de iki tablo aynı kalabalığı gösteriyor.
///  4. İşi biten silinir. Bir haftanın doldurmaları hafta biter bitmez
///     temizleniyor — bkz. `LeaderboardService.pruneSeeds`.
///
/// Sayılar Firestore'daki `config/leaderboard` belgesinden ayarlanır; kod
/// sabitleri yalnızca o belge yoksa kullanılır.
enum LeaderboardSeed {

    /// Doldurma belgelerinin kuşağı. Ad üretimi ya da dağılım değişince
    /// artırılır: eski kuşaktan kalan belgeler böylece tanınıp siliniyor,
    /// aynı haftada iki farklı üretimin yan yana durması engelleniyor.
    static let generation = 4

    /// `config/leaderboard` alanları
    struct Config {
        var enabled = true
        /// İlk 50'de kaç doldurma görünsün — asıl tabloyu dolduran sayı bu
        var target = 50
        /// Haftanın toplam doldurma nüfusu. `target` üstündekiler tablonun
        /// altında kalır: dünya kalabalık görünür ama görünen 50 satırın
        /// dengesi bozulmaz.
        ///
        /// 500 değil 327: yuvarlak sayı sayılmış gibi duruyor. Gerçek bir
        /// haftanın oyuncu sayısı 500'de bitmez. Firestore'daki
        /// `botPopulation` alanından değiştirilebilir.
        var population = 327
        var endlessBest = 33     // ilk 50'deki en iyi doldurmanın skoru
        var endlessWorst = 6     // ilk 50'deki en kötüsü
        // Hız turu süreleri saniye; düşük olan iyi. Eskiden en iyi doldurma
        // 52 saniye koşuyordu — on bölümün gerçekçi tavanı 1:59 civarındayken
        // bu, tablonun tepesini insanın giremeyeceği bir yere kapatıyordu.
        // Şimdi en iyisi 2:12: Kuazar'a değiyor, Zirve gerçek oyuncularda
        // kalıyor.
        var speedrunBest = 132.0
        var speedrunWorst = 260.0

        static let `default` = Config()
    }

    // MARK: Adlar
    //
    // Üç havuz karışıyor: gerçek adlar, tek kelimelik takma adlar ve sıfat+ad
    // birleşimleri. Beş yüz satırın hepsi "Deniz", "Kerem" olsaydı liste
    // insan listesine değil ad listesine benzerdi; oyuncuların yarısı zaten
    // kendine takma ad koyuyor.

    /// Türkçe ve yabancı gerçek adlar. Belirli bir kişiyi işaret etmesin diye
    /// hepsi tek kelime ve yaygın.
    static let firstNames: [String] = [
        "Deniz", "Kerem", "Elif", "Barış", "Zeynep", "Emre", "Selin", "Mert",
        "Aslı", "Tuna", "Ceren", "Yiğit", "Ece", "Berk", "Sude", "Kaan",
        "Melis", "Arda", "Nehir", "Doruk", "Bade", "Efe", "İpek", "Sarp",
        "Mika", "Luca", "Nora", "Theo", "Ines", "Kai", "Alma", "Ravi",
        "Sora", "Milo", "Yuki", "Iva", "Otto", "Nina", "Leo", "Zara",
        "Anton", "Mira", "Elias", "Sena", "Noa", "Bruno", "Lina", "Hugo",
        "Aylin", "Cem", "Duru", "Kuzey", "Rüzgar", "Alp", "Sıla", "Toprak",
        "Ada", "Poyraz", "Ayaz", "Işık", "Bora", "Derin", "Ekin", "Umut",
        "Pınar", "Tarık", "Ozan", "Vera", "Ilya", "Nils", "Emil", "Suna",
        "Jonas", "Amira", "Dilara", "Kian", "Rana", "Timur", "Yasin", "Lale",
        "Aren", "Bilge", "Cansu", "Halit", "Miray", "Onur", "Şevval", "Ulaş"
    ]

    /// Tek kelimelik takma adlar. Küçük harf: oyuncuların kendi yazdığı gibi.
    static let handles: [String] = [
        "gecekusu", "kuytu", "pusula", "zeplin", "karabatak", "yelkovan",
        "kivilcim", "alacakaranlik", "kutup", "kervan", "mercan", "obruk",
        "panjur", "sisliyol", "tozduman", "yankibey", "camasir", "kirlangic",
        "denizfeneri", "gemici", "harita", "kumsaat", "mandal", "nazar",
        "orakci", "pervane", "salkim", "tavuskusu", "uskumru", "vapur",
        "yakamoz", "zeytin", "bozkir", "cakil", "dolunay", "eflatun",
        "orbit", "nebula", "vortex", "glitch", "pixel", "static", "quasar",
        "cinder", "driftwood", "moonlit", "halogen", "signal", "lowbeam",
        "nightowl", "tinyrocket", "saltwater", "paperjet", "coldbrew",
        "backspace", "loopback", "sandstorm", "wintergreen", "bluehour",
        "afterglow", "sparrow", "duskfall", "ironwood", "quicksand",
        "hollowpoint", "riverbend", "tundra", "monsoon", "lantern"
    ]

    static let adjectives: [String] = [
        "hizli", "sessiz", "yalniz", "kizil", "mavi", "derin", "uzak",
        "keskin", "serin", "yaman", "cevik", "gizli", "parlak", "sakin",
        "silent", "rapid", "lucky", "tiny", "north", "late", "wild",
        "calm", "neon", "solar", "quiet", "half", "double", "midnight"
    ]

    static let nouns: [String] = [
        "kartal", "balina", "tilki", "sahin", "kunduz", "yosun", "fener",
        "kuyruk", "kirpi", "sincap", "martı", "ceylan",
        "fox", "wolf", "comet", "moth", "pixel", "tide", "echo", "drift",
        "ember", "stone", "koala", "panda", "otter", "raven", "finch"
    ]

    /// Bir doldurmanın kimliği. `bot_` önekiyle başlar: konsolda ayırt
    /// edilebilsin, gerçek playerID'lerle asla çakışmasın. Kuşak numarası da
    /// içeride: eski üretimden kalanlar bu sayede tanınıp siliniyor.
    static func prefix(week: Int) -> String { "bot_w\(week)_g\(generation)_" }

    static func documentID(week: Int, index: Int) -> String {
        prefix(week: week) + String(format: "%03d", index)
    }

    static func isSeed(_ documentID: String) -> Bool { documentID.hasPrefix("bot_") }

    /// Bu haftanın güncel üretiminden mi? Değilse temizlenecek demektir.
    static func isCurrentGeneration(_ documentID: String, week: Int) -> Bool {
        documentID.hasPrefix(prefix(week: week))
    }

    /// Bir doldurmanın adı. Hafta, sıra VE moddan türetilir; her cihaz aynı adı
    /// üretir, gelecek hafta liste baştan değişir, ve sonsuz mod ile hız turu
    /// birbirinden bağımsız iki kalabalık taşır.
    ///
    /// Mod başta hesaba katılmıyordu: iki tablo da aynı beş yüz adı gösteriyor,
    /// modlar arasında geçiş yapan oyuncu aynı listeye bakıyordu.
    static func name(week: Int, index: Int, mode: LeaderboardMode) -> String {
        let modeSalt: UInt64 = mode == .endless ? 0x2C1B_A75F : 0xE95F_31D0
        var rng = SplitMix64(seed: UInt64(bitPattern: Int64(week &* 22861 &+ index &* 48271))
                             ^ 0x9E37_79B9 ^ modeSalt)
        let pattern = Int(rng.unit() * 100)
        let first = firstNames[Int(rng.unit() * Double(firstNames.count)) % firstNames.count]
        let handle = handles[Int(rng.unit() * Double(handles.count)) % handles.count]
        let adjective = adjectives[Int(rng.unit() * Double(adjectives.count)) % adjectives.count]
        let noun = nouns[Int(rng.unit() * Double(nouns.count)) % nouns.count]
        let number = 7 + Int(rng.unit() * 92)

        // Düz adlar bilerek azınlıkta. Beş yüz satırın çoğu düz ad olsaydı
        // seksen sekiz adlık havuz defalarca dönerdi; takma adlar hem daha
        // gerçekçi hem de kombinasyonları bitmiyor.
        switch pattern {
        case ..<14:  return first                              // Deniz
        case ..<30:  return handle                             // yakamoz
        case ..<52:  return adjective + noun                   // sessizkartal
        case ..<68:  return "\(handle)\(number)"               // orbit42
        case ..<82:  return "\(first.lowercased())_\(number)"  // deniz_18
        case ..<92:  return "\(adjective)_\(noun)"             // neon_raven
        default:     return "\(adjective)\(noun)\(number)"     // wildotter77
        }
    }

    /// Bu hafta, ŞU ANA KADAR görünmesi gereken doldurmalar.
    ///
    /// Üretim tamamen hafta numarasından türetiliyor: her cihaz aynı adı, aynı
    /// skoru ve aynı görünme anını hesaplıyor. Böylece kim önce açarsa açsın
    /// tablo herkeste aynı görünüyor ve aynı belge iki kez yazılmıyor.
    ///
    /// Adlar tüm nüfus için önce üretilip TEKİLLEŞTİRİLİYOR: beş yüz satırda
    /// iki tane "Deniz" görmek hatalı görünürdü.
    static func due(week: Int, mode: LeaderboardMode, config: Config,
                    weekStart: TimeInterval, weekLength: TimeInterval,
                    now: TimeInterval = Date().timeIntervalSince1970) -> [(id: String, name: String, value: Double)] {
        guard config.enabled, config.target > 0, config.population > 0 else { return [] }

        let total = max(config.target, config.population)
        var used = Set<String>()
        var out: [(id: String, name: String, value: Double)] = []

        for i in 0..<total {
            // Adı zamanı gelmemiş olanlar için de üretiyoruz: tekilleştirme
            // ancak nüfusun tamamı görüldüğünde her cihazda aynı sonucu verir.
            // Çakışma olursa iki haneli bir sayı ekleniyor — "Deniz2" değil
            // "Deniz34". Sıra numarası eklemek listenin uydurma olduğunu
            // ilk bakışta ele verirdi.
            var candidate = name(week: week, index: i, mode: mode)
            if used.contains(candidate) {
                let base = candidate
                var tag = 11 + (i &* 37) % 88
                var tries = 0
                while used.contains("\(base)\(tag)"), tries < 88 {
                    tag = 11 + (tag &+ 7) % 88
                    tries += 1
                }
                // 88 deneme de tutmazsa sıraya düş: bu noktada zaten
                // gerçekçilik değil, tekillik önemli
                candidate = used.contains("\(base)\(tag)") ? "\(base)_\(i)" : "\(base)\(tag)"
            }
            used.insert(candidate)

            var rng = SplitMix64(seed: UInt64(bitPattern: Int64(week &* 7919 &+ i &* 104729))
                                 ^ (mode == .endless ? 0x51ED : 0xA37F))

            let inBand = i < config.target

            // Görünme anı. Düz dağıtmak yanlıştı: beş yüz kişi haftaya eşit
            // yayılınca tablo pazartesi neredeyse boş açılıyor, kalabalık ancak
            // cuma toplanıyordu. İki hızda geliyorlar:
            //  • İlk 50 (tabloda görünen bant) haftanın ilk %4'ünde, yani
            //    yaklaşık altı saatte — sabah açan boş tablo görmesin.
            //  • Geri kalanı haftanın ilk %90'ına ama KARESİYLE: yarısı ilk
            //    bir buçuk günde, kuyruğu haftanın sonuna kadar sürüyor.
            // Son gün kimse belirmesin — hafta biterken yeni ad düşmesi tuhaf.
            let u = Double(rng.unit())
            let at = inBand
                ? weekStart + u * weekLength * 0.04
                : weekStart + u * u * weekLength * 0.90
            guard now >= at else { continue }

            let t = Double(rng.unit())
            let value: Double
            switch mode {
            case .endless:
                if inBand {
                    // Yüksek skorlar seyrek: t'yi kareleyerek dağılımı aşağı çekiyoruz
                    let span = Double(config.endlessBest - config.endlessWorst)
                    value = (Double(config.endlessWorst) + span * (t * t)).rounded()
                } else {
                    // Tablonun altında kalan kalabalık: ilk 50'nin en kötüsünün
                    // altında, ama 1'in altına inmiyor (0 skorlar okunurken elenir)
                    let floorValue = 1.0
                    let ceiling = max(floorValue, Double(config.endlessWorst) - 1)
                    value = (floorValue + (ceiling - floorValue) * t).rounded()
                }
            case .speedrun:
                if inBand {
                    let span = config.speedrunWorst - config.speedrunBest
                    value = config.speedrunWorst - span * (t * t)
                } else {
                    // Hız turunda kötü olmak yavaş olmaktır
                    value = config.speedrunWorst + (config.speedrunWorst * 0.7) * t
                }
            }
            out.append((documentID(week: week, index: i), candidate, value))
        }
        return out
    }
}
