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
    // Some plugins (e.g. vibration and its androidx deps) require compiling
    // against API 36+. Force every Android plugin module up to 36 so their
    // AAR-metadata checks pass without editing each plugin's own build file.
    // Registered before evaluationDependsOn so it isn't attached too late; :app
    // is skipped because it already pins compileSdk = 36 directly.
    if (name != "app") {
        afterEvaluate {
            extensions.findByName("android")?.let {
                (it as com.android.build.gradle.BaseExtension).compileSdkVersion(36)
            }
        }
    }
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
