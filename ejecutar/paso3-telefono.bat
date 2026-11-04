@echo off
rem Conecta el telefono con la API. Doble clic para ejecutar, con el telefono conectado por USB.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0paso3-telefono.ps1"
echo.
pause
