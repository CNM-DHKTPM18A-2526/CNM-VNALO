# ====== BUILD STAGE ======
FROM maven:3.9.9-eclipse-temurin-21-alpine AS builder

WORKDIR /app

# Copy POM first for better dependency cache reuse
COPY pom.xml .
RUN mvn dependency:go-offline -B

# Copy source code and build
COPY src ./src
RUN mvn clean package -Dmaven.test.skip=true -B

# ====== RUNTIME STAGE ======
FROM eclipse-temurin:21-jre-alpine

WORKDIR /app

# Create non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Copy jar from build stage
COPY --from=builder /app/target/*.jar app.jar

# Own the working directory
RUN chown -R appuser:appgroup /app
USER appuser

# Expose port
EXPOSE 8083

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD wget -qO- http://localhost:8083/actuator/health || exit 1

# Run — shell form so $JAVA_OPTS from docker-compose is expanded
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]
