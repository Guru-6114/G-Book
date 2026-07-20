buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.google.gms:google-services:4.4.2")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://storage.googleapis.com/download.flutter.io") }
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

// ── FIX: AGP 8+ requires every Android library module to declare a
// namespace. Older/unmaintained plugins (e.g. sim_data 0.0.2) never set
// one in their build.gradle. This patches the namespace in by reading the
// `package` attribute out of that module's own AndroidManifest.xml.
// Because evaluationDependsOn(":app") above may already force some
// projects (like :app) to evaluate early, we can't blindly call
// afterEvaluate on every subproject — check project.state.executed first
// and patch immediately if it's already evaluated. ──
subprojects {
    fun patchNamespaceIfMissing() {
        val androidExt = project.extensions.findByName("android")
        if (androidExt is com.android.build.gradle.BaseExtension) {
            if (androidExt.namespace == null) {
                val manifestFile = project.file("src/main/AndroidManifest.xml")
                if (manifestFile.exists()) {
                    val manifestText = manifestFile.readText()
                    val packageMatch = Regex("package=\"([^\"]+)\"").find(manifestText)
                    if (packageMatch != null) {
                        androidExt.namespace = packageMatch.groupValues[1]
                        println("Patched missing namespace for ${project.name}: ${packageMatch.groupValues[1]}")
                    }
                }
            }
        }
    }

    if (project.state.executed) {
        patchNamespaceIfMissing()
    } else {
        afterEvaluate { patchNamespaceIfMissing() }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}