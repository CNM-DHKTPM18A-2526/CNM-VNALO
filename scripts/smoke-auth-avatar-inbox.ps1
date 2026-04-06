param(
  [string]$CoreBase = "http://localhost:8081/api/v1",
  [string]$MediaBase = "http://localhost:8083/api/v1",
  [string]$MessageBase = "http://localhost:3000/api/v1",
  [string]$Password = "Abc12345"
)

$ErrorActionPreference = "Stop"

function Post-Json {
  param(
    [Parameter(Mandatory = $true)][string]$Url,
    [Parameter(Mandatory = $true)][hashtable]$Body,
    [hashtable]$Headers = @{}
  )

  $json = $Body | ConvertTo-Json -Depth 10 -Compress
  return Invoke-RestMethod -Method Post -Uri $Url -Headers $Headers -Body $json -ContentType "application/json"
}

function Patch-Json {
  param(
    [Parameter(Mandatory = $true)][string]$Url,
    [Parameter(Mandatory = $true)][hashtable]$Body,
    [hashtable]$Headers = @{}
  )

  $json = $Body | ConvertTo-Json -Depth 10 -Compress
  return Invoke-RestMethod -Method Patch -Uri $Url -Headers $Headers -Body $json -ContentType "application/json"
}

$ts = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$phone = "+8483" + (($ts % 10000000).ToString().PadLeft(7, "0"))

Write-Output "[1/6] Register: $phone"
$register = Post-Json -Url "$CoreBase/auth/register" -Body @{
  phone = $phone
  password = $Password
  displayName = "Smoke Mobile User"
  otp = "000000"
  gender = "MALE"
}

$registerToken = $register.data.accessToken
if (-not $registerToken) {
  throw "register token missing"
}

Write-Output "[2/6] Upload avatar"
$tmp = Join-Path $env:TEMP ("smoke-avatar-" + $ts + ".png")
$pngBase64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO7Zf6cAAAAASUVORK5CYII="
[IO.File]::WriteAllBytes($tmp, [Convert]::FromBase64String($pngBase64))

$uploadRaw = curl.exe -s -X POST "$MediaBase/media/upload" -H "Authorization: Bearer $registerToken" -F "category=AVATAR" -F "file=@$tmp;type=image/png"
$upload = $uploadRaw | ConvertFrom-Json
$avatarUrl = $upload.data.url
if (-not $avatarUrl) {
  throw ("avatar upload failed: " + $uploadRaw)
}

Write-Output "[3/6] Patch profile avatar"
$null = Patch-Json -Url "$CoreBase/users/me" -Body @{ avatarUrl = $avatarUrl } -Headers @{ Authorization = "Bearer $registerToken" }
$me = Invoke-RestMethod -Method Get -Uri "$CoreBase/users/me" -Headers @{ Authorization = "Bearer $registerToken" }
if ($me.data.avatarUrl -ne $avatarUrl) {
  throw "avatar patch not persisted"
}

Write-Output "[4/6] Login"
$login = Post-Json -Url "$CoreBase/auth/login" -Body @{ identifier = $phone; password = $Password }
$loginToken = $login.data.accessToken
if (-not $loginToken) {
  throw "login token missing"
}

Write-Output "[5/6] Inbox"
$inboxRaw = curl.exe -s -X GET "$MessageBase/inbox" -H "Authorization: Bearer $loginToken"
$inbox = $inboxRaw | ConvertFrom-Json
if ($inbox -isnot [System.Array]) {
  throw ("inbox payload is not array: " + $inboxRaw)
}

Write-Output "[6/6] Result"
Write-Output ("phone=" + $phone)
Write-Output ("avatarUrl=" + $avatarUrl)
Write-Output ("inboxCount=" + $inbox.Count)
Write-Output "SMOKE PASS: register -> avatar upload -> profile patch -> login -> inbox"
