@echo off
rem Opens the game as usual, to play on a server: press "Join" on the first screen and give the server's address.
rem Usage:  tools\run_client.bat                       (runs the project here)
rem         tools\run_client.bat WizardGame.exe        (runs an exported game)
if "%~1"=="" (
  set GODOT=C:\Users\Jordan Polun\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe
  "%GODOT%" --path "%~dp0.."
) else (
  "%~1"
)
