@echo off
rem Prepara la base de datos de pruebas. Doble clic para ejecutar.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0paso1-base-de-datos.ps1"
echo.
pause
