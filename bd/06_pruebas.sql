-- 06_pruebas.sql
-- Pruebas de la base. Cada una muestra OK o FALLO con RAISE NOTICE y al final hay un resumen.
-- Todo corre dentro de una transacción que se revierte, así que no deja datos.
-- Requiere 01 a 03 aplicados. Desde la raíz del repositorio:  .\bd\aplicar.ps1 -Pruebas
-- Los datos de prueba son inventados (correos example.com, teléfonos 7000-XXXX, DUI generados por fórmula).

\set ON_ERROR_STOP on

BEGIN;

CREATE TEMP TABLE resultados (nombre text NOT NULL, ok boolean NOT NULL);
CREATE TEMP TABLE contexto (clave text PRIMARY KEY, id integer NOT NULL);

CREATE FUNCTION pg_temp.verificar(p_nombre text, p_ok boolean) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO resultados VALUES (p_nombre, COALESCE(p_ok, false));
    RAISE NOTICE '% - %', CASE WHEN COALESCE(p_ok, false) THEN 'OK   ' ELSE 'FALLO' END, p_nombre;
END $$;

-- Ejecuta p_sql y compara con lo esperado: un SQLSTATE, o 'ok' si no debe fallar.
CREATE FUNCTION pg_temp.espera(p_nombre text, p_sql text, p_esperado text) RETURNS void
LANGUAGE plpgsql AS $$
DECLARE
    v_obtenido text := 'ok';
BEGIN
    BEGIN
        EXECUTE p_sql;
    EXCEPTION WHEN OTHERS THEN
        v_obtenido := SQLSTATE;
    END;
    PERFORM pg_temp.verificar(
        CASE WHEN v_obtenido = p_esperado THEN p_nombre
             ELSE p_nombre || ' [esperado ' || p_esperado || ', obtenido ' || v_obtenido || ']' END,
        v_obtenido = p_esperado);
END $$;

CREATE FUNCTION pg_temp.ctx(p_clave text) RETURNS integer
LANGUAGE sql STABLE AS $$ SELECT id FROM contexto WHERE clave = p_clave $$;

-- Datos base para las pruebas del esquema
DO $$
DECLARE
    v_mejicanos  int := (SELECT id FROM municipios WHERE nombre = 'Mejicanos');
    v_zacamil    int := (SELECT id FROM colonias WHERE nombre = 'Zacamil');
    v_escalon    int := (SELECT id FROM colonias WHERE nombre = 'Escalón');
    v_oficio     int := (SELECT id FROM oficios WHERE nombre = 'Electricidad');
    v_cliente    int;
    v_trabajador int;
    v_solicitud  int;
BEGIN
    IF v_mejicanos IS NULL OR v_zacamil IS NULL OR v_escalon IS NULL OR v_oficio IS NULL THEN
        RAISE EXCEPTION 'Faltan los catálogos de ejemplo: corre 02_catalogos.sql';
    END IF;

    INSERT INTO usuarios (rol, nombre, correo, password_hash, telefono, municipio_id, colonia_id)
    VALUES ('cliente', 'Cliente de prueba', 'cliente.prueba@example.com', 'hash-de-prueba', '7000-0001', v_mejicanos, v_zacamil)
    RETURNING id INTO v_cliente;

    INSERT INTO usuarios (rol, nombre, correo, password_hash, telefono, dui, municipio_id)
    VALUES ('trabajador', 'Trabajador de prueba', 'trabajador.prueba@example.com', 'hash-de-prueba', '7000-0002', '01234567-8', v_mejicanos)
    RETURNING id INTO v_trabajador;

    INSERT INTO solicitudes (cliente_id, oficio_id, colonia_id, titulo, descripcion, presupuesto, direccion_exacta)
    VALUES (v_cliente, v_oficio, v_zacamil, 'Solicitud de prueba', 'Descripción de prueba', 40.00, 'Dirección inventada, casa 1')
    RETURNING id INTO v_solicitud;

    INSERT INTO contexto VALUES
        ('mejicanos', v_mejicanos), ('zacamil', v_zacamil), ('escalon', v_escalon), ('oficio', v_oficio),
        ('cliente', v_cliente), ('trabajador', v_trabajador), ('solicitud', v_solicitud);
END $$;

-- fn_validar_dui
DO $$
BEGIN
    PERFORM pg_temp.verificar('DUI válido pasa',                         fn_validar_dui('01234567-8'));
    PERFORM pg_temp.verificar('Otro DUI válido pasa',                    fn_validar_dui('12345678-4'));
    PERFORM pg_temp.verificar('DUI válido con verificador 0 pasa',       fn_validar_dui('00000005-0'));
    PERFORM pg_temp.verificar('DUI con dígito verificador incorrecto falla', NOT fn_validar_dui('01234567-9'));
    PERFORM pg_temp.verificar('DUI sin guion falla',                     NOT fn_validar_dui('012345678'));
    PERFORM pg_temp.verificar('DUI con menos de 8 dígitos falla',        NOT fn_validar_dui('1234567-8'));
    PERFORM pg_temp.verificar('DUI con letras falla',                    NOT fn_validar_dui('abcdefgh-1'));
    PERFORM pg_temp.verificar('DUI con espacio al inicio falla',         NOT fn_validar_dui(' 01234567-8'));
    PERFORM pg_temp.verificar('DUI 00000000-0 falla',                    NOT fn_validar_dui('00000000-0'));
    PERFORM pg_temp.verificar('DUI nulo falla',                          NOT fn_validar_dui(NULL));
END $$;

-- Restricciones de usuarios
DO $$
BEGIN
    PERFORM pg_temp.espera('Cliente sin colonia falla', $q$
        INSERT INTO usuarios (rol, nombre, correo, password_hash, telefono, municipio_id)
        VALUES ('cliente', 'X', 'u01@example.com', 'h', '7000-0010', pg_temp.ctx('mejicanos'))
    $q$, '23514');

    PERFORM pg_temp.espera('Cliente sin teléfono falla', $q$
        INSERT INTO usuarios (rol, nombre, correo, password_hash, municipio_id, colonia_id)
        VALUES ('cliente', 'X', 'u02@example.com', 'h', pg_temp.ctx('mejicanos'), pg_temp.ctx('zacamil'))
    $q$, '23514');

    PERFORM pg_temp.espera('Teléfono con formato malo falla', $q$
        INSERT INTO usuarios (rol, nombre, correo, password_hash, telefono, municipio_id, colonia_id)
        VALUES ('cliente', 'X', 'u03@example.com', 'h', '70000000', pg_temp.ctx('mejicanos'), pg_temp.ctx('zacamil'))
    $q$, '23514');

    PERFORM pg_temp.espera('Trabajador sin DUI falla', $q$
        INSERT INTO usuarios (rol, nombre, correo, password_hash, telefono, municipio_id)
        VALUES ('trabajador', 'X', 'u04@example.com', 'h', '7000-0011', pg_temp.ctx('mejicanos'))
    $q$, '23514');

    PERFORM pg_temp.espera('Rol inválido falla', $q$
        INSERT INTO usuarios (rol, nombre, correo, password_hash)
        VALUES ('jefe', 'X', 'u05@example.com', 'h')
    $q$, '23514');

    PERFORM pg_temp.espera('Correo mal formado falla', $q$
        INSERT INTO usuarios (rol, nombre, correo, password_hash)
        VALUES ('administrador', 'X', 'sin-arroba', 'h')
    $q$, '23514');

    PERFORM pg_temp.espera('Correo repetido con otras mayúsculas falla', $q$
        INSERT INTO usuarios (rol, nombre, correo, password_hash, telefono, municipio_id, colonia_id)
        VALUES ('cliente', 'X', 'CLIENTE.PRUEBA@example.com', 'h', '7000-0012', pg_temp.ctx('mejicanos'), pg_temp.ctx('zacamil'))
    $q$, '23505');

    PERFORM pg_temp.espera('DUI repetido falla', $q$
        INSERT INTO usuarios (rol, nombre, correo, password_hash, telefono, dui, municipio_id)
        VALUES ('trabajador', 'X', 'u06@example.com', 'h', '7000-0013', '01234567-8', pg_temp.ctx('mejicanos'))
    $q$, '23505');

    PERFORM pg_temp.espera('Colonia de otro municipio falla', $q$
        INSERT INTO usuarios (rol, nombre, correo, password_hash, telefono, municipio_id, colonia_id)
        VALUES ('cliente', 'X', 'u07@example.com', 'h', '7000-0014', pg_temp.ctx('mejicanos'), pg_temp.ctx('escalon'))
    $q$, '23503');

    PERFORM pg_temp.espera('Administrador sin zona ni teléfono es válido', $q$
        INSERT INTO usuarios (rol, nombre, correo, password_hash)
        VALUES ('administrador', 'Administrador de prueba', 'admin.prueba@example.com', 'h')
    $q$, 'ok');
END $$;

-- Restricciones de solicitudes
DO $$
BEGIN
    PERFORM pg_temp.espera('Solicitud asignada sin trabajador falla', $q$
        INSERT INTO solicitudes (cliente_id, oficio_id, colonia_id, titulo, descripcion, presupuesto, direccion_exacta, estado)
        VALUES (pg_temp.ctx('cliente'), pg_temp.ctx('oficio'), pg_temp.ctx('zacamil'), 'T', 'D', 10, 'Dir', 'asignada')
    $q$, '23514');

    PERFORM pg_temp.espera('Solicitud con presupuesto 0 falla', $q$
        INSERT INTO solicitudes (cliente_id, oficio_id, colonia_id, titulo, descripcion, presupuesto, direccion_exacta)
        VALUES (pg_temp.ctx('cliente'), pg_temp.ctx('oficio'), pg_temp.ctx('zacamil'), 'T', 'D', 0, 'Dir')
    $q$, '23514');

    PERFORM pg_temp.espera('Solicitud con estado inventado falla', $q$
        INSERT INTO solicitudes (cliente_id, oficio_id, colonia_id, titulo, descripcion, presupuesto, direccion_exacta, estado)
        VALUES (pg_temp.ctx('cliente'), pg_temp.ctx('oficio'), pg_temp.ctx('zacamil'), 'T', 'D', 10, 'Dir', 'perdida')
    $q$, '23514');

    PERFORM pg_temp.espera('Solicitud asignada con trabajador y fecha es válida', $q$
        INSERT INTO solicitudes (cliente_id, oficio_id, colonia_id, titulo, descripcion, presupuesto, direccion_exacta,
                                 estado, trabajador_id, fecha_asignacion)
        VALUES (pg_temp.ctx('cliente'), pg_temp.ctx('oficio'), pg_temp.ctx('zacamil'), 'T', 'D', 10, 'Dir',
                'asignada', pg_temp.ctx('trabajador'), now())
    $q$, 'ok');
END $$;

-- Restricciones de propuestas
DO $$
BEGIN
    PERFORM pg_temp.espera('Propuesta pendiente es válida', $q$
        INSERT INTO ofertas (solicitud_id, trabajador_id, precio)
        VALUES (pg_temp.ctx('solicitud'), pg_temp.ctx('trabajador'), 35.00)
    $q$, 'ok');

    PERFORM pg_temp.espera('Segunda propuesta activa del mismo trabajador falla', $q$
        INSERT INTO ofertas (solicitud_id, trabajador_id, precio)
        VALUES (pg_temp.ctx('solicitud'), pg_temp.ctx('trabajador'), 30.00)
    $q$, '23505');

    PERFORM pg_temp.espera('Propuesta con precio 0 falla', $q$
        INSERT INTO ofertas (solicitud_id, trabajador_id, precio)
        VALUES (pg_temp.ctx('solicitud'), pg_temp.ctx('trabajador'), 0)
    $q$, '23514');

    UPDATE ofertas SET estado = 'retirada'
     WHERE solicitud_id = pg_temp.ctx('solicitud') AND trabajador_id = pg_temp.ctx('trabajador');

    PERFORM pg_temp.espera('Tras retirar, el trabajador puede enviar otra propuesta', $q$
        INSERT INTO ofertas (solicitud_id, trabajador_id, precio)
        VALUES (pg_temp.ctx('solicitud'), pg_temp.ctx('trabajador'), 30.00)
    $q$, 'ok');
END $$;

-- Restricciones de calificaciones y mensajes
DO $$
BEGIN
    PERFORM pg_temp.espera('Calificación de 6 estrellas falla', $q$
        INSERT INTO calificaciones (solicitud_id, calificador_id, calificado_id, estrellas, comentario)
        VALUES (pg_temp.ctx('solicitud'), pg_temp.ctx('cliente'), pg_temp.ctx('trabajador'), 6, 'Comentario')
    $q$, '23514');

    PERFORM pg_temp.espera('Calificación de 0 estrellas falla', $q$
        INSERT INTO calificaciones (solicitud_id, calificador_id, calificado_id, estrellas, comentario)
        VALUES (pg_temp.ctx('solicitud'), pg_temp.ctx('cliente'), pg_temp.ctx('trabajador'), 0, 'Comentario')
    $q$, '23514');

    PERFORM pg_temp.espera('Calificación sin comentario falla', $q$
        INSERT INTO calificaciones (solicitud_id, calificador_id, calificado_id, estrellas, comentario)
        VALUES (pg_temp.ctx('solicitud'), pg_temp.ctx('cliente'), pg_temp.ctx('trabajador'), 5, '   ')
    $q$, '23514');

    PERFORM pg_temp.espera('Calificarse a sí mismo falla', $q$
        INSERT INTO calificaciones (solicitud_id, calificador_id, calificado_id, estrellas, comentario)
        VALUES (pg_temp.ctx('solicitud'), pg_temp.ctx('cliente'), pg_temp.ctx('cliente'), 5, 'Comentario')
    $q$, '23514');

    PERFORM pg_temp.espera('Calificación válida se inserta', $q$
        INSERT INTO calificaciones (solicitud_id, calificador_id, calificado_id, estrellas, comentario)
        VALUES (pg_temp.ctx('solicitud'), pg_temp.ctx('cliente'), pg_temp.ctx('trabajador'), 5, 'Buen trabajo (comentario de prueba)')
    $q$, 'ok');

    PERFORM pg_temp.espera('Calificar dos veces la misma solicitud falla', $q$
        INSERT INTO calificaciones (solicitud_id, calificador_id, calificado_id, estrellas, comentario)
        VALUES (pg_temp.ctx('solicitud'), pg_temp.ctx('cliente'), pg_temp.ctx('trabajador'), 4, 'Otra vez')
    $q$, '23505');

    PERFORM pg_temp.espera('Mensaje vacío falla', $q$
        INSERT INTO mensajes (solicitud_id, emisor_id, receptor_id, texto)
        VALUES (pg_temp.ctx('solicitud'), pg_temp.ctx('cliente'), pg_temp.ctx('trabajador'), '  ')
    $q$, '23514');

    PERFORM pg_temp.espera('Mensaje a uno mismo falla', $q$
        INSERT INTO mensajes (solicitud_id, emisor_id, receptor_id, texto)
        VALUES (pg_temp.ctx('solicitud'), pg_temp.ctx('cliente'), pg_temp.ctx('cliente'), 'Hola')
    $q$, '23514');
END $$;

-- Permisos del rol de la API
DO $$
BEGIN
    PERFORM pg_temp.verificar('gtr_api no es superusuario',
        NOT (SELECT rolsuper FROM pg_roles WHERE rolname = 'gtr_api'));
    PERFORM pg_temp.verificar('gtr_api no crea bases ni roles',
        NOT (SELECT rolcreatedb OR rolcreaterole FROM pg_roles WHERE rolname = 'gtr_api'));
    PERFORM pg_temp.verificar('gtr_api no crea objetos en public',
        NOT has_schema_privilege('gtr_api', 'public', 'CREATE'));
    PERFORM pg_temp.verificar('gtr_api puede insertar solicitudes',
        has_table_privilege('gtr_api', 'solicitudes', 'INSERT'));
    PERFORM pg_temp.verificar('gtr_api no puede borrar solicitudes',
        NOT has_table_privilege('gtr_api', 'solicitudes', 'DELETE'));
    PERFORM pg_temp.verificar('gtr_api puede reemplazar los oficios de un trabajador',
        has_table_privilege('gtr_api', 'usuario_oficio', 'DELETE'));
END $$;

-- Resumen
DO $$
DECLARE
    v_total  int;
    v_fallos int;
BEGIN
    SELECT count(*), count(*) FILTER (WHERE NOT ok) INTO v_total, v_fallos FROM resultados;
    RAISE NOTICE 'Resumen: % pruebas, % con fallo', v_total, v_fallos;
    IF v_fallos > 0 THEN
        RAISE EXCEPTION 'Hay pruebas con fallo';
    END IF;
END $$;

ROLLBACK;

-- Pendientes, se agregan en su tanda (ver docs/plan.md): registro de trabajador con DUI inválido,
-- aceptar propuesta (GT001, GT002, GT003), contacto, calificar con promedio y vencimiento de solicitudes.
