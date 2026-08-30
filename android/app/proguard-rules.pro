# Flutter
-keep class io.flutter.** { *; }
-dontwarn io.flutter.embedding.**

# Google Mobile Ads (AdMob)
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.android.gms.common.** { *; }
-dontwarn com.google.android.gms.**

# Google Play Billing / in_app_purchase
-keep class com.android.billingclient.** { *; }
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# ContentProvider das figurinhas (referenciado pelo WhatsApp via manifest)
-keep class com.figurinhasfrases.figurinhas.** { *; }

# WorkManager + Room + App Startup (o google_mobile_ads 9.x usa em background;
# o Room instancia as classes geradas *_Impl por reflexao — sem keep, crasha no boot)
-keep class androidx.work.** { *; }
-keep class androidx.startup.** { *; }
-keep class androidx.room.** { *; }
-keep class * extends androidx.room.RoomDatabase { *; }
-keepclassmembers class * extends androidx.room.RoomDatabase { <init>(...); }
-dontwarn androidx.work.**

-keepattributes Signature
-keepattributes *Annotation*
