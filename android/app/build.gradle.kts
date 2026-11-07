plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "io.github.xlulx.yafa"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    buildFeatures {
        resValues = true
    }

    // Compress the native libraries (Flutter engine and app code) inside the
    // APK. The APK is downloaded straight from GitHub Releases, so this
    // roughly halves the download (about 19 MB -> 9 MB) at the cost of
    // about 8 MB more space once installed, as Android extracts them.
    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "io.github.xlulx.yafa"
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
        // Test builds: the password is public on purpose. Using the same key
        // everywhere lets test APKs update each other in place.
        create("dev") {
            storeFile = rootProject.file("keystores/dev.jks")
            storePassword = "yafa-dev-public"
            keyAlias = "dev"
            keyPassword = "yafa-dev-public"
        }
        // Real releases: the keystore and its password only exist in CI, taken
        // from GitHub secrets (see .github/workflows/release.yml).
        val releaseStore = System.getenv("RELEASE_KEYSTORE_PATH")
        val releasePassword = System.getenv("RELEASE_KEYSTORE_PASSWORD")
        if (!releaseStore.isNullOrEmpty() && !releasePassword.isNullOrEmpty()) {
            create("release") {
                storeFile = file(releaseStore)
                storePassword = releasePassword
                keyAlias = "release"
                keyPassword = releasePassword
            }
        }
    }

    // "dev":  test build installed next to the real app ("YAFA Dev",
    //         separate data).
    // "prod": the real app; only built by the Release APK workflow.
    flavorDimensions += "channel"
    productFlavors {
        create("dev") {
            dimension = "channel"
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
            resValue("string", "app_name", "YAFA Dev")
            signingConfig = signingConfigs.getByName("dev")
        }
        create("prod") {
            dimension = "channel"
            resValue("string", "app_name", "YAFA")
            // Left unsigned without a key, so a release is never signed with the
            // wrong key.
            signingConfig = signingConfigs.findByName("release")
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
