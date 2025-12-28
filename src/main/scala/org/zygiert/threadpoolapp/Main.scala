package org.zygiert.threadpoolapp

import sttp.tapir.server.netty.{NettyConfig, NettyFutureServer}

import scala.concurrent.ExecutionContext.Implicits.global
import scala.concurrent.duration.*
import scala.concurrent.{Await, ExecutionContext, Future}

@main def run(): Unit =

  val program =
    for
      binding <- NettyFutureServer()
        .host("0.0.0.0")
        .port(8080)
        .config(NettyConfig.default.copy(requestTimeout = Some(120.seconds)))
        .addEndpoints(Endpoints.all)
        .start()
      _ <- Future:
        println(s"Go to http://localhost:${binding.port}/docs to open SwaggerUI.")
        Thread.currentThread().join()
    yield ()

  Await.result(program, Duration.Inf)
