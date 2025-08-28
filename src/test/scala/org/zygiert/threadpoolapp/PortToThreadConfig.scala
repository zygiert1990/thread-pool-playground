package org.zygiert.threadpoolapp

enum PortToThreadConfig(val description: String, val port: Int):
  
  case ForkJoinPool extends PortToThreadConfig("Fork Join Pool", 8080)
  case ForkJoinPoolBlocking extends PortToThreadConfig("Fork Join Pool with blocking", 8081)
  case ForkJoinPoolVirtualThreadPool extends PortToThreadConfig("Fork Join Pool with Virtual Thread Pool", 8082)
  case ForkJoinPoolCachedThreadPool extends PortToThreadConfig("Fork Join Pool with Cached Thread Pool", 8083)
  case CachedThreadPool extends PortToThreadConfig("Cached Thread Pool", 8084)
  case FixedThreadPool extends PortToThreadConfig("Fixed Thread Pool", 8085)
  case FixedThreadPoolVirtualThreadPool extends PortToThreadConfig("Fixed Thread Pool with Virtual Thread Pool", 8086)
  case FixedThreadPoolCachedThreadPool extends PortToThreadConfig("Fixed Thread Pool with Cached Thread Pool", 8087)
