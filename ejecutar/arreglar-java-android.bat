@echo off
rem Solo si Android Studio falla con "jlink executable ... does not exist". Doble clic para ejecutar.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0arreglar-java-android.ps1"
echo.
pause
