# Flutter specific rules
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }

# Keep local_auth for biometrics
-keep class androidx.biometric.** { *; }
-keep class androidx.fragment.app.FragmentActivity { *; }

# Keep video_player
-keep class io.flutter.plugins.videoplayer.** { *; }

# Keep crypto classes
-keep class javax.crypto.** { *; }
-keep class java.security.** { *; }

# Don't obfuscate model classes
-keepattributes *Annotation*
-keepattributes Signature

# Suppress warnings for missing Play Core classes (not used in this app)
-dontwarn com.google.android.play.core.**
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

# Ignore missing Play Store split install classes
-keep class com.google.android.play.core.** { *; }

# Suppress warnings
-dontwarn kotlin.**
-dontwarn kotlinx.**
-dontwarn javax.annotation.**
-dontwarn org.conscrypt.**
