$ErrorActionPreference = "Continue"
$BC = "http://localhost:8081/api/v1"
$BM = "http://localhost:3000/api/v1"
$BMA = "http://localhost:8083"
$BMD = "http://localhost:8083/api/v1"

$p = 0
$f = 0
$res = @()
$io = @()

$ts = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
$sf = "$ts".Substring("$ts".Length - 8)
$PH1 = "+8490$sf"
$PH2 = "+8491$sf"
$PH3 = "+8492$sf"

$runId = "enterprise-full-api-" + (Get-Date -Format "yyyyMMdd-HHmmss")
$outJson = "docs/feedback/ENTERPRISE_FULL_API_IO_2026-04-05.json"
$outMd = "docs/feedback/ENTERPRISE_FULL_API_IO_REPORT_2026-04-05.md"

function Trim-Text {
  param($Text, [int]$Max = 1200)
  if ($null -eq $Text) { return $null }

  $asString = $null
  if ($Text -is [byte[]]) {
    $asString = [System.Text.Encoding]::UTF8.GetString($Text)
  } else {
    $asString = [string]$Text
  }

  if ($asString.Length -le $Max) { return $asString }
  return $asString.Substring(0, $Max) + "...<trimmed>"
}

function TU($tag, $url, $token, $filePath, $expected) {
  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  try {
    $raw = & curl.exe -s -w "%{http_code}" -X POST $url -H "Authorization: Bearer $token" -F "category=AVATAR" -F "file=@$filePath;type=image/png"
    $sw.Stop()

    $statusStr = $raw.Substring($raw.Length - 3)
    $status = [int]$statusStr
    $body = $raw.Substring(0, $raw.Length - 3)
    $ok = ($status -eq $expected)

    if ($ok) { $script:p++ } else {
      $script:f++
      Write-Host "  FAIL [$status exp $expected] POST $url" -ForegroundColor Red
    }

    $script:res += [pscustomobject]@{ ok = $ok; ms = $sw.ElapsedMilliseconds; url = "POST $url" }
    $script:io += [ordered]@{
      tag = $tag
      method = "POST"
      url = $url
      expectedStatus = $expected
      status = $status
      ok = $ok
      durationMs = $sw.ElapsedMilliseconds
      requestBody = '{"category":"AVATAR","file":"1x1 PNG"}'
      responseBody = (Trim-Text $body)
    }
  }
  catch {
    $sw.Stop()
    $script:f++
    $script:res += [pscustomobject]@{ ok = $false; ms = $sw.ElapsedMilliseconds; url = "POST $url" }
    $script:io += [ordered]@{
      tag = $tag
      method = "POST"
      url = $url
      expectedStatus = $expected
      status = 0
      ok = $false
      durationMs = $sw.ElapsedMilliseconds
      requestBody = '{"category":"AVATAR","file":"1x1 PNG"}'
      responseBody = (Trim-Text $_.Exception.Message)
    }
    Write-Host "  FAIL [0 exp $expected] POST $url" -ForegroundColor Red
  }
}

function T($tag, $m, $u, $b, $t, $e) {
  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  $reqBody = if ($b) { ($b | ConvertTo-Json -Compress -Depth 8) } else { $null }

  try {
    $h = @{ "Content-Type" = "application/json" }
    if ($t) { $h["Authorization"] = "Bearer $t" }

    $pm = @{ Method = $m; Uri = $u; Headers = $h; UseBasicParsing = $true; ErrorAction = "Stop" }
    if ($b) { $pm.Body = $reqBody }

    $r = Invoke-WebRequest @pm
    $sw.Stop()
    $c = [int]$r.StatusCode
    $ok = ($c -eq $e)

    if ($ok) { $script:p++ } else {
      $script:f++
      Write-Host "  FAIL [$c exp $e] $m $u" -ForegroundColor Red
    }

    $script:res += [pscustomobject]@{ ok = $ok; ms = $sw.ElapsedMilliseconds; url = "$m $u" }
    $script:io += [ordered]@{
      tag = $tag
      method = $m
      url = $u
      expectedStatus = $e
      status = $c
      ok = $ok
      durationMs = $sw.ElapsedMilliseconds
      requestBody = $reqBody
      responseBody = (Trim-Text $r.Content)
    }

    return $r
  }
  catch {
    $sw.Stop()
    $c = if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { 0 }
    $ok = ($c -eq $e)

    if ($ok) { $script:p++ } else {
      $script:f++
      Write-Host "  FAIL [$c exp $e] $m $u" -ForegroundColor Red
    }

    $errText = $_.Exception.Message
    $script:res += [pscustomobject]@{ ok = $ok; ms = $sw.ElapsedMilliseconds; url = "$m $u" }
    $script:io += [ordered]@{
      tag = $tag
      method = $m
      url = $u
      expectedStatus = $e
      status = $c
      ok = $ok
      durationMs = $sw.ElapsedMilliseconds
      requestBody = $reqBody
      responseBody = (Trim-Text $errText)
    }

    return $null
  }
}

function JWT($t) {
  $pp = $t.Split('.')[1]
  while ($pp.Length % 4 -ne 0) { $pp += '=' }
  [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($pp)) | ConvertFrom-Json
}

Write-Host "=[ VNALO ENTERPRISE API TEST $(Get-Date -f 'HH:mm:ss') ]=" -ForegroundColor Cyan
Write-Host "  PH1=$PH1"
Write-Host ""

Write-Host "[1/10] HEALTH" -ForegroundColor Yellow
T H1 GET "$BC/actuator/health" $null $null 200 | Out-Null
T H2 GET "$BC/actuator/info" $null $null 200 | Out-Null
T H3 GET "$BC/auth/otp/status" $null $null 200 | Out-Null
T H4 GET "$BM/health" $null $null 200 | Out-Null
T H5 GET "$BMA/actuator/health" $null $null 200 | Out-Null

Write-Host "[2/10] AUTH" -ForegroundColor Yellow
T R1 POST "$BC/auth/register" @{ phone = $PH1; password = "Test@1234"; displayName = "Alice" } $null 201 | Out-Null
T R2 POST "$BC/auth/register" @{ phone = $PH2; password = "Test@1234"; displayName = "Bob" } $null 201 | Out-Null
T R3 POST "$BC/auth/register" @{ phone = $PH3; password = "Test@1234"; displayName = "Carol" } $null 201 | Out-Null
T RD POST "$BC/auth/register" @{ phone = $PH1; password = "Test@1234"; displayName = "Dup" } $null 409 | Out-Null
T RI POST "$BC/auth/register" @{ phone = "bad"; password = "x"; displayName = "" } $null 400 | Out-Null
$l1 = T L1 POST "$BC/auth/login" @{ identifier = $PH1; password = "Test@1234"; deviceId = "d1"; deviceName = "D1" } $null 200
$l2 = T L2 POST "$BC/auth/login" @{ identifier = $PH2; password = "Test@1234"; deviceId = "d2"; deviceName = "D2" } $null 200
$l3 = T L3 POST "$BC/auth/login" @{ identifier = $PH3; password = "Test@1234"; deviceId = "d3"; deviceName = "D3" } $null 200
T LW POST "$BC/auth/login" @{ identifier = $PH1; password = "Wrong" } $null 401 | Out-Null

$TK1 = ($l1.Content | ConvertFrom-Json).data.accessToken
$RF1 = ($l1.Content | ConvertFrom-Json).data.refreshToken
$TK2 = ($l2.Content | ConvertFrom-Json).data.accessToken
$TK3 = ($l3.Content | ConvertFrom-Json).data.accessToken
$UID1 = (JWT $TK1).sub
$UID2 = (JWT $TK2).sub
$UID3 = (JWT $TK3).sub
T LR POST "$BC/auth/refresh" @{ refreshToken = $RF1 } $null 200 | Out-Null

$tmp = Join-Path $env:TEMP ("enterprise-logged-avatar-" + (Get-Date -Format "yyyyMMddHHmmss") + ".png")
$pngBase64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO7Zf6cAAAAASUVORK5CYII="
[IO.File]::WriteAllBytes($tmp, [Convert]::FromBase64String($pngBase64))
TU MU1 "$BMD/media/upload" $TK1 $tmp 201

Write-Host "[3/10] USERS" -ForegroundColor Yellow
T U1 GET "$BC/users/me" $null $TK1 200 | Out-Null
T U2 GET "$BC/users/$UID2" $null $TK1 200 | Out-Null
T U3 GET "$BC/users/00000000-0000-0000-0000-000000000000" $null $TK1 404 | Out-Null
T U4 PATCH "$BC/users/me" @{ displayName = "Alice B"; bio = "bio" } $TK1 200 | Out-Null
T U5 GET "$BC/users/search?keyword=$PH1" $null $TK1 200 | Out-Null
T U6 GET "$BC/users/search?keyword=Alice" $null $TK1 200 | Out-Null
T U7 GET "$BC/users/me/privacy" $null $TK1 200 | Out-Null
T U8 PUT "$BC/users/me/privacy" @{ profileVisibility = "FRIENDS_ONLY" } $TK1 200 | Out-Null
T U9 PUT "$BC/users/me/privacy" @{ profileVisibility = "PUBLIC" } $TK1 200 | Out-Null

Write-Host "[4/10] FRIENDS" -ForegroundColor Yellow
$fr = T F1 POST "$BC/friends/requests" @{ toUserId = $UID2; source = "SEARCH" } $TK1 201
$FID = ($fr.Content | ConvertFrom-Json).data.id
T F2 POST "$BC/friends/requests" @{ toUserId = $UID1; source = "SEARCH" } $TK1 400 | Out-Null
T F3 GET "$BC/friends/requests/sent" $null $TK1 200 | Out-Null
T F4 GET "$BC/friends/requests/incoming" $null $TK2 200 | Out-Null
T F5 POST "$BC/friends/requests/$FID/accept" $null $TK2 200 | Out-Null
T F6 GET "$BC/friends" $null $TK1 200 | Out-Null
T F7 GET "$BC/friends" $null $TK2 200 | Out-Null
T F8 GET "$BC/friends/$UID2/status" $null $TK1 200 | Out-Null

Write-Host "[5/10] BLOCKS" -ForegroundColor Yellow
T B1 POST "$BC/blocks/$UID3" $null $TK1 200 | Out-Null
T B2 GET "$BC/blocks" $null $TK1 200 | Out-Null
T B3 GET "$BC/blocks/$UID3/status" $null $TK1 200 | Out-Null
T B4 DELETE "$BC/blocks/$UID3" $null $TK1 200 | Out-Null
T B5 POST "$BC/blocks/$UID1" $null $TK1 400 | Out-Null

Write-Host "[6/10] QR & CONTACTS" -ForegroundColor Yellow
T Q1 GET "$BC/qr/generate" $null $TK1 200 | Out-Null
T C1 POST "$BC/contacts/sync" @(@{ phoneNumber = $PH2; contactName = "Bob" }, @{ phoneNumber = $PH3; contactName = "Carol" }) $TK1 200 | Out-Null

Write-Host "[7/10] CONVERSATIONS" -ForegroundColor Yellow
$dc = T CV1 POST "$BM/conversations/direct" @{ targetUserId = $UID2 } $TK1 201
$DM = ($dc.Content | ConvertFrom-Json).id
T CV2 POST "$BM/conversations/direct" @{ targetUserId = $UID2 } $TK1 201 | Out-Null
$gc = T CV3 POST "$BM/conversations/group" @{ title = "TestGroup"; memberIds = @($UID2) } $TK1 201
$GRP = ($gc.Content | ConvertFrom-Json).id
T CV4 GET "$BM/conversations/$DM" $null $TK1 200 | Out-Null
T CV5 GET "$BM/conversations/$GRP" $null $TK1 200 | Out-Null
T CV6 PATCH "$BM/conversations/$GRP" @{ title = "Renamed" } $TK1 200 | Out-Null
T CV7 GET "$BM/conversations/$GRP/members" $null $TK1 200 | Out-Null
T CV8 POST "$BM/conversations/$GRP/members" @{ memberIds = @($UID3) } $TK1 201 | Out-Null
T CV9 DELETE "$BM/conversations/$GRP/members/$UID3" $null $TK1 200 | Out-Null

Write-Host "[8/10] MESSAGES" -ForegroundColor Yellow
$m1 = T M1 POST "$BM/messages" @{ conversationId = $DM; content = "Hello!"; messageType = "TEXT" } $TK1 201
$MID1 = ($m1.Content | ConvertFrom-Json).id
$SEQ1 = ($m1.Content | ConvertFrom-Json).serverSeq
1..5 | ForEach-Object { T MB POST "$BM/messages" @{ conversationId = $DM; content = "Msg $_"; messageType = "TEXT" } $TK1 201 | Out-Null }
T MR POST "$BM/messages" @{ conversationId = $DM; content = "Reply!"; messageType = "TEXT"; replyToMessageId = $MID1 } $TK2 201 | Out-Null
T MG1 GET "$BM/conversations/$DM/messages" $null $TK1 200 | Out-Null
T MG2 GET "$BM/conversations/$DM/messages?limit=3" $null $TK1 200 | Out-Null
T ME1 PATCH "$BM/messages/$MID1" @{ content = "Hello (edited)" } $TK1 200 | Out-Null
T MS1 GET "$BM/conversations/$DM/messages/search?keyword=Hello" $null $TK1 200 | Out-Null
T MS2 GET "$BM/conversations/$DM/messages/search?keyword=zzz" $null $TK1 200 | Out-Null
T RX1 POST "$BM/messages/$MID1/reactions" @{ emoji = "heart" } $TK2 201 | Out-Null
T RX2 GET "$BM/messages/$MID1/reactions" $null $TK1 200 | Out-Null
T RX3 DELETE "$BM/messages/$MID1/reactions" $null $TK2 200 | Out-Null
T P1 POST "$BM/conversations/$DM/pin/$MID1" $null $TK1 201 | Out-Null
T P2 GET "$BM/conversations/$DM/pins" $null $TK1 200 | Out-Null
T P3 DELETE "$BM/conversations/$DM/pin/$MID1" $null $TK1 200 | Out-Null
T RD POST "$BM/conversations/$DM/read" @{ lastReadSeq = $SEQ1 } $TK1 201 | Out-Null
$mrc = T MRC POST "$BM/messages" @{ conversationId = $DM; content = "Recall me"; messageType = "TEXT" } $TK1 201
$MRCID = ($mrc.Content | ConvertFrom-Json).id
T DEL DELETE "$BM/messages/$MRCID" $null $TK1 200 | Out-Null

Write-Host "[9/10] INBOX" -ForegroundColor Yellow
T I1 GET "$BM/inbox" $null $TK1 200 | Out-Null
T I2 GET "$BM/inbox" $null $TK2 200 | Out-Null
T I3 GET "$BM/inbox/unread-count" $null $TK1 200 | Out-Null
T I4 GET "$BM/inbox/unread-count" $null $TK2 200 | Out-Null

Write-Host "[10/10] SECURITY" -ForegroundColor Yellow
T S1 GET "$BC/users/me" $null $null 403 | Out-Null
T S2 GET "$BM/inbox" $null $null 401 | Out-Null
T S3 GET "$BC/users/me" $null "bad.jwt.token" 403 | Out-Null
T S4 GET "$BM/inbox" $null "bad.jwt.token" 401 | Out-Null
T S5 POST "$BC/auth/logout" $null $TK1 200 | Out-Null

$tot = $p + $f
$avg = [Math]::Round(($res | ForEach-Object { $_.ms } | Measure-Object -Average).Average, 1)

$report = [ordered]@{
  runId = $runId
  generatedAt = (Get-Date).ToString("o")
  baseUrls = @{ core = $BC; message = $BM; media = $BMD }
  totals = @{ passed = $p; failed = $f; total = $tot; averageMs = $avg }
  endpoints = $io
}

$jsonText = $report | ConvertTo-Json -Depth 20
$jsonDir = Split-Path -Parent $outJson
if (-not (Test-Path $jsonDir)) { New-Item -ItemType Directory -Path $jsonDir -Force | Out-Null }
Set-Content -Path $outJson -Value $jsonText -Encoding UTF8

$md = @()
$md += "# Enterprise Full API IO Report"
$md += ""
$md += "Run ID: $runId"
$md += "Generated: $($report.generatedAt)"
$md += ""
$md += "## Summary"
$md += "- Passed: $p"
$md += "- Failed: $f"
$md += "- Total: $tot"
$md += "- Average latency: ${avg}ms"
$md += ""
$md += "## Endpoint Execution Matrix"
$md += "| Tag | Method | URL | Expected | Actual | OK | Duration (ms) |"
$md += "|---|---|---|---:|---:|---:|---:|"
foreach ($x in $io) {
  $ok = if ($x.ok) { "yes" } else { "no" }
  $md += "| $($x.tag) | $($x.method) | $($x.url) | $($x.expectedStatus) | $($x.status) | $ok | $($x.durationMs) |"
}
$md += ""
$md += "## Detailed Input/Output"

$idx = 1
foreach ($x in $io) {
  $md += "### [$idx] $($x.tag) - $($x.method) $($x.url)"
  $md += "Request body:"
  $md += '```json'
  $md += $(if ($x.requestBody) { $x.requestBody } else { "null" })
  $md += '```'
  $md += "Response body:"
  $md += '```json'
  $md += $(if ($x.responseBody) { $x.responseBody } else { "null" })
  $md += '```'
  $md += ""
  $idx++
}

$mdDir = Split-Path -Parent $outMd
if (-not (Test-Path $mdDir)) { New-Item -ItemType Directory -Path $mdDir -Force | Out-Null }
Set-Content -Path $outMd -Value ($md -join "`r`n") -Encoding UTF8

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
if ($f -eq 0) {
  Write-Host "  ALL PASSED: $p/$tot (100%)" -ForegroundColor Green
} else {
  Write-Host "  FAILED: $f  PASSED: $p/$tot" -ForegroundColor Red
}
Write-Host "  AVG: ${avg}ms avg over $tot requests" -ForegroundColor Cyan
Write-Host "  JSON: $outJson" -ForegroundColor Cyan
Write-Host "  MD:   $outMd" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
