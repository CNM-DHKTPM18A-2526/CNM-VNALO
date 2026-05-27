# =============================================================================
# Analytics Service — Multi-stage Dockerfile
# Base: Eclipse Temurin 21 (Alpine)
# Build: Maven (direct)
# Runtime: JRE only
# =============================================================================

# --- Stage 1: Build ---
FROM eclipse-temurin:21-jdk-alpine AS builder
WORKDIR /build

ARG MAVEN_RETRIES=5

# Install maven directly
RUN apk add --no-cache maven

# Copy source
COPY .mvn/ .mvn/
COPY pom.xml ./
COPY mvnw mvnw.cmd ./
COPY src/ src/

# Build with retry logic
RUN set -eux; \
    attempts=0; \
    until [ "$attempts" -ge "$MAVEN_RETRIES" ]; do \
      attempts=$((attempts + 1)); \
      mvn -B -U --no-transfer-progress -DskipTests clean package && break; \
      echo "Maven package failed (attempt ${attempts}/${MAVEN_RETRIES})."; \
      find /root/.m2/repository -name "*.lastUpdated" -delete 2>/dev/null || true; \
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

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=45s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8084/api/v1/actuator/health || exit 1

EXPOSE 8084

USER appuser

ENTRYPOINT ["java", \
  "-XX:+UseContainerSupport", \
  "-XX:MaxRAMPercentage=75.0", \
  "-Djava.security.egd=file:/dev/./urandom", \
  "-jar", "app.jar"]
