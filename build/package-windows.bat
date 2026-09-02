@echo off
REM Quick wrapper: double-click or run from cmd to build Windows .exe
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0package-windows.ps1"
pause
