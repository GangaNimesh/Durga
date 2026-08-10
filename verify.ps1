# DURGA backend verification script (PowerShell)
# Works whether you run it from the repo root OR from inside the backend folder.

if (Test-Path ".\backend\app\main.py") {
    $BackendDir = "backend"        # we're in the repo root
} elseif (Test-Path ".\app\main.py") {
    $BackendDir = "."              # we're already inside backend
} else {
    Write-Host "Could not find app\main.py from here. Run this from the repo root or from inside backend\." -ForegroundColor Red
    exit 1
}

Push-Location $BackendDir

Remove-Item -Force -ErrorAction SilentlyContinue durga.db
Remove-Item -Force -ErrorAction SilentlyContinue .env

# FIX: launching the bare "uvicorn" command name via Start-Process with a
# single joined -ArgumentList string silently fails to start the process at
# all (Start-Process returns immediately with an empty ExitCode and no
# output) - this is what caused "uvicorn : not recognized". Launching the
# venv's python.exe with -m uvicorn and an array ArgumentList is reliable.
$python = ".\.venv\Scripts\python.exe"
if (-not (Test-Path $python)) {
    Write-Host "No .venv found at $((Get-Location).Path)\.venv - create one first (see LOCAL_SETUP.md)." -ForegroundColor Red
    Pop-Location
    exit 1
}

# Start the server in the background
$proc = Start-Process -FilePath $python -ArgumentList "-m", "uvicorn", "app.main:app", "--port", "8000" -PassThru -WindowStyle Hidden
Start-Sleep -Seconds 5

$B = "http://127.0.0.1:8000"
$fail = $false

function Check($name, $condition) {
    if (-not $condition) {
        Write-Host "FAIL $name" -ForegroundColor Red
        $script:fail = $true
    } else {
        Write-Host "OK   $name" -ForegroundColor Green
    }
}

# FIX: -SkipHttpErrorCheck is a PowerShell 7.4+ parameter and doesn't exist
# on Windows PowerShell 5.1 - passing it there throws a parameter-binding
# error before the request is even sent, so every check using it failed
# regardless of the actual HTTP status. This wrapper works on both by
# catching the exception non-2xx responses raise and reading the status/body
# back out of it.
function Invoke-Unchecked {
    param($Uri, $Method = "Get", $Headers = @{}, $Body = $null, $ContentType = $null)
    $params = @{ Uri = $Uri; Method = $Method; Headers = $Headers; UseBasicParsing = $true }
    if ($Body) { $params.Body = $Body }
    if ($ContentType) { $params.ContentType = $ContentType }
    try {
        $resp = Invoke-WebRequest @params
        return [PSCustomObject]@{ StatusCode = [int]$resp.StatusCode; Content = $resp.Content }
    } catch {
        $errResp = $_.Exception.Response
        if ($null -eq $errResp) { return [PSCustomObject]@{ StatusCode = 0; Content = $null } }
        if ($errResp.PSObject.Properties.Name -contains "StatusCode" -and $errResp.GetType().Name -eq "HttpWebResponse") {
            # Windows PowerShell 5.1 / .NET Framework: System.Net.HttpWebResponse
            $stream = $errResp.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($stream)
            $content = $reader.ReadToEnd()
            return [PSCustomObject]@{ StatusCode = [int]$errResp.StatusCode; Content = $content }
        }
        # PowerShell 7+ / .NET Core: System.Net.Http.HttpResponseMessage
        $content = $errResp.Content.ReadAsStringAsync().Result
        return [PSCustomObject]@{ StatusCode = [int]$errResp.StatusCode; Content = $content }
    }
}

# 1. health
try {
    $health = Invoke-RestMethod -Uri "$B/health" -Method Get
    Check "health" ($health.database -eq "connected")
} catch { Check "health" $false }

# 2. CORS preflight
try {
    $resp = Invoke-Unchecked -Uri "$B/api/v1/auth/login" -Method Options `
        -Headers @{ "Origin" = "http://x.com"; "Access-Control-Request-Method" = "POST" }
    Check "cors" ($resp.StatusCode -eq 200)
} catch { Check "cors" $false }

# 3. invalid email rejected
try {
    $resp = Invoke-Unchecked -Uri "$B/api/v1/auth/register" -Method Post `
        -ContentType "application/json" `
        -Body '{"email":"bad","password":"pass1234","full_name":"X","phone":"+911234567890"}'
    Check "email validation" ($resp.StatusCode -eq 422)
} catch { Check "email validation" $false }

# 4. register + login a real user
try {
    Invoke-RestMethod -Uri "$B/api/v1/auth/register" -Method Post `
        -ContentType "application/json" `
        -Body '{"email":"t@t.com","password":"pass1234","full_name":"T","phone":"+911234567890"}' | Out-Null

    $login = Invoke-RestMethod -Uri "$B/api/v1/auth/login" -Method Post `
        -ContentType "application/json" `
        -Body '{"email":"t@t.com","password":"pass1234"}'
    $T = $login.access_token
    Check "login" ($T.Length -gt 0)
} catch { Check "login" $false; $T = $null }

if ($T) {
    $headers = @{ Authorization = "Bearer $T" }

    # 5. contacts, no trailing-slash redirect
    try {
        $resp = Invoke-Unchecked -Uri "$B/api/v1/contacts" -Headers $headers
        Check "trailing slash" ($resp.StatusCode -eq 200)
    } catch { Check "trailing slash" $false }

    # 6. sos/last returns null, not 500
    try {
        $resp = Invoke-Unchecked -Uri "$B/api/v1/sos/last" -Headers $headers
        Check "sos/last null" ($resp.StatusCode -eq 200 -and $resp.Content.Trim() -eq "null")
    } catch { Check "sos/last null" $false }

    # 7. UTC timestamps
    try {
        $me = Invoke-RestMethod -Uri "$B/api/v1/auth/me" -Headers $headers
        Check "utc timestamps" ($me.created_at -match '\+00:00$')
    } catch { Check "utc timestamps" $false }
}

# 8. threat scoring
try {
    $threat = Invoke-RestMethod -Uri "$B/api/v1/threat/analyze" -Method Post `
        -ContentType "application/json" -Body '{"text":"hi"}'
    Check "threat scoring" ($threat.risk_level -eq "Low Risk")
} catch { Check "threat scoring" $false }

# Cleanup
Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
Pop-Location

if ($fail) {
    Write-Host "`nVerification FAILED - see FAIL lines above" -ForegroundColor Red
} else {
    Write-Host "`nVerification complete - all checks passed" -ForegroundColor Green
}
