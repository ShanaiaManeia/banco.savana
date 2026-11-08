FROM maven:3.9-eclipse-temurin-21 AS build
ARG SERVICE
WORKDIR /src
COPY pom.xml .
COPY gateway gateway
COPY auth-service auth-service
COPY contas-service contas-service
COPY transacoes-service transacoes-service
RUN mvn -q -pl ${SERVICE} -am package -DskipTests
FROM eclipse-temurin:21-jre
ARG SERVICE
WORKDIR /app
COPY --from=build /src/${SERVICE}/target/*.jar app.jar
ENTRYPOINT ["java","-jar","app.jar"]
