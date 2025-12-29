package org.zygiert.threadpoolapp

import com.typesafe.scalalogging.StrictLogging
import org.zygiert.threadpoolapp.ExecutionContextProvider.{ThreadPoolConfig, threadPoolConfigParam}

import scala.concurrent.{ExecutionContext, Future, blocking}

object FileLoaderAdapter extends StrictLogging:

  given ExecutionContext = ExecutionContextProvider.executionContexts.ioBound

  private val threadPoolConfig = sys.props.getOrElse(
    threadPoolConfigParam,
    throw new IllegalStateException(
      s"No thread pool config provided. Please provide it using -DthreadPoolConfig=VALUE. Possible values are: ${ThreadPoolConfig.values.mkString(",")}"
    )
  )
  private val fjpBlockingIo = sys.props.get("fjpBlockingIo").exists(_.toBoolean)

  logger.debug(s"Use blocking IO: $fjpBlockingIo")

  def load(longIO: Boolean)(using counter: Int): Future[Seq[String]] =
    Future {
      logger.debug(s"Load file with counter: $counter")
      if (isGlobalOrFjp && fjpBlockingIo)
        blocking(FileLoader.load(longIO))
      else
        FileLoader.load(longIO)
    }

  private def isGlobalOrFjp: Boolean =
    val config = ThreadPoolConfig.valueOf(threadPoolConfig)
    config == ThreadPoolConfig.GLOBAL || config == ThreadPoolConfig.FJP
