package org.zygiert.threadpoolapp

import org.zygiert.threadpoolapp.ExecutionContextProvider.ThreadPoolConfig.FJP
import org.zygiert.threadpoolapp.ExecutionContextProvider.{ThreadPoolConfig, threadPoolConfigParam}

import scala.concurrent.{ExecutionContext, Future, blocking}

object FileLoaderAdapter:

  given ExecutionContext = ExecutionContextProvider.executionContexts.ioBound

  private val threadPoolConfig = sys.props
    .get(threadPoolConfigParam)
    .getOrElse(
      throw new IllegalStateException(
        s"No thread pool config provided. Please provide it using -DthreadPoolConfig=VALUE. Possible values are: ${ThreadPoolConfig.values.mkString(",")}"
      )
    )
  private val fjpBlockingIo = sys.props.get("fjpBlockingIo").exists(_.toBoolean)

  def load(longIO: Boolean): Future[Seq[String]] =
    if (ThreadPoolConfig.valueOf(threadPoolConfig) == FJP && fjpBlockingIo)
      Future {
        blocking(FileLoader.load(longIO))
      }
    else Future(FileLoader.load(longIO))
