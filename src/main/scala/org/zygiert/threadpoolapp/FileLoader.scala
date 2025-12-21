package org.zygiert.threadpoolapp

import com.typesafe.scalalogging.StrictLogging

import scala.io.Source

object FileLoader extends StrictLogging:

  private val fileContent = Source.fromResource("data-10000-words.txt").getLines().toSeq
  private val delay = 500

  def load(longIO: Boolean): Seq[String] =
    val start = System.nanoTime()
    Thread.sleep(if (longIO) delay else 0)
    val end = System.nanoTime()
    logger.debug(s"Reading file took: ${end - start}ns")
    fileContent
