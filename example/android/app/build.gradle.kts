import java.util.Properties

// Detect AGP version to handle the built-in Kotlin migration (AGP 9.0+)
val agpVersion = try {
    val versionClass = Class.forName("com.android.Version")
    versionClass.getField("ANDROID_GRADLE_PLUGIN_VERSION").get(null) as String
} catch (e: Exception) {
    "0.0.0"
}

val isAgp9OrHigher = agpVersion.startsWith("9.") || 
    (agpVersion.split(".").firstOrNull()?.toIntOrNull() ?: 0) >= 9

plugins {
    id("com.android.application")
    // Note: Do not explicitly apply org.jetbrains.kotlin.android here to satisfy AGP 9.0+ guidelines
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Dynamically apply KGP for AGP 8.x and below to ensure Kotlin sources are compiled
if (!isAgp9OrHigher) {
    apply(plugin = "org.jetbrains.kotlin.android")
}

val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.inputStream().use { localProperties.load(it) }
}

android {
    namespace = "dev.wyrin.flutter_media_session_example"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = localProperties.getProperty("flutter.ndkVersion") ?: flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "dev.wyrin.flutter_media_session_example"
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

flutter {
    source = "../.."
}

// Safely configure jvmTarget for both KGP 1.x and 2.x without using the strict kotlinOptions DSL
tasks.configureEach {
    if (name.startsWith("compile") && name.endsWith("Kotlin")) {
        try {
            // Target KGP 2.x compilerOptions
            val compilerOptions = property("compilerOptions")
            if (compilerOptions != null) {
                val jvmTargetMethod = compilerOptions.javaClass.getMethod("getJvmTarget")
                val jvmTargetProperty = jvmTargetMethod.invoke(compilerOptions)
                val setMethod = jvmTargetProperty.javaClass.getMethod("set", Any::class.java)
                
                val jvmTargetClass = Class.forName("org.jetbrains.kotlin.gradle.dsl.JvmTarget")
                val jvm17 = jvmTargetClass.getField("JVM_17").get(null)
                setMethod.invoke(jvmTargetProperty, jvm17)
            }
        } catch (e: Exception) {
            // Fallback for KGP 1.x kotlinOptions
            try {
                val kotlinOptions = property("kotlinOptions")
                val setJvmTarget = kotlinOptions?.javaClass?.getMethod("setJvmTarget", String::class.java)
                setJvmTarget?.invoke(kotlinOptions, "17")
            } catch (ignored: Exception) {
                logger.warn("Failed to set Kotlin JVM target to 17 for task ${name}: ${ignored.message}")
            }
        }
    }
}
