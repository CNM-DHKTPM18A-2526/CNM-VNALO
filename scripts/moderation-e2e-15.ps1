$ErrorActionPreference = "Stop"

$coreBase = "http://localhost:8081/api/v1"
$moderationBase = "http://localhost:8082/api/v1"

$pass = 0
$fail = 0

function Invoke-Step {
    param(
        [string]$Name,
        [string]$Method,
        [string]$Url,
        [int]$ExpectedStatus,
        [object]$Body = $null,
        [string]$Token = $null
    )

    $headers = @{}
    if ($Token) {
        $headers["Authorization"] = "Bearer $Token"
    }

    try {
        if ($Body -ne $null) {
            $jsonBody = $Body | ConvertTo-Json -Depth 10
            $resp = Invoke-WebRequest -Method $Method -Uri $Url -Headers $headers -ContentType "application/json" -Body $jsonBody -UseBasicParsing
        } else {
            $resp = Invoke-WebRequest -Method $Method -Uri $Url -Headers $headers -UseBasicParsing
        }

        $status = [int]$resp.StatusCode
        if ($status -eq $ExpectedStatus) {
            $script:pass++
            Write-Host "[PASS] $Name -> $status" -ForegroundColor Green
            return $resp
        }

        $script:fail++
        Write-Host "[FAIL] $Name -> got $status, expected $ExpectedStatus" -ForegroundColor Red
        return $null
    }
    catch {
        $status = 0
        if ($_.Exception.Response) {
            $status = [int]$_.Exception.Response.StatusCode
        }

        if ($status -eq $ExpectedStatus) {
            $script:pass++
            Write-Host "[PASS] $Name -> $status" -ForegroundColor Green
            return $null
        }

        $script:fail++
        Write-Host "[FAIL] $Name -> got $status, expected $ExpectedStatus" -ForegroundColor Red
        return $null
    }
}

function Decode-JwtPayload {
    param([string]$Token)

    $parts = $Token.Split('.')
    $payload = $parts[1]
    while (($payload.Length % 4) -ne 0) {
        $payload += '='
    }

    $payload = $payload.Replace('-', '+').Replace('_', '/')
    $json = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($payload))
    return $json | ConvertFrom-Json
}

$suffix = Get-Random -Minimum 100000 -Maximum 999999
$phone = "+8498$suffix"
$password = "Test@1234"
$displayName = "Moderation E2E $suffix"

Write-Host "Running moderation E2E smoke with phone=$phone" -ForegroundColor Cyan

# 1
Invoke-Step -Name "Health moderation" -Method "GET" -Url "$moderationBase/actuator/health" -ExpectedStatus 200 | Out-Null

# 2
Invoke-Step -Name "Register user" -Method "POST" -Url "$coreBase/auth/register" -ExpectedStatus 201 -Body @{
    phone = $phone
    password = $password
    displayName = $displayName
} | Out-Null

# 3
$login = Invoke-Step -Name "Login user" -Method "POST" -Url "$coreBase/auth/login" -ExpectedStatus 200 -Body @{
    identifier = $phone
    password = $password
    deviceId = "moderation-e2e"
    deviceName = "PowerShell"
}

$jsonLogin = $login.Content | ConvertFrom-Json
$token = $jsonLogin.data.accessToken
$payload = Decode-JwtPayload -Token $token
$userId = $payload.sub

# Bootstrap moderation role table record (still may be blocked by JWT role checks)
docker exec vnalo-postgres psql -U postgres -d vnalo_core -c "
INSERT INTO moderation_admin_user(user_id, role, is_active, created_at, updated_at)
VALUES ('$userId', 'ADMIN', true, now(), now())
ON CONFLICT (user_id)
DO UPDATE SET role='ADMIN', is_active=true, updated_at=now();
" | Out-Null

# 4
$createReport = Invoke-Step -Name "Create report" -Method "POST" -Url "$moderationBase/reports" -ExpectedStatus 201 -Token $token -Body @{
    targetType = "USER"
    targetId = $userId
    reasonCode = "SPAM"
    description = "E2E moderation report"
}

$jsonReport = $createReport.Content | ConvertFrom-Json
$reportId = $jsonReport.data.reportId
$caseId = $jsonReport.data.caseId

# 5
Invoke-Step -Name "Get my reports" -Method "GET" -Url "$moderationBase/reports/me?page=0&size=20" -ExpectedStatus 200 -Token $token | Out-Null

# 6
Invoke-Step -Name "Get moderation reports" -Method "GET" -Url "$moderationBase/moderation/reports?page=0&size=20" -ExpectedStatus 403 -Token $token | Out-Null

# 7
Invoke-Step -Name "Get moderation report detail" -Method "GET" -Url "$moderationBase/moderation/reports/$reportId" -ExpectedStatus 403 -Token $token | Out-Null

# 8
Invoke-Step -Name "Assign case" -Method "POST" -Url "$moderationBase/moderation/reports/$reportId/assign" -ExpectedStatus 403 -Token $token -Body @{
    moderatorId = $userId
} | Out-Null

# 9
Invoke-Step -Name "Resolve case" -Method "POST" -Url "$moderationBase/moderation/cases/$caseId/resolve" -ExpectedStatus 403 -Token $token -Body @{
    decision = "WARN"
    note = "E2E resolve"
} | Out-Null

# 10
Invoke-Step -Name "Create moderation action" -Method "POST" -Url "$moderationBase/moderation/actions" -ExpectedStatus 403 -Token $token -Body @{
    caseId = $caseId
    actionType = "WARN_USER"
    targetUserId = $userId
    reason = "E2E action"
} | Out-Null

# 11
$createAppeal = Invoke-Step -Name "Create appeal" -Method "POST" -Url "$moderationBase/moderation/cases/$caseId/appeal" -ExpectedStatus 403 -Token $token -Body @{
    reason = "Please review"
}

$appealId = ""
if ($createAppeal -ne $null) {
    $jsonAppeal = $createAppeal.Content | ConvertFrom-Json
    $appealId = $jsonAppeal.data.id
}

# 12
Invoke-Step -Name "Get appeals" -Method "GET" -Url "$moderationBase/moderation/appeals?page=0&size=20" -ExpectedStatus 403 -Token $token | Out-Null

# 13
if ([string]::IsNullOrWhiteSpace($appealId)) {
    $appealId = "00000000-0000-0000-0000-000000000000"
}
Invoke-Step -Name "Resolve appeal" -Method "POST" -Url "$moderationBase/moderation/appeals/$appealId/resolve" -ExpectedStatus 403 -Token $token -Body @{
    status = "APPROVED"
    response = "E2E resolve appeal"
} | Out-Null

# 14
Invoke-Step -Name "Create admin user" -Method "POST" -Url "$moderationBase/admin/users" -ExpectedStatus 403 -Token $token -Body @{
    userId = $userId
    role = "MODERATOR"
} | Out-Null

# 15
Invoke-Step -Name "Health moderation (final)" -Method "GET" -Url "$moderationBase/actuator/health" -ExpectedStatus 200 | Out-Null

Write-Host "----------------------------------------" -ForegroundColor Cyan
Write-Host "Moderation E2E 15 requests: PASS=$pass FAIL=$fail" -ForegroundColor Cyan

if ($fail -gt 0) {
    exit 1
}

exit 0
