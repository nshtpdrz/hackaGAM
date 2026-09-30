# Reglas extra de R8 para la versión release (Flutter ya agrega las suyas).

# flutter_local_notifications guarda las alarmas programadas con Gson. Sin estas reglas, en release las
# alarmas de tomas fallan al reprogramarse (reinicio del teléfono, "Más tarde") con "Missing type parameter".
-keep class com.dexterous.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken

# Flutter referencia Play Core (componentes diferidos) aunque SENDA no los usa.
-dontwarn com.google.android.play.core.**
