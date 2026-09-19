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

// file_picker 11.0.3 compiles no Kotlin at all under AGP 9, and nothing says so
// until the app's own Java cannot find `FilePickerPlugin`.
//
// Three things have to line up for it, and they do:
//
//  1. `android.builtInKotlin=false` in `gradle.properties` — written there by
//     Flutter's own migrator, because this project still applies KGP itself.
//  2. file_picker's `android/build.gradle` applies KGP **only** when AGP is
//     below 9 (`if (!isAgp9OrAbove)`), on the assumption that built-in Kotlin
//     will compile its sources otherwise. Here it will not: (1) turned it off.
//  3. Flutter's Gradle plugin has a repair for exactly this — it applies
//     `kotlin-android` to any Android subproject that has neither built-in
//     Kotlin nor KGP (`FlutterPluginUtils.detectApplyingKotlinGradlePlugin`).
//     It decides by **matching the build script's text**, and file_picker's
//     guarded `apply plugin: 'org.jetbrains.kotlin.android'` line matches
//     whether or not the guard ever fires. So Flutter reads it as a module that
//     applies KGP, skips the repair, and file_picker's `.kt` files are compiled
//     by nobody. It is also why the build warns that file_picker "applies KGP".
//
// So: do what Flutter would have done had it looked at the runtime rather than
// at the text. `plugins.withId` rather than a bare apply, because KGP must land
// after the Android plugin, and this fires the moment file_picker applies it.
//
// **Remove this** on the move to file_picker 12, which drops the conditional
// and the KGP application entirely — see `docs/RELEASE.md`.
subprojects {
    if (name != "file_picker") return@subprojects

    plugins.withId("com.android.library") {
        if (plugins.hasPlugin("org.jetbrains.kotlin.android")) return@withId
        pluginManager.apply("org.jetbrains.kotlin.android")

        // Its own `kotlinOptions` block is behind the same AGP-9 guard, so the
        // Kotlin target would default to 1.8 against Java 17 and fail the
        // build's target-compatibility check instead. Same value as the
        // module's `compileOptions`, which is the point.
        extensions.configure<org.jetbrains.kotlin.gradle.dsl.KotlinAndroidProjectExtension> {
            compilerOptions {
                jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
            }
        }
    }
}
