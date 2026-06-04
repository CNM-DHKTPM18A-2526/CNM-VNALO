allprojects {
    repositories {
        google()
        mavenCentral()
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

subprojects {
    tasks.withType<org.gradle.api.tasks.compile.JavaCompile>().configureEach {
        sourceCompatibility = JavaVersion.VERSION_11.toString()
        targetCompatibility = JavaVersion.VERSION_11.toString()
        options.compilerArgs.add("-Xlint:-options")
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
