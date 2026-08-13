plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services") apply false
}

android {
    namespace = "com.example.vox_client_flutter"
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
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.vox_client_flutter"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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
