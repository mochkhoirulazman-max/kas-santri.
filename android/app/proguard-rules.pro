# Kas-Santri v3.3 ProGuard / R8 Keep Rules

-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep MainActivity and native security MethodChannel handler
-keep class com.pondok.kassantri.** { *; }

# Flutter Secure Storage / AndroidX Security / Biometric / Play Billing / ML Kit
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-keep class androidx.security.crypto.** { *; }
-keep class androidx.biometric.** { *; }
-keep class com.android.billingclient.** { *; }
-keep class com.revenuecat.purchases.** { *; }
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.errorprone.annotations.**
-dontwarn javax.annotation.**
