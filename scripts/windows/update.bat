@echo off
rem update.bat - double-click: check for crDroid updates, build and publish them
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0update.ps1" %*
echo.
echo Press any key to close this window . . .
pause >nul
