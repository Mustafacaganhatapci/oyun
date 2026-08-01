# Play Faturalandırma ve AdMob kendi sınıflarını yansıma ile çözer
-keep class com.android.billingclient.** { *; }
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.android.ump.** { *; }
# Firestore modelleri alan adlarıyla eşleşir
-keepclassmembers class com.caganhatapci.orbeon.** { *; }
