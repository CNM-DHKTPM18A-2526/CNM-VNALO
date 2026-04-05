param(
  [string]$CoreBase = "http://localhost:8081/api/v1",
  [string]$MediaBase = "http://localhost:8083/api/v1",
  [string]$MessageBase = "http://localhost:3000/api/v1",
  [int]$PerfIterations = 8,
  [string]$Password = "Abc12345",
  [string]$OutputJson = "docs/feedback/ENTERPRISE_ENDPOINT_IO_2026-04-05.json",
  [string]$OutputMd = "docs/feedback/ENTERPRISE_ENDPOINT_IO_REPORT_2026-04-05.md"
)

$ErrorActionPreference = "Stop"

function ConvertTo-Hashtable {
  param([Parameter(ValueFromPipeline = $true)] $InputObject)

  if ($null -eq $InputObject) { return $null }

  if ($InputObject -is [System.Collections.IDictionary]) {
    $result = @{}
    foreach ($k in $InputObject.Keys) {
      $result[$k] = ConvertTo-Hashtable $InputObject[$k]
    }
    return $result
  }

  if ($InputObject -is [System.Collections.IEnumerable] -and -not ($InputObject -is [string])) {
    $list = @()
    foreach ($item in $InputObject) {
      $list += ,(ConvertTo-Hashtable $item)
    }
    return $list
  }

  if ($InputObject.PSObject -and $InputObject.PSObject.Properties.Count -gt 0) {
    $result = @{}
    foreach ($prop in $InputObject.PSObject.Properties) {
      $result[$prop.Name] = ConvertTo-Hashtable $prop.Value
    }
    return $result
  }

  return $InputObject
}

function Invoke-TimedJson {
  param(
    [Parameter(Mandatory = $true)][string]$Method,
    [Parameter(Mandatory = $true)][string]$Url,
    [hashtable]$Headers = @{},
    [hashtable]$Body,
    [string]$ContentType = "application/json"
  )

  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  try {
    $params = @{ Method = $Method; Uri = $Url; Headers = $Headers; ErrorAction = "Stop" }
    if ($Body) {
      if ($ContentType -eq "application/json") {
        $params["Body"] = ($Body | ConvertTo-Json -Depth 20 -Compress)
      } else {
        $params["Body"] = $Body
      }
      $params["ContentType"] = $ContentType
    }

    $res = Invoke-RestMethod @params
    $sw.Stop()

    return @{
      ok = $true
      statusCode = 200
      durationMs = [Math]::Round($sw.Elapsed.TotalMilliseconds, 2)
      response = (ConvertTo-Hashtable $res)
    }
  }
  catch {
    $sw.Stop()
    $status = 0
    $raw = $_.Exception.Message
    if ($_.Exception.Response -and $_.Exception.Response.StatusCode) {
      $status = [int]$_.Exception.Response.StatusCode
    }
    return @{
      ok = $false
      statusCode = $status
      durationMs = [Math]::Round($sw.Elapsed.TotalMilliseconds, 2)
      error = $raw
      response = $null
    }
  }
}

function Get-Percentile {
  param([double[]]$Values, [double]$P)
  if (-not $Values -or $Values.Count -eq 0) { return $null }
  $sorted = $Values | Sort-Object
  $index = [int][Math]::Ceiling(($P / 100.0) * $sorted.Count) - 1
  if ($index -lt 0) { $index = 0 }
  if ($index -ge $sorted.Count) { $index = $sorted.Count - 1 }
  return [Math]::Round([double]$sorted[$index], 2)
}

$ts = Get-Date -Format "yyyy-MM-ddTHH:mm:ssK"
$runId = "enterprise-audit-" + (Get-Date -Format "yyyyMMdd-HHmmss")

$phone = "+8483" + (([DateTimeOffset]::UtcNow.ToUnixTimeSeconds() % 1000000).ToString().PadLeft(6, "0"))
$displayName = "Enterprise Audit User"

$results = [ordered]@{
  runId = $runId
  timestamp = $ts
  services = [ordered]@{
    core = $CoreBase
    media = $MediaBase
    message = $MessageBase
  }
  functional = @()
  performance = @()
  notes = @()
}

# Functional flow
$healthCore = Invoke-TimedJson -Method GET -Url "$CoreBase/actuator/health"
$results.functional += [ordered]@{
  service = "core-service"
  endpoint = "GET /actuator/health"
  request = @{ headers = @{}; body = $null }
  outcome = $healthCore
}

$healthMedia = Invoke-TimedJson -Method GET -Url "$MediaBase/../actuator/health"
$results.functional += [ordered]@{
  service = "media-service"
  endpoint = "GET /actuator/health"
  request = @{ headers = @{}; body = $null }
  outcome = $healthMedia
}

$healthMsg = Invoke-TimedJson -Method GET -Url "$MessageBase/health"
$results.functional += [ordered]@{
  service = "message-service"
  endpoint = "GET /health"
  request = @{ headers = @{}; body = $null }
  outcome = $healthMsg
}

$registerBody = @{ phone = $phone; password = $Password; displayName = $displayName; otp = "000000"; gender = "MALE" }
$register = Invoke-TimedJson -Method POST -Url "$CoreBase/auth/register" -Body $registerBody
$results.functional += [ordered]@{
  service = "core-service"
  endpoint = "POST /auth/register"
  request = @{ headers = @{ "Content-Type" = "application/json" }; body = $registerBody }
  outcome = $register
}

if (-not $register.ok) {
  $results.notes += "Registration failed; aborting remaining functional chain."
} else {
  $accessToken = $register.response.data.accessToken

  $tmp = Join-Path $env:TEMP ("enterprise-audit-avatar-" + (Get-Date -Format "yyyyMMddHHmmss") + ".png")
  $pngBase64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO7Zf6cAAAAASUVORK5CYII="
  [IO.File]::WriteAllBytes($tmp, [Convert]::FromBase64String($pngBase64))

  $swUpload = [System.Diagnostics.Stopwatch]::StartNew()
  $uploadRaw = curl.exe -s -X POST "$MediaBase/media/upload" -H "Authorization: Bearer $accessToken" -F "category=AVATAR" -F "file=@$tmp;type=image/png"
  $swUpload.Stop()
  try {
    $uploadObj = ConvertTo-Hashtable ($uploadRaw | ConvertFrom-Json)
    $uploadOk = $true
  } catch {
    $uploadObj = @{ raw = $uploadRaw }
    $uploadOk = $false
  }

  $results.functional += [ordered]@{
    service = "media-service"
    endpoint = "POST /media/upload"
    request = @{ headers = @{ Authorization = "Bearer <register_token>" }; body = @{ category = "AVATAR"; file = "1x1 PNG" } }
    outcome = @{ ok = $uploadOk; statusCode = ($(if ($uploadObj.status) { [int]$uploadObj.status } else { 200 })); durationMs = [Math]::Round($swUpload.Elapsed.TotalMilliseconds, 2); response = $uploadObj }
  }

  $avatarUrl = $uploadObj.data.url
  if ($avatarUrl) {
    $patchBody = @{ avatarUrl = $avatarUrl }
    $patch = Invoke-TimedJson -Method PATCH -Url "$CoreBase/users/me" -Headers @{ Authorization = "Bearer $accessToken" } -Body $patchBody
    $results.functional += [ordered]@{
      service = "core-service"
      endpoint = "PATCH /users/me"
      request = @{ headers = @{ Authorization = "Bearer <register_token>"; "Content-Type" = "application/json" }; body = $patchBody }
      outcome = $patch
    }

    $me = Invoke-TimedJson -Method GET -Url "$CoreBase/users/me" -Headers @{ Authorization = "Bearer $accessToken" }
    $results.functional += [ordered]@{
      service = "core-service"
      endpoint = "GET /users/me"
      request = @{ headers = @{ Authorization = "Bearer <register_token>" }; body = $null }
      outcome = $me
    }
  }

  $loginBody = @{ identifier = $phone; password = $Password }
  $login = Invoke-TimedJson -Method POST -Url "$CoreBase/auth/login" -Body $loginBody
  $results.functional += [ordered]@{
    service = "core-service"
    endpoint = "POST /auth/login"
    request = @{ headers = @{ "Content-Type" = "application/json" }; body = $loginBody }
    outcome = $login
  }

  if ($login.ok) {
    $loginToken = $login.response.data.accessToken
    $inbox = Invoke-TimedJson -Method GET -Url "$MessageBase/inbox" -Headers @{ Authorization = "Bearer $loginToken" }
    $results.functional += [ordered]@{
      service = "message-service"
      endpoint = "GET /inbox"
      request = @{ headers = @{ Authorization = "Bearer <login_token>" }; body = $null }
      outcome = $inbox
    }

    # Performance samples
    $perfSpecs = @(
      @{ service = "core-service"; endpoint = "GET /actuator/health"; method = "GET"; url = "$CoreBase/actuator/health"; headers = @{}; body = $null },
      @{ service = "core-service"; endpoint = "POST /auth/login"; method = "POST"; url = "$CoreBase/auth/login"; headers = @{}; body = $loginBody },
      @{ service = "core-service"; endpoint = "GET /users/me"; method = "GET"; url = "$CoreBase/users/me"; headers = @{ Authorization = "Bearer $loginToken" }; body = $null },
      @{ service = "message-service"; endpoint = "GET /health"; method = "GET"; url = "$MessageBase/health"; headers = @{}; body = $null },
      @{ service = "message-service"; endpoint = "GET /inbox"; method = "GET"; url = "$MessageBase/inbox"; headers = @{ Authorization = "Bearer $loginToken" }; body = $null },
      @{ service = "media-service"; endpoint = "GET /actuator/health"; method = "GET"; url = "$MediaBase/../actuator/health"; headers = @{}; body = $null }
    )

    foreach ($spec in $perfSpecs) {
      $samples = @()
      for ($i = 0; $i -lt $PerfIterations; $i++) {
        $r = Invoke-TimedJson -Method $spec.method -Url $spec.url -Headers $spec.headers -Body $spec.body
        $samples += [double]$r.durationMs
      }

      $results.performance += [ordered]@{
        service = $spec.service
        endpoint = $spec.endpoint
        iterations = $PerfIterations
        minMs = [Math]::Round((($samples | Measure-Object -Minimum).Minimum), 2)
        maxMs = [Math]::Round((($samples | Measure-Object -Maximum).Maximum), 2)
        avgMs = [Math]::Round((($samples | Measure-Object -Average).Average), 2)
        p50Ms = (Get-Percentile -Values $samples -P 50)
        p95Ms = (Get-Percentile -Values $samples -P 95)
        samplesMs = $samples
      }
    }
  }
}

# Write JSON
$jsonText = $results | ConvertTo-Json -Depth 30
$jsonDir = Split-Path -Parent $OutputJson
if (-not (Test-Path $jsonDir)) { New-Item -ItemType Directory -Path $jsonDir -Force | Out-Null }
Set-Content -Path $OutputJson -Value $jsonText -Encoding UTF8

# Write Markdown summary
$md = @()
$md += "# Enterprise Endpoint IO Report"
$md += ""
$md += "Generated: $ts"
$md += "Run ID: $runId"
$md += ""
$md += "## Functional Endpoint Results"
$md += ""
$md += "| Service | Endpoint | OK | Status | Duration (ms) |"
$md += "|---|---|---:|---:|---:|"
foreach ($f in $results.functional) {
  $ok = if ($f.outcome.ok) { "yes" } else { "no" }
  $md += "| $($f.service) | $($f.endpoint) | $ok | $($f.outcome.statusCode) | $($f.outcome.durationMs) |"
}
$md += ""
$md += "## Performance Summary"
$md += ""
$md += "| Service | Endpoint | Iterations | Min | Avg | P50 | P95 | Max |"
$md += "|---|---|---:|---:|---:|---:|---:|---:|"
foreach ($p in $results.performance) {
  $md += "| $($p.service) | $($p.endpoint) | $($p.iterations) | $($p.minMs) | $($p.avgMs) | $($p.p50Ms) | $($p.p95Ms) | $($p.maxMs) |"
}
$md += ""
$md += "## Endpoint Input/Output (Captured)"
$md += ""
$i = 1
foreach ($f in $results.functional) {
  $md += "### [$i] $($f.service) - $($f.endpoint)"
  $md += "Request:"
  $md += '```json'
  $md += (($f.request | ConvertTo-Json -Depth 20))
  $md += '```'
  $md += "Response:"
  $md += '```json'
  $md += (($f.outcome | ConvertTo-Json -Depth 20))
  $md += '```'
  $md += ""
  $i++
}

if ($results.notes.Count -gt 0) {
  $md += "## Notes"
  foreach ($n in $results.notes) {
    $md += "- $n"
  }
}

$mdDir = Split-Path -Parent $OutputMd
if (-not (Test-Path $mdDir)) { New-Item -ItemType Directory -Path $mdDir -Force | Out-Null }
Set-Content -Path $OutputMd -Value ($md -join "`r`n") -Encoding UTF8

Write-Output "Enterprise endpoint audit completed"
Write-Output "JSON: $OutputJson"
Write-Output "MD: $OutputMd"
