-- 05_vistas.sql
-- Vistas de lectura. Idempotente (CREATE OR REPLACE VIEW).
-- Ninguna vista expone dirección exacta, teléfono, correo ni DUI.

-- Solicitudes con su zona general y los nombres de las partes. La usa fn_detalle_solicitud.
CREATE OR REPLACE VIEW vw_solicitudes_publicas AS
SELECT s.id,
       s.cliente_id,
       cl.nombre                         AS cliente_nombre,
       s.oficio_id,
       o.nombre                          AS oficio,
       s.colonia_id,
       c.nombre                          AS colonia,
       m.id                              AS municipio_id,
       m.nombre                          AS municipio,
       d.nombre                          AS departamento,
       m.nombre || ', Col. ' || c.nombre AS zona,
       s.titulo,
       s.descripcion,
       s.presupuesto,
       s.estado,
       s.trabajador_id,
       tr.nombre                         AS trabajador_nombre,
       s.fecha_publicacion,
       s.fecha_asignacion
  FROM solicitudes s
  JOIN usuarios cl ON cl.id = s.cliente_id
  JOIN oficios o ON o.id = s.oficio_id
  JOIN colonias c ON c.id = s.colonia_id
  JOIN municipios m ON m.id = c.municipio_id
  JOIN departamentos d ON d.id = m.departamento_id
  LEFT JOIN usuarios tr ON tr.id = s.trabajador_id
 WHERE NOT s.eliminado;

-- La API solo lee las vistas. 01_esquema.sql da INSERT y UPDATE en "todas las tablas", que en una segunda
-- corrida incluye esta vista; se quitan aquí.
REVOKE INSERT, UPDATE ON vw_solicitudes_publicas FROM gtr_api;
GRANT SELECT ON vw_solicitudes_publicas TO gtr_api;

-- Resumen para el administrador, en una sola fila: solicitudes por estado, calificaciones y cuentas.
CREATE OR REPLACE VIEW vw_reporte_resumen AS
SELECT s.total_solicitudes, s.publicadas, s.asignadas, s.en_proceso, s.finalizadas, s.canceladas, s.vencidas,
       k.total_calificaciones, k.promedio_general,
       u.clientes, u.trabajadores, u.suspendidos
  FROM (SELECT count(*)::int                                            AS total_solicitudes,
               (count(*) FILTER (WHERE estado = 'publicada'))::int     AS publicadas,
               (count(*) FILTER (WHERE estado = 'asignada'))::int      AS asignadas,
               (count(*) FILTER (WHERE estado = 'en_proceso'))::int    AS en_proceso,
               (count(*) FILTER (WHERE estado = 'finalizada'))::int    AS finalizadas,
               (count(*) FILTER (WHERE estado = 'cancelada'))::int     AS canceladas,
               (count(*) FILTER (WHERE estado = 'vencida'))::int       AS vencidas
          FROM solicitudes
         WHERE NOT eliminado) AS s
 CROSS JOIN
       (SELECT count(*)::int                               AS total_calificaciones,
               COALESCE(avg(estrellas), 0)::numeric(3,2)   AS promedio_general
          FROM calificaciones) AS k
 CROSS JOIN
       (SELECT (count(*) FILTER (WHERE rol = 'cliente'))::int          AS clientes,
               (count(*) FILTER (WHERE rol = 'trabajador'))::int       AS trabajadores,
               (count(*) FILTER (WHERE estado = 'suspendido'))::int    AS suspendidos
          FROM usuarios
         WHERE NOT eliminado) AS u;

REVOKE INSERT, UPDATE ON vw_reporte_resumen FROM gtr_api;
GRANT SELECT ON vw_reporte_resumen TO gtr_api;
