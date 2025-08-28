## Quick start

This is an example where I would like to show how different thread pools work under various load conditions.

In this repository there are basically two applications:

- thread-pool-playground-app
- thread-pool-playground-io-app

Flow is straightforward. There is a single endpoint in thread-pool-playground-app which calculates the number of words
in a given file. File is provided by thread-pool-playground-io-app, so it is easier for me to manage the delay (I want
to simulate long and short IO operations).

There are some configurations that may be passed using system variables.

thread-pool-playground-app:

- `threadPoolConfig` (mandatory) — possible values: FJP, FJP_VTP, FJP_CTP, CTP, FTP, FTP_VTP, FTP_CTP
- `ioAppUrl` (optional) - default value is `http://localhost:9090`
- `fjpBlockingIo` (optional) - Indicates whether use `blocking` operation, default value is `false`. It only applies to
  FJP thread pool config.
- `host` (optional) - default value is `localhost`

thread-pool-playground-io-app:

- `host` (optional) - default value is `localhost`
