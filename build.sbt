val tapirVersion = "1.11.36"
val sttp4Version = "4.0.9"

lazy val rootProject = (project in file(".")).settings(
  Seq(
    name := "thread-pool-playground",
    version := "0.1.0-SNAPSHOT",
    organization := "org.zygiert",
    scalaVersion := "3.6.3",
    libraryDependencies ++= Seq(
      "com.softwaremill.sttp.tapir" %% "tapir-netty-server" % tapirVersion,
      "com.softwaremill.sttp.tapir" %% "tapir-swagger-ui-bundle" % tapirVersion,
      "com.softwaremill.sttp.tapir" %% "tapir-jsoniter-scala" % tapirVersion,
      "com.softwaremill.sttp.client4" %% "core" % sttp4Version,
      "com.softwaremill.sttp.client4" %% "jsoniter" % sttp4Version,
      "com.github.plokhotnyuk.jsoniter-scala" %% "jsoniter-scala-macros" % "2.36.7",
      "ch.qos.logback" % "logback-classic" % "1.5.18",
      "com.typesafe.scala-logging" %% "scala-logging" % "3.9.5",
      "com.softwaremill.sttp.tapir" %% "tapir-sttp-stub-server" % tapirVersion % Test,
      "org.scalatest" %% "scalatest" % "3.2.19" % Test
    )
  )
)
