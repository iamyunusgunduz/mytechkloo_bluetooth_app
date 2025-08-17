group 'com.hui.bluetooth_enable'
version '1.0'

buildscript {
    repositories {
        google()
        mavenCentral()
        mavenLocal()
    }

    dependencies {
        classpath 'com.android.tools.build:gradle:4.1.3'
    }
}

rootProject.allprojects {
    repositories {
        google()
        mavenCentral()
        mavenLocal()
    }
}

apply plugin: 'com.android.library'

android {
    compileSdkVersion 34 // Bu satırı ekleyin.
    namespace "com.hui.bluetooth_enable" // Daha önceki düzeltme
    
    defaultConfig {
        minSdkVersion 18
        testInstrumentationRunner "androidx.test.runner.AndroidJUnitRunner"
    }
    lintOptions {
        disable 'InvalidPackage'
    }
    compileOptions {
        sourceCompatibility JavaVersion.VERSION_1_7
        targetCompatibility JavaVersion.VERSION_1_7
    }
}

dependencies {
    implementation 'androidx.core:core:1.8.0'
}