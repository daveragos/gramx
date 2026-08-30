import java.io.FileInputStream
import java.util.Properties

// Release signing details, kept out of the repository. See key.properties.example.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        load(FileInputStream(keystorePropertiesFile))
    }
}
val hasReleaseKey = keystorePropertiesFile.exists()

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// AGP 9 removed `android { kotlinOptions { } }`; the Kotlin plugin owns this
// now. Same value as `compileOptions` below, which is the point — a mismatch
// between the Java and Kotlin targets is a link error at assembly time rather
// than a compile error here.
kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

android {
    namespace = "dev.ragoose.gramx"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // `flutter_local_notifications` uses java.time, which is not in the
        // Android API level this app supports. Desugaring is how that library
        // reaches an older device, and the build refuses outright without it —
        // which is the right kind of failure: loud, and at assembly time.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }


    defaultConfig {
        applicationId = "dev.ragoose.gramx"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (hasReleaseKey) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Falls back to the debug key so a checkout without the keystore
            // still builds — but says so loudly, because a debug-signed build
            // handed to someone is one they have to uninstall before they can
            // ever take an update.
            signingConfig = if (hasReleaseKey) {
                signingConfigs.getByName("release")
            } else {
                logger.warn(
                    "\n*** No android/key.properties — signing this release with the DEBUG key. ***\n" +
                    "*** Do not distribute this build: upgrades will be refused.            ***\n"
                )
                signingConfigs.getByName("debug")
            }
        }
    }
}

dependencies {
    // Required by the compileOptions flag above. Version tracks what AGP asks
    // for; a mismatch is reported at assembly time rather than silently.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
