# ============================================================================
# Kas-Santri v4.2 — ProGuard / R8 Release Rules (AGP 9.3.1 Full Mode Safe)
# ============================================================================

# Preserve essential metadata for Kotlin, generics, reflection, and stacktraces
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod,Exceptions,SourceFile,LineNumberTable
-keep class kotlin.Metadata { *; }

# 1. Flutter Engine, Embedding & Plugins
-keep class io.flutter.** { *; }
-dontwarn io.flutter.embedding.**

# 2. Flutter Play Core / Deferred Components (R8 missing class fix)
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# 3. App MainActivity & Native Security MethodChannel
-keep class com.pondok.kassantri.** { *; }

# 4. flutter_secure_storage, AndroidX Security Crypto & Google Tink
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-keep class androidx.security.crypto.** { *; }
-keep class com.google.crypto.tink.** { *; }
-dontwarn com.google.crypto.tink.**
-dontwarn com.google.protobuf.**

# 5. purchases_flutter (RevenueCat) & Google Play Billing
-keep class com.revenuecat.purchases.** { *; }
-keep class com.android.billingclient.** { *; }
-dontwarn com.revenuecat.purchases.**
-dontwarn com.amazon.**

# 6. mobile_scanner, Google ML Kit Barcode & CameraX
-keep class dev.steenbakker.mobile_scanner.** { *; }
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_barcode.** { *; }
-keep class com.google.android.gms.vision.** { *; }
-keep class androidx.camera.** { *; }
-dontwarn com.google.mlkit.**
-dontwarn androidx.camera.**

# 7. google_sign_in & Google Play Services Auth
-keep class io.flutter.plugins.googlesignin.** { *; }
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }
-keepnames class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# 8. local_auth (AndroidX Biometric) & Core Flutter Plugins
-keep class io.flutter.plugins.localauth.** { *; }
-keep class androidx.biometric.** { *; }
-dontwarn androidx.biometric.**
-keep class com.tekartik.sqflite.** { *; }
-keep class net.nfetellino.printing.** { *; }
-keep class com.mr.flutter.plugin.filepicker.** { *; }
-keep class dev.fluttercommunity.plus.share.** { *; }

# 9. Optional Compile-Time Annotations & TLS Providers
-dontwarn kotlin.**
-dontwarn kotlinx.**
-dontwarn com.google.errorprone.annotations.**
-dontwarn javax.annotation.**
-dontwarn org.codehaus.mojo.animal_sniffer.**
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**
-dontwarn org.slf4j.**
