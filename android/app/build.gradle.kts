plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "io.github.xlulx.yasba"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    buildFeatures {
        resValues = true
    }

    // Compress the native libraries (Flutter engine and app code) inside the
    // APK. The APK is downloaded straight from GitHub Releases, so this
    // roughly halves the download (about 19 MB -> 9 MB) at the cost of
    // about 8 MB more space once installed, as Android extracts them.
    // Not for the Play bundle: Play compresses downloads itself.
    val buildingBundle = gradle.startParameter.taskNames.any { it.contains("bundle", ignoreCase = true) }
    packaging {
        jniLibs {
            useLegacyPackaging = !buildingBundle
        }
    }

    compileOptions {
        // Needed by the notifications plugin.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "io.github.xlulx.yasba"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Set by the release workflow from the version (see release.yml).
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // Test builds: the password is public on purpose. Using the same key
        // everywhere lets test APKs update each other in place.
        create("dev") {
            storeFile = rootProject.file("keystores/dev.jks")
            storePassword = "yasba-dev-public"
            keyAlias = "dev"
            keyPassword = "yasba-dev-public"
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

    // "dev":  test build installed next to the real app ("YASBA Dev",
    //         separate data).
    // "prod": the real app; only built by the Release APK workflow.
    flavorDimensions += "channel"
    productFlavors {
        create("dev") {
            dimension = "channel"
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
            resValue("string", "app_name", "YASBA Dev")
            signingConfig = signingConfigs.getByName("dev")
        }
        create("prod") {
            dimension = "channel"
            resValue("string", "app_name", "YASBA")
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
