FROM maven:3.9-eclipse-temurin-21-alpine AS build

WORKDIR /build

COPY pom.xml .
COPY src ./src

RUN mvn clean package -DskipTests

FROM eclipse-temurin:21-jre-alpine

WORKDIR /app

RUN addgroup -S secureflow && adduser -S secureflow -G secureflow

COPY --from=build /build/target/secureflow-api-0.0.1-SNAPSHOT.jar app.jar

RUN chown secureflow:secureflow app.jar

USER secureflow

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "/app/app.jar"]
