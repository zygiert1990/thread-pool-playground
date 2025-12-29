## Quick start

This is an example where I would like to show how different thread pools work under various load conditions.

In this repository there are basically two applications:

- thread-pool-playground-app
- thread-pool-playground-io-app

Flow is straightforward. There is a single endpoint in thread-pool-playground-app which calculates the number of words
in a given file. File is provided by thread-pool-playground-io-app, so it is easier for me to manage the delay (I want
to simulate long and short IO operations).

There are some configurations that may be passed using system properties.

thread-pool-playground-app:

- `threadPoolConfig` (mandatory) — possible values: FJP, FJP_VTP, FJP_CTP, CTP, FTP, FTP_VTP, FTP_CTP, VTP
- `fjpBlockingIo` (optional) – indicates whether use `blocking` operation, default value is `false`. It only applies to
  FJP thread pool config.
- `numberOfProcessingThreads` (optional) – default value is numebr of cores on the machine.

For get more logs from Netty, please adjust Netty config:
```
        .config(NettyConfig.default.copy(
          requestTimeout = Some(1200.seconds),
          idleTimeout = Some(1200.seconds),
          host = "0.0.0.0",
          addLoggingHandler = true))
```

Having this, we can analyze intervals between the request was initially handled by Netty event loop and the 
response was sent back:
`./netty-log-analyzer.sh <log_file>`

To check in what interval they arrived:
`./netty-intervals-between-requests.sh <log_file>`