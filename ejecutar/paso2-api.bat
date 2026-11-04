@echo off
rem Configura y levanta la API. Doble clic para ejecutar. Deja la ventana abierta mientras pruebas.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0paso2-api.ps1"
echo.
pause
