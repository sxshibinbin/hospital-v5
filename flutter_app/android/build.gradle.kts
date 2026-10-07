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

// audioplayers_android 5.3.0 的 build.gradle 使用 kotlin { compilerOptions } DSL，
// 但没有自行 apply kotlin 插件，依赖外部注入；这里在评估前为其补齐，
// 版本沿用 settings.gradle.kts 中声明的 org.jetbrains.kotlin.android 2.2.20
subprojects {
    if (project.name == "audioplayers_android") {
        project.pluginManager.apply("org.jetbrains.kotlin.android")
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
