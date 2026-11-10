param([string]$Godot, [string]$OutDir, [switch]$Phase1, [switch]$Crafting)
# Renders preview screenshots with the normal renderer into an isolated directory.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'find_godot.ps1')
$taskEngine = Find-MistboundGodot $Godot
$taskProject = Split-Path $PSScriptRoot -Parent
if (-not $OutDir) { $OutDir = Join-Path $taskProject 'test-results\capture' }
$taskOut = [IO.Path]::GetFullPath($OutDir)
New-Item -ItemType Directory -Path $taskOut -Force | Out-Null
# Keep Godot from importing screenshots written inside the project tree.
$taskIgnore = Join-Path $taskProject 'test-results\.gdignore'
if ($taskOut.StartsWith((Join-Path $taskProject 'test-results')) -and -not (Test-Path $taskIgnore)) {
    New-Item -ItemType File -Path $taskIgnore | Out-Null
}
$taskPreviousSave = $env:MISTBOUND_SAVE_DIR
$env:MISTBOUND_CAPTURE_DIR = $taskOut
$env:MISTBOUND_SAVE_DIR = Join-Path $taskOut ('saves-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
try {
    $taskArguments = @('--path', $taskProject, '--script', 'res://tests/capture_preview.gd')
    if ($Phase1) { $taskArguments += @('--', '--phase1') }
    if ($Crafting) { $taskArguments += @('--', '--crafting') }
    & $taskEngine @taskArguments 2>&1 | Where-Object { "$_" -match 'PREVIEW_CAPTURE|ERROR' }
}
finally {
    $env:MISTBOUND_SAVE_DIR = $taskPreviousSave
    Remove-Item Env:MISTBOUND_CAPTURE_DIR -ErrorAction SilentlyContinue
}
