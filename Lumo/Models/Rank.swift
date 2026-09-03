import SwiftUI

/// Sıralamadaki rütbeler.
///
/// Elli satırlık düz bir liste bir şey anlatmıyor: 41. olmakla 39. olmak
/// arasında bir his farkı yok. Rütbe onu veriyor — hangi kümede olduğunu
/// görüyorsun, bir üstündeki kümeye ne kadar kaldığını da.
///
/// Eşikler tema değil: renkleri sabit. Bir rütbe herkeste aynı görünmeli,
/// yoksa "mor olan iyidir" gibi ortak bir dil kurulamaz.
enum Rank: Int, CaseIterable, Identifiable {
    case spark = 0, ember, beacon, pulsar, quasar, zenith

    var id: Int { rawValue }

    /// Sonsuz modda bu rütbeye giriş skoru.
    ///
    /// Eşikler doldurmaların tavanına göre ayarlı: en iyi doldurma 33 atlıyor,
    /// yani Pulsar'a ancak değiyor. Kuazar ve Zirve'ye yalnızca gerçek insanlar
    /// çıkabiliyor — en üst iki basamak uydurma bir isimle dolmasın.
    static let endlessFloor: [Int] = [1, 8, 16, 28, 45, 70]

    /// Hız turunda bu rütbenin ÜST süre sınırı (saniye) — altında kalan girer.
    /// İlk eleman sonsuz: en alt rütbeye herkes girer.
    ///
    /// Eşikler baştan çok iyimserdi: Zirve 50 saniye istiyordu, oysa on bölümün
    /// gerçekte inebildiği yer 1:59 civarı. Üst üç basamak kimsenin
    /// giremeyeceği bir yerdeydi, yani hiç yokmuş gibiydi. Artık Zirve 2:05'in
    /// altı — zor ama insan işi.
    static let speedrunCeiling: [Double] = [.infinity, 240, 200, 170, 145, 125]

    /// Adlar bilerek ışığın şiddetine göre: kıvılcımdan zirveye. Hiçbiri
    /// küre stili ya da tema adıyla çakışmıyor (Nova, Comet, Aurora hepsi
    /// başka şeylerin adı) — biri karakter, biri arka plan, biri rütbe;
    /// üçü karışsa oyuncu neyi kazandığını anlamaz.
    var title: LocalizedStringKey {
        switch self {
        case .spark:  return "Spark"
        case .ember:  return "Ember"
        case .beacon: return "Beacon"
        case .pulsar: return "Pulsar"
        case .quasar: return "Quasar"
        case .zenith: return "Zenith"
        }
    }

    /// Griden turuncuya, altına, camgöbeğine, mora, en üstte beyaza.
    /// Sıcaklık değil parlaklık artıyor — yukarı çıkmak "daha aydınlık".
    var color: Color {
        switch self {
        case .spark:  return Color(red: 0.54, green: 0.58, blue: 0.65)
        case .ember:  return Color(red: 0.91, green: 0.53, blue: 0.24)
        case .beacon: return Color(red: 0.94, green: 0.77, blue: 0.23)
        case .pulsar: return Color(red: 0.27, green: 0.78, blue: 0.88)
        case .quasar: return Color(red: 0.64, green: 0.42, blue: 0.96)
        case .zenith: return Color(red: 0.92, green: 0.95, blue: 1.00)
        }
    }

    /// Bir sonucun rütbesi
    static func of(value: Double, mode: LeaderboardMode) -> Rank {
        switch mode {
        case .endless:
            var found = Rank.spark
            for rank in allCases where Int(value) >= endlessFloor[rank.rawValue] { found = rank }
            return found
        case .speedrun:
            var found = Rank.spark
            for rank in allCases where value < speedrunCeiling[rank.rawValue] { found = rank }
            return found
        }
    }

    /// Rütbe aralığının okunur hâli — cetvelde gösteriliyor
    func rangeText(mode: LeaderboardMode) -> String {
        switch mode {
        case .endless:
            let low = Self.endlessFloor[rawValue]
            guard rawValue < Self.allCases.count - 1 else { return "\(low)+" }
            return "\(low)–\(Self.endlessFloor[rawValue + 1] - 1)"
        case .speedrun:
            let f = Self.clock
            guard rawValue > 0 else { return "\(f(Self.speedrunCeiling[1]))+" }
            guard rawValue < Self.allCases.count - 1 else { return "< \(f(Self.speedrunCeiling[rawValue]))" }
            return "\(f(Self.speedrunCeiling[rawValue + 1]))–\(f(Self.speedrunCeiling[rawValue]))"
        }
    }

    /// Cetveldeki süreler salise istemiyor: "1:45", "1:45.00" değil
    private static func clock(_ t: Double) -> String {
        String(format: "%d:%02d", Int(t) / 60, Int(t) % 60)
    }
}

/// Rütbe nişanı: oyunun kendi dilinde küçük bir küre. Simge yerine küre,
/// çünkü ekranın geri kalanı zaten kürelerden oluşuyor.
struct RankBadge: View {
    let rank: Rank
    var size: CGFloat = 16

    var body: some View {
        Circle()
            .fill(
                RadialGradient(colors: [.white.opacity(0.9), rank.color],
                               center: UnitPoint(x: 0.35, y: 0.3),
                               startRadius: 0, endRadius: size * 0.7)
            )
            .frame(width: size, height: size)
            .overlay(Circle().strokeBorder(.white.opacity(0.25), lineWidth: 0.5))
            .shadow(color: rank.color.opacity(0.8), radius: size * 0.3)
    }
}
