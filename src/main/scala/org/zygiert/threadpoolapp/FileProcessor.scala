package org.zygiert.threadpoolapp

import com.typesafe.scalalogging.StrictLogging

import scala.annotation.tailrec
import scala.concurrent.{ExecutionContext, Future}

object FileProcessor extends StrictLogging:

  private val numberOfThreads = 4
  private val baseExponent = 100

  given ExecutionContext = ExecutionContextProvider.executionContexts.cpuBound

  def process(longIO: Boolean, computationComplexity: Int, concurrencyMultiplier: Int): Future[BigInt] =
    for {
      lines <- FileLoaderAdapter.load(longIO)
      notEmptyLines <- Future(lines.filter(!_.isBlank))
      allWords <- Future(notEmptyLines.flatMap(_.split(" ").toSeq))
      groupedWords <- Future(allWords.grouped(resolveGroupSize(concurrencyMultiplier, allWords.length)))
      result <- compute(resolveExponent(computationComplexity), groupedWords)
    } yield result

  private def resolveGroupSize(concurrencyMultiplier: Int, nrOfWords: Int): Int =
    val concurrency = numberOfThreads * concurrencyMultiplier
    nrOfWords / concurrency + (if (nrOfWords % concurrency == 0) 0 else 1)

  private def resolveExponent(computationComplexity: Int): Int = baseExponent * computationComplexity

  private def compute(exponent: Int, groupedWords: Iterator[Seq[String]]): Future[BigInt] =
    Future.traverse(groupedWords)(words => doComputation(words, exponent)).map(_.sum)

  private def doComputation(words: Seq[String], exponent: Int): Future[BigInt] =
    Future {
      val start = System.currentTimeMillis()
      val res = words.map(word => doComputation(word, exponent)).sum
      val end = System.currentTimeMillis()
      logger.debug(s"My Computation took: ${end - start}ms")
      res
    }

  private def doComputation(word: String, exponent: Int): BigInt =
    val base = word.length
    @tailrec
    def helperFunction(counter: Int, result: BigInt): BigInt =
      if (counter == 0) result
      else helperFunction(counter - 1, result * base)

    helperFunction(exponent, 1)
