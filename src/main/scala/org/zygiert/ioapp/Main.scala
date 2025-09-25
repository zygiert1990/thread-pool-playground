package org.zygiert.ioapp

import sttp.tapir.server.netty.NettyFutureServer

import scala.concurrent.duration.Duration
import scala.concurrent.{Await, ExecutionContext, Future}
import scala.io.StdIn
import ExecutionContext.Implicits.global

@main def run(): Unit =

  val host = sys.env.getOrElse("host", "localhost")
  val port = sys.env.getOrElse("port", "9095").toInt
  
  val program =
    for
      binding <- NettyFutureServer().host(host).port(port).addEndpoints(Endpoints.all).start()
      _ <- Future:
        println(s"Go to http://localhost:${binding.port}/docs to open SwaggerUI. Press ENTER key to exit.")
        StdIn.readLine()
      stop <- binding.stop()
    yield stop

  Await.result(program, Duration.Inf)
