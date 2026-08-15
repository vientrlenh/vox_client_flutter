import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services") apply false
}

// Release signing config, loaded from key.properties (gitignored, not committed).
// Falls back to null (and the debug key) when the file is absent, so
// `flutter run --release` keeps working for anyone without the release keystore.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasReleaseSigning = keystorePropertiesFile.exists()
if (hasReleaseSigning) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

android {
    namespace = "com.voxenta.vox"
    // 37 chu khong phai flutter.compileSdkVersion (dang la 36): flutter_secure_storage 11
    // khai compileSdk = 37, va rang buoc do di vao AAR metadata -- moi module dung no deu
    // phai compile o API >= 37. Bo dong nay ve mac dinh cua Flutter la build Android hong ngay.
    // Keo theo: AGP phai >= 9.1.1 (9.0.1 chi ho tro toi 36 va khong hieu minor version cua
    // API 37, Google chi publish android-37.0/37.1 chu khong co android-37), va AGP 9.1.1
    // lai doi Gradle >= 9.3.1 -- xem gradle-wrapper.properties.
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.voxenta.vox"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // Uses the release keystore once android/key.properties exists;
            // otherwise falls back to the debug key so local `flutter run
            // --release` still works without it.
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
