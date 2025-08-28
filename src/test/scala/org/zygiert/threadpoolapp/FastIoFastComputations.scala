package org.zygiert.threadpoolapp

import io.gatling.core.Predef.*
import io.gatling.core.scenario.Simulation
import io.gatling.http.Predef.*
import org.zygiert.threadpoolapp.PortToThreadConfig.*

import scala.concurrent.duration.*

class FastIoFastComputations extends Simulation:

  private def request(description: String) =
    scenario(s"short computations & short IO with $description")
      .exec(
        http(s"short computations & short IO with $description")
          .get("/compute")
          .queryParamMap(Map("longIO" -> false, "computationComplexity" -> 1, "concurrencyMultiplier" -> 1))
      )

  private def useCase(config: PortToThreadConfig) =
    request(config.description)
      .inject(constantUsersPerSec(10).during(10.seconds))
      .protocols(protocol(config.port))

  setUp(
    useCase(ForkJoinPool),
    useCase(ForkJoinPoolBlocking),
    useCase(ForkJoinPoolVirtualThreadPool),
    useCase(ForkJoinPoolCachedThreadPool),
    useCase(CachedThreadPool),
    useCase(FixedThreadPool),
    useCase(FixedThreadPoolVirtualThreadPool),
    useCase(FixedThreadPoolCachedThreadPool)
  )

  private def protocol(port: Int) = http.baseUrl(s"http://localhost:$port")
