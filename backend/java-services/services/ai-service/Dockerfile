# =============================================================================
# AI Service — Multi-stage Dockerfile
# Base: Eclipse Temurin 21 (Alpine)
# Build: Maven wrapper (./mvnw) — no Maven install required
# Runtime: JRE only — minimal image size
# =============================================================================

# --- Stage 1: Build ---
FROM eclipse-temurin:21-jdk-alpine AS builder
WORKDIR /build

ARG MAVEN_RETRIES=5

# Copy Maven wrapper and config first (cache dependencies layer)
COPY .mvn/ .mvn/
COPY mvnw pom.xml ./
RUN set -eux; \
    chmod +x mvnw; \
    attempts=0; \
    until [ "$attempts" -ge "$MAVEN_RETRIES" ]; do \
      attempts=$((attempts + 1)); \
      ./mvnw -B -U --no-transfer-progress -Dmaven.wagon.http.retryHandler.count=5 dependency:go-offline && break; \
      echo "Maven go-offline failed (attempt ${attempts}/${MAVEN_RETRIES})."; \
      find /root/.m2/repository -name "*.lastUpdated" -delete || true; \
      if [ "$attempts" -ge "$MAVEN_RETRIES" ]; then exit 1; fi; \
      sleep $((attempts * 5)); \
    done

# Copy source and build
COPY src/ src/
RUN set -eux; \
    attempts=0; \
    until [ "$attempts" -ge "$MAVEN_RETRIES" ]; do \
      attempts=$((attempts + 1)); \
      ./mvnw -B -U --no-transfer-progress -DskipTests clean package && break; \
      echo "Maven package failed (attempt ${attempts}/${MAVEN_RETRIES})."; \
      find /root/.m2/repository -name "*.lastUpdated" -delete || true; \
      if [ "$attempts" -ge "$MAVEN_RETRIES" ]; then exit 1; fi; \
      sleep $((attempts * 5)); \
    done

# --- Stage 2: Runtime ---
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app

# Security: run as non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Copy JAR from builder
COPY --from=builder /build/target/*.jar app.jar

# Health check — AI service usually has a slightly longer start period
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8094/api/v1/actuator/health || exit 1

EXPOSE 8094

USER appuser

ENTRYPOINT ["java", \
  "-XX:+UseContainerSupport", \
  "-XX:MaxRAMPercentage=75.0", \
  "-Djava.security.egd=file:/dev/./urandom", \
  "-jar", "app.jar"]
