import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Company branding, passed by tool/build_company_apk.sh as
// --android-project-arg=brandName=... etc. All optional.
val brandName = (project.findProperty("brandName") as String?)?.takeIf { it.isNotBlank() }
val brandId = (project.findProperty("brandId") as String?)
    ?.lowercase()?.replace(Regex("[^a-z0-9]"), "")?.takeIf { it.isNotEmpty() }
    ?.let { if (it[0].isDigit()) "c$it" else it }
val brandIconDir = (project.findProperty("brandIconDir") as String?)?.takeIf { it.isNotBlank() }

fun xmlEscape(s: String) = s.replace("&", "&amp;").replace("<", "&lt;")
    .replace(">", "&gt;").replace("\"", "&quot;")

android {
    namespace = "com.tcbinfotech.tcb_portal"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.tcbinfotech.tcb_portal"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Launcher name. Overridden per company by tool/build_company_apk.sh.
        manifestPlaceholders["appLabel"] = xmlEscape(brandName ?: "TCB Portal")
        if (brandId != null) {
            // Own package per company, so each company's app installs and
            // updates on its own.
            applicationIdSuffix = "." + brandId
        }
    }

    // Company launcher icons (mipmap-*/ic_launcher.png). The release source
    // set takes priority over main, so these replace the default icon.
    if (brandIconDir != null) {
        sourceSets.getByName("release").res.srcDir(brandIconDir)
    }

    // Play upload key. android/key.properties (git-ignored) points at the
    // keystore, which lives outside the repo:
    //   storeFile=/home/<you>/keys/tcb-upload.jks
    //   storePassword=...   keyAlias=upload   keyPassword=...
    // Without it a release build falls back to the debug key, which Play rejects.
    val keystoreProperties = Properties()
    val keystorePropertiesFile = rootProject.file("key.properties")
    if (keystorePropertiesFile.exists()) {
        keystoreProperties.load(FileInputStream(keystorePropertiesFile))
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Fused Location Provider — Google Play Services. Powers the location
    // tracking foreground service. Version pinned to match the Play Services
    // BOM commonly available on Realme/Samsung/Vivo phones (2024+).
    implementation("com.google.android.gms:play-services-location:21.3.0")
}
