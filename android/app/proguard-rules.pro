# Flutter wrapper & core plugins
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.**

# Dusk App and App Widgets
-keep class com.example.dusk.** { *; }
-keepclassmembers class com.example.dusk.** { *; }

# flutter_local_notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-dontwarn com.dexterous.flutterlocalnotifications.**
-keep class com.google.gson.** { *; }
-dontwarn com.google.gson.**
-keep class androidx.window.** { *; }
-dontwarn androidx.window.**

# home_widget
-keep class es.antonborri.home_widget.** { *; }
-dontwarn es.antonborri.home_widget.**

# receive_sharing_intent
-keep class com.kasem.receive_sharing_intent.** { *; }
-dontwarn com.kasem.receive_sharing_intent.**

# sqflite
-keep class com.tekartik.sqflite.** { *; }
-dontwarn com.tekartik.sqflite.**

# audioplayers
-keep class xyz.luan.audioplayers.** { *; }
-dontwarn xyz.luan.audioplayers.**

# flutter_timezone / native timezone
-keep class net.jonhanson.flutter_native_timezone.** { *; }
-keep class com.whelksoft.flutter_timezone.** { *; }
-dontwarn net.jonhanson.flutter_native_timezone.**
-dontwarn com.whelksoft.flutter_timezone.**

# flutter community plus plugins (connectivity_plus, share_plus, etc.)
-keep class dev.fluttercommunity.plus.** { *; }
-dontwarn dev.fluttercommunity.plus.**

# quick_actions
-keep class io.flutter.plugins.quickactions.** { *; }

# Google Sign-In & Play Services
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**
-dontwarn com.google.android.play.core.**

# Kotlin Coroutines & Reflect
-keep class kotlinx.coroutines.** { *; }
-dontwarn kotlinx.coroutines.**
-keep class kotlin.reflect.** { *; }
-dontwarn kotlin.reflect.**

# General Kotlin
-keep class kotlin.** { *; }
-dontwarn kotlin.**
