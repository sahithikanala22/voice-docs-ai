allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Some Flutter plugins (e.g. vosk_flutter_service) hardcode an old
// compileSdk in their own android/build.gradle instead of deriving it from
// flutter.compileSdkVersion, which then fails AAR-metadata checks against
// newer transitive dependencies. Force every Android library subproject to
// compile against at least API 36 — compileSdk only affects which APIs are
// compiled against, not minSdk/targetSdk, so this is safe to raise
// unconditionally.
subprojects {
    val fixCompileSdk = {
        val androidExtension = extensions.findByName("android")
        if (androidExtension is com.android.build.gradle.LibraryExtension) {
            val current = androidExtension.compileSdkVersion?.removePrefix("android-")?.toIntOrNull()
            if (current != null && current < 36) {
                androidExtension.compileSdk = 36
            }
        }
    }
    // `:app`'s evaluationDependsOn above can force some subprojects to
    // finish evaluating before this block runs for them — afterEvaluate
    // throws in that case, so apply immediately when that's already true.
    if (state.executed) {
        fixCompileSdk()
    } else {
        afterEvaluate { fixCompileSdk() }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
