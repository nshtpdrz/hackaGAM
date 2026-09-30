import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Push (Firebase Cloud Messaging): se aplica abajo solo si existe google-services.json.
    id("com.google.gms.google-services") apply false
}

// google-services.json (consola de Firebase, app Android "mx.senda.app") va en android/app/ y no se sube al
// repositorio. Sin él la app compila y funciona igual; solo se omiten las notificaciones push.
// Ver docs/NOTIFICACIONES.md.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

// Firma de publicación: android/key.properties (no se sube; ver docs/EMPAQUETADO.md).
// Sin ese archivo, release se firma con la llave de debug para que `flutter run --release` funcione.
val llaveFirma = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}

android {
    namespace = "mx.senda.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications usa java.time en Android 7 (desugaring).
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "mx.senda.app"
        // Android 7.0 (API 24): el mínimo que piden local_auth, image_picker y flutter_tts.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        // Versión: `version:` de pubspec.yaml (nombre+número), o --build-name / --build-number.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (llaveFirma.isNotEmpty()) {
            create("release") {
                keyAlias = llaveFirma.getProperty("keyAlias")
                keyPassword = llaveFirma.getProperty("keyPassword")
                storeFile = file(llaveFirma.getProperty("storeFile"))
                storePassword = llaveFirma.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // R8 (minify y recursos) lo activa Flutter; las reglas extra están en proguard-rules.pro.
            signingConfig = signingConfigs.findByName("release") ?: signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // Temas AppCompat (res/values/styles.xml): local_auth los pide para el diálogo de huella en Android 7 y 8.
    implementation("androidx.appcompat:appcompat:1.7.0")
}

flutter {
    source = "../.."
}
