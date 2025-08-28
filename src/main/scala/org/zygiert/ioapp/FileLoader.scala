package org.zygiert.ioapp

import java.util.concurrent.{Executors, ScheduledExecutorService, TimeUnit}
import scala.concurrent.{ExecutionContext, Future, Promise}
import scala.io.Source

object FileLoader:

  private val fileContent = Source.fromResource("data-10000-words.txt").getLines().toSeq
  private val scheduler: ScheduledExecutorService = Executors.newSingleThreadScheduledExecutor()

  def load(durationMillis: Long)(using ExecutionContext): Future[Seq[String]] = {
    val promise = Promise[Seq[String]]()
    scheduler.schedule(
      () => promise.success(fileContent),
      durationMillis,
      TimeUnit.MILLISECONDS
    )
    promise.future
  }
