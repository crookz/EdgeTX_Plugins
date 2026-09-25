# Copies one widget to the radio's SD card (radio connected as USB Storage).
#
#   .\deploy.ps1 BDSwitchPRO           copy by widget name
#   .\deploy.ps1 widgets\X\main.lua    copy the widget a file belongs to
#   .\deploy.ps1 BDSwitchPRO -Drive E  skip drive detection

param(
  [Parameter(Mandatory = $true)][string]$Widget,
  [string]$Drive
)

$widgetsDir = Join-Path $PSScriptRoot "widgets"

# accept a widget name, or any path inside widgets\<name>\
$name = $Widget
$full = $Widget
if (-not [System.IO.Path]::IsPathRooted($full)) { $full = Join-Path (Get-Location) $full }
$full = [System.IO.Path]::GetFullPath($full)
if ($full.StartsWith($widgetsDir + "\", [System.StringComparison]::OrdinalIgnoreCase)) {
  $name = $full.Substring($widgetsDir.Length + 1).Split("\")[0]
}

$src = Join-Path $widgetsDir $name
if (-not (Test-Path $src -PathType Container)) {
  Write-Error "Widget folder not found: $src"
  exit 1
}

# find the radio: a drive other than C: whose root has WIDGETS and RADIO folders
if ($Drive) {
  $root = $Drive.TrimEnd(":\") + ":\"
  if (-not (Test-Path $root)) {
    Write-Error "Drive $root not found."
    exit 1
  }
} else {
  $root = [System.IO.DriveInfo]::GetDrives() |
    Where-Object { $_.IsReady -and $_.Name -ne "C:\" -and
                   (Test-Path (Join-Path $_.Name "WIDGETS")) -and
                   (Test-Path (Join-Path $_.Name "RADIO")) } |
    Select-Object -First 1 -ExpandProperty Name
  if (-not $root) {
    Write-Error "No radio SD card found. Connect the radio and choose USB Storage (SD)."
    exit 1
  }
}

$dest = Join-Path $root "WIDGETS\$name"
Write-Host "Copying $name -> $dest"
robocopy $src $dest /E /NJH /NJS /NDL /NP
# robocopy exit codes below 8 mean success
if ($LASTEXITCODE -ge 8) { exit $LASTEXITCODE }

# remove compiled copies so the radio recompiles the new scripts
Get-ChildItem $dest -Filter *.luac -Recurse | ForEach-Object {
  Write-Host "Removing $($_.Name)"
  Remove-Item $_.FullName
}
Write-Host "Done."
exit 0
