@echo off
rem Starts the game as a server with no window and nobody at it (a dedicated server).
rem Usage:  tools\run_server.bat                       (runs the project here with the Godot console program)
rem         tools\run_server.bat WizardGame.exe        (runs an exported game; give its path)
rem Friends join with the "Join" box on the first screen, at this computer's address (on this computer: 127.0.0.1).
rem --upnp asks the router to open the port by itself and prints the address to give friends outside the house.
rem Set WIZARD_PORT to use a port other than 24565. Close the window to stop it.
if not "%~1"=="" goto exported
"C:\Users\Jordan Polun\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless --path "%~dp0.." -- --server --upnp
goto :eof
:exported
"%~1" --headless -- --server --upnp
