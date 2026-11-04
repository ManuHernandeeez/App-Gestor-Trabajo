# Guarda en dotnet user-secrets la configuración secreta de la API (Windows, PowerShell).
# Desde la raíz del repositorio:  .\api\configurar-secretos.ps1
# Pide los datos sin mostrarlos, para que no queden en el historial de PowerShell.
# Se corre una vez por PC. Si lo vuelves a correr, reemplaza la cadena de conexión y los datos del administrador
# y conserva la clave JWT que ya exista.
param(
    [string]$Servidor = 'localhost',
    [int]$Puerto = 5432
)

$ErrorActionPreference = 'Stop'
$proyecto = Join-Path $PSScriptRoot 'GestorTrabajoApi.csproj'

function Leer-Clave($mensaje) {
    $segura = Read-Host $mensaje -AsSecureString
    return [System.Net.NetworkCredential]::new('', $segura).Password
}

function Guardar($llave, $valor) {
    dotnet user-secrets set $llave $valor --project $proyecto | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "No se pudo guardar $llave" }
}

$claveApi = Leer-Clave "Contraseña del rol gtr_api (la que fijaste con \password)"
if ($claveApi -match '[;"=''\s]' -or $claveApi.Length -eq 0) {
    throw 'La contraseña de gtr_api debe llevar solo letras y números, sin espacios ni ; = comillas.'
}

$correoAdmin = (Read-Host "Correo del administrador").Trim()
if ($correoAdmin -notmatch '^[^@\s]+@[^@\s]+\.[^@\s]+$') { throw 'El correo del administrador no es válido.' }

$claveAdmin = Leer-Clave "Contraseña del administrador (mínimo 8 caracteres)"
if ($claveAdmin.Length -lt 8) { throw 'La contraseña del administrador debe tener al menos 8 caracteres.' }

Guardar 'ConnectionStrings:GestorTrabajo' "Host=$Servidor;Port=$Puerto;Database=gestor_trabajo_rapido;Username=gtr_api;Password=$claveApi"
Guardar 'Administrador:Correo' $correoAdmin
Guardar 'Administrador:Clave' $claveAdmin

$hayClaveJwt = dotnet user-secrets list --project $proyecto | Select-String -Pattern '^Jwt:Clave ' -Quiet
if (-not $hayClaveJwt) {
    $bytes = New-Object byte[] 48
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    Guardar 'Jwt:Clave' ([Convert]::ToBase64String($bytes))
}

Write-Host 'Listo. Secretos guardados:'
dotnet user-secrets list --project $proyecto | ForEach-Object { '  ' + ($_ -split ' = ', 2)[0] }
Write-Host 'Arranca la API con:  cd api; dotnet run'
