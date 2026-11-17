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

// integration_test 的依赖声明使用动态版本（1.2+ / 3.2+），每次构建都要联网
// 查询 maven-metadata；离线或 download.flutter.io 不通时会直接失败。
// 这里钉死为本机 Gradle 缓存中已存在的静态版本（与 1.2+ 的解析结果一致）。
subprojects {
    if (project.name == "integration_test") {
        project.configurations.configureEach {
            resolutionStrategy {
                force("androidx.test:runner:1.2.0")
                force("androidx.test:rules:1.2.0")
                force("androidx.test.espresso:espresso-core:3.2.0")
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
