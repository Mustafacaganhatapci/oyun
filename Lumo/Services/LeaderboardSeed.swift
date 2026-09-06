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
    static let generation = 6

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
    // Gerçek bir sıralama BAKIMSIZ görünür. Önceki havuz kelime seçkisi
    // gibiydi — "alacakaranlik", "wintergreen", "duskfall" — ve üstüne
    // sıfat+ad birleştiriyordu: "sessizkartal", "wildotter77". O kalıp
    // makine üretimi listelerin imzasıdır; kimse kendine sıfat seçip ad
    // yapıştırmıyor. İnsanlar adını yazıyor, sesli harfleri düşürüyor,
    // arkasına doğum yılını ya da plakasını ekliyor, harfi iki kere basıyor.
    //
    // Havuzlar buna göre: adlar, kısaltmalar, birkaç düz kelime ve GERÇEK
    // sayılar. Süsleme yok.

    /// Türkçe ve yabancı gerçek adlar. Belirli bir kişiyi işaret etmesin diye
    /// hepsi tek kelime ve yaygın.
    static let firstNames: [String] = [
        "Deniz", "Kerem", "Elif", "Barış", "Zeynep", "Emre", "Selin", "Mert",
        "Aslı", "Tuna", "Ceren", "Yiğit", "Ece", "Berk", "Sude", "Kaan",
        // Buradaki adların hepsi hem küçük hem büyük harfe SORUNSUZ dönüyor.
        // "İpek" ve "Işık" havuzdan çıktı: Swift'in yerelden bağımsız
        // `lowercased()` çağrısı "İ"yi birleşik noktalı bir "i̇"ye çeviriyor,
        // "I"yı da noktalı "i" yapıp "işık" gibi yanlış yazımlar üretiyordu.
        "Melis", "Arda", "Nehir", "Doruk", "Bade", "Efe", "Irmak", "Sarp",
        "Mika", "Luca", "Nora", "Theo", "Ines", "Kai", "Alma", "Ravi",
        "Sora", "Milo", "Yuki", "Iva", "Otto", "Nina", "Leo", "Zara",
        "Anton", "Mira", "Elias", "Sena", "Noa", "Bruno", "Lina", "Hugo",
        "Aylin", "Cem", "Duru", "Kuzey", "Rüzgar", "Alp", "Sıla", "Toprak",
        "Ada", "Poyraz", "Ayaz", "Ayla", "Bora", "Derin", "Ekin", "Umut",
        "Pınar", "Tarık", "Ozan", "Vera", "Ilya", "Nils", "Emil", "Suna",
        "Jonas", "Amira", "Dilara", "Kian", "Rana", "Timur", "Yasin", "Lale",
        "Aren", "Bilge", "Cansu", "Halit", "Miray", "Onur", "Şevval", "Ulaş"
    ]

    /// Sesli harfleri düşmüş kısaltmalar. Bir oyun hesabına en çok yazılan
    /// şey bu: adın kendisi değil, üç dört harfi.
    static let shortNames: [String] = [
        "mrt", "brk", "krm", "zynp", "cnr", "srkn", "onr", "efe", "ahmt",
        "hsn", "ylmz", "tlha", "byrm", "kvn", "sdt", "brc", "gkhn", "mstf",
        "elf", "slm", "ozn", "arda", "ecm", "nzm", "rmzn", "svg", "ynk",
        "mke", "nte", "jke", "tmy", "alx", "chrs", "mtt", "sm", "dnl",
        "krl", "sbn", "vlk", "ykt", "dgn", "hkn", "cgn", "brn", "ekn"
    ]

    /// Düz kelimeler. Az ve sıradan: kimse kendine şiir seçmiyor, aklına
    /// ilk geleni yazıyor.
    static let words: [String] = [
        "kartal", "zeytin", "pusula", "dolunay", "fener", "sincap", "tilki",
        "balina", "kirpi", "vapur", "nazar", "yakamoz", "bozkir", "mercan",
        "pixel", "orbit", "comet", "otter", "raven", "panda", "wolf",
        "static", "signal", "tundra", "lantern", "sparrow", "echo", "drift"
    ]

    /// Ada yapıştırılan ön ekler. "by" Türk oyun kültürünün klasiği,
    /// "mr"/"the"/"lil" karşılığı.
    static let prefixes: [String] = ["by", "by", "mr", "the", "lil", "kral", "efsane"]

    /// Adın arkasındaki sayı UYDURMA OLMASIN. Önceki sürüm 7 ile 98 arası
    /// rastgele sayı basıyordu; gerçek hesaplarda o sayı bir şeydir —
    /// doğum yılı, plaka, kuruluş yılı ya da klavyeye üç kez basmak.
    static let tags: [String] = [
        "34", "06", "35", "41", "16", "61", "27", "07", "55", "42", "01",
        "31", "38", "21", "26", "44", "52",                       // plaka
        "95", "96", "97", "98", "99", "00", "01", "02", "03", "04",
        "05", "06", "07", "08", "09", "10", "11", "12",           // doğum yılı
        "1998", "2003", "2005", "2007", "2010", "2012",
        "1903", "1905", "1907",                                   // kuruluş
        "11", "22", "77", "99", "123", "1234", "10", "23", "45"
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
        let first = pick(firstNames, &rng)
        let short = pick(shortNames, &rng)
        let word = pick(words, &rng)
        let tag = pick(tags, &rng)
        let prefix = pick(prefixes, &rng)
        let separator = pick(["_", ".", ""], &rng)
        let lower = first.lowercased()

        // Gerçek bir tabloda yazım da dağınıktır: aynı ad kimi satırda büyük
        // harfle, kimi satırda küçük başlar. Tek biçime sokmak listeyi
        // tek elden yazılmış gibi gösteriyordu.
        switch pattern {
        case ..<15:  return first                          // Deniz
        case ..<26:  return lower                          // deniz
        case ..<31:  return first.uppercased()             // DENIZ
        case ..<45:  return lower + tag                    // deniz34
        case ..<53:  return lower + separator + tag        // kaan.07
        case ..<62:  return short                          // mrt
        case ..<71:  return short + tag                    // brk61
        case ..<78:  return prefix + first                 // byEmre
        case ..<85:  return word                           // zeytin
        case ..<93:  return word + tag                     // pixel07
        // Adı alınmış olanın klasik çözümü: son harfe bir daha basmak
        default:     return lower + String(lower.last ?? "a")   // emree
        }
    }

    /// Havuzdan deterministik seçim — her cihaz aynı sırayı üretsin diye
    /// tek yerde
    private static func pick<T>(_ list: [T], _ rng: inout SplitMix64) -> T {
        list[min(list.count - 1, Int(rng.unit() * Double(list.count)))]
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
            //
            // Çakışanın çözümü ADI BAŞTAN ÇEKMEK. Eskiden sonuna iki haneli
            // bir sayı yapıştırılıyordu; "kartal47" tek başına masum ama
            // çakışmalar aynı küçük havuzlarda toplandığı için tabloda alt
            // alta rastgele sayılı satırlar birikiyordu. Yeniden çekilen ad
            // hangi kalıba düşerse düşsün gerçek görünüyor.
            var candidate = name(week: week, index: i, mode: mode)
            var reroll = 0
            while used.contains(candidate), reroll < 12 {
                reroll += 1
                candidate = name(week: week, index: i &+ reroll &* 9973, mode: mode)
            }
            if used.contains(candidate) {
                // On iki deneme de tutmadı: bu noktada gerçekçilik değil,
                // tekillik önemli
                candidate += "_\(i)"
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
                    // Hız turunda kötü olmak yavaş olmaktır — ama bir sınıra
                    // kadar. Yayılım %70'ti ve tablonun dibi 7:22'ye kadar
                    // çıkıyordu; on bölümü altı buçuk dakikada bitiren biri
                    // oynamıyor, telefonu bırakmış demektir. %25 ile en yavaş
                    // satır 5:25'te kalıyor: acemi ama gerçek bir oyuncu.
                    value = config.speedrunWorst + (config.speedrunWorst * 0.25) * t
                }
            }
            out.append((documentID(week: week, index: i), candidate, value))
        }
        return out
    }
}
