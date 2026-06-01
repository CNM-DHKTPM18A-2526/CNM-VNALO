# syntax=docker/dockerfile:1.4
# =============================================================================
# Content Service — Multi-stage Dockerfile
# Build: Maven 3.9 + Temurin 21 (no mvnw in container — avoids CRLF / go-offline hangs)
# =============================================================================

# --- Stage 1: Build ---
FROM maven:3.9.9-eclipse-temurin-21-alpine AS builder
WORKDIR /build

ENV MAVEN_OPTS="-Dmaven.wagon.http.connectionTimeout=120000 -Dmaven.wagon.http.readTimeout=120000"

# Cache dependencies (faster than dependency:go-offline; shows download progress)
COPY pom.xml .
RUN --mount=type=cache,target=/root/.m2 \
    mvn -B -DskipTests dependency:resolve

COPY src ./src
RUN --mount=type=cache,target=/root/.m2 \
    mvn -B -DskipTests package

# --- Stage 2: Runtime ---
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app

RUN apk add --no-cache wget \
    && addgroup -S appgroup && adduser -S appuser -G appgroup

COPY --from=builder /build/target/*.jar app.jar

HEALTHCHECK --interval=30s --timeout=5s --start-period=40s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8086/api/v1/actuator/health || exit 1

EXPOSE 8086

USER appuser

ENTRYPOINT ["java", \
  "-XX:+UseContainerSupport", \
  "-XX:MaxRAMPercentage=75.0", \
  "-Djava.security.egd=file:/dev/./urandom", \
  "-jar", "app.jar"]
