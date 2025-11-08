@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem ===== SETTINGS (edit these) =====
set "DST=%USERPROFILE%\Documents\Spoolman\gcodes"
set "BASE_URL=http://127.0.0.1:7912"

rem ===== INPUT CHECK =====
if "%~1"=="" (
  echo [ERROR] No input filepath from PrusaSlicer.
  exit /b 100
)
if not exist "%~1" (
  echo [ERROR] Source file not found: "%~1"
  exit /b 101
)

rem ===== STEP 1: COPY TO DST WITH A CLEAN NAME =====
set "name=%~nx1"
if defined SLIC3R_PP_OUTPUT_NAME for %%F in ("%SLIC3R_PP_OUTPUT_NAME%") do set "name=%%~nxF"
if /I "%name:~-3%"==".pp" set "name=%name:~0,-3%"
for %%X in ("%name%") do if /I "%%~xX"=="" set "name=%name%.gcode"

if not exist "%DST%" mkdir "%DST%" >nul 2>nul

echo Copying:
echo   "%~1"
echo   -> "%DST%\%name%"
copy /Y "%~1" "%DST%\%name%" >nul
if errorlevel 1 (
  echo [ERROR] Copy failed.
  exit /b 102
)
if not exist "%DST%\%name%" (
  echo [ERROR] Copy produced no file: "%DST%\%name%"
  exit /b 103
)

set "GCODE_FILE=%DST%\%name%"
echo Copied file: "%GCODE_FILE%"

rem ===== STEP 2: PARSE + CALL API (weight-only) VIA POWERSHELL =====
set "PS1=%TEMP%\spoolman_use_weight.ps1"
> "%PS1%" echo param([string]$Path,[string]$BaseUrl)
>>"%PS1%" echo $ErrorActionPreference='Stop'
>>"%PS1%" echo Write-Host "Parsing values from G-code..."
>>"%PS1%" echo $raw = Get-Content -Raw -LiteralPath $Path
>>"%PS1%" echo $spool = [regex]::Match($raw,'SPOOLMAN_ID\s*=\s*(\d+)').Groups[1].Value
>>"%PS1%" echo $w     = [regex]::Match($raw,';\s*filament used \[g\]\s*=\s*([0-9]+(?:[.,][0-9]+)?)').Groups[1].Value
>>"%PS1%" echo if(-not $spool){ Write-Host "[ERROR] SPOOLMAN_ID not found."; exit 2 }
>>"%PS1%" echo if(-not $w){     Write-Host "[ERROR] ''filament used [g]'' not found."; exit 4 }
>>"%PS1%" echo $w = ($w -replace ',','.')
>>"%PS1%" echo Write-Host ("Parsed: spool_id={0}, use_weight={1}" -f $spool,$w)
>>"%PS1%" echo $uri  = "{0}/api/v1/spool/{1}/use" -f $BaseUrl.TrimEnd('/ '),$spool
>>"%PS1%" echo $body = @{ use_weight = [double]$w } ^| ConvertTo-Json -Compress
>>"%PS1%" echo Write-Host ("Sending: PUT {0}" -f $uri)
>>"%PS1%" echo Write-Host ("Body: {0}" -f $body)
>>"%PS1%" echo $resp = Invoke-RestMethod -Method Put -Uri $uri -ContentType "application/json" -Body $body -TimeoutSec 15
>>"%PS1%" echo if($resp){ Write-Host "Response:" (ConvertTo-Json -InputObject $resp -Compress) }
>>"%PS1%" echo Write-Host "SUCCESS."
>>"%PS1%" echo exit 0

powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -Path "%GCODE_FILE%" -BaseUrl "%BASE_URL%"
set "RC=%ERRORLEVEL%"
del "%PS1%" >nul 2>nul

echo Exit code: %RC%
exit /b %RC%
