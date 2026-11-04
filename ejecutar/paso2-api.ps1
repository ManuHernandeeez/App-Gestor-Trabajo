# Configura y levanta la API (Windows, PowerShell).
# Guarda la configuracion de pruebas con dotnet user-secrets (queda en tu usuario de Windows, no en Git)
# y arranca la API en http://localhost:5000. Para apagarla: Ctrl+C.
# Los valores son de pruebas y deben coincidir con los de paso1-base-de-datos.ps1.
$ErrorActionPreference = 'Stop'
$raiz = Split-Path $PSScriptRoot -Parent
$carpetaApi = Join-Path $raiz 'api'
$proyecto = Join-Path $carpetaApi 'GestorTrabajoApi.csproj'

if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
    throw 'No se encontro dotnet. Instala el SDK de .NET 10 (ver LEEME.txt) y abre una ventana nueva.'
}

function Guardar($llave, $valor) {
    dotnet user-secrets set $llave $valor --project $proyecto | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "No se pudo guardar $llave" }
}

Guardar 'ConnectionStrings:GestorTrabajo' 'Host=localhost;Port=5432;Database=gestor_trabajo_rapido;Username=gtr_api;Password=gtr_api_prueba'
Guardar 'Jwt:Clave' 'clave-de-pruebas-equipo-7-solo-desarrollo-0123456789'
Guardar 'Administrador:Correo' 'admin@example.com'
Guardar 'Administrador:Clave' 'Admin12345'

Write-Host 'Configuracion guardada. Levantando la API...'
Write-Host 'Cuando diga "Now listening on: http://0.0.0.0:5000" ya esta lista. Deja esta ventana abierta.'
Write-Host ''

# La API debe correr desde su propia carpeta para encontrar su configuracion
Set-Location $carpetaApi
dotnet run
