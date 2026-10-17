# BANAAG ProGuard / R8 Rules for Release Hardening

# Keep Flutter Wrapper & Engine Entrypoints
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Obfuscate internal application classes
-repackageclasses 'com.electrical.banaag.core'
-allowaccessmodification

# Remove debugging logs in release
-assumenosideeffects class android.util.Log {
    public static boolean isLoggable(java.lang.String, int);
    public static int v(...);
    public static int d(...);
    public static int i(...);
}

# Preserve Native Method Names (JNI / NDK)
-keepclasseswithmembernames class * {
    native <methods>;
}
