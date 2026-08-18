# Flutter local notifications
-keep class com.dexterous.** { *; }

# SQFLite
-keep class io.flutter.plugins.** { *; }

# Keep model classes
-keep class com.viet.lichviet.** { *; }

# Keep Gson serialization
-keepattributes Signature
-keepattributes *Annotation*
-keep class sun.misc.Unsafe { *; }

# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-dontwarn io.flutter.embedding.**

# ============================================================
# Google Play Core (Deferred Components / Dynamic Feature Modules)
# App KHÔNG dùng deferred components / split APK, nhưng Flutter
# engine vẫn tham chiếu các class Play Core này trong
# io.flutter.app.FlutterPlayStoreSplitApplication → R8 báo lỗi
# "missing classes" khi minifyEnabled=true.
#
# Chỉ dùng -dontwarn (KHÔNG -keep) vì các class Play Core này
# không thực sự tồn tại trong classpath — code path liên quan
# không bao giờ được gọi trong app này.
# Xem: https://docs.flutter.dev/deployment/android#r8
# ============================================================
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.SplitInstallException
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManager
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManagerFactory
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest$Builder
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest
-dontwarn com.google.android.play.core.splitinstall.SplitInstallSessionState
-dontwarn com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task
-dontwarn io.flutter.app.FlutterPlayStoreSplitApplication
# Wildcard an toàn: chặn mọi class Play Core khác có thể phát sinh
# (SplitInstallHelper, listener phụ...) không nằm trong danh sách cụ thể ở trên
-dontwarn com.google.android.play.core.**

