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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

// file_picker 11.0.3 applies KGP only below AGP 9. With built-in Kotlin off
// (gradle.properties), Flutter's Gradle plugin would normally apply it, but it
// matches the build script's text and wrongly sees KGP applied, so the Kotlin
// sources never compile. Apply KGP here, after the Android plugin. Remove this
// on file_picker 12.
subprojects {
    if (name != "file_picker") return@subprojects

    plugins.withId("com.android.library") {
        if (plugins.hasPlugin("org.jetbrains.kotlin.android")) return@withId
        pluginManager.apply("org.jetbrains.kotlin.android")

        // Its own `kotlinOptions` is behind the same AGP 9 guard, so set the
        // Kotlin target to match its Java 17 `compileOptions` here.
        extensions.configure<org.jetbrains.kotlin.gradle.dsl.KotlinAndroidProjectExtension> {
            compilerOptions {
                jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
            }
        }
    }
}
