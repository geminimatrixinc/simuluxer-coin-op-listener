@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "AHK_SCRIPT=%SCRIPT_DIR%coin-op-listener.ahk"

REM Try common AutoHotkey v2 install paths.
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

echo Starting Coin-Op AHK listener...
start "" "%AHK_EXE%" "%AHK_SCRIPT%"

endlocal
exit /b 0
