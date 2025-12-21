package org.zygiert.threadpoolapp

import sttp.tapir.server.netty.NettyFutureServer

import scala.concurrent.ExecutionContext.Implicits.global
import scala.concurrent.duration.Duration
import scala.concurrent.{Await, ExecutionContext, Future}

@main def run(): Unit =

  val program =
    for
      binding <- NettyFutureServer().host("0.0.0.0").port(8080).addEndpoints(Endpoints.all).start()
      _ <- Future:
        println(s"Go to http://localhost:${binding.port}/docs to open SwaggerUI.")
        Thread.currentThread().join()
    yield ()

  Await.result(program, Duration.Inf)
