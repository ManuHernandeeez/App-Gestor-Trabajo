# Conecta el telefono (o el emulador) con la API de esta PC (Windows, PowerShell).
# Crea un tunel para que "localhost:5000" en el telefono llegue a la API de la PC.
# Hay que repetirlo cada vez que se reconecta el cable USB o se reinicia el telefono.
$ErrorActionPreference = 'Stop'
$adb = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'

if (-not (Test-Path $adb)) {
    throw 'No se encontro adb. Instala Android Studio y abrelo una vez para que descargue el SDK.'
}

$conectados = & $adb devices | Select-String '\sdevice$'
if (-not $conectados) {
    Write-Host 'No se ve ningun telefono ni emulador.'
    Write-Host '  1. Conecta el telefono por USB.'
    Write-Host '  2. Activa la depuracion por USB (ver LEEME.txt) y acepta el aviso en la pantalla del telefono.'
    Write-Host '  3. Vuelve a abrir este paso.'
    exit 1
}

& $adb reverse tcp:5000 tcp:5000
if ($LASTEXITCODE -ne 0) { throw 'No se pudo crear el tunel' }

Write-Host ''
Write-Host 'Listo: el telefono ya llega a la API. Ahora ejecuta la app desde Android Studio.'
