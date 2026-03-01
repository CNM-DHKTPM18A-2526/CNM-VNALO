# =============================================================================
# VNALO — Local Development Startup Script
# Runs infrastructure (PostgreSQL + Redis) in Docker,
# and application services (core-service, message-service) locally.
#
# Usage:
#   .\scripts\dev-local.ps1           # Start all (default)
#   .\scripts\dev-local.ps1 -Stop     # Stop all local processes
#   .\scripts\dev-local.ps1 -Core     # Start only core-service locally
#   .\scripts\dev-local.ps1 -Message  # Start only message-service locally
#   .\scripts\dev-local.ps1 -Infra    # Start only Docker infra
# =============================================================================

param(
    [switch]$Stop,
    [switch]$Core,
    [switch]$Message,
    [switch]$Infra
)

$Root = Split-Path -Parent $PSScriptRoot
$CoreDir = Join-Path $Root "backend\java-services\services\core-service"
$NodeDir = Join-Path $Root "backend\node-services"
$DockerDir = Join-Path $Root "docker"

function Write-Step($msg) { Write-Host "`n>> $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "  [OK] $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "  [!] $msg" -ForegroundColor Yellow }
function Write-Err($msg)  { Write-Host "  [ERR] $msg" -ForegroundColor Red }

# ── STOP ──────────────────────────────────────────────────────────────────────
if ($Stop) {
    Write-Step "Stopping local services..."
    Get-Process -Name "java" -ErrorAction SilentlyContinue | Stop-Process -Force
    Get-Process -Name "node" -ErrorAction SilentlyContinue |
        Where-Object { $_.MainWindowTitle -like "*message*" -or $_.CommandLine -like "*nest*" } |
        Stop-Process -Force -ErrorAction SilentlyContinue
    Write-Ok "Local services stopped."
    Write-Warn "Docker infra (postgres, redis) still running. Use 'docker compose down' to stop them."
    exit 0
}

# ── ENSURE DOCKER INFRA IS RUNNING ───────────────────────────────────────────
Write-Step "Ensuring Docker infrastructure (postgres + redis) is running..."

$pgRunning = (docker ps --filter "name=vnalo-postgres" --filter "status=running" -q) -ne ""
$redisRunning = (docker ps --filter "name=vnalo-redis" --filter "status=running" -q) -ne ""

if (-not $pgRunning -or -not $redisRunning) {
    Write-Warn "Starting Docker infra containers..."
    Push-Location $DockerDir
    docker compose -f docker-compose.infra.yml up -d
    Pop-Location

    Write-Warn "Waiting for postgres to be ready..."
    $retries = 0
    do {
        Start-Sleep -Seconds 2
        $pgReady = (docker exec vnalo-postgres pg_isready -U postgres 2>&1) -match "accepting"
        $retries++
    } while (-not $pgReady -and $retries -lt 15)

    if ($pgReady) { Write-Ok "PostgreSQL ready." } else { Write-Err "PostgreSQL not ready after 30s!"; exit 1 }
} else {
    Write-Ok "Docker infra already running (postgres + redis)."
}

# ── STOP DOCKER APP CONTAINERS (free ports 8081 and 3000) ────────────────────
Write-Step "Stopping Docker app containers to free ports 8081 and 3000..."

$coreDockerRunning = (docker ps --filter "name=vnalo-core-service" --filter "status=running" -q) -ne ""
$msgDockerRunning  = (docker ps --filter "name=vnalo-message-service" --filter "status=running" -q) -ne ""

if ($coreDockerRunning) {
    docker stop vnalo-core-service | Out-Null
    Write-Ok "Stopped Docker vnalo-core-service (freed port 8081)."
} else {
    Write-Ok "vnalo-core-service Docker container not running."
}

if ($msgDockerRunning) {
    docker stop vnalo-message-service | Out-Null
    Write-Ok "Stopped Docker vnalo-message-service (freed port 3000)."
} else {
    Write-Ok "vnalo-message-service Docker container not running."
}

if ($Infra) {
    Write-Ok "Infrastructure ready. Run services manually when needed."
    exit 0
}

# ── START CORE-SERVICE LOCALLY ────────────────────────────────────────────────
if (-not $Message) {
    Write-Step "Starting core-service locally (Spring Boot, port 8081)..."
    $coreCmd = "cd `"$CoreDir`"; Write-Host '--- core-service ---' -ForegroundColor Cyan; .\mvnw.cmd spring-boot:run"
    Start-Process powershell -ArgumentList "-NoExit", "-Command", $coreCmd
    Write-Ok "core-service starting in new window. URL: http://localhost:8081/api/v1/actuator/health"
}

# ── START MESSAGE-SERVICE LOCALLY ────────────────────────────────────────────
if (-not $Core) {
    Write-Step "Starting message-service locally (NestJS, port 3000)..."
    $msgCmd = "cd `"$NodeDir`"; Write-Host '--- message-service ---' -ForegroundColor Cyan; npm run start:dev"
    Start-Process powershell -ArgumentList "-NoExit", "-Command", $msgCmd
    Write-Ok "message-service starting in new window. URL: http://localhost:3000/api/v1/health"
}

# ── SUMMARY ───────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "  VNALO Local Dev Environment" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "  PostgreSQL  : localhost:5432  [Docker]" -ForegroundColor White
Write-Host "  Redis       : localhost:6379  [Docker]" -ForegroundColor White
Write-Host "  core-service: http://localhost:8081/api/v1  [Local]" -ForegroundColor White
Write-Host "  msg-service : http://localhost:3000/api/v1  [Local]" -ForegroundColor White
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "  Swagger UI  : http://localhost:8081/api/v1/swagger-ui.html" -ForegroundColor Gray
Write-Host "  Health      : http://localhost:8081/api/v1/actuator/health" -ForegroundColor Gray
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  To stop: .\scripts\dev-local.ps1 -Stop" -ForegroundColor Yellow
Write-Host "  To test: powershell -File .\test-api-run.ps1" -ForegroundColor Yellow
Write-Host ""
