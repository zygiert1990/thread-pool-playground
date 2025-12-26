package org.zygiert.threadpoolapp

import io.gatling.core.Predef.*
import io.gatling.core.scenario.Simulation
import io.gatling.http.Predef.*

import scala.concurrent.duration.*

class RunComputations extends Simulation:

  private def envOrThrow(name: String) =
    sys.env.getOrElse(name, throw new Exception(s"Please provide $name!"))

  private val baseUrl = envOrThrow("GATLING_BASE_URL")
  private val computationComplexity = envOrThrow("COMPUTATION_COMPLEXITY").toInt
  private val concurrencyMultiplier = envOrThrow("CONCURRENCY_MULTIPLIER").toInt
  private val duration = envOrThrow("DURATION").toInt
  private val longIO = envOrThrow("LONG_IO").toBoolean

  println(s"Running simulation with:")
  println(s"  Base URL: $baseUrl")
  println(s"  Computation Complexity: $computationComplexity")
  println(s"  Concurrency Multiplier: $concurrencyMultiplier")
  println(s"  Duration: ${duration}s")
  println(s"  Long IO: $longIO")

  private val request =
    scenario(s"Run computations with complexity: $computationComplexity, concurrency multiplier: $concurrencyMultiplier and long IO: $longIO")
      .exec(
        http(s"Run computations")
          .get("/compute")
          .queryParamMap(
            Map("longIO" -> longIO, "computationComplexity" -> computationComplexity, "concurrencyMultiplier" -> concurrencyMultiplier)
          )
      )

  setUp(
    request
      .inject(constantUsersPerSec(4).during(duration.seconds))
      .protocols(http.baseUrl(baseUrl))
  )
