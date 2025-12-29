package org.zygiert.threadpoolapp

import com.typesafe.scalalogging.StrictLogging

import java.util.concurrent.Executors
import scala.concurrent.ExecutionContext
import scala.util.Try

object ExecutionContextProvider extends StrictLogging:

  val threadPoolConfigParam: String = "threadPoolConfig"

  case class ExecutionContexts(cpuBound: ExecutionContext, ioBound: ExecutionContext)

  val executionContexts: ExecutionContexts = resolveExecutionContexts

  private def resolveExecutionContexts: ExecutionContexts =
    sys.props.get(threadPoolConfigParam) match {
      case Some(value) =>
        logger.debug(s"thread pool config to parse: $value")
        Try(ThreadPoolConfig.valueOf(value))
          .map {
            case ThreadPoolConfig.GLOBAL =>
              val ec = ExecutionContext.global
              ExecutionContexts(ec, ec)
            case ThreadPoolConfig.GLOBAL_VTP =>
              ExecutionContexts(ExecutionContext.global, virtualThreadPool)
            case ThreadPoolConfig.GLOBAL_CTP =>
              ExecutionContexts(ExecutionContext.global, cachedThreadPool)
            case ThreadPoolConfig.FJP =>
              val ec = forkJoinPool
              ExecutionContexts(ec, ec)
            case ThreadPoolConfig.FJP_VTP =>
              ExecutionContexts(forkJoinPool, virtualThreadPool)
            case ThreadPoolConfig.FJP_CTP =>
              ExecutionContexts(forkJoinPool, cachedThreadPool)
            case ThreadPoolConfig.CTP =>
              val ec = cachedThreadPool
              ExecutionContexts(ec, ec)
            case ThreadPoolConfig.CTP_VTP =>
              ExecutionContexts(cachedThreadPool, virtualThreadPool)
            case ThreadPoolConfig.FTP =>
              val ec = fixedThreadPool
              ExecutionContexts(ec, ec)
            case ThreadPoolConfig.FTP_VTP =>
              ExecutionContexts(fixedThreadPool, virtualThreadPool)
            case ThreadPoolConfig.FTP_CTP =>
              ExecutionContexts(fixedThreadPool, cachedThreadPool)
            case ThreadPoolConfig.VTP =>
              val ec = virtualThreadPool
              ExecutionContexts(ec, ec)
          }
          .getOrElse(
            throw new IllegalArgumentException(
              s"Unknown thread pool config: $value. Allowed values: ${ThreadPoolConfig.values.mkString(",")}"
            )
          )
      case None =>
        throw new IllegalStateException(
          s"No thread pool config provided. Please provide it using -DthreadPoolConfig=VALUE. Possible values are: ${ThreadPoolConfig.values.mkString(",")}"
        )
    }

  private def forkJoinPool: ExecutionContext = ExecutionContext.fromExecutor(Executors.newWorkStealingPool)
  private def virtualThreadPool = ExecutionContext.fromExecutor(Executors.newVirtualThreadPerTaskExecutor())
  private def cachedThreadPool = ExecutionContext.fromExecutor(Executors.newCachedThreadPool())
  private def fixedThreadPool = ExecutionContext.fromExecutor(Executors.newFixedThreadPool(Runtime.getRuntime.availableProcessors()))

  enum ThreadPoolConfig {
    case GLOBAL, GLOBAL_VTP, GLOBAL_CTP, FJP, FJP_VTP, FJP_CTP, CTP, CTP_VTP, FTP, FTP_VTP, FTP_CTP, VTP
  }
