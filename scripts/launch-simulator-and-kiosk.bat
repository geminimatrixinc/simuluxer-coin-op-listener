@echo off
setlocal

REM Update these paths for your simulator install.
set "SIMULATOR_BAT=C:\Path\To\Your\Simulator.bat"
set "KIOSK_BAT=%~dp0start-kiosk.bat"
set "SIMULATOR_DELAY_SECONDS=10"

if not exist "%SIMULATOR_BAT%" (
  echo Simulator .bat not found: %SIMULATOR_BAT%
  echo Update SIMULATOR_BAT at the top of this file.
  pause
  exit /b 1
)

echo Starting simulator...
start "Simulator" "%SIMULATOR_BAT%"

echo Waiting %SIMULATOR_DELAY_SECONDS% seconds before starting kiosk listener...
timeout /t %SIMULATOR_DELAY_SECONDS% /nobreak >nul

if not exist "%KIOSK_BAT%" (
  echo Kiosk launcher not found: %KIOSK_BAT%
  pause
  exit /b 1
)

echo Starting kiosk listener...
start "KioskListener" "%KIOSK_BAT%"

echo Done.
endlocal
