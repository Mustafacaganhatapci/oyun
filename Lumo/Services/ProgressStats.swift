import Foundation

/// "İnsanlar en fazla hangi bölüme kadar gelmiş?"
///
/// Bu soruya bugüne kadar cevap veremiyorduk. Sıralama yalnızca sonsuz mod ve
/// hız turunu tutuyor, kampanya ilerlemesi hiçbir yere yazılmıyordu; yani
/// oyuncuların oyunu nerede bıraktığı görülmüyordu. Bir bölüm çok zorsa,
/// bir bölüm bozuksa ya da insanlar 12'de toptan gidiyorsa bunu ancak birinin
/// yazıp söylemesiyle öğrenebilirdik.
///
/// Toplanan şey bir SAYAÇ, bir kayıt değil: "kaç kişi bu bölümü bitirdi".
/// Kim olduğu yazılmıyor, yazılamıyor da — `FieldValue.increment` sayıyı
/// okumadan bir artırıyor, belge de istemciye kapalı. Panoyu yalnızca
/// Firebase konsolundan görüyoruz.
///
/// Her bölüm CİHAZ BAŞINA BİR KEZ sayılıyor. Aynı bölümü on kez oynayan biri
/// eğriyi on kat bozmamalı; ölçmek istediğimiz "kaç kişi buraya geldi",
/// "kaç kez oynandı" değil.
enum ProgressStats {
    /// Bu cihazın şimdiye kadar bildirdiği en yüksek bölüm
    private static let key = "lumo.stats.reportedLevel"

    /// Bölüm bitirildiğinde çağrılır.
    ///
    /// Yalnızca ÖNCEKİ EN YÜKSEKTEN büyük olanlar bildiriliyor: eski bir
    /// bölüme dönüp tekrar oynamak sayacı ikinci kez artırmıyor. Ardışık
    /// oynandığı için atlanan bölüm de olmuyor.
    static func reportCompleted(level: Int) {
        guard level > 0, level != LevelLibrary.tutorialID else { return }
        let defaults = UserDefaults.standard
        guard level > defaults.integer(forKey: key) else { return }
        defaults.set(level, forKey: key)

        #if canImport(FirebaseCore)
        Task { await FirebaseBridge.bumpLevelReached(level) }
        #endif
    }
}
