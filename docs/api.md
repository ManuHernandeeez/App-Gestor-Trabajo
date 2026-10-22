# API

Tabla de endpoints. Se mantiene al día en cada tanda: al implementar un endpoint se cambia su estado y,
si es importante, se agrega un ejemplo de JSON.

## Convenciones

- Prefijo `/api`. Todo requiere `Authorization: Bearer <token>` salvo lo marcado como público.
- Error: `{ "codigo": "GT001", "mensaje": "..." }`. `GT001` responde 409, `GT002` 404, `GT003` 403; cualquier otro error, 500 sin detalles.
- Fechas en ISO 8601 con zona horaria; la app las muestra en hora local.
- Dinero en dólares con dos decimales.
- `dui`, `correo`, `telefono` y `direccion_exacta` solo salen en `GET /solicitudes/{id}/contacto` y en la auditoría del administrador.

## Endpoints

| Método y ruta | Rol | Qué hace | Estado |
|---|---|---|---|
| `POST /auth/registro` | público | Crea cliente o trabajador | Pendiente |
| `POST /auth/login` | público | Devuelve `{ token, rol, usuarioId, nombre }` | Pendiente |
| `GET /catalogos/departamentos` | público | Lista activos | Pendiente |
| `GET /catalogos/departamentos/{id}/municipios` | público | Lista activos | Pendiente |
| `GET /catalogos/municipios/{id}/colonias` | público | Lista activas | Pendiente |
| `GET /catalogos/oficios` | público | Lista activos | Pendiente |
| `GET /perfil` | cliente, trabajador | Perfil propio con promedio | Pendiente |
| `PUT /perfil` | cliente, trabajador | Actualiza nombre, teléfono y zona | Pendiente |
| `POST /perfil/foto` | cliente, trabajador | Multipart, jpg o png, máximo 2 MB, nombre GUID | Pendiente |
| `PUT /perfil/oficios` | trabajador | Reemplaza oficios | Pendiente |
| `PUT /perfil/colonias` | trabajador | Reemplaza colonias de trabajo | Pendiente |
| `POST /solicitudes` | cliente | Publica solicitud | Pendiente |
| `GET /solicitudes/mias?estado=` | cliente | Lista propias con conteo de propuestas | Pendiente |
| `GET /solicitudes/{id}` | cliente, trabajador | Detalle sin datos sensibles | Pendiente |
| `PUT /solicitudes/{id}/cancelar` | cliente | Cancela | Pendiente |
| `PUT /solicitudes/{id}/finalizar` | cliente | Confirma que terminó | Pendiente |
| `GET /solicitudes/{id}/propuestas` | cliente | Propuestas con precio y promedio del trabajador | Pendiente |
| `POST /propuestas/{id}/aceptar` | cliente | Llama a `fn_aceptar_oferta` | Pendiente |
| `POST /propuestas/{id}/rechazar` | cliente | Rechaza | Pendiente |
| `GET /trabajos/zona?oficioId=` | trabajador | Llama a `fn_trabajos_por_zona` | Pendiente |
| `POST /trabajos/{solicitudId}/propuestas` | trabajador | Envía propuesta | Pendiente |
| `GET /propuestas/mias?estado=` | trabajador | Lista propias | Pendiente |
| `PUT /propuestas/{id}/retirar` | trabajador | Solo si está `pendiente` | Pendiente |
| `PUT /trabajos/{solicitudId}/en-proceso` | trabajador | Marca en proceso | Pendiente |
| `GET /solicitudes/{id}/contacto` | cliente, trabajador | Contacto de la otra parte | Pendiente |
| `POST /solicitudes/{id}/calificaciones` | cliente, trabajador | Califica a la otra parte | Pendiente |
| `GET /usuarios/{id}/reputacion` | cliente, trabajador | Promedio y últimas calificaciones | Pendiente |
| `GET /solicitudes/{id}/mensajes?desde=` | cliente, trabajador | Mensajes del trabajo | Pendiente |
| `POST /solicitudes/{id}/mensajes` | cliente, trabajador | Envía mensaje (solo con trabajador asignado) | Pendiente |
| `GET /conversaciones` | cliente, trabajador | Trabajos con trabajador asignado y último mensaje | Pendiente |
| `GET /sincronizacion?desde=` | cliente, trabajador | Mensajes y avisos nuevos | Pendiente |
| `PUT /avisos/leidos` | cliente, trabajador | Marca avisos como leídos | Pendiente |
| `GET, POST, PUT /admin/oficios` (y `/admin/departamentos`, `/admin/municipios`, `/admin/colonias`) | administrador | Crear, editar, activar o desactivar | Pendiente |
| `GET /admin/usuarios?q=` | administrador | Búsqueda por nombre o correo | Pendiente |
| `PUT /admin/usuarios/{id}/suspender` y `/reactivar` | administrador | Suspende o reactiva | Pendiente |
| `GET /admin/usuarios/{id}/auditoria` | administrador | DUI, teléfono y correo | Pendiente |
| `GET /admin/reportes/resumen` | administrador | Totales por estado y promedio general | Pendiente |

## Ejemplos

Login:

```json
{ "token": "eyJ...", "rol": "trabajador", "usuarioId": 7, "nombre": "Luis Hernández" }
```

Un trabajo de la zona (sin teléfono ni dirección):

```json
{ "id": 21, "titulo": "Cambio de tomacorrientes", "oficio": "Electricidad",
  "presupuesto": 40.00, "zona": "Mejicanos, Col. Zacamil",
  "clienteNombre": "María R.", "publicadaHaceHoras": 2, "yaPropuse": false }
```
