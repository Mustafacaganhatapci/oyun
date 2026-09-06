import Foundation
#if canImport(FirebaseCrashlytics)
import FirebaseCrashlytics
#endif

/// Çökme ve hata raporu.
///
/// Bugüne kadar bir oyuncuda bir şey bozulduğunda haberimiz olmuyordu:
/// `leaderboardLog` yalnızca cihazın kendi günlüğüne yazıyor, yani hatayı
/// görmenin tek yolu o telefonu elinde tutmaktı. Mağazadaki bir kullanıcının
/// çökmesi ise hiçbir yere düşmüyordu.
///
/// Crashlytics bunu üç şey için kullanıyor:
///  1. **Çökmeler** — yığın izi, cihaz, sürüm; gruplanmış hâlde
///  2. **Ölümcül olmayan hatalar** — Firestore yazamadı, ürün yüklenemedi,
///     ses motoru başlamadı gibi. Uygulama çalışmaya devam ediyor ama bir şey
///     yolunda gitmedi; bunlar toplanmadan hangi hatanın yaygın olduğu
///     bilinemiyor.
///  3. **Kimlik** — hangi oyuncuda olduğu. Firestore'daki `supporters` ve
///     sıralama kayıtlarıyla aynı `playerID`; destek isteyen birinin kaydını
///     aramak iş olmaktan çıkıyor.
///
/// XCODE'DA GEREKEN: paket zaten projede (firebase-ios-sdk). Hedefe
/// **FirebaseCrashlytics** ürününü ekle, sonra Build Phases → **+ New Run
/// Script Phase** → `"${BUILD_DIR%/Build/*}/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run"`
/// ve Input Files'a `${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}/Contents/Resources/DWARF/${TARGET_NAME}`
/// ile `$(SRCROOT)/$(BUILT_PRODUCTS_DIR)/$(INFOPLIST_PATH)` satırlarını yaz.
/// Betik olmadan çökmeler gelir ama yığın izi okunamaz hâlde gelir.
///
/// Paket eklenmediği sürece bu dosya derleniyor ve hiçbir şey yapmıyor —
/// projedeki Firestore ve RevenueCat kalıbının aynısı.
enum Diagnostics {

    static var isAvailable: Bool {
        #if canImport(FirebaseCrashlytics)
        return true
        #else
        return false
        #endif
    }

    /// Oyuncu kimliğini rapora bağlar. Kişisel hiçbir şey göndermiyor:
    /// `playerID` cihazda üretilmiş bir UUID, ada ya da hesaba bağlı değil.
    static func identify(playerID: String) {
        #if canImport(FirebaseCrashlytics)
        guard !playerID.isEmpty else { return }
        Crashlytics.crashlytics().setUserID(playerID)
        #endif
    }

    /// Ölümcül olmayan hata. Uygulama çalışmaya devam ediyor ama bir şey
    /// olması gerektiği gibi olmadı.
    ///
    /// `domain` gruplama için: aynı alandan gelenler panoda tek satırda
    /// toplanıyor, "üç kişide olmuş" ile "üç bin kişide olmuş" ayırt
    /// edilebiliyor.
    static func record(_ message: String, domain: String = "Orbeon") {
        #if canImport(FirebaseCrashlytics)
        let error = NSError(domain: domain, code: 0,
                            userInfo: [NSLocalizedDescriptionKey: message])
        Crashlytics.crashlytics().record(error: error)
        #endif
    }

    /// Çökmenin ÖNCESİNDE ne olduğunu anlatan iz. Yığın izi nerede
    /// çöküldüğünü söylüyor, bu da oraya nasıl gelindiğini.
    static func breadcrumb(_ message: String) {
        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().log(message)
        #endif
    }
}
