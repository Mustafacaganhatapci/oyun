plugins {
    // compileSdk 36 (Android 16) için Google'ın belirttiği en düşük AGP 8.9.1.
    // Play artık API 36 hedeflenmesini şart koşuyor, dolayısıyla 8.5.2'de
    // kalmak mümkün değil. Bilerek en düşük sürüm seçildi: daha yenisi
    // Kotlin/Compose eklentileriyle ek uyum sorunu çıkarabilir.
    id("com.android.application") version "8.9.1" apply false
    id("org.jetbrains.kotlin.android") version "2.0.20" apply false
    id("org.jetbrains.kotlin.plugin.compose") version "2.0.20" apply false
    id("com.google.gms.google-services") version "4.4.2" apply false
    id("com.google.firebase.crashlytics") version "3.0.2" apply false
}
