package org.zygiert.threadpoolapp

import com.typesafe.scalalogging.StrictLogging

import scala.io.Source

object FileLoader extends StrictLogging:

  private val fileContent = Source.fromResource("data-10000-words.txt").getLines().toSeq
  private val longDelay = 500
  private val shortDelay = 50

  def load(longIO: Boolean): Seq[String] =
    val start = System.nanoTime()
    Thread.sleep(if (longIO) longDelay else shortDelay)
    val end = System.nanoTime()
    logger.debug(s"Reading file took: ${end - start}ns")
    fileContent
