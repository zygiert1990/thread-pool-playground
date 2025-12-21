package org.zygiert.threadpoolapp

import sttp.tapir.server.netty.NettyFutureServer

import scala.concurrent.ExecutionContext.Implicits.global
import scala.concurrent.duration.Duration
import scala.concurrent.{Await, ExecutionContext, Future}
import scala.io.StdIn

@main def run(): Unit =

  val program =
    for
      binding <- NettyFutureServer().port(8080).addEndpoints(Endpoints.all).start()
      _ <- Future:
        println(s"Go to http://localhost:${binding.port}/docs to open SwaggerUI. Press ENTER key to exit.")
        StdIn.readLine()
      stop <- binding.stop()
    yield stop

  Await.result(program, Duration.Inf)
