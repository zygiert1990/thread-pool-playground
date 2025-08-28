FROM eclipse-temurin:21-jre-alpine

WORKDIR /app
COPY target/scala-3.6.3/thread-pool-playground.jar app.jar

CMD ["java", "-cp", "app.jar", "org.zygiert.threadpoolapp.run"]