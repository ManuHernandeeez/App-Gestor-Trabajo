# Gestor de Trabajo Rápido

Proyecto académico de Técnicas de Producción Industrial de Software I (UTEC, ciclo 02-2026, Equipo 7).
App Android para contratar u ofrecer trabajos por oficio en la zona del usuario, con una API en
ASP.NET Core y base de datos PostgreSQL.

El alcance y el diseño están en [CLAUDE.md](CLAUDE.md). El plan de trabajo por tandas está en
[docs/plan.md](docs/plan.md) y las decisiones tomadas en [docs/decisiones.md](docs/decisiones.md).

## Estructura

| Carpeta | Contenido |
|---|---|
| `bd/` | Scripts SQL numerados y `aplicar.ps1` para correrlos en orden |
| `api/` | Solución ASP.NET Core (se crea en la tanda 3) |
| `android/` | Proyecto de Android Studio (Java, vistas XML) |
| `docs/` | Plan, decisiones, tabla de endpoints y bocetos de las pantallas |

## Requisitos (Windows 10)

| Herramienta | Versión | Para qué |
|---|---|---|
| PostgreSQL | 16 | Base de datos |
| SDK de .NET | 10 (`dotnet --list-sdks`) | API |
| Android Studio | La actual | App Android |
| Git | 2.x | Control de versiones |

Todos los comandos de este archivo son para PowerShell.

## Base de datos

### Instalar PostgreSQL 16

1. Instala con winget (abre el asistente de EDB) o descarga el instalador desde
   <https://www.postgresql.org/download/windows/>:

   ```powershell
   winget install -e --id PostgreSQL.PostgreSQL.16
   ```

2. En el asistente deja marcados *PostgreSQL Server* y *Command Line Tools*. Usa el puerto 5432, la
   configuración regional por defecto y anota la contraseña que elijas para el usuario `postgres`.
3. Comprueba la instalación:

   ```powershell
   & 'C:\Program Files\PostgreSQL\16\bin\psql.exe' --version
   ```

### Crear la base y aplicar los scripts

Desde la raíz del repositorio:

```powershell
.\bd\aplicar.ps1             # crea gestor_trabajo_rapido si falta y aplica 01 a 05
.\bd\aplicar.ps1 -Pruebas    # además corre 06_pruebas.sql (no deja datos)
.\bd\aplicar.ps1 -Reiniciar  # borra todo y vuelve a crear. Solo desarrollo
```

El script pide la contraseña de `postgres` y encuentra `psql` aunque no esté en el PATH. Los scripts son
idempotentes: se pueden correr varias veces. Si PowerShell bloquea el `.ps1`, ejecuta una sola vez
`Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`.

### Contraseña del rol de la API

La API se conecta con el rol `gtr_api` (sin superusuario y sin `CREATE`). El script lo crea sin contraseña
para que no quede en el repositorio. Fíjala una vez:

```powershell
& 'C:\Program Files\PostgreSQL\16\bin\psql.exe' -U postgres -d gestor_trabajo_rapido -c '\password gtr_api'
```

Esa contraseña irá en `dotnet user-secrets` cuando exista la API.

### Respaldos

```powershell
$pg = 'C:\Program Files\PostgreSQL\16\bin'

# Respaldar
& "$pg\pg_dump.exe" -h localhost -U postgres -d gestor_trabajo_rapido -F c -f respaldo.dump

# Restaurar (el rol gtr_api debe existir: corre .\bd\aplicar.ps1 antes en una PC nueva)
& "$pg\pg_restore.exe" -h localhost -U postgres -d gestor_trabajo_rapido --clean --if-exists --no-owner respaldo.dump
```

Los archivos `.dump` y `.backup` están en `.gitignore`: un respaldo tiene datos de usuarios.

## API

Pendiente. Se crea en la tanda 3 con las instrucciones de `dotnet user-secrets` y el arranque en
`http://0.0.0.0:5000`.

## App Android

1. Abre la carpeta `android/` en Android Studio (*File > Open*) y espera a que termine la sincronización de Gradle.
2. Para compilar desde la terminal usa el JDK que trae Android Studio:

   ```powershell
   $env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
   cd android
   .\gradlew.bat assembleDebug
   ```

La conexión con la API (URL base, emulador, teléfono real y regla del firewall) se documenta en la tanda 3.
