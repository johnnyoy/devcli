@echo off
setlocal EnableDelayedExpansion

REM =========================================================================
REM  devcli — portable AI dev container launcher (Windows)
REM
REM  Usage (from any folder):
REM    devcli                  run Claude Code in the current folder
REM    devcli bash             open a shell in the current folder
REM    devcli openclaw ...     run OpenClaw with args
REM    devcli <cmd> [args]     run any command inside the container
REM    devcli gateway up       start the OpenClaw gateway as a background daemon
REM    devcli gateway down     stop the gateway daemon
REM    devcli gateway status   show gateway status
REM    devcli gateway url      print the tokenized dashboard URL
REM    devcli gateway logs     tail gateway logs
REM =========================================================================

REM ---- gateway subcommand (before docker run) -----------------------------
if /i "%1"=="gateway" (
    set "_GW_CMD=%2"
    if "!_GW_CMD!"==""      goto :gw_help
    if /i "!_GW_CMD!"=="up"     goto :gw_up
    if /i "!_GW_CMD!"=="down"   goto :gw_down
    if /i "!_GW_CMD!"=="status" goto :gw_status
    if /i "!_GW_CMD!"=="url"    goto :gw_url
    if /i "!_GW_CMD!"=="logs"   goto :gw_logs
    echo Unknown gateway command: !_GW_CMD!
    goto :gw_help
)

REM ---- ensure host auth dirs exist ----------------------------------------
if not exist "%USERPROFILE%\.claude"     mkdir "%USERPROFILE%\.claude"
if not exist "%USERPROFILE%\.openclaw"   mkdir "%USERPROFILE%\.openclaw"
if not exist "%USERPROFILE%\.config\gh"  mkdir "%USERPROFILE%\.config\gh"

REM ---- pass-through env vars (only if set on host) -------------------------
set "_ENV_FLAGS="
if defined ANTHROPIC_API_KEY set "_ENV_FLAGS=!_ENV_FLAGS! -e ANTHROPIC_API_KEY"
if defined GITHUB_TOKEN      set "_ENV_FLAGS=!_ENV_FLAGS! -e GITHUB_TOKEN"
if defined GH_TOKEN          set "_ENV_FLAGS=!_ENV_FLAGS! -e GH_TOKEN"

REM ---- optional extra port maps (DEVCLI_PORTS="-p 8000:8000 -p 5173:5173") -
set "_PORT_FLAGS="
if defined DEVCLI_PORTS set "_PORT_FLAGS=%DEVCLI_PORTS%"

REM ---- run (ephemeral, current dir as /workspace) --------------------------
docker run --rm -it ^
    -v "%CD%:/workspace" ^
    -v "%USERPROFILE%\.claude:/home/dev/.claude" ^
    -v "%USERPROFILE%\.openclaw:/home/dev/.openclaw" ^
    -v "%USERPROFILE%\.config\gh:/home/dev/.config/gh" ^
    !_ENV_FLAGS! ^
    !_PORT_FLAGS! ^
    devcli:latest %*
exit /b %ERRORLEVEL%

REM =========================================================================
REM  Gateway management
REM =========================================================================

:gw_up
REM Check if already running
for /f "tokens=*" %%s in ('docker inspect --format "{{.State.Running}}" devcli-gateway 2^>nul') do set "_GW_RUNNING=%%s"
if "!_GW_RUNNING!"=="true" (
    echo devcli-gateway is already running.
    exit /b 0
)
REM Remove stopped container if it exists
docker rm devcli-gateway >nul 2>&1
if not exist "%USERPROFILE%\.openclaw" mkdir "%USERPROFILE%\.openclaw"
docker run -d --restart unless-stopped --name devcli-gateway ^
    -v "%USERPROFILE%\.openclaw:/home/dev/.openclaw" ^
    -p 127.0.0.1:18789:18789 ^
    devcli:latest openclaw gateway run --bind lan --port 18789 --force
if %ERRORLEVEL%==0 (
    echo devcli-gateway started on http://127.0.0.1:18789
    echo Run: devcli gateway url    to get the tokenized dashboard link.
)
exit /b %ERRORLEVEL%

:gw_down
docker rm -f devcli-gateway >nul 2>&1
if %ERRORLEVEL%==0 (echo devcli-gateway stopped.) else (echo devcli-gateway was not running.)
exit /b 0

:gw_status
docker ps --filter "name=devcli-gateway" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
exit /b 0

:gw_url
powershell -NoProfile -Command ^
    "$f = Join-Path $env:USERPROFILE '.openclaw\openclaw.json';" ^
    "if (Test-Path $f) {" ^
    "  $c = Get-Content $f -Raw | ConvertFrom-Json;" ^
    "  $t = [Uri]::EscapeDataString($c.gateway.auth.token);" ^
    "  Write-Host ('http://127.0.0.1:18789/#token=' + $t)" ^
    "} else {" ^
    "  Write-Host 'No openclaw config found. Run: devcli openclaw  to initialise OpenClaw first.'" ^
    "}"
exit /b 0

:gw_logs
docker logs -f devcli-gateway
exit /b %ERRORLEVEL%

:gw_help
echo Usage: devcli gateway ^<up^|down^|status^|url^|logs^>
exit /b 1
