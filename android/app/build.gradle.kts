import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
    id("com.google.gms.google-services")
}

// Yükleme anahtarı depoya girmez. `keystore.properties` yoksa (temiz bir
// klonda, CI'da) release yine derlenir — sadece imzasız çıkar, Play'e
// yüklenemez. Dosya varsa release otomatik imzalanır.
val keystoreProps = Properties().apply {
    val f = rootProject.file("keystore.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
val hasKeystore = keystoreProps.getProperty("storeFile") != null

android {
    namespace = "com.caganhatapci.orbeon"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.caganhatapci.orbeon"
        minSdk = 24
        targetSdk = 35
        versionCode = 7
        versionName = "2.0"
        resourceConfigurations += listOf("en", "tr", "de", "fr", "es", "ja")
    }

    signingConfigs {
        if (hasKeystore) {
            create("release") {
                storeFile = rootProject.file(keystoreProps.getProperty("storeFile"))
                storePassword = keystoreProps.getProperty("storePassword")
                keyAlias = keystoreProps.getProperty("keyAlias")
                keyPassword = keystoreProps.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        debug {
            isMinifyEnabled = false
            // Google'ın resmi TEST uygulama kimliği: geliştirmede gerçek
            // reklam istenmez, kendi reklamına tıklayıp hesabı kapattırma riski olmaz
            manifestPlaceholders["admobAppId"] = "ca-app-pub-3940256099942544~3347511713"
        }
        release {
            // AdMob'daki ANDROID uygulamasının kimliği (iOS'unkinden farklıdır)
            manifestPlaceholders["admobAppId"] = "ca-app-pub-2696377554654488~9317548394"
            if (hasKeystore) signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }
    buildFeatures {
        compose = true
        // AdsManager, test/gerçek reklam birimini ayırmak için BuildConfig.DEBUG
        // okur; AGP 8'de bu özellik varsayılan olarak kapalıdır.
        buildConfig = true
    }
    packaging {
        resources.excludes += "/META-INF/{AL2.0,LGPL2.1}"
    }
}

dependencies {
    val composeBom = platform("androidx.compose:compose-bom:2024.09.02")
    implementation(composeBom)

    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.activity:activity-compose:1.9.2")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.6")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.8.6")

    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-graphics")
    implementation("androidx.compose.foundation:foundation")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-extended")

    // Google Play Faturalandırma — Premium ve bahşişler
    implementation("com.android.billingclient:billing-ktx:7.1.1")

    // AdMob + GDPR onay formu (UMP)
    implementation("com.google.android.gms:play-services-ads:23.3.0")
    implementation("com.google.android.ump:user-messaging-platform:3.0.0")

    // Play Store içi değerlendirme istemi
    implementation("com.google.android.play:review-ktx:2.0.1")

    // Dünya sıralaması — google-services.json ekleyince etkinleşir
    implementation(platform("com.google.firebase:firebase-bom:33.4.0"))
    implementation("com.google.firebase:firebase-firestore-ktx")
    implementation("com.google.firebase:firebase-auth-ktx")
}
