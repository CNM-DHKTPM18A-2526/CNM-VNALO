# Load .env and start content-service on http://localhost:8086/api/v1
$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $here

$envFile = Join-Path $here ".env"
if (-not (Test-Path $envFile)) {
    Write-Error "Missing .env — copy .env.example to .env and fill JWT_SECRET."
}

Get-Content $envFile | ForEach-Object {
    $line = $_.Trim()
    if ($line -eq "" -or $line.StartsWith("#")) { return }
    $idx = $line.IndexOf("=")
    if ($idx -lt 1) { return }
    $name = $line.Substring(0, $idx).Trim()
    $value = $line.Substring($idx + 1).Trim()
    Set-Item -Path "env:$name" -Value $value
}

Write-Host "Starting content-service at http://localhost:$($env:SERVER_PORT)/api/v1"
mvn spring-boot:run
