# Solo si Android Studio falla con "jlink executable ... does not exist" (Windows, PowerShell).
# Pasa cuando en la PC hay otro Java (por ejemplo el de VS Code) y Gradle lo elige por error.
# Le dice a Gradle que use siempre el Java que trae Android Studio.
$ErrorActionPreference = 'Stop'
$raiz = Split-Path $PSScriptRoot -Parent
$jbr = 'C:\Program Files\Android\Android Studio\jbr'
$archivo = Join-Path $env:USERPROFILE '.gradle\gradle.properties'

if (-not (Test-Path (Join-Path $jbr 'bin\jlink.exe'))) {
    throw "No se encontro el Java de Android Studio en $jbr. Revisa donde instalaste Android Studio."
}

New-Item -ItemType Directory -Force (Split-Path $archivo) | Out-Null
$lineas = @()
if (Test-Path $archivo) {
    $lineas = Get-Content $archivo | Where-Object { $_ -notmatch '^org\.gradle\.java\.home=' }
}
$lineas += 'org.gradle.java.home=' + ($jbr -replace '\\', '/')
Set-Content -Path $archivo -Value $lineas -Encoding ascii

# Apaga los procesos de Gradle que sigan usando el Java equivocado
$env:JAVA_HOME = $jbr
& "$raiz\android\gradlew.bat" --stop

Write-Host ''
Write-Host 'Listo. En Android Studio: File > Sync Project with Gradle Files, y vuelve a pulsar Run.'
