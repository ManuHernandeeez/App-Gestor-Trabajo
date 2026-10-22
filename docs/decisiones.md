# Decisiones

Una línea por decisión. Lo que cambia el modelo de datos o el contrato de la API se consulta antes de decidir.

## Repositorio y estructura

- Monorepo local con `android/`, `api/`, `bd/` y `docs/`; el remoto de GitHub se decide más adelante.
- La carpeta `App Gestor Trabajo/` (clon vacío del repositorio de GitHub) queda fuera del repo, excluida en `.git/info/exclude`.
- El esqueleto de Android pasó de la raíz a `android/` y los bocetos a `docs/bocetos/`.
- Paquete y `applicationId` de Android: `com.utec.gestortrabajo`; nombre visible "Gestor de Trabajo Rápido".
- `appsettings.Development.json` está en `.gitignore` para que no se cuelen secretos; se versiona `appsettings.Example.json`.

## Contrato y reglas de negocio

- El teléfono es obligatorio al registrarse (cliente y trabajador), con formato `0000-0000`; el administrador no lleva teléfono.
- La dirección exacta y el presupuesto de la solicitud son obligatorios.
- Límites de texto en la base: nombre 100, título 100, descripción 1000, dirección 200, mensaje de propuesta 300, comentario de calificación 500, mensaje de chat 1000.
- Un cliente puede publicar en una colonia distinta a la de su perfil; la app propone la de su perfil por defecto.

## Base de datos

- Restricciones con prefijo `ck_`, `uq_` y `fk_`; índices con `ix_`.
- `usuarios` tiene una restricción `ck_usuarios_por_rol` que fija qué datos lleva cada rol (zona, DUI, teléfono).
- La colonia del cliente debe pertenecer a su municipio: llave foránea compuesta `(colonia_id, municipio_id)` hacia `colonias`.
- El correo es único sin distinguir mayúsculas (índice sobre `lower(correo)`).
- Una solicitud `asignada`, `en_proceso` o `finalizada` exige trabajador; `publicada` y `vencida` no pueden tenerlo; `cancelada` puede conservar el que tenía.
- `avisos.tipo` no lleva `CHECK`; los valores los definen los triggers.
- El regex del DUI usa `[0-9]` en lugar de `\d` para no aceptar dígitos de otros alfabetos.
- Reejecutar la semilla deja huecos en los ids (`ON CONFLICT DO NOTHING` consume la secuencia); no afecta a los datos.
- Los municipios y colonias de la semilla son de ejemplo y no oficiales; se marcan así en `02_catalogos.sql`.
- El rol `gtr_api` se crea sin contraseña en `01_esquema.sql`; la contraseña se fija con `\password`.
- `gtr_api` tiene `SELECT`, `INSERT` y `UPDATE` en las tablas, y `DELETE` solo en `usuario_oficio` y `trabajador_colonia`, que se reemplazan completas.
- `bd/aplicar.ps1` aplica los scripts en orden y verifica que la base sea UTF8.
- `06_pruebas.sql` corre en una transacción que se revierte y además prueba las restricciones del esquema y los permisos de `gtr_api`.

## API

- Plataforma `net10.0` (SDK 10.0.401 instalado).
- Swagger con `Swashbuckle.AspNetCore` solo en desarrollo, además de `pruebas.http`.
