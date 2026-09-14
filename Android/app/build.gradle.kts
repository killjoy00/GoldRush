plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.plugin.compose")
}

// AdMob identifiers are public app configuration, not credentials. Keep them
// here so the manifest and BuildConfig cannot drift apart.
val admobAppId = "ca-app-pub-1217971050094766~3907429685"
val admobBannerAdUnitId = "ca-app-pub-1217971050094766/4428717591"

android {
    namespace = "com.killjoy00.goldrush"
    // Android 17 / API 37 is still a preview SDK in September 2026. Compile
    // against the current stable platform so CI and Play release builds do not
    // depend on preview-channel SDK packages.
    compileSdk = 36

    defaultConfig {
        applicationId = "com.killjoy00.goldrush"
        minSdk = 26
        targetSdk = 36
        // versionCode 2 is the first Gold Rush build accepted by Google Play.
        // Every later Play upload must use a strictly higher version code.
        versionCode = 2
        versionName = "1.5"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"

        manifestPlaceholders["adMobAppId"] = admobAppId
        buildConfigField("String", "ADMOB_APP_ID", "\"$admobAppId\"")
        buildConfigField("String", "ADMOB_BANNER_AD_UNIT_ID", "\"$admobBannerAdUnitId\"")
    }

    buildTypes {
        getByName("release") {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    packaging {
        resources.excludes += "/META-INF/{AL2.0,LGPL2.1}"
    }
}

dependencies {
    // The September 2026 BOM pulls Compose 1.12, whose Android artifacts require
    // compileSdk 37. Keep this on the June production BOM until API 37 is stable.
    val composeBom = platform("androidx.compose:compose-bom:2026.06.00")
    implementation(composeBom)
    androidTestImplementation(composeBom)

    implementation("androidx.activity:activity-compose:1.13.0")
    implementation("androidx.compose.foundation:foundation")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.datastore:datastore-preferences:1.2.1")
    implementation("com.android.billingclient:billing-ktx:9.1.0")
    implementation("com.google.android.gms:play-services-ads:25.4.0")
    implementation("com.google.android.play:review-ktx:2.0.2")
    implementation("com.google.android.ump:user-messaging-platform:4.0.0")

    debugImplementation("androidx.compose.ui:ui-tooling")
    debugImplementation("androidx.compose.ui:ui-test-manifest")

    testImplementation("junit:junit:4.13.2")
    androidTestImplementation("androidx.compose.ui:ui-test-junit4")
}
