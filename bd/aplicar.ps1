# Aplica los scripts de bd/ en orden sobre la base gestor_trabajo_rapido (Windows, PowerShell).
# Desde la raíz del repositorio:
#   .\bd\aplicar.ps1               crea la base si falta y aplica 01 a 05
#   .\bd\aplicar.ps1 -Pruebas      además corre 06_pruebas.sql
#   .\bd\aplicar.ps1 -Reiniciar    borra todo (99_reiniciar.sql) antes de aplicar. Solo desarrollo
param(
    [string]$Servidor = 'localhost',
    [int]$Puerto = 5432,
    [string]$Usuario = 'postgres',
    [switch]$Pruebas,
    [switch]$Reiniciar
)

$ErrorActionPreference = 'Stop'
$base = 'gestor_trabajo_rapido'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$env:PGCLIENTENCODING = 'UTF8'

function Buscar-Psql {
    $comando = Get-Command psql -ErrorAction SilentlyContinue
    if ($comando) { return $comando.Source }
    $ruta = 'C:\Program Files\PostgreSQL\16\bin\psql.exe'
    if (Test-Path $ruta) { return $ruta }
    throw 'No se encontró psql. Instala PostgreSQL 16 o agrega su carpeta bin al PATH.'
}

function Psql-Archivo($archivo) {
    & $psql -h $Servidor -p $Puerto -U $Usuario -d $base -v ON_ERROR_STOP=1 -q -f $archivo
    if ($LASTEXITCODE -ne 0) { throw "Falló $archivo" }
}

$psql = Buscar-Psql

$pedirClave = -not $env:PGPASSWORD
if ($pedirClave) {
    $clave = Read-Host "Contraseña de '$Usuario' en PostgreSQL" -AsSecureString
    $env:PGPASSWORD = [System.Net.NetworkCredential]::new('', $clave).Password
}

try {
    $existe = & $psql -h $Servidor -p $Puerto -U $Usuario -d postgres -tA -c "SELECT 1 FROM pg_database WHERE datname = '$base'"
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo conectar a PostgreSQL. Revisa servidor, puerto, usuario y contraseña.' }
    if (-not $existe) {
        & $psql -h $Servidor -p $Puerto -U $Usuario -d postgres -c "CREATE DATABASE $base"
        if ($LASTEXITCODE -ne 0) { throw "No se pudo crear la base $base" }
    }

    $codificacion = & $psql -h $Servidor -p $Puerto -U $Usuario -d $base -tA -c 'SHOW server_encoding'
    if ($codificacion -ne 'UTF8') { throw "La base usa $codificacion y se necesita UTF8. Crea el clúster de PostgreSQL con codificación UTF8." }

    if ($Reiniciar) { Psql-Archivo "$PSScriptRoot\99_reiniciar.sql" }

    foreach ($archivo in Get-ChildItem "$PSScriptRoot\0[1-5]_*.sql" | Sort-Object Name) {
        Write-Host "Aplicando $($archivo.Name)"
        Psql-Archivo $archivo.FullName
    }

    if ($Pruebas) {
        Write-Host 'Corriendo 06_pruebas.sql'
        Psql-Archivo "$PSScriptRoot\06_pruebas.sql"
    }

    $sinClave = & $psql -h $Servidor -p $Puerto -U $Usuario -d $base -tA -c "SELECT rolpassword IS NULL FROM pg_authid WHERE rolname = 'gtr_api'"
    if ($sinClave -eq 't') {
        Write-Host "Falta la contraseña del rol gtr_api. Ejecuta:  psql -U $Usuario -d $base -c '\password gtr_api'"
    }
}
finally {
    if ($pedirClave) { Remove-Item Env:\PGPASSWORD -ErrorAction SilentlyContinue }
}
