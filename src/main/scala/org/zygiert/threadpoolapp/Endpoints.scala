package org.zygiert.threadpoolapp

import sttp.tapir.*
import sttp.tapir.server.ServerEndpoint
import sttp.tapir.server.metrics.prometheus.PrometheusMetrics
import sttp.tapir.swagger.bundle.SwaggerInterpreter

import scala.concurrent.{ExecutionContext, Future}

object Endpoints:

  private val processFileEndpoint = endpoint.get
    .in("compute")
    .in(query[Boolean]("longIO"))
    .in(
      query[Int]("computationComplexity").description(
        "This number indicates how complex computation will be. Complexity doesn't grow linearly, but rather exponentially."
      )
        .default(1)
    )
    .in(
      query[Int]("concurrencyMultiplier")
        .description(
          "This number is a multiplier to number of available cores. It means that computation will be started concurrently according to formula: nrOfCores * concurrencyMultiplier."
        )
        .default(1)
    )
    .out(stringBody)
    .serverLogicSuccess((longIO, computationComplexity, concurrencyMultiplier) =>
      FileProcessor.process(longIO, computationComplexity, concurrencyMultiplier).map(_.toString)(using ExecutionContext.parasitic)
    )

  private val apiEndpoints: List[ServerEndpoint[Any, Future]] = List(processFileEndpoint)

  private val docEndpoints: List[ServerEndpoint[Any, Future]] = SwaggerInterpreter()
    .fromServerEndpoints[Future](apiEndpoints, "thread-pool-playground-app", "1.0.0")

  val prometheusMetrics: PrometheusMetrics[Future] = PrometheusMetrics.default[Future]()
  private val metricsEndpoint: ServerEndpoint[Any, Future] = prometheusMetrics.metricsEndpoint

  val all: List[ServerEndpoint[Any, Future]] = apiEndpoints ++ docEndpoints ++ List(metricsEndpoint)
