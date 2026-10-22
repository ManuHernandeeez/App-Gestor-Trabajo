# Gestor de Trabajo Rápido — Indicaciones para Claude Code

Proyecto académico del curso Técnicas de Producción Industrial de Software I (UTEC, ciclo 02-2026, Equipo 7). Este archivo va en la raíz del repositorio como `CLAUDE.md`. Cubre la base de datos (PostgreSQL), la API (ASP.NET Core), la app Android (Java) y lo que falta alrededor: estructura, seguridad, pruebas y orden de trabajo.

## 0. Cómo trabajar con este archivo

- Lee todo el archivo antes de escribir código.
- Si algo no está definido y cambia el modelo de datos o el contrato de la API, pregunta antes de decidir. En lo demás, elige lo más simple y anótalo en `docs/decisiones.md` (una línea por decisión).
- No agregues funciones que no estén en la sección 1. El docente ya señaló que el proyecto era muy amplio; el alcance está recortado a propósito.
- Trabaja por tandas pequeñas: termina una parte, pruébala y avisa qué hiciste y cómo probarlo antes de pasar a la siguiente.
- Si el código se aparta de lo documentado en el Avance (EV2), dilo al final de la tanda para que se actualicen los documentos.

## 1. Alcance

### Qué hace la app

- Registro por rol (Cliente o Trabajador) e inicio de sesión. El Administrador se crea por semilla.
- Perfil: datos básicos, foto, zona. El trabajador marca oficios y colonias donde trabaja.
- El cliente publica una solicitud (título, descripción, oficio, presupuesto, zona), la consulta y la cancela.
- El trabajador ve las solicitudes de su zona y oficios, envía una propuesta de precio y puede retirarla.
- El cliente revisa propuestas y acepta o rechaza. Al aceptar, el sistema asigna el trabajo y rechaza las demás.
- Estados de la solicitud: `publicada`, `asignada`, `en_proceso`, `finalizada`, `cancelada`, `vencida`.
- El trabajador marca en proceso, el cliente confirma que terminó y ambos se califican de 1 a 5 con comentario.
- Mensajes de texto entre cliente y trabajador asignado, y avisos. Se cargan al abrir la app o la pantalla.
- Administrador: catálogos de oficios y zonas, suspender o reactivar usuarios, ver DUI y contacto para auditoría, reportes básicos.
- Validación automática del DUI del trabajador al registrarse.
- Las solicitudes publicadas que llevan más de 72 horas sin asignar pasan a `vencida`.
- Bitácora de cada cambio de estado de una solicitud.
- Privacidad por fases: teléfono y dirección exacta solo se entregan cuando el trabajo está asignado y solo a las dos partes.

### Qué NO hace

- Nada de GPS, mapas ni geolocalización. La zona se elige con listas de departamento, municipio y colonia.
- Nada de pasarela de pago. Solo se registra el monto acordado (el precio de la oferta aceptada).
- Nada de chat en tiempo real, notificaciones push, Firebase ni servicios de Google.
- No se publica en Play Store. No hay iOS ni versión web.
- No hay recuperación de contraseña, verificación de correo ni inicio de sesión con redes sociales.
- Solo hay foto de perfil; no hay fotos de los trabajos.

## 2. Reglas globales

- **Idioma:** todo en español de El Salvador (nombres de tablas, columnas, clases del dominio, textos de pantalla, mensajes de error). Los términos técnicos estándar de cada lenguaje se quedan como son (`Controller`, `Repository`, `Intent`).
- **Moneda:** dólares estadounidenses. Se muestran como `$25.00`.
- **Entorno de desarrollo:** Windows 10. Da los comandos para PowerShell. No uses comandos de bash ni rutas de Linux en las instrucciones al equipo.
- **Simplicidad:** una solución sencilla y legible gana a una elegante. Funciones cortas con un solo propósito, comentarios mínimos y naturales, sin emojis ni adornos en comentarios.
- **Dependencias:** agrega solo las que este archivo permite. Si crees que hace falta otra, pregunta.
- **Secretos:** nunca en el repositorio. Cadenas de conexión, clave JWT y contraseña del administrador van en `dotnet user-secrets` o variables de entorno. Deja un `appsettings.Example.json` con valores de relleno.
- **Datos de ejemplo:** nombres, teléfonos, DUI y direcciones de prueba son inventados y se marcan como tales. No uses datos reales de personas.
- **Git:** commits pequeños en español, uno por cambio lógico. Incluye un `.gitignore` para .NET, Android Studio y archivos de secretos.

## 3. Estructura del repositorio

```
/
├── CLAUDE.md
├── README.md                 cómo levantar todo en Windows 10
├── docs/
│   ├── decisiones.md
│   ├── bocetos/              PNG de las 8 pantallas (referencia visual)
│   └── api.md                tabla de endpoints (se mantiene al día)
├── bd/                       scripts SQL numerados
├── api/                      solución ASP.NET Core
└── android/                  proyecto de Android Studio
```

## 4. Modelo de datos

Base: PostgreSQL 16, base de datos `gestor_trabajo_rapido`, esquema `public`. Nombres en `snake_case` y en español. Claves primarias `id integer generated always as identity`. Dinero en `numeric(10,2)`. Fechas en `timestamptz`.

| Tabla | Columnas principales | Notas |
|---|---|---|
| `departamentos` | id, nombre, activo | Catálogo, lo administra el admin |
| `municipios` | id, departamento_id FK, nombre, activo | |
| `colonias` | id, municipio_id FK, nombre, activo | |
| `oficios` | id, nombre único, activo | Electricidad, Fontanería, Pintura, Limpieza, Acarreo, Jardinería |
| `usuarios` | id, rol, nombre, correo único, password_hash, telefono, dui, foto_ruta, municipio_id FK, colonia_id FK nulo, estado, promedio_calificacion, total_calificaciones, fecha_registro, eliminado | `rol`: `cliente`, `trabajador`, `administrador`. `estado`: `activo`, `suspendido`. `dui` solo para trabajadores, único. `colonia_id` solo para clientes |
| `usuario_oficio` | usuario_id FK, oficio_id FK | PK compuesta. Oficios del trabajador |
| `trabajador_colonia` | usuario_id FK, colonia_id FK | PK compuesta. Colonias donde trabaja |
| `solicitudes` | id, cliente_id FK, oficio_id FK, colonia_id FK, titulo, descripcion, presupuesto, direccion_exacta, estado, trabajador_id FK nulo, fecha_publicacion, fecha_asignacion nula, eliminado | `direccion_exacta` es dato sensible |
| `ofertas` | id, solicitud_id FK, trabajador_id FK, precio, mensaje, estado, fecha | `estado`: `pendiente`, `aceptada`, `rechazada`, `retirada`. Índice único parcial sobre (solicitud_id, trabajador_id) donde estado esté en `pendiente` o `aceptada` |
| `calificaciones` | id, solicitud_id FK, calificador_id FK, calificado_id FK, estrellas 1 a 5, comentario NOT NULL, fecha | Única por (solicitud_id, calificador_id) |
| `mensajes` | id, solicitud_id FK, emisor_id FK, receptor_id FK, texto, fecha | Solo existen para solicitudes con trabajador asignado |
| `avisos` | id, usuario_id FK, tipo, texto, solicitud_id FK nulo, fecha, leido | |
| `bitacora` | id, solicitud_id FK, estado_anterior nulo, estado_nuevo, usuario_id nulo, fecha | Se llena por trigger |

Reglas de integridad:

- Llaves foráneas en todas las relaciones, para que no existan ofertas sin solicitud válida.
- Borrado lógico (`eliminado`/`activo`) en lugar de `DELETE` en tablas principales y catálogos. Desactivar un oficio o una colonia no borra el historial.
- `CHECK` para los valores de `rol`, `estado` y `estrellas`.
- Índices en llaves foráneas y en `solicitudes (estado, colonia_id, oficio_id)`.

## 5. Base de datos (carpeta `bd/`)

### 5.1 Scripts

Numerados, en este orden, y todos idempotentes (se pueden correr varias veces sin romper nada: `CREATE ... IF NOT EXISTS`, `CREATE OR REPLACE`, `ON CONFLICT DO NOTHING`).

1. `01_esquema.sql`: tablas, restricciones e índices.
2. `02_catalogos.sql`: oficios y zonas de ejemplo.
3. `03_funciones.sql`: funciones de negocio.
4. `04_triggers.sql`: triggers.
5. `05_vistas.sql`: vistas de lectura.
6. `06_pruebas.sql`: pruebas de la sección 5.6 con `RAISE NOTICE` del resultado.
7. `99_reiniciar.sql`: borra todo para empezar de cero (solo desarrollo).

### 5.2 Convenciones

- Funciones `fn_...`, triggers `trg_...`, funciones de trigger `fn_trg_...`, índices `ix_...`.
- La lógica importante vive en la base de datos: validación del DUI, aceptar oferta, promedio, avisos y bitácora.
- Errores de negocio con `RAISE EXCEPTION '...' USING ERRCODE = 'GT001'`. Códigos propios: `GT001` regla de negocio incumplida (la API responde 409), `GT002` no encontrado (404), `GT003` sin permiso (403). Mensajes en español, claros para mostrar al usuario.
- Una función de PL/pgSQL ya corre dentro de una transacción: si lanza una excepción se deshace todo. Eso cubre la "gestión transaccional de estados" del Avance sin escribir `BEGIN/COMMIT` dentro de la función.

### 5.3 Funciones

| Función | Qué hace |
|---|---|
| `fn_validar_dui(texto)` | Devuelve `boolean`. Formato `########-#` y dígito verificador |
| `fn_registrar_usuario(...)` | Inserta el usuario. Si es trabajador exige DUI válido y único y guarda oficios y colonias. Si es cliente exige colonia |
| `fn_trabajos_por_zona(trabajador_id, oficio_id nulo)` | Solicitudes `publicada` del municipio del trabajador, en sus colonias y oficios, sin teléfono ni dirección. Indica si el trabajador ya envió propuesta |
| `fn_enviar_oferta(trabajador_id, solicitud_id, precio, mensaje)` | Valida que la solicitud esté `publicada` y esté en la zona y oficios del trabajador. Si había una oferta `retirada`, la reactiva |
| `fn_aceptar_oferta(cliente_id, oferta_id)` | Ver 5.4 |
| `fn_marcar_en_proceso(trabajador_id, solicitud_id)` | Solo el trabajador asignado, solo desde `asignada` |
| `fn_finalizar_solicitud(cliente_id, solicitud_id)` | Solo el dueño, solo desde `en_proceso` |
| `fn_cancelar_solicitud(cliente_id, solicitud_id)` | Solo el dueño, solo desde `publicada` o `asignada`. Las ofertas pendientes pasan a `rechazada` |
| `fn_contacto_trabajo(usuario_id, solicitud_id)` | Devuelve teléfono y dirección de la otra parte solo si la solicitud está `asignada`, `en_proceso` o `finalizada` y el usuario es el cliente o el trabajador asignado |
| `fn_calificar(calificador_id, solicitud_id, estrellas, comentario)` | Solo si está `finalizada` y el calificador es una de las dos partes. Califica a la otra parte. Una vez por solicitud |
| `fn_vencer_solicitudes()` | Pasa a `vencida` las `publicada` con más de 72 horas. Sus ofertas pendientes pasan a `rechazada`. Devuelve cuántas |
| `fn_sincronizar(usuario_id, desde)` | Mensajes y avisos del usuario posteriores a `desde` |

### 5.4 Piezas clave (punto de partida, ajústalo y pruébalo)

Validación del DUI. El algoritmo es el que suele citarse: dígitos 1 a 8 multiplicados por 9, 8, 7, 6, 5, 4, 3, 2; se suma y el verificador es `(10 - suma % 10) % 10`. Verifica con DUI reales que el equipo conozca antes de darlo por bueno.

```sql
CREATE OR REPLACE FUNCTION fn_validar_dui(p_dui text)
RETURNS boolean LANGUAGE plpgsql IMMUTABLE AS $$
DECLARE
  v_suma int := 0;
  i int;
BEGIN
  IF p_dui IS NULL OR p_dui !~ '^\d{8}-\d$' OR p_dui = '00000000-0' THEN
    RETURN false;
  END IF;
  FOR i IN 1..8 LOOP
    v_suma := v_suma + substr(p_dui, i, 1)::int * (10 - i);
  END LOOP;
  RETURN ((10 - (v_suma % 10)) % 10) = substr(p_dui, 10, 1)::int;
END $$;
```

Aceptar oferta. Bloquea la solicitud, revisa dueño y estado, y hace los tres cambios juntos.

```sql
CREATE OR REPLACE FUNCTION fn_aceptar_oferta(p_cliente_id int, p_oferta_id int)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE
  v_solicitud_id int;
  v_trabajador_id int;
  v_cliente_id int;
  v_estado text;
BEGIN
  SELECT solicitud_id, trabajador_id INTO v_solicitud_id, v_trabajador_id
  FROM ofertas WHERE id = p_oferta_id AND estado = 'pendiente';
  IF NOT FOUND THEN
    RAISE EXCEPTION 'La propuesta no existe o ya no está pendiente' USING ERRCODE = 'GT002';
  END IF;

  -- bloquea la solicitud para que dos aceptaciones no se pisen
  SELECT cliente_id, estado INTO v_cliente_id, v_estado
  FROM solicitudes WHERE id = v_solicitud_id AND NOT eliminado FOR UPDATE;
  IF NOT FOUND OR v_cliente_id <> p_cliente_id THEN
    RAISE EXCEPTION 'No tienes permiso sobre esta solicitud' USING ERRCODE = 'GT003';
  END IF;
  IF v_estado <> 'publicada' THEN
    RAISE EXCEPTION 'La solicitud ya no está disponible para asignar' USING ERRCODE = 'GT001';
  END IF;

  UPDATE ofertas SET estado = 'aceptada' WHERE id = p_oferta_id;
  UPDATE ofertas SET estado = 'rechazada'
   WHERE solicitud_id = v_solicitud_id AND id <> p_oferta_id AND estado = 'pendiente';
  UPDATE solicitudes
     SET estado = 'asignada', trabajador_id = v_trabajador_id, fecha_asignacion = now()
   WHERE id = v_solicitud_id;
END $$;
```

Promedio de calificación.

```sql
CREATE OR REPLACE FUNCTION fn_trg_promedio() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  UPDATE usuarios u
     SET promedio_calificacion = x.prom, total_calificaciones = x.total
    FROM (SELECT COALESCE(AVG(estrellas), 0)::numeric(3,2) AS prom, COUNT(*)::int AS total
            FROM calificaciones WHERE calificado_id = NEW.calificado_id) x
   WHERE u.id = NEW.calificado_id;
  RETURN NULL;
END $$;

CREATE OR REPLACE TRIGGER trg_calificaciones_promedio
AFTER INSERT ON calificaciones
FOR EACH ROW EXECUTE FUNCTION fn_trg_promedio();
```

### 5.5 Triggers

| Trigger | Cuándo | Qué hace |
|---|---|---|
| `trg_solicitudes_bitacora` | INSERT, o UPDATE de `estado` en `solicitudes` | Escribe en `bitacora` el estado anterior, el nuevo y el usuario. El usuario sale de `current_setting('app.usuario_id', true)`, que la API fija al inicio de cada transacción con `SELECT set_config('app.usuario_id', @id, true)`. Si viene vacío, se guarda `NULL` (tarea automática) |
| `trg_ofertas_aviso` | INSERT en `ofertas` | Aviso al cliente: propuesta nueva |
| `trg_ofertas_estado_aviso` | UPDATE de `estado` en `ofertas` | Aviso al trabajador cuando su oferta pasa a `aceptada` o `rechazada` |
| `trg_solicitudes_aviso` | UPDATE de `estado` en `solicitudes` | Aviso a la otra parte en `en_proceso`, `finalizada`, `cancelada` y `vencida` |
| `trg_mensajes_aviso` | INSERT en `mensajes` | Aviso al receptor: mensaje nuevo |
| `trg_calificaciones_promedio` | INSERT en `calificaciones` | Recalcula el promedio del calificado |

### 5.6 Vistas, semilla y pruebas

- `vw_solicitudes_publicas`: solicitudes sin `direccion_exacta` ni datos de contacto, con nombre del cliente y zona general.
- `vw_reporte_resumen`: totales por estado y calificación promedio general.
- Semilla: los 14 departamentos, los oficios de la tabla y un conjunto pequeño de municipios y colonias de ejemplo (marcados como no oficiales). El administrador puede agregar más desde la app.
- Administrador inicial: no pongas su contraseña en SQL. La API lo crea al arrancar si no existe, con correo y contraseña tomados de variables de entorno o `user-secrets`.
- `06_pruebas.sql` debe comprobar como mínimo:
  - DUI válido pasa, DUI con dígito incorrecto falla, DUI con formato malo falla, `00000000-0` falla.
  - Registrar trabajador con DUI inválido no inserta nada.
  - Aceptar una oferta deja la solicitud `asignada`, la oferta elegida `aceptada` y las demás `rechazada`.
  - Aceptar otra oferta de la misma solicitud ya asignada lanza `GT002` (la propuesta ya no está pendiente).
  - Aceptar una oferta de la solicitud de otro cliente lanza `GT003`. Aceptar una oferta pendiente de una solicitud cancelada lanza `GT001`.
  - `fn_contacto_trabajo` devuelve contacto solo con la solicitud asignada y solo a las dos partes; para cualquier otro usuario lanza `GT003`.
  - Calificar inserta y el promedio del calificado cambia.
  - `fn_vencer_solicitudes` vence una solicitud con `fecha_publicacion` de hace 73 horas y no toca una de hace 71.
- Permisos: crea un rol de base de datos `gtr_api` solo con los permisos que la API necesita (sin superusuario, sin `CREATE`). La API se conecta con ese rol.
- Respaldos: documenta en el README el comando `pg_dump` y cómo restaurar.

## 6. API (carpeta `api/`, ASP.NET Core)

### 6.1 Stack

- C# con ASP.NET Core Web API usando **controladores**. Antes de fijar la versión, revisa con `dotnet --list-sdks` qué SDK LTS está instalado y usa ese.
- Acceso a datos con **Npgsql directo** (ADO.NET: `NpgsqlConnection`, `NpgsqlCommand`) y **patrón repositorio**. Sin Entity Framework. Los repositorios llaman a las funciones `fn_...` de la sección 5.
- Paquetes permitidos: `Npgsql`, `BCrypt.Net-Next`, `Microsoft.AspNetCore.Authentication.JwtBearer`, y Swagger para pruebas en desarrollo. Nada más sin preguntar.

### 6.2 Capas y carpetas

```
api/
├── Controllers/     un controlador por módulo
├── Servicios/       reglas que no están en la base (fotos, JWT, hash)
├── Repositorios/    una clase por área; solo SQL y mapeo
├── Modelos/         entidades y DTO de entrada y salida
├── Seguridad/       JwtServicio, HashServicio
├── Tareas/          VencimientoTarea (BackgroundService)
├── Fotos/           archivos subidos (fuera de Git)
└── Program.cs
```

- Controladores, como en el Avance: `Auth`, `Usuarios` (perfil), `Zonas` (catálogos), `Solicitudes`, `Ofertas` (las propuestas), `Mensajes`, `Avisos`, `Calificaciones` y `Admin`.
- Un DTO por respuesta. Nunca devuelvas entidades completas.
- Cada petición que modifica datos abre una transacción y fija `app.usuario_id` antes de llamar a la función.
- Un manejador global convierte las excepciones de Npgsql con SQLSTATE `GT001`, `GT002` y `GT003` en 409, 404 y 403, y cualquier otra en 500 sin detalles internos. El cuerpo de error es `{ "codigo": "GT001", "mensaje": "..." }`.

### 6.3 Seguridad

- Contraseñas con BCrypt (`BCrypt.Net-Next`). Nunca se guarda ni se registra la contraseña en texto plano. Mínimo 8 caracteres.
- Sesión con JWT. Claims: `sub` (id de usuario), `rol`, `nombre`. Vigencia de 24 horas. La clave sale de `user-secrets`, mínimo 32 caracteres.
- Autorización por rol con `[Authorize(Roles = "cliente")]`, `"trabajador"` o `"administrador"`. Además, en cada acción verifica que el recurso pertenezca al usuario del token (un cliente no puede tocar solicitudes de otro).
- Un usuario con `estado = suspendido` no puede iniciar sesión, y su token deja de servir. Comprueba el estado en cada petición o en el login más una vigencia corta; documenta cuál elegiste.
- `dui`, `correo`, `telefono` y `direccion_exacta` jamás salen en listas ni en detalles generales. Solo salen por `GET /api/solicitudes/{id}/contacto` (partes del trabajo, trabajo asignado) y por los endpoints de auditoría del administrador.
- No registres cuerpos de petición con contraseñas ni tokens.

### 6.4 Endpoints

Prefijo `/api`. Todo requiere token salvo lo marcado como público.

| Método y ruta | Rol | Qué hace |
|---|---|---|
| `POST /auth/registro` | público | Crea cliente o trabajador |
| `POST /auth/login` | público | Devuelve `{ token, rol, usuarioId, nombre }` |
| `GET /catalogos/departamentos` | público | Lista activos |
| `GET /catalogos/departamentos/{id}/municipios` | público | Lista activos |
| `GET /catalogos/municipios/{id}/colonias` | público | Lista activas |
| `GET /catalogos/oficios` | público | Lista activos |
| `GET /perfil` | cliente, trabajador | Perfil propio con promedio |
| `PUT /perfil` | cliente, trabajador | Actualiza nombre, teléfono y zona |
| `POST /perfil/foto` | cliente, trabajador | Multipart. Solo jpg o png, máximo 2 MB, nombre de archivo generado (GUID). Guarda la ruta |
| `PUT /perfil/oficios` | trabajador | Reemplaza oficios |
| `PUT /perfil/colonias` | trabajador | Reemplaza colonias de trabajo |
| `POST /solicitudes` | cliente | Publica solicitud |
| `GET /solicitudes/mias?estado=` | cliente | Lista propias con conteo de propuestas |
| `GET /solicitudes/{id}` | cliente, trabajador | Detalle. Al trabajador, solo si está en su zona u oficios o es el asignado; sin datos sensibles |
| `PUT /solicitudes/{id}/cancelar` | cliente | |
| `PUT /solicitudes/{id}/finalizar` | cliente | Confirma que terminó |
| `GET /solicitudes/{id}/propuestas` | cliente | Propuestas con precio y promedio del trabajador |
| `POST /propuestas/{id}/aceptar` | cliente | Llama a `fn_aceptar_oferta` |
| `POST /propuestas/{id}/rechazar` | cliente | |
| `GET /trabajos/zona?oficioId=` | trabajador | Llama a `fn_trabajos_por_zona` |
| `POST /trabajos/{solicitudId}/propuestas` | trabajador | Envía propuesta |
| `GET /propuestas/mias?estado=` | trabajador | Lista propias |
| `PUT /propuestas/{id}/retirar` | trabajador | Solo si está `pendiente` |
| `PUT /trabajos/{solicitudId}/en-proceso` | trabajador | |
| `GET /solicitudes/{id}/contacto` | cliente, trabajador | Contacto de la otra parte (ver 5.3) |
| `POST /solicitudes/{id}/calificaciones` | cliente, trabajador | Califica a la otra parte |
| `GET /usuarios/{id}/reputacion` | cliente, trabajador | Promedio y últimas calificaciones |
| `GET /solicitudes/{id}/mensajes?desde=` | cliente, trabajador | Mensajes del trabajo |
| `POST /solicitudes/{id}/mensajes` | cliente, trabajador | Envía mensaje (solo si hay trabajador asignado) |
| `GET /conversaciones` | cliente, trabajador | Trabajos con trabajador asignado y último mensaje |
| `GET /sincronizacion?desde=` | cliente, trabajador | Mensajes y avisos nuevos (carga al abrir la app) |
| `PUT /avisos/leidos` | cliente, trabajador | Marca avisos como leídos |
| `GET, POST, PUT /admin/oficios` (y `/admin/departamentos`, `/admin/municipios`, `/admin/colonias`) | administrador | Crear, editar, activar o desactivar |
| `GET /admin/usuarios?q=` | administrador | Búsqueda por nombre o correo |
| `PUT /admin/usuarios/{id}/suspender` y `/reactivar` | administrador | |
| `GET /admin/usuarios/{id}/auditoria` | administrador | DUI, teléfono y correo |
| `GET /admin/reportes/resumen` | administrador | Totales por estado y promedio general |

Mantén `docs/api.md` con esta tabla al día y un ejemplo de JSON por endpoint importante. Ejemplo del login:

```json
{ "token": "eyJ...", "rol": "trabajador", "usuarioId": 7, "nombre": "Luis Hernández" }
```

Ejemplo de un trabajo de la zona (nota: sin teléfono ni dirección):

```json
{ "id": 21, "titulo": "Cambio de tomacorrientes", "oficio": "Electricidad",
  "presupuesto": 40.00, "zona": "Mejicanos, Col. Zacamil",
  "clienteNombre": "María R.", "publicadaHaceHoras": 2, "yaPropuse": false }
```

Las fechas viajan en ISO 8601 con zona horaria. La app Android las muestra en hora local.

### 6.5 Tareas y archivos

- `VencimientoTarea`: `BackgroundService` que cada hora llama a `fn_vencer_solicitudes()` y registra cuántas venció.
- Fotos: carpeta `Fotos/` fuera del control de versiones, servida como archivos estáticos. En la base solo va la ruta relativa.
- Escucha en `http://0.0.0.0:5000` en desarrollo para que el emulador de Android (`10.0.2.2:5000`) y un teléfono en la misma red lleguen. En Windows puede hacer falta una regla del firewall para el puerto 5000; documéntalo en el README.

## 7. App Android (carpeta `android/`)

### 7.1 Estilo de código (obligatorio)

- **Java**, Android Studio, vistas en XML. Nada de Kotlin.
- **Sin librerías externas.** Usa solo las dependencias que trae la plantilla *Empty Views Activity*. No agregues Retrofit, Gson, Glide, Picasso ni similares.
- Código legible y mantenible, dividido en funciones cortas, con comentarios mínimos y naturales. Sin emojis ni puntuación decorativa en comentarios o mensajes.
- Una pantalla por `Activity`, con `onCreate` y `onDestroy` explícitos. Las vistas se obtienen con `findViewById` y las imágenes con `getDrawable`.
- Datos entre pantallas con `Intent` y extras (`putExtra`, `getIntent().getExtras()`). `startActivity` simple, sin flags ni modos de lanzamiento especiales. Después de pasar del login al menú, llama a `finish()`.
- **No usar** ViewBinding, DataBinding, Jetpack Compose, ViewModel, LiveData, coroutines, Navigation Component ni Fragments.
- **IDs de vistas en español y cortos según su función**: `btnAceptar`, `txtTitulo`, `listaSolicitudes`, `edtCorreo`, `spnDepartamento`. Prefijos: `btn`, `txt`, `edt`, `spn`, `lista`, `img`, `vista`.
- Prefiere un estilo clásico y simple (métodos privados con nombre claro, clases anónimas o `android:onClick`). Sin streams. Evita funciones complejas o poco comunes.
- Textos en `strings.xml`, colores en `colors.xml`, medidas repetidas en `dimens.xml`.

### 7.2 Permisos y red

- Solo permiso `INTERNET`. No pidas ubicación. Para elegir la foto usa `Intent.ACTION_GET_CONTENT`, que no necesita permiso de almacenamiento.
- URL base en una constante (`Config.URL_BASE = "http://10.0.2.2:5000/"`). En desarrollo se permite HTTP sin cifrar solo para `10.0.2.2` y la IP de la PC, con `network_security_config.xml`. Documenta cómo cambiarla para un teléfono real.
- Cliente HTTP propio con `HttpURLConnection` y JSON con `org.json` (`JSONObject`, `JSONArray`). Cada petición corre en un `Thread` y devuelve el resultado al hilo principal con `runOnUiThread`. No uses `AsyncTask`. Si la pantalla ya se cerró (`isFinishing()`), ignora la respuesta.
- Forma sugerida de la clase de red, para tener un solo punto de acceso:

```java
public class ClienteApi {
    public interface Respuesta {
        void alExito(String cuerpo);
        void alError(int codigo, String mensaje);
    }

    // metodo: "GET", "POST", "PUT". cuerpo puede ser null.
    public static void pedir(final Activity pantalla, final String metodo, final String ruta,
                             final String cuerpo, final Respuesta respuesta) {
        new Thread(new Runnable() {
            public void run() {
                // abrir HttpURLConnection, poner el token de SharedPreferences si hay,
                // enviar el cuerpo, leer la respuesta y llamar a respuesta en el hilo principal
            }
        }).start();
    }
}
```

- Si la API responde 401, borra la sesión y vuelve al login. Si responde 403, 404 o 409, muestra el mensaje del cuerpo con un `Toast`.

### 7.3 Sesión y datos locales

- `SharedPreferences` (`sesion`): `token`, `rol`, `usuarioId`, `nombre` y `ultimaCarga` (fecha de la última sincronización de mensajes y avisos).
- No guardes contraseña, DUI ni datos de contacto en el teléfono.
- Mientras una pantalla está abierta, las listas descargadas viven en memoria (arreglos en la `Activity`). No hay base de datos local.

### 7.4 Navegación por rol

Después del login, según `rol`: cliente va a *Mis solicitudes*, trabajador a *Trabajos de mi zona* y administrador a *Catálogos*. Las `Activity` son:

| Rol | Pantallas |
|---|---|
| Sin sesión | `LoginActivity`, `RegistroActivity` |
| Cliente | `MisSolicitudesActivity`, `NuevaSolicitudActivity`, `DetalleSolicitudActivity`, `PropuestasActivity`, `SeguimientoActivity`, `CalificarActivity` |
| Trabajador | `TrabajosZonaActivity`, `DetalleTrabajoActivity` (incluye enviar propuesta), `MisPropuestasActivity`, `SeguimientoActivity` (compartida), `CalificarActivity` (compartida) |
| Ambos | `MensajesActivity` (lista de conversaciones), `ConversacionActivity`, `PerfilActivity` |
| Administrador | `AdminCatalogosActivity` (pestañas Oficios y Zonas), `AdminUsuariosActivity` (usuarios y reportes) |

La barra inferior es un layout reutilizable por rol (`barra_cliente.xml`, `barra_trabajador.xml`, `barra_admin.xml`) incluido con `<include>`. Cada botón llama a `startActivity`.

### 7.5 Pantallas y comportamiento

Las 8 pantallas de referencia están en `docs/bocetos/` y siguen la paleta de la sección 7.6. Sigue su estructura, pero respeta este documento donde haya diferencia.

- **Registro:** nombre, correo, contraseña, rol. Si es trabajador: DUI (formato `########-#`), oficios (casillas) y colonias de trabajo. Si es cliente: colonia. El DUI lo valida el servidor; la app solo revisa el formato y muestra el mensaje que devuelva la API.
- **Zona en cascada, tipo select2:** departamento (`Spinner`) → municipio (`Spinner`) → colonia. Al cambiar el nivel de arriba se vuelve a pedir el de abajo a la API. Para las colonias usa un cuadro de diálogo con un campo de búsqueda y una lista filtrada con `TextWatcher`; para el trabajador, la lista permite marcar varias.
- **Mis solicitudes:** filtros por estado, tarjetas con título, oficio, zona, presupuesto, estado y número de propuestas. Botón para crear nueva.
- **Detalle del trabajo (trabajador):** muestra zona general y nombre del cliente. Un aviso indica que teléfono y dirección se liberan al ser aceptado. Campos de precio y mensaje, y botón *Enviar propuesta*.
- **Propuestas (cliente):** precio, nombre y promedio del trabajador, botones *Aceptar* y *Rechazar*.
- **Seguimiento:** estado actual. Cuando el trabajo está asignado, muestra el contacto de la otra parte (de `/contacto`). Acciones según rol: el trabajador *Marcar en proceso*, el cliente *Confirmar trabajo terminado*.
- **Calificar:** de 1 a 5 estrellas y comentario **obligatorio**.
- **Conversación:** burbujas, campo de texto y botón enviar. Se carga al abrir y con un botón de actualizar. Sin sondeo en segundo plano ni notificaciones.
- **Al abrir la app (con sesión):** llama a `/sincronizacion?desde=ultimaCarga`, muestra un aviso con el número de mensajes y avisos nuevos y actualiza `ultimaCarga`.
- **Perfil y zona:** datos, foto, zona, oficios y colonias (trabajador) y promedio. El DUI se muestra enmascarado y no se edita.
- **Administración:** oficios y zonas con interruptor activo/inactivo y botón agregar. Usuarios con búsqueda, *Suspender* o *Reactivar*, y resumen de reportes (los datos de auditoría salen del endpoint de auditoría).
- Estados vacíos con un texto corto y errores con `Toast`.

### 7.6 Colores (`res/values/colors.xml`)

La paleta es nueva y reemplaza la azul y naranja de la Propuesta (EV1).

| Nombre | Hex | Uso |
|---|---|---|
| `principal` | `#0F766E` | Barra superior, elementos activos |
| `accion` | `#7C3AED` | Botones principales y enlaces |
| `fondo` | `#F1F5F4` | Fondo de pantallas |
| `texto` | `#0F172A` | Texto |
| `superficie` | `#FFFFFF` | Tarjetas y campos |
| `exito` | `#16A34A` | Finalizada, aceptada |
| `alerta` | `#F59E0B` | Pendiente, estrellas |
| `error` | `#DC2626` | Rechazada, errores, suspender |

Colores por estado de la solicitud: publicada violeta, en proceso verde azulado (`principal`), finalizada verde (`exito`), vencida y cancelada gris.

## 8. Pruebas y criterios de aceptación

- **Base de datos:** `06_pruebas.sql` completo y en verde (sección 5.6).
- **API:** un archivo `api/pruebas.http` con una petición por endpoint y el flujo completo en orden. Sin paquetes de pruebas extra, salvo que el equipo lo pida.
- **Android:** lista de verificación manual en `docs/pruebas-android.md` con el recorrido completo.
- **Recorrido de demostración** que debe funcionar de principio a fin:
  1. El administrador inicia sesión y deja activos los oficios y zonas.
  2. Se registra un cliente y un trabajador (el trabajador con un DUI válido; un DUI inválido es rechazado).
  3. El cliente publica una solicitud en su colonia.
  4. El trabajador la ve en su lista, sin teléfono ni dirección, y envía una propuesta.
  5. Un segundo trabajador envía otra propuesta.
  6. El cliente ve las propuestas y acepta una. La otra queda rechazada y su trabajador recibe aviso.
  7. Ambos ven el contacto del otro. Un tercer usuario no puede pedirlo.
  8. Se intercambian mensajes y se cargan al abrir la app.
  9. El trabajador marca en proceso, el cliente confirma que terminó y ambos se califican; el promedio cambia.
  10. El administrador suspende a un usuario y este ya no puede entrar.
  11. Una solicitud publicada hace más de 72 horas aparece como vencida.

## 9. Seguridad: lista de verificación

- Contraseñas con BCrypt; ninguna en texto plano ni en logs.
- JWT con clave fuera del repositorio; rutas protegidas por rol y por dueño del recurso.
- `dui`, `correo`, `telefono` y `direccion_exacta` solo en `/contacto` y en los endpoints de auditoría del administrador.
- Consultas siempre parametrizadas (nada de concatenar texto en SQL).
- Subida de fotos limitada por tipo y tamaño, con nombre generado.
- Usuarios suspendidos sin acceso.
- La app Android no guarda datos sensibles.

## 10. Orden de trabajo sugerido

Avanza por flujos completos (base, API y Android juntos) para poder probar de verdad después de cada paso.

1. **Estructura:** repositorio, `.gitignore`, README con instalación en Windows 10 (PostgreSQL 16, SDK de .NET, Android Studio), `docs/`.
2. **Base:** `01_esquema.sql`, `02_catalogos.sql` y `fn_validar_dui`, con sus pruebas.
3. **Cuentas:** registro, login, catálogos, perfil, zona y oficios. API y Android (`LoginActivity`, `RegistroActivity`, `PerfilActivity`).
4. **Solicitudes y propuestas:** publicar, trabajos por zona, enviar propuesta, aceptar y rechazar (con `fn_aceptar_oferta` y sus pruebas). API y Android de cliente y trabajador.
5. **Seguimiento:** estados, contacto, calificaciones, promedio, vencimiento y bitácora.
6. **Mensajes y avisos:** triggers, sincronización al abrir, conversación.
7. **Administración:** catálogos, usuarios, reportes.
8. **Cierre:** recorrido de demostración completo, `docs/api.md` al día, README y revisión de la lista de seguridad.

## 11. Decisiones tomadas y puntos por confirmar con el equipo

Tomadas aquí por simplicidad; cámbialas solo si el equipo lo pide:

- El comentario de la calificación es obligatorio (así lo dicen el Avance y la Propuesta, aunque el boceto de EV1 lo mostraba como opcional).
- Un trabajador puede reenviar propuesta a una solicitud si antes la retiró; no puede tener dos propuestas activas.
- Al cancelarse o vencerse una solicitud, sus propuestas pendientes pasan a rechazadas.
- Solo el cliente confirma que el trabajo terminó.

Por confirmar:

- El algoritmo del dígito verificador del DUI (ver 5.4) con DUI reales de prueba.
- Si el estado `suspendido` se comprueba en cada petición o solo al iniciar sesión.
- El Avance (EV2) y el documento de Perfil, Funcionalidades y Aspecto mencionan Retrofit y Gson; en este plan la app Android no los usa. Hay que actualizar esos documentos si el código se queda sin esas librerías.
