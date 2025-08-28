package org.zygiert.threadpoolapp

import sttp.tapir.server.netty.{NettyFutureServer, NettyFutureServerOptions}

import scala.concurrent.ExecutionContext.Implicits.global
import scala.concurrent.duration.Duration
import scala.concurrent.{Await, ExecutionContext, Future}
import scala.io.StdIn

@main def run(): Unit =

  val host = sys.env.getOrElse("host", "localhost")
  val serverOptions = NettyFutureServerOptions.customiseInterceptors
    .metricsInterceptor(Endpoints.prometheusMetrics.metricsInterceptor())
    .options

  val program =
    for
      binding <- NettyFutureServer(serverOptions).host(host).port(8080).addEndpoints(Endpoints.all).start()
      _ <- Future:
        println(s"Go to http://localhost:${binding.port}/docs to open SwaggerUI. Press ENTER key to exit.")
        StdIn.readLine()
      stop <- binding.stop()
    yield stop

  Await.result(program, Duration.Inf)
