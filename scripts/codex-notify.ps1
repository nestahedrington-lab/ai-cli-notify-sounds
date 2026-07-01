param(
  [string]$EventName = "turn-ended",
  [string]$Payload = ""
)

$ErrorActionPreference = "SilentlyContinue"
. "$PSScriptRoot\notify-common.ps1"

if ([string]::IsNullOrWhiteSpace($Payload)) {
  $Payload = Get-AiNotifyPayloadFromStdin
}

$data = ConvertFrom-AiNotifyJson $Payload
if ($null -eq $data) {
  exit 0
}

$message = $data.'last-assistant-message'
$cwd = $data.cwd
$label = Get-AiNotifyLabel -Message $message -Cwd $cwd -Fallback "Codex completed"

Send-AiNotify -Title "Codex" -Message $label -SoundName "ok.mp3" -Icon "Info"

