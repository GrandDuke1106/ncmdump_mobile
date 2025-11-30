pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        //maven { url = java.net.URI("https://storage.flutter-io.cn/download.flutter.io") }
        
        //maven { url = java.net.URI("https://maven.aliyun.com/repository/google") }
        //maven { url = java.net.URI("https://maven.aliyun.com/repository/public") }
        //maven { url = java.net.URI("https://maven.aliyun.com/repository/gradle-plugin") }
        
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
}

include(":app")

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.PREFER_SETTINGS)
    repositories {
        //maven { url = java.net.URI("https://storage.flutter-io.cn/download.flutter.io") }
        
        //maven { url = java.net.URI("https://maven.aliyun.com/repository/google") }
        //maven { url = java.net.URI("https://maven.aliyun.com/repository/public") }
        
        google()
        mavenCentral()
        maven {
            url = uri("https://storage.googleapis.com/download.flutter.io")
        }
    }
}
