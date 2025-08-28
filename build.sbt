import sbtassembly.AssemblyPlugin.autoImport.{assembly, assemblyMergeStrategy}

val tapirVersion = "1.11.42"
val sttp4Version = "4.0.9"
val gatlingVersion = "3.14.3"

ThisBuild / externalResolvers := Seq(Resolver.mavenCentral)

lazy val rootProject = (project in file("."))
  .settings(
    Seq(
      name := "thread-pool-playground",
      version := "0.1.0-SNAPSHOT",
      organization := "org.zygiert",
      scalaVersion := "3.6.3",
      libraryDependencies ++= Seq(
        "com.softwaremill.sttp.tapir" %% "tapir-netty-server" % tapirVersion,
        "com.softwaremill.sttp.tapir" %% "tapir-swagger-ui-bundle" % tapirVersion,
        "com.softwaremill.sttp.tapir" %% "tapir-jsoniter-scala" % tapirVersion,
        "com.softwaremill.sttp.tapir" %% "tapir-prometheus-metrics" % tapirVersion,
        "com.softwaremill.sttp.client4" %% "core" % sttp4Version,
        "com.softwaremill.sttp.client4" %% "jsoniter" % sttp4Version,
        "com.github.plokhotnyuk.jsoniter-scala" %% "jsoniter-scala-macros" % "2.37.6",
        "ch.qos.logback" % "logback-classic" % "1.5.18",
        "com.typesafe.scala-logging" %% "scala-logging" % "3.9.5",
        "com.softwaremill.sttp.tapir" %% "tapir-sttp-stub-server" % tapirVersion % Test,
        "org.scalatest" %% "scalatest" % "3.2.19" % Test,
        "io.gatling.highcharts" % "gatling-charts-highcharts" % gatlingVersion % Test excludeAll ("com.typesafe.scala-logging", "scala-logging"),
        "io.gatling" % "gatling-test-framework" % gatlingVersion % Test excludeAll ("com.typesafe.scala-logging", "scala-logging")
      )
    )
  )
  .settings(fatJarSettings)
  .enablePlugins(GatlingPlugin)

lazy val fatJarSettings = Seq(
  assembly / assemblyJarName := "thread-pool-playground.jar",
  assembly / assemblyMergeStrategy := {
    // SwaggerUI: https://tapir.softwaremill.com/en/latest/docs/openapi.html#using-swaggerui-with-sbt-assembly
    case PathList("META-INF", "maven", "org.webjars", "swagger-ui", "pom.properties") => MergeStrategy.singleOrError
    case PathList("META-INF", "resources", "webjars", "swagger-ui", _*)               => MergeStrategy.singleOrError
    // other
    case PathList(ps @ _*) if ps.last endsWith "io.netty.versions.properties" => MergeStrategy.first
    case PathList(ps @ _*) if ps.last endsWith "pom.properties"               => MergeStrategy.discard
    case PathList(ps @ _*) if ps.last endsWith "module-info.class"            => MergeStrategy.discard
    case PathList(ps @ _*) if ps.last endsWith "okio.kotlin_module"           => MergeStrategy.discard
    case x =>
      val oldStrategy = (assembly / assemblyMergeStrategy).value
      oldStrategy(x)
  }
)
