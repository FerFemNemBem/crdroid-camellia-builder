@echo off
rem build-all.bat - double-click: complete first build of crDroid for camellia (several hours)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build-all.ps1" %*
echo.
echo Press any key to close this window . . .
pause >nul
