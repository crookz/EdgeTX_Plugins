# Copies one widget to the radio's SD card (radio connected as USB Storage).
#
#   .\deploy.ps1 BDSwitchPRO           copy by widget name
#   .\deploy.ps1 widgets\X\main.lua    copy the widget a file belongs to
#   .\deploy.ps1 BDSwitchPRO -Drive E  skip drive detection

param(
  [string]$Widget,
  [string]$Tool,
  [string]$Drive
)

$widgetsDir = Join-Path $PSScriptRoot "widgets"
$toolsDir = Join-Path $PSScriptRoot "SCRIPTS\TOOLS"

if (-not $Widget -and -not $Tool) {
  Write-Error "Provide a widget name or a tool name, e.g. .\deploy.ps1 BDCellBatt or .\deploy.ps1 -Tool BDConfigTool"
  exit 1
}

# Accept the default VS Code task call, which passes a direct file path such as
# "...\SCRIPTS\TOOLS\BDConfigTool.lua".
if ($Widget -and $Widget.Trim() -ne "") {
  $candidate = $Widget
  if (-not [System.IO.Path]::IsPathRooted($candidate)) {
    $candidate = Join-Path (Get-Location) $candidate
  }
  $candidate = [System.IO.Path]::GetFullPath($candidate)

  if ($candidate.StartsWith($toolsDir + "\", [System.StringComparison]::OrdinalIgnoreCase)) {
    $Tool = [System.IO.Path]::GetFileNameWithoutExtension($candidate)
    $Widget = $null
  }
  elseif ($candidate.StartsWith($widgetsDir + "\", [System.StringComparison]::OrdinalIgnoreCase)) {
    $Widget = $candidate
  }
}

if ($Tool) {
  $toolPath = Join-Path $PSScriptRoot "SCRIPTS\TOOLS\$Tool"
  if (-not (Test-Path $toolPath -PathType Leaf) -and -not (Test-Path ($toolPath + ".lua") -PathType Leaf)) {
    Write-Error "Tool not found: $toolPath"
    exit 1
  }

  if (-not (Test-Path ($toolPath + ".lua") -PathType Leaf)) {
    $toolFile = $toolPath
  } else {
    $toolFile = $toolPath + ".lua"
  }

  if ($Drive) {
    $root = $Drive.TrimEnd(":\") + ":\"
    if (-not (Test-Path $root)) {
      Write-Error "Drive $root not found."
      exit 1
    }
  } else {
    $root = [System.IO.DriveInfo]::GetDrives() |
      Where-Object { $_.IsReady -and $_.Name -ne "C:" -and
                     (Test-Path (Join-Path $_.Name "WIDGETS")) -and
                     (Test-Path (Join-Path $_.Name "RADIO")) } |
      Select-Object -First 1 -ExpandProperty Name
    if (-not $root) {
      Write-Error "No radio SD card found. Connect the radio and choose USB Storage (SD)."
      exit 1
    }
  }

  $dest = Join-Path $root "SCRIPTS\TOOLS\$Tool.lua"
  New-Item -ItemType Directory -Force -Path (Split-Path $dest) | Out-Null
  Copy-Item $toolFile $dest -Force
  Write-Host "Copying $toolFile -> $dest"
  Write-Host "Done."
  exit 0
}

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
