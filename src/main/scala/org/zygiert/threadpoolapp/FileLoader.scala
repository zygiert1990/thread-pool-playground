package org.zygiert.threadpoolapp

import com.github.plokhotnyuk.jsoniter_scala.core.JsonValueCodec
import com.github.plokhotnyuk.jsoniter_scala.macros.JsonCodecMaker
import com.typesafe.scalalogging.StrictLogging
import sttp.client4.*
import sttp.client4.jsoniter.*

import scala.concurrent.{ExecutionContext, Future}

object FileLoader extends StrictLogging:

  private val ioAppUrl = sys.env.getOrElse("ioAppUrl", "http://localhost:9090")
  private val delay = 500

  given JsonValueCodec[Seq[String]] = JsonCodecMaker.make

  def load(longIO: Boolean): Seq[String] =
    val start = System.nanoTime()

    val response = basicRequest
      .get(uri"$ioAppUrl/file?delay=${if (longIO) delay else 0}")
      .response(asJson[Seq[String]])
      .send(DefaultSyncBackend())

    val end = System.nanoTime()
    logger.debug(s"Reading file took: ${end - start}ns")
    response.body match {
      case Left(error)  => throw new IllegalStateException(error)
      case Right(value) => value
    }
