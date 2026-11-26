import java.util.UUID

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

val workspaceId = UUID.nameUUIDFromBytes(rootProject.projectDir.canonicalPath.toByteArray())

subprojects {
    val projectRoot = projectDir.toPath().root
    if (projectRoot == newBuildDir.asFile.toPath().root) {
        layout.buildDirectory.set(newBuildDir.dir(name))
    } else {
        // Android unit test tasks need paths relative to the plugin's project directory.
        val gradleHome = gradle.gradleUserHomeDir
        val externalBuildDir = if (projectRoot == gradleHome.toPath().root) {
            gradleHome.resolve("flutter-builds/$workspaceId/$name")
        } else {
            projectDir.resolve("build/$workspaceId")
        }
        layout.buildDirectory.set(externalBuildDir)
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
