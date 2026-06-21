@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "AHK_SCRIPT=%SCRIPT_DIR%coin-op-listener-comport.ahk"

set "AHK_EXE="
if exist "%ProgramFiles%\AutoHotkey\v2\AutoHotkey64.exe" set "AHK_EXE=%ProgramFiles%\AutoHotkey\v2\AutoHotkey64.exe"
if not defined AHK_EXE if exist "%ProgramFiles%\AutoHotkey\v2\AutoHotkey32.exe" set "AHK_EXE=%ProgramFiles%\AutoHotkey\v2\AutoHotkey32.exe"
if not defined AHK_EXE if exist "%ProgramFiles%\AutoHotkey\AutoHotkey.exe" set "AHK_EXE=%ProgramFiles%\AutoHotkey\AutoHotkey.exe"

if not defined AHK_EXE (
  echo AutoHotkey v2 not found. Install from https://www.autohotkey.com/
  pause
  exit /b 1
)

if not exist "%AHK_SCRIPT%" (
  echo AHK script not found: %AHK_SCRIPT%
  pause
  exit /b 1
)

echo Starting Coin-Op COM Port listener...
echo Edit COM_PORT at the top of coin-op-listener-comport.ahk if needed.
start "" "%AHK_EXE%" "%AHK_SCRIPT%"

endlocal
exit /b 0
