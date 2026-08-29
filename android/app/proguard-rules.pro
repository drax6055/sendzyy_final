# Flutter ProGuard Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Google Play Core (Flutter Deferred Components)
-dontwarn com.google.android.play.core.**

# Keep Flutter Local Notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# Keep WebRTC & Firebase
-keep class org.webrtc.** { *; }
-keep class com.google.firebase.** { *; }

# General ProGuard safety
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-dontwarn javax.annotation.**
-dontwarn java.lang.invoke.**
-keepclassmembers enum * { *; }
