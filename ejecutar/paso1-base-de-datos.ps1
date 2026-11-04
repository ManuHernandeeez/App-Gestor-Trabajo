# Prepara la base de datos de pruebas (Windows, PowerShell).
# Crea la base gestor_trabajo_rapido, aplica los scripts de bd/, carga las cuentas de ejemplo
# y deja fija la contrasena del rol gtr_api (la usa la API). Se puede repetir sin problema.
# Solo para desarrollo y pruebas.
param(
    [switch]$Pruebas
)

$ErrorActionPreference = 'Stop'
$raiz = Split-Path $PSScriptRoot -Parent
$base = 'gestor_trabajo_rapido'
$claveApi = 'gtr_api_prueba'

function Buscar-Psql {
    $comando = Get-Command psql -ErrorAction SilentlyContinue
    if ($comando) { return $comando.Source }
    $versiones = Get-ChildItem 'C:\Program Files\PostgreSQL' -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^\d+$' } | Sort-Object { [int]$_.Name } -Descending
    foreach ($version in $versiones) {
        $ruta = Join-Path $version.FullName 'bin\psql.exe'
        if (Test-Path $ruta) { return $ruta }
    }
    throw 'No se encontro PostgreSQL. Instalalo primero (ver LEEME.txt).'
}

$psql = Buscar-Psql
Write-Host 'Escribe la contrasena del usuario postgres (la que pusiste al instalar PostgreSQL).'
Write-Host 'Al escribirla no se ve nada, es normal. Luego pulsa Enter.'
$segura = Read-Host 'Contrasena de postgres' -AsSecureString
$env:PGPASSWORD = [System.Net.NetworkCredential]::new('', $segura).Password

try {
    $opciones = @{ DatosPrueba = $true }
    if ($Pruebas) { $opciones.Pruebas = $true }
    & "$raiz\bd\aplicar.ps1" @opciones

    & $psql -h localhost -U postgres -d $base -q -c "ALTER ROLE gtr_api PASSWORD '$claveApi'"
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo fijar la contrasena del rol gtr_api' }
}
finally {
    Remove-Item Env:\PGPASSWORD -ErrorAction SilentlyContinue
}

Write-Host ''
Write-Host 'Base de datos lista. Siguiente: paso2-api.bat'
