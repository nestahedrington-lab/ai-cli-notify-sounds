param(
  [switch]$Help,
  [switch]$Version
)

$ErrorActionPreference = "Stop"
$AppVersion = "0.2.1"

if ($Help) {
  @"
AI CLI Notify installer $AppVersion

Usage:
  powershell -ExecutionPolicy Bypass -File .\install.ps1
  powershell -ExecutionPolicy Bypass -File .\install.ps1 -Help
  powershell -ExecutionPolicy Bypass -File .\install.ps1 -Version

Installs local notification scripts and sound files for:
  - Codex
  - Claude Code
  - OpenCode

The installer writes user-level files only and creates timestamped backups
before modifying existing CLI configuration files.
"@
  exit 0
}

if ($Version) {
  Write-Output $AppVersion
  exit 0
}

function Backup-File {
  param([string]$Path)

  if (Test-Path -LiteralPath $Path) {
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    Copy-Item -LiteralPath $Path -Destination "$Path.bak.ai-notify-$stamp"
  }
}

function Require-File {
  param([string]$Path)

  if (-not (Test-Path -LiteralPath $Path)) {
    throw "Missing package file: $Path"
  }
}

function Write-Utf8NoBom {
  param(
    [string]$Path,
    [string]$Text
  )

  $utf8 = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path, $Text, $utf8)
}

function Get-PowerShellCommand {
  $pwsh = Get-Command pwsh.exe -ErrorAction SilentlyContinue
  if ($pwsh) {
    return $pwsh.Source
  }

  $powershell = Get-Command powershell.exe -ErrorAction SilentlyContinue
  if ($powershell) {
    return $powershell.Source
  }

  throw "Missing required command: powershell.exe"
}

function Convert-ToJsonFile {
  param(
    [object]$Data,
    [string]$Path
  )

  $json = $Data | ConvertTo-Json -Depth 20
  Write-Utf8NoBom -Path $Path -Text ($json + [Environment]::NewLine)
}

$PackageDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$InstallRoot = Join-Path $env:LOCALAPPDATA "ai-notify"
$BinDir = Join-Path $InstallRoot "bin"
$SoundDir = Join-Path $InstallRoot "sounds"
$OpenCodePluginDir = Join-Path $env:USERPROFILE ".config\opencode\plugins"

$CodexConfig = Join-Path $env:USERPROFILE ".codex\config.toml"
$ClaudeConfig = Join-Path $env:USERPROFILE ".claude\settings.json"
$OpenCodeConfig = Join-Path $env:USERPROFILE ".config\opencode\opencode.json"

$PowerShellCommand = Get-PowerShellCommand

$requiredFiles = @(
  "scripts\notify-common.ps1",
  "scripts\codex-notify.ps1",
  "scripts\claude-notify.ps1",
  "scripts\opencode-notify.ps1",
  "sounds\ok.mp3",
  "sounds\error.mp3",
  "opencode\opencode-notify.mjs"
)

foreach ($relative in $requiredFiles) {
  Require-File (Join-Path $PackageDir $relative)
}

Write-Host "Installing AI CLI notification sounds for Windows..."

New-Item -ItemType Directory -Force -Path $BinDir, $SoundDir, $OpenCodePluginDir | Out-Null

Copy-Item -Force (Join-Path $PackageDir "scripts\notify-common.ps1") (Join-Path $BinDir "notify-common.ps1")
Copy-Item -Force (Join-Path $PackageDir "scripts\codex-notify.ps1") (Join-Path $BinDir "codex-notify.ps1")
Copy-Item -Force (Join-Path $PackageDir "scripts\claude-notify.ps1") (Join-Path $BinDir "claude-notify.ps1")
Copy-Item -Force (Join-Path $PackageDir "scripts\opencode-notify.ps1") (Join-Path $BinDir "opencode-notify.ps1")
Copy-Item -Force (Join-Path $PackageDir "sounds\ok.mp3") (Join-Path $SoundDir "ok.mp3")
Copy-Item -Force (Join-Path $PackageDir "sounds\error.mp3") (Join-Path $SoundDir "error.mp3")
Copy-Item -Force (Join-Path $PackageDir "opencode\opencode-notify.mjs") (Join-Path $OpenCodePluginDir "opencode-notify.mjs")

Write-Host "Patching Codex config..."
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $CodexConfig) | Out-Null
Backup-File $CodexConfig

$codexScript = Join-Path $BinDir "codex-notify.ps1"
$escapedPowerShell = $PowerShellCommand.Replace("\", "\\")
$escapedCodexScript = $codexScript.Replace("\", "\\")
$desiredNotify = "notify = [`"$escapedPowerShell`", `"-NoProfile`", `"-ExecutionPolicy`", `"Bypass`", `"-File`", `"$escapedCodexScript`", `"turn-ended`"]"

$codexText = if (Test-Path -LiteralPath $CodexConfig) { Get-Content -LiteralPath $CodexConfig -Raw } else { "" }
$codexLines = if ($codexText) { $codexText -split "`r?`n" } else { @() }
$newCodexLines = New-Object System.Collections.Generic.List[string]
$replaced = $false

foreach ($line in $codexLines) {
  if ($line -match "^\s*notify\s*=") {
    if (-not $replaced) {
      $newCodexLines.Add($desiredNotify)
      $replaced = $true
    }
    continue
  }
  $newCodexLines.Add($line)
}

if (-not $replaced) {
  $inserted = $false
  $output = New-Object System.Collections.Generic.List[string]
  foreach ($line in $newCodexLines) {
    if ((-not $inserted) -and $line.StartsWith("[")) {
      $output.Add($desiredNotify)
      $output.Add("")
      $inserted = $true
    }
    $output.Add($line)
  }

  if (-not $inserted) {
    if ($output.Count -gt 0 -and $output[$output.Count - 1] -ne "") {
      $output.Add("")
    }
    $output.Add($desiredNotify)
  }
  $newCodexLines = $output
}

Write-Utf8NoBom -Path $CodexConfig -Text (($newCodexLines -join [Environment]::NewLine).TrimEnd() + [Environment]::NewLine)

Write-Host "Patching Claude Code config..."
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $ClaudeConfig) | Out-Null
Backup-File $ClaudeConfig

if ((Test-Path -LiteralPath $ClaudeConfig) -and ((Get-Content -LiteralPath $ClaudeConfig -Raw).Trim())) {
  $claudeData = Get-Content -LiteralPath $ClaudeConfig -Raw | ConvertFrom-Json
} else {
  $claudeData = [pscustomobject]@{}
}

if (-not $claudeData.PSObject.Properties["hooks"] -or $null -eq $claudeData.hooks) {
  $claudeData | Add-Member -MemberType NoteProperty -Name hooks -Value ([pscustomobject]@{}) -Force
}

$claudeScript = Join-Path $BinDir "claude-notify.ps1"
$events = @("StopFailure", "Stop", "Notification")
foreach ($event in $events) {
  $entries = @()
  if ($claudeData.hooks.PSObject.Properties[$event]) {
    $entries = @($claudeData.hooks.$event)
  }

  $exists = $false
  foreach ($entry in $entries) {
    foreach ($hook in @($entry.hooks)) {
      if ($hook.command -eq $PowerShellCommand -and ($hook.args -contains $claudeScript)) {
        $exists = $true
      }
    }
  }

  if (-not $exists) {
    $entries += [pscustomobject]@{
      hooks = @(
        [pscustomobject]@{
          type = "command"
          command = $PowerShellCommand
          args = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $claudeScript)
          async = $true
        }
      )
    }
  }

  $claudeData.hooks | Add-Member -MemberType NoteProperty -Name $event -Value $entries -Force
}

Convert-ToJsonFile -Data $claudeData -Path $ClaudeConfig

Write-Host "Patching OpenCode config..."
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OpenCodeConfig) | Out-Null
Backup-File $OpenCodeConfig

if ((Test-Path -LiteralPath $OpenCodeConfig) -and ((Get-Content -LiteralPath $OpenCodeConfig -Raw).Trim())) {
  $openCodeData = Get-Content -LiteralPath $OpenCodeConfig -Raw | ConvertFrom-Json
} else {
  $openCodeData = [pscustomobject]@{
    '$schema' = "https://opencode.ai/config.json"
  }
}

if (-not $openCodeData.PSObject.Properties["plugin"] -or $null -eq $openCodeData.plugin) {
  $openCodeData | Add-Member -MemberType NoteProperty -Name plugin -Value @() -Force
}

$pluginPath = Join-Path $OpenCodePluginDir "opencode-notify.mjs"
$plugins = @($openCodeData.plugin)
if (($plugins -notcontains $pluginPath) -and ($plugins -notcontains "file://$pluginPath")) {
  $plugins += $pluginPath
}
$openCodeData.plugin = $plugins

Convert-ToJsonFile -Data $openCodeData -Path $OpenCodeConfig

Write-Host "Done."
Write-Host "Restart Codex, Claude Code, and OpenCode for the notification hooks to take effect."
