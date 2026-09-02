@echo off
setlocal

set "LOVE="
for %%P in (
  "C:\Program Files\LOVE\love.exe"
  "C:\Program Files (x86)\LOVE\love.exe"
  "%LOCALAPPDATA%\Programs\LOVE\love.exe"
) do (
  if exist %%P set "LOVE=%%~P"
)

if not defined LOVE (
  echo Love2D not found. Install from https://love2d.org/
  echo Then run this file again, or drag the Refract folder onto love.exe
  pause
  exit /b 1
)

cd /d "%~dp0"
"%LOVE%" .
