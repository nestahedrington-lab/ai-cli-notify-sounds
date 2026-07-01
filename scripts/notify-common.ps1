function Get-AiNotifySoundDir {
  if ($env:AI_NOTIFY_SOUNDS_DIR) {
    return $env:AI_NOTIFY_SOUNDS_DIR
  }

  return Join-Path $env:LOCALAPPDATA "ai-notify\sounds"
}

function Get-AiNotifyPayloadFromStdin {
  if ([Console]::IsInputRedirected) {
    return [Console]::In.ReadToEnd()
  }

  return ""
}

function ConvertFrom-AiNotifyJson {
  param([string]$Text)

  if ([string]::IsNullOrWhiteSpace($Text)) {
    return $null
  }

  try {
    return $Text | ConvertFrom-Json -ErrorAction Stop
  } catch {
    return $null
  }
}

function Get-AiNotifyProjectName {
  param([string]$Path)

  if ([string]::IsNullOrWhiteSpace($Path)) {
    return ""
  }

  try {
    return Split-Path -Leaf $Path
  } catch {
    return ""
  }
}

function Get-AiNotifyLabel {
  param(
    [string]$Message,
    [string]$Cwd,
    [string]$Fallback
  )

  $text = if ([string]::IsNullOrWhiteSpace($Message)) { $Fallback } else { $Message }
  $firstLine = ($text -split "`r?`n")[0]
  if ($firstLine.Length -gt 80) {
    $firstLine = $firstLine.Substring(0, 80)
  }

  $project = Get-AiNotifyProjectName $Cwd
  if ($project) {
    return "$project | $firstLine"
  }

  return $firstLine
}

function Play-AiNotifySound {
  param([string]$SoundName)

  $soundPath = Join-Path (Get-AiNotifySoundDir) $SoundName
  if (-not (Test-Path -LiteralPath $soundPath)) {
    [console]::Beep(880, 180)
    return
  }

  try {
    Add-Type -AssemblyName PresentationCore -ErrorAction Stop
    $player = New-Object System.Windows.Media.MediaPlayer
    $player.Open([Uri]$soundPath)
    $player.Play()
    Start-Sleep -Milliseconds 1800
    $player.Close()
    return
  } catch {
  }

  try {
    $player = New-Object -ComObject WMPlayer.OCX
    $player.URL = $soundPath
    $player.controls.play()
    Start-Sleep -Milliseconds 1800
    $player.controls.stop()
    return
  } catch {
  }

  [console]::Beep(880, 180)
}

function Show-AiNotifyBalloon {
  param(
    [string]$Title,
    [string]$Message,
    [ValidateSet("Info", "Warning", "Error")]
    [string]$Icon = "Info"
  )

  try {
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
    Add-Type -AssemblyName System.Drawing -ErrorAction Stop

    $notifyIcon = New-Object System.Windows.Forms.NotifyIcon
    $notifyIcon.Icon = [System.Drawing.SystemIcons]::Information
    if ($Icon -eq "Warning") {
      $notifyIcon.Icon = [System.Drawing.SystemIcons]::Warning
    } elseif ($Icon -eq "Error") {
      $notifyIcon.Icon = [System.Drawing.SystemIcons]::Error
    }

    $notifyIcon.Visible = $true
    $tipIcon = [System.Enum]::Parse([System.Windows.Forms.ToolTipIcon], $Icon)
    $notifyIcon.ShowBalloonTip(5000, $Title, $Message, $tipIcon)
    Start-Sleep -Milliseconds 1200
    $notifyIcon.Dispose()
  } catch {
    Write-Host "$Title - $Message"
  }
}

function Send-AiNotify {
  param(
    [string]$Title,
    [string]$Message,
    [string]$SoundName,
    [ValidateSet("Info", "Warning", "Error")]
    [string]$Icon = "Info"
  )

  Show-AiNotifyBalloon -Title $Title -Message $Message -Icon $Icon
  Play-AiNotifySound -SoundName $SoundName
}
