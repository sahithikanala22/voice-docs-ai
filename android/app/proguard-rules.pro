# flutter_local_notifications deserializes scheduled-notification details via
# Gson reflection (an anonymous TypeToken subclass captures the generic type
# at compile time). R8's default release shrinking strips that generic
# signature, which crashes rescheduling with "Missing type parameter" the
# first time the boot receiver runs after a reboot/update. Keep the plugin's
# classes and the attributes Gson's reflection depends on.
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class com.google.gson.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses
-dontwarn com.google.gson.**
