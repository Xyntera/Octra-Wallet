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

# Suppress warnings
-dontwarn kotlin.**
-dontwarn kotlinx.**
