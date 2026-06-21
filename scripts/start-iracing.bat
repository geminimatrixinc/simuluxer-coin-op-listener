@echo off
setlocal

REM Placeholder iRacing launcher. Edit window title and keys to match your setup.
REM Workflow:
REM 1. Focus the iRacing window (must already be running).
REM 2. Send Enter to click the native Start button on iRacing's current screen.

set "IRACING_WINDOW_TITLE=iRacing.com Simulator"

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "Add-Type -AssemblyName Microsoft.VisualBasic;" ^
  "Add-Type -AssemblyName System.Windows.Forms;" ^
  "try { [Microsoft.VisualBasic.Interaction]::AppActivate('%IRACING_WINDOW_TITLE%') } catch { Write-Host 'iRacing window not found.' };" ^
  "Start-Sleep -Milliseconds 400;" ^
  "[System.Windows.Forms.SendKeys]::SendWait('{ENTER}')"

endlocal
exit /b 0
