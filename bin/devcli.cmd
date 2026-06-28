@echo off
setlocal EnableDelayedExpansion

REM =========================================================================
REM  devcli — portable AI dev container launcher (Windows)
REM
REM  Usage (from any folder):
REM    devcli                  run Claude Code in the current folder
REM    devcli bash             open a shell in the current folder
REM    devcli pi               run the pi harness
REM    devcli <cmd> [args]     run any command inside the container
REM =========================================================================

REM ---- ensure host auth dirs exist ----------------------------------------
if not exist "%USERPROFILE%\.claude"     mkdir "%USERPROFILE%\.claude"
if not exist "%USERPROFILE%\.pi"         mkdir "%USERPROFILE%\.pi"
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
    --hostname devcli ^
    -v "%CD%:/workspace" ^
    -v "%USERPROFILE%\.claude:/home/dev/.claude" ^
    -v "%USERPROFILE%\.pi:/home/dev/.pi" ^
    -v "%USERPROFILE%\.config\gh:/home/dev/.config/gh" ^
    !_ENV_FLAGS! ^
    !_PORT_FLAGS! ^
    devcli:latest %*
exit /b %ERRORLEVEL%
