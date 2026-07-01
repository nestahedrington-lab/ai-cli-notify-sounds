$ErrorActionPreference = "SilentlyContinue"
. "$PSScriptRoot\notify-common.ps1"

$payload = Get-AiNotifyPayloadFromStdin
$data = ConvertFrom-AiNotifyJson $payload
if ($null -eq $data) {
  Send-AiNotify -Title "Claude" -Message "Claude completed" -SoundName "ok.mp3" -Icon "Info"
  exit 0
}

$event = $data.hook_event_name
$cwd = $data.cwd

if ($event -eq "Notification") {
  $notificationType = $data.notification_type
  $needsAction = $notificationType -in @("permission_prompt", "elicitation_dialog")
  if (-not $needsAction) {
    exit 0
  }

  $actionText = $data.message
  if ([string]::IsNullOrWhiteSpace($actionText)) {
    $actionText = $data.title
  }

  $label = Get-AiNotifyLabel -Message $actionText -Cwd $cwd -Fallback "Claude needs your attention"
  Send-AiNotify -Title "Claude needs action" -Message $label -SoundName "error.mp3" -Icon "Warning"
  exit 0
}

$label = Get-AiNotifyLabel -Message $data.last_assistant_message -Cwd $cwd -Fallback "Claude completed"
Send-AiNotify -Title "Claude" -Message $label -SoundName "ok.mp3" -Icon "Info"

