package org.zygiert.threadpoolapp

import com.typesafe.scalalogging.StrictLogging

import scala.concurrent.{ExecutionContext, Future}
import scala.io.Source

object FileLoader extends StrictLogging:

  given ExecutionContext = ExecutionContextProvider.executionContexts.ioBound

  private val fileContent = Source.fromResource("data-10000-words.txt").getLines().toSeq
  private val longDelay = 500
  private val shortDelay = 50

  def load(longIO: Boolean): Future[Seq[String]] =
    Future {
      val start = System.nanoTime()
      Thread.sleep(if (longIO) longDelay else shortDelay)
      val end = System.nanoTime()
      logger.debug(s"Reading file took: ${end - start}ns")
      fileContent
    }
