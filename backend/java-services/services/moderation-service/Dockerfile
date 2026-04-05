# =============================================================================
# Moderation Service — Multi-stage Dockerfile
# Base: Eclipse Temurin 21 (Alpine)
# Build: Maven wrapper (./mvnw) — no Maven install required
# Runtime: JRE only — minimal image size
# =============================================================================

# --- Stage 1: Build ---
FROM eclipse-temurin:21-jdk-alpine AS builder
WORKDIR /build

# Copy Maven wrapper and config first (cache dependencies layer)
COPY .mvn/ .mvn/
COPY mvnw pom.xml ./
RUN chmod +x mvnw && ./mvnw dependency:go-offline -B

# Copy source and build
COPY src/ src/
RUN ./mvnw clean package -DskipTests -B

# --- Stage 2: Runtime ---
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app

# Security: run as non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Copy JAR from builder
COPY --from=builder /build/target/*.jar app.jar

# Expose port
EXPOSE 8082

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=40s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8082/api/v1/actuator/health || exit 1

# Run as non-root
USER appuser

# Start application
ENTRYPOINT ["java", "-jar", "/app/app.jar"]