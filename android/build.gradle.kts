group = "dev.wyrin.flutter_media_session"
version = "1.0-SNAPSHOT"

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
    id("com.android.library")
    // Note: Do not explicitly apply org.jetbrains.kotlin.android here to satisfy AGP 9.0+ guidelines
}

// Dynamically apply KGP for AGP 8.x and below to ensure Kotlin sources are compiled
if (!isAgp9OrHigher) {
    apply(plugin = "org.jetbrains.kotlin.android")
}

android {
    namespace = "dev.wyrin.flutter_media_session"
    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }
        getByName("test") {
            java.srcDirs("src/test/kotlin")
        }
    }

    defaultConfig {
        minSdk = 24
    }

    testOptions {
        unitTests {
            isIncludeAndroidResources = true
            all {
                it.useJUnitPlatform()
                it.outputs.upToDateWhen { false }
                it.testLogging {
                    events("passed", "skipped", "failed", "standardOut", "standardError")
                    showStandardStreams = true
                }
            }
        }
    }
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
            } catch (ignored: Exception) {}
        }
    }
}

dependencies {
    implementation("androidx.media3:media3-session:1.5.1")
    implementation("androidx.media3:media3-common:1.5.1")
    testImplementation("org.jetbrains.kotlin:kotlin-test")
    testImplementation("org.mockito:mockito-core:5.0.0")
}