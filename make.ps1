#!/usr/bin/env pwsh
# =============================================================================
# devcli — control surface (PowerShell, primary on Windows)
#
#   .\make.ps1 install        build image + add bin\ to user PATH (run once)
#   .\make.ps1 build          build (or rebuild) the image
#   .\make.ps1 install-path   add bin\ to user PATH only
#   .\make.ps1 uninstall-path remove bin\ from user PATH
#   .\make.ps1 rebuild        force-rebuild (--no-cache, refreshes agents)
#   .\make.ps1 doctor         print tool versions
#   .\make.ps1 gateway <sub>  manage the OpenClaw background gateway
#   .\make.ps1 help           show this help
# =============================================================================
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Target = 'help',
    [Parameter(Position = 1, ValueFromRemainingArguments = $true)]
    [string[]]$Rest
)

$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$binDir = Join-Path $here 'bin'
$dockerfile = Join-Path $here '.devcontainer\Dockerfile'
$image = 'devcli:latest'

function Show-Help {
    @'
devcli control surface

  .\make.ps1 install          Build image and add bin\ to user PATH (run once)
  .\make.ps1 build            Build (or rebuild) the image
  .\make.ps1 install-path     Add bin\ to user PATH (idempotent)
  .\make.ps1 uninstall-path   Remove bin\ from user PATH
  .\make.ps1 rebuild          Force rebuild with --no-cache (refreshes agents)
  .\make.ps1 doctor           Print versions of all tools in the container
  .\make.ps1 gateway <sub>    Manage the OpenClaw background gateway
                              subs: up | down | status | url | logs
  .\make.ps1 help             Show this help
'@ | Write-Host
}

function Build-Image {
    param([switch]$NoCache)
    $args = @('build', '-t', $image, '-f', $dockerfile, $here)
    if ($NoCache) { $args = @('build', '--no-cache', '-t', $image, '-f', $dockerfile, $here) }
    & docker @args
    if ($LASTEXITCODE -ne 0) { throw "docker build failed" }
}

function Add-ToPath {
    $current = [Environment]::GetEnvironmentVariable('Path', 'User')
    if ($current -split ';' | Where-Object { $_ -eq $binDir }) {
        Write-Host "bin\ is already on your user PATH — nothing to do."
        return
    }
    $newPath = ($current.TrimEnd(';') + ';' + $binDir)
    [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
    Write-Host "Added to user PATH: $binDir"
    Write-Host "Open a new PowerShell/CMD window for the change to take effect."
}

function Remove-FromPath {
    $current = [Environment]::GetEnvironmentVariable('Path', 'User')
    $parts = $current -split ';' | Where-Object { $_ -ne $binDir }
    $newPath = $parts -join ';'
    [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
    Write-Host "Removed from user PATH: $binDir"
}

function Ensure-AuthDirs {
    $null = New-Item -ItemType Directory -Force (Join-Path $env:USERPROFILE '.claude')
    $null = New-Item -ItemType Directory -Force (Join-Path $env:USERPROFILE '.openclaw')
    $null = New-Item -ItemType Directory -Force (Join-Path $env:USERPROFILE '.config\gh')
}

switch ($Target) {
    'help' { Show-Help }

    'build' {
        Build-Image
        Write-Host "`nImage built: $image"
    }

    'rebuild' {
        Build-Image -NoCache
        Write-Host "`nImage rebuilt (no-cache): $image"
    }

    'install-path' {
        Ensure-AuthDirs
        Add-ToPath
    }

    'install' {
        Build-Image
        Ensure-AuthDirs
        Add-ToPath
        Write-Host "`nDone. Open a new terminal and run 'devcli' from any folder."
    }

    'uninstall-path' {
        Remove-FromPath
    }

    'doctor' {
        & docker run --rm "$image" bash -lc @'
printf "%-12s %s\n" "tool" "version"
printf "%-12s %s\n" "------------" "----------------------------"
printf "%-12s %s\n" "python"   "$(python --version 2>&1)"
printf "%-12s %s\n" "pip"      "$(pip --version 2>&1 | cut -d' ' -f1-2)"
printf "%-12s %s\n" "node"     "$(node --version)"
printf "%-12s %s\n" "npm"      "$(npm --version)"
printf "%-12s %s\n" "git"      "$(git --version | cut -d' ' -f1-3)"
printf "%-12s %s\n" "gh"       "$(gh --version | head -n1)"
printf "%-12s %s\n" "ripgrep"  "$(rg --version | head -n1)"
printf "%-12s %s\n" "jq"       "$(jq --version)"
printf "%-12s %s\n" "make"     "$(make --version | head -n1)"
printf "%-12s %s\n" "claude"   "$(claude --version 2>/dev/null || echo 'not found')"
printf "%-12s %s\n" "openclaw" "$(openclaw --version 2>/dev/null || echo 'not found')"
'@
        if ($LASTEXITCODE -ne 0) { throw "docker run failed" }
    }

    'gateway' {
        $sub = if ($Rest.Count -gt 0) { $Rest[0] } else { '' }
        $devcliCmd = Join-Path $binDir 'devcli.cmd'
        & cmd /c "$devcliCmd" gateway $sub
        exit $LASTEXITCODE
    }

    default {
        Write-Host "Unknown target: $Target`n"
        Show-Help
        exit 1
    }
}
