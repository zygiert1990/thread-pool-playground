FROM eclipse-temurin:21-jre-alpine

WORKDIR /app
COPY target/scala-3.6.3/thread-pool-playground.jar app.jar
COPY jmx_prometheus_javaagent-0.18.0.jar .
COPY jmx_prometheus_config.yaml .

CMD ["java", "-cp", "app.jar", "org.zygiert.threadpoolapp.run"]