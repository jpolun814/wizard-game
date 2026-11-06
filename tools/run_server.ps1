# Starts the game as a dedicated server (no window). Ctrl-C stops it at once, with no question.
# Usage:  .\tools\run_server.ps1            or, for an exported game:  .\tools\run_server.ps1 WizardGame.exe
param([string]$Exe = "")
if ($Exe -eq "") {
    & "C:\Users\Jordan Polun\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless --path "$PSScriptRoot\.." -- --server
} else {
    & $Exe --headless -- --server
}
