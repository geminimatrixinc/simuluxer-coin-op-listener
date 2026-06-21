@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "ROOT_DIR=%SCRIPT_DIR%.."

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%start-kiosk.ps1" -AppRoot "%ROOT_DIR%"

endlocal
