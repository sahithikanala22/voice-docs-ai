import java.util.Properties
import java.util.Base64
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

// Never silently ship a release signed with the public Android debug key.
val releaseRequested = gradle.startParameter.taskNames.any { it.contains("release", ignoreCase = true) }
if (releaseRequested) {
    val requiredKeys = listOf("keyAlias", "keyPassword", "storeFile", "storePassword")
    check(keystorePropertiesFile.exists() && requiredKeys.all {
        !keystoreProperties.getProperty(it).isNullOrBlank()
    }) { "Release signing is missing. Configure android/key.properties; see release/README.md." }
    check(file(keystoreProperties.getProperty("storeFile")).isFile) {
        "The configured upload keystore does not exist."
    }
    check(keystoreProperties.getProperty("keyAlias") != "androiddebugkey") {
        "A debug signing key cannot be used for a Play Store release."
    }
}


val packagingRelease = gradle.startParameter.taskNames.any {
    it.endsWith("bundleRelease", ignoreCase = true) || it.endsWith("assembleRelease", ignoreCase = true)
}
if (packagingRelease) {
    val definitions = (project.findProperty("dart-defines") as? String).orEmpty()
        .split(",").filter { it.isNotEmpty() }.associate {
            val pair = String(Base64.getDecoder().decode(it), Charsets.UTF_8).split("=", limit = 2)
            pair[0] to pair.getOrElse(1) { "" }
        }
    check(!definitions["DEVELOPER_NAME"].isNullOrBlank() &&
        definitions["SUPPORT_EMAIL"].orEmpty().matches(Regex("^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$")) &&
        definitions["PRIVACY_POLICY_URL"].orEmpty().startsWith("https://")) {
        "Public developer contact and privacy URL are required. Run scripts/build_play_release.ps1."
    }
}

android {
    namespace = "com.aivoicedocs.app"
    // file_picker's flutter_plugin_android_lifecycle dependency requires
    // compiling against API 36+; flutter.compileSdkVersion (34/35 depending
    // on the Flutter release) is too old, so pin explicitly rather than via
    // the Flutter-provided default. This only affects what APIs are
    // compiled against, not minSdk/targetSdk (device compatibility).
    compileSdk = 36
    ndkVersion = "29.0.13113456"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.aivoicedocs.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = keystoreProperties["storeFile"]?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // Required by local_auth's biometric prompt dialog and the
    // Theme.AppCompat.* themes MainActivity now uses.
    implementation("androidx.appcompat:appcompat:1.7.0")
}

flutter {
    source = "../.."
}
