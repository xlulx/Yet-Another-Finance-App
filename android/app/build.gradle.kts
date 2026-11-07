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
        // Test sürümü: şifresi herkese açık, her makinede aynı anahtar olduğu
        // için test APK'ları birbirinin üzerine güncellenebilir.
        create("dev") {
            storeFile = rootProject.file("keystores/dev.jks")
            storePassword = "yafa-dev-public"
            keyAlias = "dev"
            keyPassword = "yafa-dev-public"
        }
        // Gerçek sürüm: anahtar dosyası ve şifresi sadece CI'da, GitHub
        // secret'larından gelir (bkz. .github/workflows/release.yml).
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

    // "dev":  telefonda gerçek uygulamanın yanına ayrı kurulan test sürümü
    //         ("YAFA Dev" adıyla, verileri ayrı).
    // "prod": gerçek uygulama; sadece GitHub Release ile derlenir.
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
            // Anahtar yoksa imzasız kalır; yanlış anahtarla sürüm çıkmaz.
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
