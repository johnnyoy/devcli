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
  .\make.ps1 help             Show this help
'@ | Write-Host
}

function Build-Image {
    param([switch]$NoCache)
    $buildArgs = @('build', '-t', $image, '-f', $dockerfile, $here)
    if ($NoCache) { $buildArgs = @('build', '--no-cache', '-t', $image, '-f', $dockerfile, $here) }
    & docker @buildArgs
    if ($LASTEXITCODE -ne 0) { throw "docker build failed" }
}

function Add-ToPath {
    $current = [Environment]::GetEnvironmentVariable('Path', 'User')
    if (($current -split ';') -contains $binDir) {
        Write-Host "bin\ is already on your user PATH -- nothing to do."
        return
    }
    $newPath = $current.TrimEnd(';') + ';' + $binDir
    [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
    Write-Host "Added to user PATH: $binDir"
    Write-Host "Open a new PowerShell/CMD window for the change to take effect."
}

function Remove-FromPath {
    $current = [Environment]::GetEnvironmentVariable('Path', 'User')
    $newPath = (($current -split ';') | Where-Object { $_ -ne $binDir }) -join ';'
    [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
    Write-Host "Removed from user PATH: $binDir"
}

function Ensure-AuthDirs {
    $null = New-Item -ItemType Directory -Force (Join-Path $env:USERPROFILE '.claude')
    $null = New-Item -ItemType Directory -Force (Join-Path $env:USERPROFILE '.config\gh')
}

# Doctor script runs inside the container as bash. Defined here so the
# closing '@  can sit at column 0 as PowerShell 5.1 requires.
$doctorScript = @'
printf "%-12s %s\n" "tool"     "version"
printf "%-12s %s\n" "--------" "----------------------------"
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
printf "%-12s %s\n" "pi"       "$(pi --version 2>/dev/null || echo 'not found')"
'@

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
        & docker run --rm $image bash -lc $doctorScript
        if ($LASTEXITCODE -ne 0) { throw "docker run failed" }
    }

    default {
        Write-Host "Unknown target: $Target"
        Write-Host ""
        Show-Help
        exit 1
    }
}
