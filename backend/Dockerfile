FROM gradle:8.10.0-jdk21 AS build

WORKDIR /home/gradle/src

COPY build.gradle settings.gradle ./

RUN gradle --no-daemon dependencies > /dev/null 2>&1 || true

COPY src ./src

RUN gradle --no-daemon clean bootJar -x test

# ---------- Runtime Stage ----------
FROM eclipse-temurin:21-jre-alpine

ENV JAVA_OPTS="-XX:MaxRAMPercentage=75.0 -XX:+UseContainerSupport"

RUN addgroup -S spring && adduser -S spring -G spring
USER spring:spring

WORKDIR /app

COPY --from=build /home/gradle/src/build/libs/*.jar /app/app.jar

EXPOSE 8080

ENV SPRING_PROFILES_ACTIVE=default

ENTRYPOINT ["sh", "-c", "exec java $JAVA_OPTS -jar /app/app.jar"]
