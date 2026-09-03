plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "ec.libreta.libreta"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "ec.libreta.libreta"

        // The spec asks for API 21 (Android 5.0). Flutter 3.47 no longer
        // supports it — 24 (Android 7.0, 2016) is the SDK's own floor and the
        // build fails below it. Pinned explicitly so the gap is visible rather
        // than inherited silently.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Debug keys for now: the pilot ships by hand-delivered APK. A real
            // signing config is needed before the Play Store.
            signingConfig = signingConfigs.getByName("debug")

            // Code shrinking is deliberately left off. The spec's <25MB target
            // is already met without it — build with --split-per-abi and each
            // APK lands around 8MB — and R8 is not worth enabling on a config
            // nobody has been able to run yet.
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
