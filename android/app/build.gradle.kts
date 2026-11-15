import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Clave propia de la app (ver README, "Firma de la app"). Los datos están en
// android/key.properties, que NO se comparte (está en .gitignore). Si el
// archivo no existe, se firma con la clave de prueba de esta PC.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}
val tieneClavePropia = keystorePropertiesFile.exists()

android {
    namespace = "com.hermann.gdocente"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "30.0.16248370" // NDK ya instalado (flutter.ndkVersion pedía 28.2, no instalado)

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.hermann.gdocente"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (tieneClavePropia) {
            create("propia") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        // Release y debug usan la MISMA clave: así el celular puede pasar de
        // `flutter run` al APK final (y al revés) sin desinstalar ni perder datos.
        val firma = if (tieneClavePropia) signingConfigs.getByName("propia")
                    else signingConfigs.getByName("debug")
        release {
            signingConfig = firma
        }
        debug {
            signingConfig = firma
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
