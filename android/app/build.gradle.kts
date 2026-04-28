import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keyProperties = Properties()
val keyPropertiesFile = rootProject.file("key.properties")
if (keyPropertiesFile.exists()) {
    FileInputStream(keyPropertiesFile).use { keyProperties.load(it) }
}

val releaseStoreFilePath = keyProperties.getProperty("storeFile")?.takeIf { it.isNotBlank() }
val releaseStorePassword = keyProperties.getProperty("storePassword")?.takeIf { it.isNotBlank() }
val releaseKeyAlias = keyProperties.getProperty("keyAlias")?.takeIf { it.isNotBlank() }
val releaseKeyPassword = keyProperties.getProperty("keyPassword")?.takeIf { it.isNotBlank() }
val releaseStoreFile = releaseStoreFilePath?.let { file(it) }
val missingReleaseSigningProperties = buildList {
    if (releaseStoreFilePath == null) add("storeFile")
    if (releaseStorePassword == null) add("storePassword")
    if (releaseKeyAlias == null) add("keyAlias")
    if (releaseKeyPassword == null) add("keyPassword")
}
val isReleaseBuildRequested = gradle.startParameter.taskNames.any { taskName ->
    taskName.contains("Release", ignoreCase = true)
}

if (isReleaseBuildRequested) {
    check(keyPropertiesFile.exists()) {
        "Release signing requires android/key.properties for release builds."
    }
    check(missingReleaseSigningProperties.isEmpty()) {
        "Release signing is missing required properties in android/key.properties: ${missingReleaseSigningProperties.joinToString(", ")}."
    }
    check(releaseStoreFile?.exists() == true) {
        "Release signing storeFile does not exist: ${releaseStoreFile?.path ?: "<missing>"}."
    }
}

val ciNdkPath = System.getenv("ANDROID_NDK_HOME") ?: System.getenv("ANDROID_NDK_ROOT")

android {
    namespace = "com.example.globi_mobile"
    compileSdk = flutter.compileSdkVersion
    if (!ciNdkPath.isNullOrBlank()) {
        ndkPath = ciNdkPath
    } else {
        ndkVersion = flutter.ndkVersion
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "cn.tamochi.globi"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (releaseStoreFile != null && missingReleaseSigningProperties.isEmpty()) {
                storeFile = releaseStoreFile
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}
