plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.electricbattery_user"
    compileSdk = flutter.compileSdkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        // Enable core library desugaring
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.electricbattery_user"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Enable MultiDex if minSdk < 21
        multiDexEnabled = true
    }

    buildTypes {
        release {
            // Signing with debug keys for now
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    // Add desugaring library
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.2")
    // Add MultiDex if minSdk < 21
    implementation("androidx.multidex:multidex:2.0.1")
}

flutter {
    source = "../.."
}