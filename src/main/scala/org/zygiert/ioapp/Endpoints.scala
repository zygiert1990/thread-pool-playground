package org.zygiert.ioapp

import com.github.plokhotnyuk.jsoniter_scala.core.JsonValueCodec
import com.github.plokhotnyuk.jsoniter_scala.macros.JsonCodecMaker
import sttp.tapir.*
import sttp.tapir.json.jsoniter.*
import sttp.tapir.server.ServerEndpoint
import sttp.tapir.swagger.bundle.SwaggerInterpreter

import scala.concurrent.{ExecutionContext, Future}

object Endpoints:

  given JsonValueCodec[Seq[String]] = JsonCodecMaker.make
  given ExecutionContext = ExecutionContext.global

  private val getFileEndpoint = endpoint.get
    .in("file")
    .in(query[Long]("delay"))
    .out(jsonBody[Seq[String]])
    .serverLogicSuccess(delay => FileLoader.load(delay))

  private val apiEndpoints: List[ServerEndpoint[Any, Future]] = List(getFileEndpoint)

  private val docEndpoints: List[ServerEndpoint[Any, Future]] = SwaggerInterpreter()
    .fromServerEndpoints[Future](apiEndpoints, "thread-pool-playground-io-app", "1.0.0")

  val all: List[ServerEndpoint[Any, Future]] = apiEndpoints ++ docEndpoints
