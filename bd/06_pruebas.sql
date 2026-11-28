-- 06_pruebas.sql
-- Pruebas de la base. Cada una muestra OK o FALLO con RAISE NOTICE y al final hay un resumen.
-- Todo corre dentro de una transacción que se revierte, así que no deja datos.
-- Requiere 01 a 05 aplicados. Desde la raíz del repositorio:  .\bd\aplicar.ps1 -Pruebas
-- Se corre como postgres: una sección cambia a gtr_api (SET ROLE) para probar sus permisos.
-- Los datos de prueba son inventados (correos example.com, teléfonos 7000-XXXX, DUI generados por fórmula).
-- Se pueden correr con datos ya cargados en la base, siempre que no existan estos correos ni estos DUI:
-- 01234567-8, 55555555-0, 23456789-0, 11111111-6, 22222222-2, 33333333-8 y 44444444-4.
-- Las cuentas de ejemplo de api/pruebas.http usan otros (por ejemplo 12345678-4).

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

-- fn_registrar_usuario y fn_asegurar_administrador
DO $$
DECLARE
    v_id int;
BEGIN
    v_id := fn_registrar_usuario('cliente', 'Cliente nuevo', 'cliente.nuevo@example.com', 'hash-de-prueba',
                                 '7000-0101', NULL, pg_temp.ctx('mejicanos'), pg_temp.ctx('zacamil'), NULL, NULL);
    PERFORM pg_temp.verificar('Registrar cliente válido crea el usuario',
        EXISTS (SELECT 1 FROM usuarios WHERE id = v_id AND rol = 'cliente' AND estado = 'activo' AND dui IS NULL));

    v_id := fn_registrar_usuario('trabajador', 'Trabajador nuevo', 'trabajador.nuevo@example.com', 'hash-de-prueba',
                                 '7000-0102', '55555555-0', pg_temp.ctx('mejicanos'), NULL,
                                 ARRAY[pg_temp.ctx('oficio')],
                                 ARRAY[pg_temp.ctx('zacamil'), (SELECT id FROM colonias WHERE nombre = 'Lourdes')]);
    PERFORM pg_temp.verificar('Registrar trabajador válido guarda DUI, oficios y colonias',
        EXISTS (SELECT 1 FROM usuarios WHERE id = v_id AND rol = 'trabajador' AND dui = '55555555-0')
        AND (SELECT count(*) FROM usuario_oficio WHERE usuario_id = v_id) = 1
        AND (SELECT count(*) FROM trabajador_colonia WHERE usuario_id = v_id) = 2);

    PERFORM pg_temp.espera('Trabajador con DUI inválido falla', $q$
        SELECT fn_registrar_usuario('trabajador', 'X', 'dui.malo@example.com', 'h', '7000-0103', '12345678-9',
               pg_temp.ctx('mejicanos'), NULL, ARRAY[pg_temp.ctx('oficio')], ARRAY[pg_temp.ctx('zacamil')])
    $q$, 'GT001');
    PERFORM pg_temp.verificar('Trabajador con DUI inválido no inserta nada',
        NOT EXISTS (SELECT 1 FROM usuarios WHERE correo = 'dui.malo@example.com'));

    PERFORM pg_temp.espera('DUI repetido falla', $q$
        SELECT fn_registrar_usuario('trabajador', 'X', 'dui.repetido@example.com', 'h', '7000-0104', '55555555-0',
               pg_temp.ctx('mejicanos'), NULL, ARRAY[pg_temp.ctx('oficio')], ARRAY[pg_temp.ctx('zacamil')])
    $q$, 'GT001');

    PERFORM pg_temp.espera('Correo repetido con otras mayúsculas falla', $q$
        SELECT fn_registrar_usuario('cliente', 'X', 'CLIENTE.NUEVO@example.com', 'h', '7000-0105', NULL,
               pg_temp.ctx('mejicanos'), pg_temp.ctx('zacamil'), NULL, NULL)
    $q$, 'GT001');

    PERFORM pg_temp.espera('Cliente sin colonia falla', $q$
        SELECT fn_registrar_usuario('cliente', 'X', 'sin.colonia@example.com', 'h', '7000-0106', NULL,
               pg_temp.ctx('mejicanos'), NULL, NULL, NULL)
    $q$, 'GT001');

    PERFORM pg_temp.espera('Cliente con colonia de otro municipio falla', $q$
        SELECT fn_registrar_usuario('cliente', 'X', 'otra.colonia@example.com', 'h', '7000-0107', NULL,
               pg_temp.ctx('mejicanos'), pg_temp.ctx('escalon'), NULL, NULL)
    $q$, 'GT001');

    PERFORM pg_temp.espera('Teléfono con formato malo falla', $q$
        SELECT fn_registrar_usuario('cliente', 'X', 'tel.malo@example.com', 'h', '70000108', NULL,
               pg_temp.ctx('mejicanos'), pg_temp.ctx('zacamil'), NULL, NULL)
    $q$, 'GT001');

    PERFORM pg_temp.espera('No se puede registrar un administrador por esta vía', $q$
        SELECT fn_registrar_usuario('administrador', 'X', 'admin.falso@example.com', 'h', NULL, NULL,
               NULL, NULL, NULL, NULL)
    $q$, 'GT001');

    PERFORM pg_temp.espera('Trabajador sin oficios falla', $q$
        SELECT fn_registrar_usuario('trabajador', 'X', 'sin.oficios@example.com', 'h', '7000-0109', '00000005-0',
               pg_temp.ctx('mejicanos'), NULL, NULL, ARRAY[pg_temp.ctx('zacamil')])
    $q$, 'GT001');
    PERFORM pg_temp.verificar('Trabajador sin oficios no deja un usuario a medias',
        NOT EXISTS (SELECT 1 FROM usuarios WHERE correo = 'sin.oficios@example.com'));

    PERFORM pg_temp.espera('Trabajador con oficio inexistente falla', $q$
        SELECT fn_registrar_usuario('trabajador', 'X', 'oficio.falso@example.com', 'h', '7000-0110', '00000005-0',
               pg_temp.ctx('mejicanos'), NULL, ARRAY[-1], ARRAY[pg_temp.ctx('zacamil')])
    $q$, 'GT001');

    PERFORM pg_temp.espera('Trabajador con colonia de otro municipio falla', $q$
        SELECT fn_registrar_usuario('trabajador', 'X', 'colonia.ajena@example.com', 'h', '7000-0111', '00000005-0',
               pg_temp.ctx('mejicanos'), NULL, ARRAY[pg_temp.ctx('oficio')], ARRAY[pg_temp.ctx('escalon')])
    $q$, 'GT001');

    PERFORM pg_temp.verificar('Crear el administrador semilla devuelve true',
        fn_asegurar_administrador('Administrador de prueba', 'admin.semilla@example.com', 'hash-de-prueba'));
    PERFORM pg_temp.verificar('Crear el administrador semilla otra vez devuelve false',
        NOT fn_asegurar_administrador('Administrador de prueba', 'ADMIN.SEMILLA@example.com', 'otro-hash'));
    PERFORM pg_temp.verificar('El administrador semilla conserva su contraseña original',
        (SELECT password_hash FROM usuarios WHERE lower(correo) = 'admin.semilla@example.com') = 'hash-de-prueba');
END $$;

-- Flujo de solicitudes y propuestas: publicar, trabajos por zona, enviar, retirar, rechazar y aceptar.
-- Los DUI de ejemplo se generaron con la fórmula; los datos de las cuentas son inventados.
DO $$
DECLARE
    v_mej      int := pg_temp.ctx('mejicanos');
    v_zac      int := pg_temp.ctx('zacamil');
    v_esc      int := pg_temp.ctx('escalon');
    v_lourdes  int := (SELECT id FROM colonias WHERE nombre = 'Lourdes' AND municipio_id = pg_temp.ctx('mejicanos'));
    v_mun_ss   int := (SELECT municipio_id FROM colonias WHERE id = pg_temp.ctx('escalon'));
    v_elec     int := pg_temp.ctx('oficio');
    v_pintura  int := (SELECT id FROM oficios WHERE nombre = 'Pintura');
    v_cl1 int; v_cl2 int; v_tr1 int; v_tr2 int; v_tr3 int; v_tr4 int; v_tr5 int;
    v_s1 int; v_s2 int; v_o1 int; v_o2 int; v_o3 int; v_o4 int; v_reenviada int;
BEGIN
    v_cl1 := fn_registrar_usuario('cliente', 'Carlos Ejemplo', 'flujo.cliente1@example.com', 'h', '7000-0301', NULL, v_mej, v_zac, NULL, NULL);
    v_cl2 := fn_registrar_usuario('cliente', 'Diana Ejemplo', 'flujo.cliente2@example.com', 'h', '7000-0302', NULL, v_mej, v_zac, NULL, NULL);
    -- tr1 y tr5 trabajan electricidad en Mejicanos; tr2 solo en Zacamil; tr3 hace otro oficio; tr4 trabaja en otro municipio
    v_tr1 := fn_registrar_usuario('trabajador', 'Luis Flujo', 'flujo.trabajador1@example.com', 'h', '7000-0311', '23456789-0', v_mej, NULL, ARRAY[v_elec], ARRAY[v_zac, v_lourdes]);
    v_tr2 := fn_registrar_usuario('trabajador', 'Pedro Flujo', 'flujo.trabajador2@example.com', 'h', '7000-0312', '11111111-6', v_mej, NULL, ARRAY[v_elec], ARRAY[v_zac]);
    v_tr3 := fn_registrar_usuario('trabajador', 'Mario Flujo', 'flujo.trabajador3@example.com', 'h', '7000-0313', '22222222-2', v_mej, NULL, ARRAY[v_pintura], ARRAY[v_zac]);
    v_tr4 := fn_registrar_usuario('trabajador', 'José Flujo', 'flujo.trabajador4@example.com', 'h', '7000-0314', '33333333-8', v_mun_ss, NULL, ARRAY[v_elec], ARRAY[v_esc]);
    v_tr5 := fn_registrar_usuario('trabajador', 'Raúl Flujo', 'flujo.trabajador5@example.com', 'h', '7000-0315', '44444444-4', v_mej, NULL, ARRAY[v_elec], ARRAY[v_zac]);
    INSERT INTO contexto VALUES ('cl1', v_cl1), ('cl2', v_cl2), ('tr1', v_tr1), ('tr2', v_tr2), ('tr3', v_tr3),
                                ('tr4', v_tr4), ('tr5', v_tr5), ('pintura', v_pintura);

    -- Publicar
    v_s1 := fn_publicar_solicitud(v_cl1, v_elec, v_zac, 'Cambio de tomacorrientes', 'Cuatro tomacorrientes (texto de prueba)', 40.00, 'Dirección inventada, casa 7');
    INSERT INTO contexto VALUES ('s1', v_s1);
    PERFORM pg_temp.verificar('Publicar crea la solicitud en estado publicada',
        EXISTS (SELECT 1 FROM solicitudes WHERE id = v_s1 AND estado = 'publicada' AND cliente_id = v_cl1 AND trabajador_id IS NULL));
    PERFORM pg_temp.espera('Un trabajador no puede publicar', $q$
        SELECT fn_publicar_solicitud(pg_temp.ctx('tr1'), pg_temp.ctx('oficio'), pg_temp.ctx('zacamil'), 'T', 'D', 10, 'Dir')
    $q$, 'GT003');
    PERFORM pg_temp.espera('Publicar con presupuesto 0 falla con GT001', $q$
        SELECT fn_publicar_solicitud(pg_temp.ctx('cl1'), pg_temp.ctx('oficio'), pg_temp.ctx('zacamil'), 'T', 'D', 0, 'Dir')
    $q$, 'GT001');
    PERFORM pg_temp.espera('Publicar sin título falla con GT001', $q$
        SELECT fn_publicar_solicitud(pg_temp.ctx('cl1'), pg_temp.ctx('oficio'), pg_temp.ctx('zacamil'), '  ', 'D', 10, 'Dir')
    $q$, 'GT001');
    PERFORM pg_temp.espera('Publicar sin dirección falla con GT001', $q$
        SELECT fn_publicar_solicitud(pg_temp.ctx('cl1'), pg_temp.ctx('oficio'), pg_temp.ctx('zacamil'), 'T', 'D', 10, '')
    $q$, 'GT001');
    PERFORM pg_temp.espera('Publicar con oficio inexistente falla con GT001', $q$
        SELECT fn_publicar_solicitud(pg_temp.ctx('cl1'), -1, pg_temp.ctx('zacamil'), 'T', 'D', 10, 'Dir')
    $q$, 'GT001');
    PERFORM pg_temp.espera('Publicar con colonia inexistente falla con GT001', $q$
        SELECT fn_publicar_solicitud(pg_temp.ctx('cl1'), pg_temp.ctx('oficio'), -1, 'T', 'D', 10, 'Dir')
    $q$, 'GT001');

    -- Trabajos por zona
    PERFORM pg_temp.verificar('El trabajador de la zona y el oficio ve la solicitud',
        EXISTS (SELECT 1 FROM fn_trabajos_por_zona(v_tr1) z WHERE z.id = v_s1));
    PERFORM pg_temp.verificar('Otro trabajador de la colonia y el oficio también la ve',
        EXISTS (SELECT 1 FROM fn_trabajos_por_zona(v_tr2) z WHERE z.id = v_s1));
    PERFORM pg_temp.verificar('Un trabajador de otro oficio no la ve',
        NOT EXISTS (SELECT 1 FROM fn_trabajos_por_zona(v_tr3) z WHERE z.id = v_s1));
    PERFORM pg_temp.verificar('Un trabajador de otro municipio no la ve',
        NOT EXISTS (SELECT 1 FROM fn_trabajos_por_zona(v_tr4) z WHERE z.id = v_s1));
    PERFORM pg_temp.verificar('El filtro por oficio la incluye cuando coincide',
        EXISTS (SELECT 1 FROM fn_trabajos_por_zona(v_tr1, v_elec) z WHERE z.id = v_s1));
    PERFORM pg_temp.verificar('El filtro por otro oficio la excluye',
        NOT EXISTS (SELECT 1 FROM fn_trabajos_por_zona(v_tr1, v_pintura) z WHERE z.id = v_s1));
    PERFORM pg_temp.verificar('El nombre del cliente sale abreviado y la zona completa',
        EXISTS (SELECT 1 FROM fn_trabajos_por_zona(v_tr1) z
                 WHERE z.id = v_s1 AND z.cliente_nombre = 'Carlos E.' AND z.zona = 'Mejicanos, Col. Zacamil'
                   AND z.oficio = 'Electricidad' AND z.presupuesto = 40.00 AND z.publicada_hace_horas = 0));
    PERFORM pg_temp.verificar('La lista de trabajos no tiene columnas de teléfono ni de dirección',
        pg_get_function_result('fn_trabajos_por_zona(integer, integer)'::regprocedure) !~* 'telefono|direccion|correo|dui');
    PERFORM pg_temp.verificar('Antes de proponer, yaPropuse es falso',
        NOT (SELECT z.ya_propuse FROM fn_trabajos_por_zona(v_tr1) z WHERE z.id = v_s1));
    PERFORM pg_temp.espera('Un cliente no puede pedir trabajos por zona', $q$
        SELECT * FROM fn_trabajos_por_zona(pg_temp.ctx('cl1'))
    $q$, 'GT003');

    -- Enviar propuesta
    v_o1 := fn_enviar_oferta(v_tr1, v_s1, 35.00, 'Puedo ir mañana (texto de prueba)');
    INSERT INTO contexto VALUES ('o1', v_o1);
    PERFORM pg_temp.verificar('Enviar propuesta la deja pendiente con su precio',
        EXISTS (SELECT 1 FROM ofertas WHERE id = v_o1 AND estado = 'pendiente' AND precio = 35.00 AND trabajador_id = v_tr1));
    PERFORM pg_temp.verificar('Tras proponer, yaPropuse es verdadero',
        (SELECT z.ya_propuse FROM fn_trabajos_por_zona(v_tr1) z WHERE z.id = v_s1));
    PERFORM pg_temp.espera('Segunda propuesta activa falla con GT001', $q$
        SELECT fn_enviar_oferta(pg_temp.ctx('tr1'), pg_temp.ctx('s1'), 30, NULL)
    $q$, 'GT001');
    PERFORM pg_temp.espera('Proponer fuera de tus oficios falla con GT003', $q$
        SELECT fn_enviar_oferta(pg_temp.ctx('tr3'), pg_temp.ctx('s1'), 30, NULL)
    $q$, 'GT003');
    PERFORM pg_temp.espera('Proponer fuera de tu municipio falla con GT003', $q$
        SELECT fn_enviar_oferta(pg_temp.ctx('tr4'), pg_temp.ctx('s1'), 30, NULL)
    $q$, 'GT003');
    PERFORM pg_temp.espera('Un cliente no puede enviar propuestas', $q$
        SELECT fn_enviar_oferta(pg_temp.ctx('cl2'), pg_temp.ctx('s1'), 30, NULL)
    $q$, 'GT003');
    PERFORM pg_temp.espera('Proponer con precio 0 falla con GT001', $q$
        SELECT fn_enviar_oferta(pg_temp.ctx('tr2'), pg_temp.ctx('s1'), 0, NULL)
    $q$, 'GT001');
    PERFORM pg_temp.espera('Proponer con mensaje de 301 caracteres falla con GT001', $q$
        SELECT fn_enviar_oferta(pg_temp.ctx('tr2'), pg_temp.ctx('s1'), 30, repeat('x', 301))
    $q$, 'GT001');
    PERFORM pg_temp.espera('Proponer a una solicitud inexistente falla con GT002', $q$
        SELECT fn_enviar_oferta(pg_temp.ctx('tr2'), -1, 30, NULL)
    $q$, 'GT002');

    -- Retirar y reenviar
    PERFORM pg_temp.espera('Retirar la propuesta de otro trabajador falla con GT003', $q$
        SELECT fn_retirar_oferta(pg_temp.ctx('tr2'), pg_temp.ctx('o1'))
    $q$, 'GT003');
    PERFORM fn_retirar_oferta(v_tr1, v_o1);
    PERFORM pg_temp.verificar('Retirar deja la propuesta en retirada',
        EXISTS (SELECT 1 FROM ofertas WHERE id = v_o1 AND estado = 'retirada'));
    PERFORM pg_temp.verificar('Tras retirar, yaPropuse vuelve a ser falso',
        NOT (SELECT z.ya_propuse FROM fn_trabajos_por_zona(v_tr1) z WHERE z.id = v_s1));
    PERFORM pg_temp.espera('Retirar dos veces falla con GT001', $q$
        SELECT fn_retirar_oferta(pg_temp.ctx('tr1'), pg_temp.ctx('o1'))
    $q$, 'GT001');
    -- la función y la consulta van en sentencias separadas: una consulta no ve lo que cambia una función de su misma sentencia
    v_reenviada := fn_enviar_oferta(v_tr1, v_s1, 32.50, 'Mejor precio (texto de prueba)');
    PERFORM pg_temp.verificar('Reenviar tras retirar reactiva la misma propuesta', v_reenviada = v_o1);
    PERFORM pg_temp.verificar('La propuesta reactivada queda pendiente con el nuevo precio',
        EXISTS (SELECT 1 FROM ofertas WHERE id = v_o1 AND estado = 'pendiente' AND precio = 32.50));
    PERFORM pg_temp.verificar('Reactivar no duplica filas',
        (SELECT count(*) FROM ofertas WHERE solicitud_id = v_s1 AND trabajador_id = v_tr1) = 1);

    -- Rechazar
    v_o2 := fn_enviar_oferta(v_tr2, v_s1, 45.00, NULL);
    v_o3 := fn_enviar_oferta(v_tr5, v_s1, 38.00, NULL);
    INSERT INTO contexto VALUES ('o2', v_o2), ('o3', v_o3);
    PERFORM pg_temp.verificar('El dueño ve sus tres propuestas, con el promedio del trabajador',
        (SELECT count(*) FROM fn_propuestas_de_solicitud(v_cl1, v_s1)) = 3
        AND EXISTS (SELECT 1 FROM fn_propuestas_de_solicitud(v_cl1, v_s1) p
                     WHERE p.id = v_o1 AND p.trabajador_nombre = 'Luis Flujo' AND p.promedio_calificacion = 0 AND p.precio = 32.50));
    PERFORM pg_temp.espera('Otro cliente no puede ver las propuestas ajenas', $q$
        SELECT * FROM fn_propuestas_de_solicitud(pg_temp.ctx('cl2'), pg_temp.ctx('s1'))
    $q$, 'GT003');
    PERFORM pg_temp.espera('Ver propuestas de una solicitud inexistente falla con GT002', $q$
        SELECT * FROM fn_propuestas_de_solicitud(pg_temp.ctx('cl1'), -1)
    $q$, 'GT002');
    PERFORM pg_temp.espera('Otro cliente no puede rechazar una propuesta ajena', $q$
        SELECT fn_rechazar_oferta(pg_temp.ctx('cl2'), pg_temp.ctx('o2'))
    $q$, 'GT003');
    PERFORM fn_rechazar_oferta(v_cl1, v_o2);
    PERFORM pg_temp.verificar('Rechazar deja la propuesta en rechazada y la solicitud sigue publicada',
        EXISTS (SELECT 1 FROM ofertas WHERE id = v_o2 AND estado = 'rechazada')
        AND EXISTS (SELECT 1 FROM solicitudes WHERE id = v_s1 AND estado = 'publicada'));
    PERFORM pg_temp.espera('Rechazar una propuesta ya rechazada falla con GT002', $q$
        SELECT fn_rechazar_oferta(pg_temp.ctx('cl1'), pg_temp.ctx('o2'))
    $q$, 'GT002');
    PERFORM pg_temp.espera('El trabajador rechazado no puede reenviar: GT001', $q$
        SELECT fn_enviar_oferta(pg_temp.ctx('tr2'), pg_temp.ctx('s1'), 20, NULL)
    $q$, 'GT001');

    -- Aceptar
    PERFORM pg_temp.espera('Aceptar una propuesta de la solicitud de otro cliente falla con GT003', $q$
        SELECT fn_aceptar_oferta(pg_temp.ctx('cl2'), pg_temp.ctx('o1'))
    $q$, 'GT003');
    PERFORM pg_temp.espera('Aceptar una propuesta inexistente falla con GT002', $q$
        SELECT fn_aceptar_oferta(pg_temp.ctx('cl1'), -1)
    $q$, 'GT002');
    PERFORM fn_aceptar_oferta(v_cl1, v_o1);
    PERFORM pg_temp.verificar('Aceptar deja la solicitud asignada al trabajador y con fecha de asignación',
        EXISTS (SELECT 1 FROM solicitudes WHERE id = v_s1 AND estado = 'asignada' AND trabajador_id = v_tr1 AND fecha_asignacion IS NOT NULL));
    PERFORM pg_temp.verificar('Aceptar deja la propuesta elegida en aceptada',
        EXISTS (SELECT 1 FROM ofertas WHERE id = v_o1 AND estado = 'aceptada'));
    PERFORM pg_temp.verificar('Aceptar rechaza todas las demás',
        (SELECT count(*) FROM ofertas WHERE solicitud_id = v_s1 AND id <> v_o1 AND estado = 'rechazada') = 2
        AND NOT EXISTS (SELECT 1 FROM ofertas WHERE solicitud_id = v_s1 AND id <> v_o1 AND estado <> 'rechazada'));
    PERFORM pg_temp.espera('Aceptar otra propuesta de la misma solicitud ya asignada falla con GT002', $q$
        SELECT fn_aceptar_oferta(pg_temp.ctx('cl1'), pg_temp.ctx('o3'))
    $q$, 'GT002');
    PERFORM pg_temp.espera('Aceptar de nuevo la propuesta ya aceptada falla con GT002', $q$
        SELECT fn_aceptar_oferta(pg_temp.ctx('cl1'), pg_temp.ctx('o1'))
    $q$, 'GT002');
    PERFORM pg_temp.verificar('Una solicitud asignada ya no aparece en los trabajos de la zona',
        NOT EXISTS (SELECT 1 FROM fn_trabajos_por_zona(v_tr5) z WHERE z.id = v_s1));
    PERFORM pg_temp.espera('Proponer a una solicitud ya asignada falla con GT001', $q$
        SELECT fn_enviar_oferta(pg_temp.ctx('tr5'), pg_temp.ctx('s1'), 20, NULL)
    $q$, 'GT001');
    PERFORM pg_temp.espera('Retirar una propuesta ya aceptada falla con GT001', $q$
        SELECT fn_retirar_oferta(pg_temp.ctx('tr1'), pg_temp.ctx('o1'))
    $q$, 'GT001');

    -- Aceptar una propuesta pendiente de una solicitud cancelada (la cancelación se simula directo)
    v_s2 := fn_publicar_solicitud(v_cl1, v_elec, v_zac, 'Otra solicitud', 'Texto de prueba', 25.00, 'Dirección inventada, casa 9');
    v_o4 := fn_enviar_oferta(v_tr1, v_s2, 20.00, NULL);
    INSERT INTO contexto VALUES ('o4', v_o4);
    UPDATE solicitudes SET estado = 'cancelada' WHERE id = v_s2;
    PERFORM pg_temp.espera('Aceptar una propuesta pendiente de una solicitud cancelada falla con GT001', $q$
        SELECT fn_aceptar_oferta(pg_temp.ctx('cl1'), pg_temp.ctx('o4'))
    $q$, 'GT001');
    PERFORM pg_temp.verificar('Tras el fallo, nada cambió: la propuesta sigue pendiente y la solicitud cancelada',
        EXISTS (SELECT 1 FROM ofertas WHERE id = v_o4 AND estado = 'pendiente')
        AND EXISTS (SELECT 1 FROM solicitudes WHERE id = v_s2 AND estado = 'cancelada' AND trabajador_id IS NULL));
END $$;

-- Detalle de una solicitud (fn_detalle_solicitud) y vista pública
DO $$
DECLARE
    v_s3  int;
    v_r   record;
BEGIN
    v_s3 := fn_publicar_solicitud(pg_temp.ctx('cl1'), pg_temp.ctx('oficio'), pg_temp.ctx('zacamil'), 'Revisar breaker',
                                  'Se baja la luz al usar la plancha (texto de prueba)', 30.00, 'Dirección inventada, casa 11');
    INSERT INTO contexto VALUES ('s3', v_s3);

    SELECT * INTO v_r FROM fn_detalle_solicitud(pg_temp.ctx('cl1'), pg_temp.ctx('s1'));
    PERFORM pg_temp.verificar('El dueño ve el detalle con su nombre completo, el asignado y el número de propuestas',
        v_r.cliente_nombre = 'Carlos Ejemplo' AND v_r.trabajador_nombre = 'Luis Flujo' AND v_r.propuestas = 3
        AND v_r.estado = 'asignada' AND v_r.mi_propuesta_id IS NULL);

    SELECT * INTO v_r FROM fn_detalle_solicitud(pg_temp.ctx('tr1'), pg_temp.ctx('s1'));
    PERFORM pg_temp.verificar('El trabajador asignado ve el detalle, su propuesta aceptada y el cliente abreviado',
        v_r.cliente_nombre = 'Carlos E.' AND v_r.trabajador_nombre = 'Luis Flujo' AND v_r.propuestas IS NULL
        AND v_r.mi_propuesta_id = pg_temp.ctx('o1') AND v_r.mi_propuesta_estado = 'aceptada');

    SELECT * INTO v_r FROM fn_detalle_solicitud(pg_temp.ctx('tr2'), pg_temp.ctx('s1'));
    PERFORM pg_temp.verificar('Un trabajador rechazado ve el detalle y su propuesta, pero no a quién se asignó',
        v_r.mi_propuesta_estado = 'rechazada' AND v_r.trabajador_nombre IS NULL);

    SELECT * INTO v_r FROM fn_detalle_solicitud(pg_temp.ctx('tr2'), v_s3);
    PERFORM pg_temp.verificar('Un trabajador de la zona ve una publicada con su descripción y sin propuesta propia',
        v_r.id = v_s3 AND v_r.descripcion LIKE 'Se baja la luz%' AND v_r.zona = 'Mejicanos, Col. Zacamil'
        AND v_r.presupuesto = 30.00 AND v_r.mi_propuesta_id IS NULL AND v_r.cliente_id = pg_temp.ctx('cl1'));

    PERFORM pg_temp.espera('Un trabajador de otro oficio no ve el detalle: GT003', $q$
        SELECT * FROM fn_detalle_solicitud(pg_temp.ctx('tr3'), pg_temp.ctx('s3'))
    $q$, 'GT003');
    PERFORM pg_temp.espera('Un trabajador de otro municipio no ve el detalle: GT003', $q$
        SELECT * FROM fn_detalle_solicitud(pg_temp.ctx('tr4'), pg_temp.ctx('s3'))
    $q$, 'GT003');
    PERFORM pg_temp.espera('Otro cliente no ve el detalle: GT003', $q$
        SELECT * FROM fn_detalle_solicitud(pg_temp.ctx('cl2'), pg_temp.ctx('s3'))
    $q$, 'GT003');
    PERFORM pg_temp.espera('Detalle de una solicitud inexistente: GT002', $q$
        SELECT * FROM fn_detalle_solicitud(pg_temp.ctx('cl1'), -1)
    $q$, 'GT002');

    PERFORM pg_temp.verificar('La vista pública muestra la solicitud',
        EXISTS (SELECT 1 FROM vw_solicitudes_publicas WHERE id = v_s3));
    PERFORM pg_temp.verificar('La vista pública no tiene columnas de dirección, teléfono, correo ni DUI',
        NOT EXISTS (SELECT 1 FROM information_schema.columns
                     WHERE table_name = 'vw_solicitudes_publicas'
                       AND column_name ~ 'direccion|telefono|correo|dui|password'));
    PERFORM pg_temp.verificar('El detalle no tiene columnas de dirección, teléfono, correo ni DUI',
        pg_get_function_result('fn_detalle_solicitud(integer, integer)'::regprocedure) !~* 'direccion|telefono|correo|dui');
END $$;

-- Seguimiento: contacto, en proceso, finalizar y calificar (s1 está asignada a tr1)
DO $$
DECLARE
    v_r   record;
    v_id  int;
BEGIN
    INSERT INTO contexto SELECT 'admin', id FROM usuarios WHERE lower(correo) = 'admin.semilla@example.com';
    INSERT INTO contexto SELECT 's2', solicitud_id FROM ofertas WHERE id = pg_temp.ctx('o4');

    -- Contacto
    SELECT * INTO v_r FROM fn_contacto_trabajo(pg_temp.ctx('cl1'), pg_temp.ctx('s1'));
    PERFORM pg_temp.verificar('El dueño de una solicitud asignada ve el contacto del trabajador y la dirección',
        v_r.rol = 'trabajador' AND v_r.nombre = 'Luis Flujo' AND v_r.telefono = '7000-0311'
        AND v_r.direccion_exacta = 'Dirección inventada, casa 7');
    SELECT * INTO v_r FROM fn_contacto_trabajo(pg_temp.ctx('tr1'), pg_temp.ctx('s1'));
    PERFORM pg_temp.verificar('El trabajador asignado ve el contacto del cliente y la dirección',
        v_r.rol = 'cliente' AND v_r.nombre = 'Carlos Ejemplo' AND v_r.telefono = '7000-0301'
        AND v_r.direccion_exacta = 'Dirección inventada, casa 7');
    PERFORM pg_temp.verificar('El contacto es una sola fila',
        (SELECT count(*) FROM fn_contacto_trabajo(pg_temp.ctx('cl1'), pg_temp.ctx('s1'))) = 1);
    PERFORM pg_temp.espera('Un trabajador rechazado no ve el contacto: GT003', $q$
        SELECT * FROM fn_contacto_trabajo(pg_temp.ctx('tr2'), pg_temp.ctx('s1'))
    $q$, 'GT003');
    PERFORM pg_temp.espera('Otro cliente no ve el contacto: GT003', $q$
        SELECT * FROM fn_contacto_trabajo(pg_temp.ctx('cl2'), pg_temp.ctx('s1'))
    $q$, 'GT003');
    PERFORM pg_temp.espera('El dueño de una solicitud publicada no recibe contacto: GT003', $q$
        SELECT * FROM fn_contacto_trabajo(pg_temp.ctx('cl1'), pg_temp.ctx('s3'))
    $q$, 'GT003');
    PERFORM pg_temp.espera('El dueño de una solicitud cancelada no recibe contacto: GT003', $q$
        SELECT * FROM fn_contacto_trabajo(pg_temp.ctx('cl1'), pg_temp.ctx('s2'))
    $q$, 'GT003');
    PERFORM pg_temp.espera('Contacto de una solicitud inexistente: GT002', $q$
        SELECT * FROM fn_contacto_trabajo(pg_temp.ctx('cl1'), -1)
    $q$, 'GT002');

    -- En proceso
    PERFORM pg_temp.espera('Otro trabajador no puede marcar en proceso: GT003', $q$
        SELECT fn_marcar_en_proceso(pg_temp.ctx('tr2'), pg_temp.ctx('s1'))
    $q$, 'GT003');
    PERFORM pg_temp.espera('El cliente no puede marcar en proceso: GT003', $q$
        SELECT fn_marcar_en_proceso(pg_temp.ctx('cl1'), pg_temp.ctx('s1'))
    $q$, 'GT003');
    PERFORM pg_temp.espera('Marcar en proceso una solicitud inexistente: GT002', $q$
        SELECT fn_marcar_en_proceso(pg_temp.ctx('tr1'), -1)
    $q$, 'GT002');
    PERFORM pg_temp.espera('Confirmar terminado un trabajo que solo está asignado: GT001', $q$
        SELECT fn_finalizar_solicitud(pg_temp.ctx('cl1'), pg_temp.ctx('s1'))
    $q$, 'GT001');
    PERFORM pg_temp.espera('Calificar un trabajo que no está finalizado: GT001', $q$
        SELECT fn_calificar(pg_temp.ctx('cl1'), pg_temp.ctx('s1'), 5, 'Comentario de prueba')
    $q$, 'GT001');

    -- la API fija app.usuario_id al inicio de cada transacción; aquí se simula para la bitácora
    PERFORM set_config('app.usuario_id', pg_temp.ctx('tr1')::text, true);
    PERFORM fn_marcar_en_proceso(pg_temp.ctx('tr1'), pg_temp.ctx('s1'));
    PERFORM pg_temp.verificar('El trabajador asignado marca el trabajo en proceso',
        EXISTS (SELECT 1 FROM solicitudes WHERE id = pg_temp.ctx('s1') AND estado = 'en_proceso'));
    PERFORM pg_temp.espera('Marcar en proceso dos veces: GT001', $q$
        SELECT fn_marcar_en_proceso(pg_temp.ctx('tr1'), pg_temp.ctx('s1'))
    $q$, 'GT001');
    PERFORM pg_temp.verificar('En proceso el contacto sigue disponible',
        EXISTS (SELECT 1 FROM fn_contacto_trabajo(pg_temp.ctx('cl1'), pg_temp.ctx('s1'))));

    -- Finalizar
    PERFORM set_config('app.usuario_id', pg_temp.ctx('cl1')::text, true);
    PERFORM pg_temp.espera('Otro cliente no puede confirmar el trabajo: GT003', $q$
        SELECT fn_finalizar_solicitud(pg_temp.ctx('cl2'), pg_temp.ctx('s1'))
    $q$, 'GT003');
    PERFORM pg_temp.espera('El trabajador no puede confirmar el trabajo: GT003', $q$
        SELECT fn_finalizar_solicitud(pg_temp.ctx('tr1'), pg_temp.ctx('s1'))
    $q$, 'GT003');
    PERFORM pg_temp.espera('Confirmar una solicitud inexistente: GT002', $q$
        SELECT fn_finalizar_solicitud(pg_temp.ctx('cl1'), -1)
    $q$, 'GT002');
    PERFORM fn_finalizar_solicitud(pg_temp.ctx('cl1'), pg_temp.ctx('s1'));
    PERFORM set_config('app.usuario_id', '', true);
    PERFORM pg_temp.verificar('El dueño confirma que el trabajo terminó',
        EXISTS (SELECT 1 FROM solicitudes WHERE id = pg_temp.ctx('s1') AND estado = 'finalizada'));
    PERFORM pg_temp.espera('Confirmar dos veces: GT001', $q$
        SELECT fn_finalizar_solicitud(pg_temp.ctx('cl1'), pg_temp.ctx('s1'))
    $q$, 'GT001');
    PERFORM pg_temp.verificar('Finalizado el contacto sigue disponible',
        EXISTS (SELECT 1 FROM fn_contacto_trabajo(pg_temp.ctx('tr1'), pg_temp.ctx('s1'))));

    -- Calificar
    SELECT * INTO v_r FROM fn_detalle_solicitud(pg_temp.ctx('cl1'), pg_temp.ctx('s1'));
    PERFORM pg_temp.verificar('El detalle trae al dueño el id del trabajador y que aún no califica',
        v_r.trabajador_id = pg_temp.ctx('tr1') AND NOT v_r.ya_califique);
    PERFORM pg_temp.verificar('Antes de calificar, el trabajador tiene promedio 0',
        EXISTS (SELECT 1 FROM usuarios WHERE id = pg_temp.ctx('tr1') AND promedio_calificacion = 0 AND total_calificaciones = 0));
    v_id := fn_calificar(pg_temp.ctx('cl1'), pg_temp.ctx('s1'), 5, '  Muy puntual (comentario de prueba)  ');
    PERFORM pg_temp.verificar('Calificar inserta la calificación al trabajador, con el comentario sin espacios a los lados',
        EXISTS (SELECT 1 FROM calificaciones
                 WHERE id = v_id AND calificador_id = pg_temp.ctx('cl1') AND calificado_id = pg_temp.ctx('tr1')
                   AND estrellas = 5 AND comentario = 'Muy puntual (comentario de prueba)'));
    PERFORM pg_temp.verificar('Calificar cambia el promedio del calificado',
        EXISTS (SELECT 1 FROM usuarios WHERE id = pg_temp.ctx('tr1') AND promedio_calificacion = 5.00 AND total_calificaciones = 1));
    SELECT * INTO v_r FROM fn_detalle_solicitud(pg_temp.ctx('cl1'), pg_temp.ctx('s1'));
    PERFORM pg_temp.verificar('Después de calificar, el detalle dice que el dueño ya calificó', v_r.ya_califique);
    PERFORM pg_temp.espera('Calificar dos veces el mismo trabajo: GT001', $q$
        SELECT fn_calificar(pg_temp.ctx('cl1'), pg_temp.ctx('s1'), 4, 'Otra vez')
    $q$, 'GT001');
    PERFORM pg_temp.espera('Calificar con 0 estrellas: GT001', $q$
        SELECT fn_calificar(pg_temp.ctx('tr1'), pg_temp.ctx('s1'), 0, 'Comentario de prueba')
    $q$, 'GT001');
    PERFORM pg_temp.espera('Calificar con 6 estrellas: GT001', $q$
        SELECT fn_calificar(pg_temp.ctx('tr1'), pg_temp.ctx('s1'), 6, 'Comentario de prueba')
    $q$, 'GT001');
    PERFORM pg_temp.espera('Calificar con el comentario vacío: GT001', $q$
        SELECT fn_calificar(pg_temp.ctx('tr1'), pg_temp.ctx('s1'), 4, '   ')
    $q$, 'GT001');
    PERFORM pg_temp.espera('Calificar sin comentario: GT001', $q$
        SELECT fn_calificar(pg_temp.ctx('tr1'), pg_temp.ctx('s1'), 4, NULL)
    $q$, 'GT001');
    PERFORM pg_temp.espera('Calificar con un comentario de 501 caracteres: GT001', $q$
        SELECT fn_calificar(pg_temp.ctx('tr1'), pg_temp.ctx('s1'), 4, repeat('x', 501))
    $q$, 'GT001');
    PERFORM pg_temp.espera('Un tercero no puede calificar: GT003', $q$
        SELECT fn_calificar(pg_temp.ctx('tr2'), pg_temp.ctx('s1'), 3, 'Comentario de prueba')
    $q$, 'GT003');
    PERFORM pg_temp.espera('Calificar una solicitud inexistente: GT002', $q$
        SELECT fn_calificar(pg_temp.ctx('cl1'), -1, 5, 'Comentario de prueba')
    $q$, 'GT002');
    PERFORM fn_calificar(pg_temp.ctx('tr1'), pg_temp.ctx('s1'), 4, 'Cliente amable (comentario de prueba)');
    PERFORM pg_temp.verificar('El trabajador califica al cliente y cambia el promedio del cliente',
        EXISTS (SELECT 1 FROM usuarios WHERE id = pg_temp.ctx('cl1') AND promedio_calificacion = 4.00 AND total_calificaciones = 1));

    SELECT * INTO v_r FROM fn_detalle_solicitud(pg_temp.ctx('tr1'), pg_temp.ctx('s1'));
    PERFORM pg_temp.verificar('El trabajador asignado ve su id en el detalle y que ya calificó',
        v_r.trabajador_id = pg_temp.ctx('tr1') AND v_r.ya_califique);
    SELECT * INTO v_r FROM fn_detalle_solicitud(pg_temp.ctx('tr2'), pg_temp.ctx('s1'));
    PERFORM pg_temp.verificar('Un trabajador rechazado no ve el id del asignado',
        v_r.trabajador_id IS NULL AND NOT v_r.ya_califique);
END $$;

-- Bitácora (trigger trg_solicitudes_bitacora)
DO $$
BEGIN
    PERFORM pg_temp.verificar('La bitácora guarda la publicación y cada cambio de estado, en orden',
        (SELECT string_agg(COALESCE(b.estado_anterior, '-') || '>' || b.estado_nuevo, ' ' ORDER BY b.id)
           FROM bitacora b WHERE b.solicitud_id = pg_temp.ctx('s1'))
        = '->publicada publicada>asignada asignada>en_proceso en_proceso>finalizada');
    PERFORM pg_temp.verificar('Sin app.usuario_id la bitácora guarda el usuario en NULL',
        NOT EXISTS (SELECT 1 FROM bitacora
                     WHERE solicitud_id = pg_temp.ctx('s1') AND estado_nuevo IN ('publicada', 'asignada') AND usuario_id IS NOT NULL));
    PERFORM pg_temp.verificar('Con app.usuario_id la bitácora guarda quién hizo el cambio',
        (SELECT usuario_id FROM bitacora WHERE solicitud_id = pg_temp.ctx('s1') AND estado_nuevo = 'en_proceso') = pg_temp.ctx('tr1')
        AND (SELECT usuario_id FROM bitacora WHERE solicitud_id = pg_temp.ctx('s1') AND estado_nuevo = 'finalizada') = pg_temp.ctx('cl1'));

    UPDATE solicitudes SET estado = estado WHERE id = pg_temp.ctx('s3');
    UPDATE solicitudes SET titulo = titulo WHERE id = pg_temp.ctx('s3');
    PERFORM pg_temp.verificar('Un UPDATE que no cambia el estado no escribe en la bitácora',
        (SELECT count(*) FROM bitacora WHERE solicitud_id = pg_temp.ctx('s3')) = 1);
END $$;

-- Cancelar y vencer
DO $$
DECLARE
    v_cl1   int := pg_temp.ctx('cl1');
    v_cl2   int := pg_temp.ctx('cl2');
    v_elec  int := pg_temp.ctx('oficio');
    v_zac   int := pg_temp.ctx('zacamil');
    v_s5 int; v_s6 int; v_s7 int; v_s8 int;
    v_o5 int; v_o6 int; v_o7 int; v_o8 int; v_o9 int;
    v_esperadas  int;
    v_vencidas   int;
BEGIN
    -- Cancelar una publicada: la propuesta pendiente pasa a rechazada y la retirada no cambia
    v_s5 := fn_publicar_solicitud(v_cl1, v_elec, v_zac, 'Instalar lámpara', 'Texto de prueba', 20.00, 'Dirección inventada, casa 13');
    v_o5 := fn_enviar_oferta(pg_temp.ctx('tr1'), v_s5, 18.00, NULL);
    v_o6 := fn_enviar_oferta(pg_temp.ctx('tr5'), v_s5, 19.00, NULL);
    PERFORM fn_retirar_oferta(pg_temp.ctx('tr5'), v_o6);
    INSERT INTO contexto VALUES ('s5', v_s5);
    PERFORM pg_temp.espera('Otro cliente no puede cancelar: GT003', $q$
        SELECT fn_cancelar_solicitud(pg_temp.ctx('cl2'), pg_temp.ctx('s5'))
    $q$, 'GT003');
    PERFORM pg_temp.espera('Un trabajador no puede cancelar: GT003', $q$
        SELECT fn_cancelar_solicitud(pg_temp.ctx('tr1'), pg_temp.ctx('s5'))
    $q$, 'GT003');
    PERFORM pg_temp.espera('Cancelar una solicitud inexistente: GT002', $q$
        SELECT fn_cancelar_solicitud(pg_temp.ctx('cl1'), -1)
    $q$, 'GT002');
    PERFORM fn_cancelar_solicitud(v_cl1, v_s5);
    PERFORM pg_temp.verificar('Cancelar una publicada la deja cancelada y sin trabajador',
        EXISTS (SELECT 1 FROM solicitudes WHERE id = v_s5 AND estado = 'cancelada' AND trabajador_id IS NULL));
    PERFORM pg_temp.verificar('Al cancelar, la propuesta pendiente pasa a rechazada y la retirada no cambia',
        EXISTS (SELECT 1 FROM ofertas WHERE id = v_o5 AND estado = 'rechazada')
        AND EXISTS (SELECT 1 FROM ofertas WHERE id = v_o6 AND estado = 'retirada'));
    PERFORM pg_temp.espera('Cancelar dos veces: GT001', $q$
        SELECT fn_cancelar_solicitud(pg_temp.ctx('cl1'), pg_temp.ctx('s5'))
    $q$, 'GT001');
    PERFORM pg_temp.espera('Cancelar un trabajo finalizado: GT001', $q$
        SELECT fn_cancelar_solicitud(pg_temp.ctx('cl1'), pg_temp.ctx('s1'))
    $q$, 'GT001');

    -- Cancelar una asignada: se conservan el trabajador y la propuesta aceptada
    v_s6 := fn_publicar_solicitud(v_cl1, v_elec, v_zac, 'Revisar instalación', 'Texto de prueba', 50.00, 'Dirección inventada, casa 15');
    v_o7 := fn_enviar_oferta(pg_temp.ctx('tr1'), v_s6, 50.00, NULL);
    v_o8 := fn_enviar_oferta(pg_temp.ctx('tr2'), v_s6, 55.00, NULL);
    PERFORM fn_aceptar_oferta(v_cl1, v_o7);
    INSERT INTO contexto VALUES ('s6', v_s6);
    PERFORM fn_cancelar_solicitud(v_cl1, v_s6);
    PERFORM pg_temp.verificar('Cancelar una asignada conserva el trabajador y la propuesta aceptada',
        EXISTS (SELECT 1 FROM solicitudes WHERE id = v_s6 AND estado = 'cancelada' AND trabajador_id = pg_temp.ctx('tr1'))
        AND EXISTS (SELECT 1 FROM ofertas WHERE id = v_o7 AND estado = 'aceptada')
        AND EXISTS (SELECT 1 FROM ofertas WHERE id = v_o8 AND estado = 'rechazada'));
    PERFORM pg_temp.espera('Una solicitud cancelada ya no da contacto al trabajador: GT003', $q$
        SELECT * FROM fn_contacto_trabajo(pg_temp.ctx('tr1'), pg_temp.ctx('s6'))
    $q$, 'GT003');
    PERFORM pg_temp.espera('El trabajador de una cancelada no puede marcarla en proceso: GT001', $q$
        SELECT fn_marcar_en_proceso(pg_temp.ctx('tr1'), pg_temp.ctx('s6'))
    $q$, 'GT001');

    -- Vencer: la de hace 73 horas sí, la de hace 71 no
    v_s7 := fn_publicar_solicitud(v_cl2, v_elec, v_zac, 'Solicitud vieja', 'Texto de prueba', 30.00, 'Dirección inventada, casa 17');
    v_s8 := fn_publicar_solicitud(v_cl2, v_elec, v_zac, 'Solicitud reciente', 'Texto de prueba', 30.00, 'Dirección inventada, casa 19');
    v_o9 := fn_enviar_oferta(pg_temp.ctx('tr1'), v_s7, 30.00, NULL);
    UPDATE solicitudes SET fecha_publicacion = now() - interval '73 hours' WHERE id = v_s7;
    UPDATE solicitudes SET fecha_publicacion = now() - interval '71 hours' WHERE id = v_s8;
    INSERT INTO contexto VALUES ('s7', v_s7), ('s8', v_s8);
    v_esperadas := (SELECT count(*) FROM solicitudes
                     WHERE estado = 'publicada' AND NOT eliminado AND fecha_publicacion < now() - interval '72 hours');
    v_vencidas := fn_vencer_solicitudes();
    PERFORM pg_temp.verificar('fn_vencer_solicitudes devuelve cuántas venció', v_vencidas = v_esperadas AND v_vencidas >= 1);
    PERFORM pg_temp.verificar('Una solicitud publicada hace 73 horas pasa a vencida',
        EXISTS (SELECT 1 FROM solicitudes WHERE id = v_s7 AND estado = 'vencida'));
    PERFORM pg_temp.verificar('Una solicitud publicada hace 71 horas sigue publicada',
        EXISTS (SELECT 1 FROM solicitudes WHERE id = v_s8 AND estado = 'publicada'));
    PERFORM pg_temp.verificar('Las propuestas pendientes de la vencida pasan a rechazada',
        EXISTS (SELECT 1 FROM ofertas WHERE id = v_o9 AND estado = 'rechazada'));
    PERFORM pg_temp.verificar('Vencer otra vez no vence nada más', fn_vencer_solicitudes() = 0);
    PERFORM pg_temp.espera('Una solicitud vencida no recibe propuestas: GT001', $q$
        SELECT fn_enviar_oferta(pg_temp.ctx('tr2'), pg_temp.ctx('s7'), 20, NULL)
    $q$, 'GT001');
    PERFORM pg_temp.espera('Una solicitud vencida no se cancela: GT001', $q$
        SELECT fn_cancelar_solicitud(pg_temp.ctx('cl2'), pg_temp.ctx('s7'))
    $q$, 'GT001');
END $$;

-- Avisos que dejan los triggers
DO $$
BEGIN
    PERFORM pg_temp.verificar('Cada propuesta nueva o reactivada avisa al cliente',
        (SELECT count(*) FROM avisos
          WHERE usuario_id = pg_temp.ctx('cl1') AND solicitud_id = pg_temp.ctx('s1') AND tipo = 'propuesta_nueva') = 4);
    PERFORM pg_temp.verificar('El aviso de propuesta nueva dice quién, cuánto y para qué solicitud',
        EXISTS (SELECT 1 FROM avisos
                 WHERE usuario_id = pg_temp.ctx('cl1') AND solicitud_id = pg_temp.ctx('s1') AND tipo = 'propuesta_nueva'
                   AND texto = 'Luis F. envió una propuesta de $35.00 para «Cambio de tomacorrientes»' AND NOT leido));
    PERFORM pg_temp.verificar('La propuesta reactivada vuelve a avisar con el precio nuevo',
        EXISTS (SELECT 1 FROM avisos
                 WHERE usuario_id = pg_temp.ctx('cl1') AND solicitud_id = pg_temp.ctx('s1')
                   AND texto = 'Luis F. envió una propuesta de $32.50 para «Cambio de tomacorrientes»'));
    PERFORM pg_temp.verificar('El trabajador aceptado recibe aviso',
        EXISTS (SELECT 1 FROM avisos
                 WHERE usuario_id = pg_temp.ctx('tr1') AND solicitud_id = pg_temp.ctx('s1') AND tipo = 'propuesta_aceptada'
                   AND texto = 'El cliente aceptó tu propuesta para «Cambio de tomacorrientes»'));
    PERFORM pg_temp.verificar('Los trabajadores rechazados, a mano o al aceptar otra, reciben aviso',
        EXISTS (SELECT 1 FROM avisos
                 WHERE usuario_id = pg_temp.ctx('tr2') AND solicitud_id = pg_temp.ctx('s1') AND tipo = 'propuesta_rechazada'
                   AND texto = 'Tu propuesta para «Cambio de tomacorrientes» fue rechazada')
        AND EXISTS (SELECT 1 FROM avisos
                     WHERE usuario_id = pg_temp.ctx('tr5') AND solicitud_id = pg_temp.ctx('s1') AND tipo = 'propuesta_rechazada'));
    PERFORM pg_temp.verificar('Marcar en proceso avisa al cliente',
        EXISTS (SELECT 1 FROM avisos
                 WHERE usuario_id = pg_temp.ctx('cl1') AND solicitud_id = pg_temp.ctx('s1') AND tipo = 'solicitud_en_proceso'
                   AND texto = 'Luis F. marcó en proceso «Cambio de tomacorrientes»'));
    PERFORM pg_temp.verificar('Confirmar que terminó avisa al trabajador',
        EXISTS (SELECT 1 FROM avisos
                 WHERE usuario_id = pg_temp.ctx('tr1') AND solicitud_id = pg_temp.ctx('s1') AND tipo = 'solicitud_finalizada'));
    PERFORM pg_temp.verificar('Cancelar una asignada avisa al trabajador asignado',
        EXISTS (SELECT 1 FROM avisos
                 WHERE usuario_id = pg_temp.ctx('tr1') AND solicitud_id = pg_temp.ctx('s6') AND tipo = 'solicitud_cancelada'
                   AND texto = 'El cliente canceló «Revisar instalación»'));
    PERFORM pg_temp.verificar('Cancelar una publicada no da aviso de cancelación',
        NOT EXISTS (SELECT 1 FROM avisos WHERE solicitud_id = pg_temp.ctx('s5') AND tipo = 'solicitud_cancelada'));
    PERFORM pg_temp.verificar('Al cancelar, el trabajador con propuesta pendiente recibe aviso de rechazo y el que la retiró no',
        EXISTS (SELECT 1 FROM avisos
                 WHERE usuario_id = pg_temp.ctx('tr1') AND solicitud_id = pg_temp.ctx('s5') AND tipo = 'propuesta_rechazada')
        AND NOT EXISTS (SELECT 1 FROM avisos WHERE usuario_id = pg_temp.ctx('tr5') AND solicitud_id = pg_temp.ctx('s5')));
    PERFORM pg_temp.verificar('Vencer avisa al cliente y al trabajador con propuesta pendiente',
        EXISTS (SELECT 1 FROM avisos
                 WHERE usuario_id = pg_temp.ctx('cl2') AND solicitud_id = pg_temp.ctx('s7') AND tipo = 'solicitud_vencida')
        AND EXISTS (SELECT 1 FROM avisos
                     WHERE usuario_id = pg_temp.ctx('tr1') AND solicitud_id = pg_temp.ctx('s7') AND tipo = 'propuesta_rechazada'));
    PERFORM pg_temp.verificar('Todos los avisos llevan solicitud',
        NOT EXISTS (SELECT 1 FROM avisos WHERE solicitud_id IS NULL));
END $$;

-- Mensajes, conversaciones, sincronización y avisos leídos
DO $$
DECLARE
    v_cl1  int := pg_temp.ctx('cl1');
    v_tr1  int := pg_temp.ctx('tr1');
    v_s1   int := pg_temp.ctx('s1');
    v_s6   int := pg_temp.ctx('s6');
    v_s4 int; v_o int; v_m1 int; v_m2 int; v_m3 int; v_aviso int; v_n int;
    v_r    record;
BEGIN
    v_s4 := fn_publicar_solicitud(v_cl1, pg_temp.ctx('oficio'), pg_temp.ctx('zacamil'), 'Revisar timbre', 'Texto de prueba', 15.00, 'Dirección inventada, casa 21');
    v_o := fn_enviar_oferta(v_tr1, v_s4, 15.00, NULL);
    PERFORM fn_aceptar_oferta(v_cl1, v_o);
    INSERT INTO contexto VALUES ('s4', v_s4);

    -- Enviar
    v_m1 := fn_enviar_mensaje(v_cl1, v_s4, '  ¿A qué hora llega? (texto de prueba)  ');
    PERFORM pg_temp.verificar('El cliente escribe al trabajador asignado; el texto se guarda sin espacios a los lados',
        EXISTS (SELECT 1 FROM mensajes
                 WHERE id = v_m1 AND emisor_id = v_cl1 AND receptor_id = v_tr1 AND texto = '¿A qué hora llega? (texto de prueba)'));
    v_m2 := fn_enviar_mensaje(v_tr1, v_s4, 'Llego a las tres (texto de prueba)');
    PERFORM pg_temp.verificar('El trabajador responde al cliente',
        EXISTS (SELECT 1 FROM mensajes WHERE id = v_m2 AND emisor_id = v_tr1 AND receptor_id = v_cl1));
    PERFORM pg_temp.verificar('Cada mensaje avisa al receptor',
        EXISTS (SELECT 1 FROM avisos
                 WHERE usuario_id = v_tr1 AND solicitud_id = v_s4 AND tipo = 'mensaje_nuevo'
                   AND texto = 'Mensaje nuevo de Carlos E. sobre «Revisar timbre»')
        AND EXISTS (SELECT 1 FROM avisos
                     WHERE usuario_id = v_cl1 AND solicitud_id = v_s4 AND tipo = 'mensaje_nuevo'
                       AND texto = 'Mensaje nuevo de Luis F. sobre «Revisar timbre»'));
    PERFORM pg_temp.espera('Un trabajador que no es el asignado no puede escribir: GT003', $q$
        SELECT fn_enviar_mensaje(pg_temp.ctx('tr2'), pg_temp.ctx('s4'), 'Hola')
    $q$, 'GT003');
    PERFORM pg_temp.espera('Otro cliente no puede escribir: GT003', $q$
        SELECT fn_enviar_mensaje(pg_temp.ctx('cl2'), pg_temp.ctx('s4'), 'Hola')
    $q$, 'GT003');
    PERFORM pg_temp.espera('No se escribe en una solicitud publicada: GT001', $q$
        SELECT fn_enviar_mensaje(pg_temp.ctx('cl1'), pg_temp.ctx('s3'), 'Hola')
    $q$, 'GT001');
    PERFORM pg_temp.espera('No se escribe en una solicitud cancelada: GT001', $q$
        SELECT fn_enviar_mensaje(pg_temp.ctx('tr1'), pg_temp.ctx('s6'), 'Hola')
    $q$, 'GT001');
    PERFORM pg_temp.espera('Mensaje vacío: GT001', $q$
        SELECT fn_enviar_mensaje(pg_temp.ctx('cl1'), pg_temp.ctx('s4'), '   ')
    $q$, 'GT001');
    PERFORM pg_temp.espera('Mensaje sin texto: GT001', $q$
        SELECT fn_enviar_mensaje(pg_temp.ctx('cl1'), pg_temp.ctx('s4'), NULL)
    $q$, 'GT001');
    PERFORM pg_temp.espera('Mensaje de 1001 caracteres: GT001', $q$
        SELECT fn_enviar_mensaje(pg_temp.ctx('cl1'), pg_temp.ctx('s4'), repeat('x', 1001))
    $q$, 'GT001');
    PERFORM pg_temp.espera('Mensaje a una solicitud inexistente: GT002', $q$
        SELECT fn_enviar_mensaje(pg_temp.ctx('cl1'), -1, 'Hola')
    $q$, 'GT002');

    -- Lista de mensajes
    PERFORM pg_temp.verificar('La lista trae los mensajes en orden, con el nombre completo del emisor y es_mio',
        (SELECT string_agg(m.emisor_nombre || ':' || m.es_mio::text, ',' ORDER BY m.fecha, m.id)
           FROM fn_mensajes_de_solicitud(v_cl1, v_s4) m) = 'Carlos Ejemplo:true,Luis Flujo:false');
    PERFORM pg_temp.verificar('Para el trabajador, es_mio marca sus propios mensajes',
        (SELECT string_agg(m.es_mio::text, ',' ORDER BY m.fecha, m.id)
           FROM fn_mensajes_de_solicitud(v_tr1, v_s4) m) = 'false,true');
    UPDATE mensajes SET fecha = now() - interval '2 hours' WHERE id = v_m1;
    PERFORM pg_temp.verificar('Con desde, la lista solo trae los mensajes posteriores',
        (SELECT array_agg(m.id) FROM fn_mensajes_de_solicitud(v_cl1, v_s4, now() - interval '1 hour') m) = ARRAY[v_m2]);
    PERFORM pg_temp.espera('Un tercero no ve los mensajes: GT003', $q$
        SELECT * FROM fn_mensajes_de_solicitud(pg_temp.ctx('tr2'), pg_temp.ctx('s4'))
    $q$, 'GT003');
    PERFORM pg_temp.espera('Mensajes de una solicitud inexistente: GT002', $q$
        SELECT * FROM fn_mensajes_de_solicitud(pg_temp.ctx('cl1'), -1)
    $q$, 'GT002');

    -- Conversaciones: s4 con mensajes, s1 finalizada con un mensaje de hace una hora, s6 cancelada sin mensajes
    v_m3 := fn_enviar_mensaje(v_cl1, v_s1, 'Gracias por el trabajo (texto de prueba)');
    PERFORM pg_temp.verificar('Se puede escribir en un trabajo finalizado', v_m3 IS NOT NULL);
    UPDATE mensajes SET fecha = now() - interval '1 hour' WHERE id = v_m3;
    UPDATE solicitudes SET fecha_asignacion = now() - interval '1 day' WHERE id = v_s6;
    PERFORM pg_temp.verificar('Las conversaciones salen ordenadas por el último mensaje o la asignación',
        (SELECT array_agg(c.solicitud_id ORDER BY c.ordinality) FROM fn_conversaciones(v_cl1) WITH ORDINALITY AS c)
        = ARRAY[v_s4, v_s1, v_s6]);
    SELECT * INTO v_r FROM fn_conversaciones(v_cl1) c WHERE c.solicitud_id = v_s4;
    PERFORM pg_temp.verificar('La conversación trae a la otra parte, el último mensaje y cuántos no ha leído',
        v_r.otra_parte_nombre = 'Luis Flujo' AND v_r.ultimo_mensaje = 'Llego a las tres (texto de prueba)'
        AND v_r.titulo = 'Revisar timbre' AND v_r.estado = 'asignada' AND v_r.mensajes_nuevos = 1);
    SELECT * INTO v_r FROM fn_conversaciones(v_cl1) c WHERE c.solicitud_id = v_s6;
    PERFORM pg_temp.verificar('Sin mensajes, el último mensaje y su fecha van en NULL',
        v_r.ultimo_mensaje IS NULL AND v_r.fecha_ultimo IS NULL AND v_r.mensajes_nuevos = 0);
    SELECT * INTO v_r FROM fn_conversaciones(v_tr1) c WHERE c.solicitud_id = v_s4;
    PERFORM pg_temp.verificar('Para el trabajador, la otra parte es el cliente',
        v_r.otra_parte_nombre = 'Carlos Ejemplo' AND v_r.mensajes_nuevos = 1);
    PERFORM pg_temp.verificar('Quien no tiene trabajos asignados no tiene conversaciones',
        NOT EXISTS (SELECT 1 FROM fn_conversaciones(pg_temp.ctx('cl2'))));
    PERFORM pg_temp.espera('Un administrador no tiene conversaciones: GT003', $q$
        SELECT * FROM fn_conversaciones(pg_temp.ctx('admin'))
    $q$, 'GT003');

    -- Sincronizar
    PERFORM pg_temp.verificar('Sin desde, sincronizar trae los mensajes recibidos con emisor y título',
        EXISTS (SELECT 1 FROM fn_sincronizar(v_tr1, NULL) x
                 WHERE x.clase = 'mensaje' AND x.id = v_m1 AND x.solicitud_id = v_s4 AND x.titulo = 'Revisar timbre'
                   AND x.emisor_nombre = 'Carlos Ejemplo' AND x.tipo IS NULL AND x.leido IS NULL));
    PERFORM pg_temp.verificar('Sin desde, sincronizar trae los avisos sin leer',
        EXISTS (SELECT 1 FROM fn_sincronizar(v_tr1, NULL) x
                 WHERE x.clase = 'aviso' AND x.tipo = 'propuesta_aceptada' AND x.solicitud_id = v_s4
                   AND x.titulo = 'Revisar timbre' AND x.emisor_nombre IS NULL AND NOT x.leido));
    PERFORM pg_temp.verificar('Sincronizar no trae los mensajes que el usuario envió',
        NOT EXISTS (SELECT 1 FROM fn_sincronizar(v_tr1, NULL) x WHERE x.clase = 'mensaje' AND x.id = v_m2));
    PERFORM pg_temp.verificar('Con desde, sincronizar solo trae lo posterior',
        NOT EXISTS (SELECT 1 FROM fn_sincronizar(v_tr1, now() - interval '1 hour') x WHERE x.clase = 'mensaje')
        AND EXISTS (SELECT 1 FROM fn_sincronizar(v_tr1, now() - interval '1 hour') x WHERE x.clase = 'aviso'));
    UPDATE mensajes SET fecha = now() - interval '8 days' WHERE id = v_m1;
    PERFORM pg_temp.verificar('Sin desde, no trae mensajes de hace más de 7 días',
        NOT EXISTS (SELECT 1 FROM fn_sincronizar(v_tr1, NULL) x WHERE x.clase = 'mensaje' AND x.id = v_m1));
    PERFORM pg_temp.verificar('Sincronizar sale ordenado por fecha',
        (SELECT x.id FROM fn_sincronizar(v_tr1, NULL) WITH ORDINALITY AS x ORDER BY x.ordinality LIMIT 1) = v_m3);
    PERFORM pg_temp.espera('Sincronizar con un usuario inexistente: GT003', $q$
        SELECT * FROM fn_sincronizar(-1, NULL)
    $q$, 'GT003');

    -- Marcar avisos leídos
    v_aviso := (SELECT id FROM avisos WHERE usuario_id = v_tr1 AND solicitud_id = v_s4 AND tipo = 'propuesta_aceptada');
    v_n := fn_marcar_avisos_leidos(v_tr1, ARRAY[v_aviso,
               (SELECT id FROM avisos WHERE usuario_id = v_cl1 AND solicitud_id = v_s4 AND tipo = 'mensaje_nuevo')]);
    PERFORM pg_temp.verificar('Marcar por ids solo marca los avisos propios',
        v_n = 1 AND (SELECT leido FROM avisos WHERE id = v_aviso)
        AND NOT (SELECT leido FROM avisos WHERE usuario_id = v_cl1 AND solicitud_id = v_s4 AND tipo = 'mensaje_nuevo'));
    PERFORM pg_temp.verificar('Sin desde, sincronizar ya no trae el aviso leído',
        NOT EXISTS (SELECT 1 FROM fn_sincronizar(v_tr1, NULL) x WHERE x.clase = 'aviso' AND x.id = v_aviso));
    PERFORM pg_temp.verificar('Con desde, sincronizar también trae los avisos leídos',
        EXISTS (SELECT 1 FROM fn_sincronizar(v_tr1, now() - interval '1 minute') x WHERE x.clase = 'aviso' AND x.id = v_aviso AND x.leido));
    v_n := fn_marcar_avisos_leidos(v_cl1, NULL, v_s4);
    PERFORM pg_temp.verificar('Marcar por solicitud marca los avisos de esa solicitud',
        v_n = 2 AND NOT EXISTS (SELECT 1 FROM avisos WHERE usuario_id = v_cl1 AND solicitud_id = v_s4 AND NOT leido)
        AND (SELECT c.mensajes_nuevos FROM fn_conversaciones(v_cl1) c WHERE c.solicitud_id = v_s4) = 0);
    v_n := fn_marcar_avisos_leidos(v_tr1);
    PERFORM pg_temp.verificar('Sin ids ni solicitud marca todos los avisos del usuario',
        v_n > 0 AND NOT EXISTS (SELECT 1 FROM avisos WHERE usuario_id = v_tr1 AND NOT leido));
    PERFORM pg_temp.verificar('Marcar otra vez no marca nada', fn_marcar_avisos_leidos(v_tr1) = 0);
    v_n := (SELECT count(*) FROM avisos WHERE usuario_id = pg_temp.ctx('cl2') AND NOT leido);
    PERFORM pg_temp.verificar('Con una lista vacía también marca todos',
        v_n > 0 AND fn_marcar_avisos_leidos(pg_temp.ctx('cl2'), ARRAY[]::int[]) = v_n);
    PERFORM pg_temp.espera('Marcar avisos con un usuario inexistente: GT003', $q$
        SELECT fn_marcar_avisos_leidos(-1)
    $q$, 'GT003');

    -- Una segunda calificación recalcula el promedio del trabajador: (5 + 3) / 2
    PERFORM fn_marcar_en_proceso(v_tr1, v_s4);
    PERFORM fn_finalizar_solicitud(v_cl1, v_s4);
    PERFORM fn_calificar(v_cl1, v_s4, 3, 'Llegó tarde (comentario de prueba)');
    PERFORM pg_temp.verificar('Con una segunda calificación el promedio del trabajador se recalcula',
        EXISTS (SELECT 1 FROM usuarios WHERE id = v_tr1 AND promedio_calificacion = 4.00 AND total_calificaciones = 2));
END $$;

-- Chat antes de aceptar: un hilo por cada trabajador que envió propuesta
DO $$
DECLARE
    v_cl1  int := pg_temp.ctx('cl1');
    v_tr1  int := pg_temp.ctx('tr1');
    v_tr2  int := pg_temp.ctx('tr2');
    v_s int; v_s2 int; v_o1 int; v_o2 int; v_m1 int; v_m2 int; v_m3 int; v_n int;
    v_r    record;
BEGIN
    v_s := fn_publicar_solicitud(v_cl1, pg_temp.ctx('oficio'), pg_temp.ctx('zacamil'), 'Cambiar llave del baño', 'Texto de prueba', 20.00, 'Dirección inventada, casa 31');
    INSERT INTO contexto VALUES ('chat1', v_s);

    -- Sin propuestas no hay hilo
    PERFORM pg_temp.espera('Sin propuesta, el trabajador no puede escribir: GT003', $q$
        SELECT fn_enviar_mensaje(pg_temp.ctx('tr1'), pg_temp.ctx('chat1'), 'Hola')
    $q$, 'GT003');
    PERFORM pg_temp.espera('Sin trabajador asignado, el cliente tiene que decir con quién habla: GT001', $q$
        SELECT fn_enviar_mensaje(pg_temp.ctx('cl1'), pg_temp.ctx('chat1'), 'Hola')
    $q$, 'GT001');
    PERFORM pg_temp.espera('El cliente no escribe a un trabajador que no envió propuesta: GT003', $q$
        SELECT fn_enviar_mensaje(pg_temp.ctx('cl1'), pg_temp.ctx('chat1'), 'Hola', pg_temp.ctx('tr3'))
    $q$, 'GT003');
    PERFORM pg_temp.verificar('Sin propuestas no hay hilos abiertos en la lista del cliente',
        NOT EXISTS (SELECT 1 FROM fn_conversaciones(v_cl1) c WHERE c.solicitud_id = v_s));

    v_o1 := fn_enviar_oferta(v_tr1, v_s, 20.00, NULL);
    v_o2 := fn_enviar_oferta(v_tr2, v_s, 18.00, NULL);

    -- Con la solicitud publicada y la propuesta pendiente, los dos se escriben
    v_m1 := fn_enviar_mensaje(v_tr1, v_s, 'Hola, ¿tiene la llave a mano? (texto de prueba)');
    PERFORM pg_temp.verificar('Con propuesta pendiente, el trabajador escribe al cliente antes de que acepte',
        EXISTS (SELECT 1 FROM mensajes WHERE id = v_m1 AND emisor_id = v_tr1 AND receptor_id = v_cl1 AND solicitud_id = v_s));
    v_m2 := fn_enviar_mensaje(v_cl1, v_s, 'Sí, está en la cocina (texto de prueba)', v_tr1);
    PERFORM pg_temp.verificar('El cliente responde indicando con qué trabajador habla',
        EXISTS (SELECT 1 FROM mensajes WHERE id = v_m2 AND emisor_id = v_cl1 AND receptor_id = v_tr1));
    v_m3 := fn_enviar_mensaje(v_cl1, v_s, 'Hola, ¿cuándo puede venir? (texto de prueba)', v_tr2);
    PERFORM pg_temp.espera('Con varios trabajadores, el cliente sin indicar con cuál habla: GT001', $q$
        SELECT fn_enviar_mensaje(pg_temp.ctx('cl1'), pg_temp.ctx('chat1'), 'Hola')
    $q$, 'GT001');

    -- Cada hilo es aparte
    PERFORM pg_temp.verificar('El hilo del primer trabajador tiene sus dos mensajes y el del segundo solo el suyo',
        (SELECT array_agg(m.id ORDER BY m.id) FROM fn_mensajes_de_solicitud(v_cl1, v_s, NULL, v_tr1) m) = ARRAY[v_m1, v_m2]
        AND (SELECT array_agg(m.id) FROM fn_mensajes_de_solicitud(v_cl1, v_s, NULL, v_tr2) m) = ARRAY[v_m3]);
    PERFORM pg_temp.verificar('Cada trabajador solo ve su propio hilo con el cliente',
        (SELECT array_agg(m.id ORDER BY m.id) FROM fn_mensajes_de_solicitud(v_tr1, v_s) m) = ARRAY[v_m1, v_m2]
        AND (SELECT array_agg(m.id) FROM fn_mensajes_de_solicitud(v_tr2, v_s) m) = ARRAY[v_m3]);
    PERFORM pg_temp.espera('Un trabajador no puede pedir el hilo de otro trabajador: GT003', $q$
        SELECT * FROM fn_mensajes_de_solicitud(pg_temp.ctx('tr2'), pg_temp.ctx('chat1'), NULL, pg_temp.ctx('tr1'))
    $q$, 'GT003');
    PERFORM pg_temp.espera('Un trabajador sin propuesta no lee ningún hilo: GT003', $q$
        SELECT * FROM fn_mensajes_de_solicitud(pg_temp.ctx('tr3'), pg_temp.ctx('chat1'))
    $q$, 'GT003');
    PERFORM pg_temp.espera('Otro cliente no lee los hilos: GT003', $q$
        SELECT * FROM fn_mensajes_de_solicitud(pg_temp.ctx('cl2'), pg_temp.ctx('chat1'), NULL, pg_temp.ctx('tr1'))
    $q$, 'GT003');
    PERFORM pg_temp.verificar('Antes de la asignación, el trabajador ve al cliente con el nombre abreviado',
        (SELECT string_agg(m.emisor_nombre, ',' ORDER BY m.id) FROM fn_mensajes_de_solicitud(v_tr1, v_s) m) = 'Luis Flujo,Carlos E.');
    PERFORM pg_temp.verificar('El cliente ve los nombres completos',
        (SELECT string_agg(m.emisor_nombre, ',' ORDER BY m.id) FROM fn_mensajes_de_solicitud(v_cl1, v_s, NULL, v_tr1) m) = 'Luis Flujo,Carlos Ejemplo');

    -- Lista de hilos: uno por trabajador, con los no leídos de cada uno
    PERFORM pg_temp.verificar('El cliente tiene un hilo por cada trabajador con propuesta pendiente',
        (SELECT count(*) FROM fn_conversaciones(v_cl1) c WHERE c.solicitud_id = v_s AND c.abierto) = 2);
    SELECT * INTO v_r FROM fn_conversaciones(v_cl1) c WHERE c.solicitud_id = v_s AND c.otra_parte_id = v_tr1;
    PERFORM pg_temp.verificar('El hilo del primer trabajador trae su nombre, su último mensaje y 1 sin leer',
        v_r.otra_parte_nombre = 'Luis Flujo' AND v_r.ultimo_mensaje = 'Sí, está en la cocina (texto de prueba)'
        AND v_r.mensajes_nuevos = 1 AND v_r.estado = 'publicada');
    SELECT * INTO v_r FROM fn_conversaciones(v_cl1) c WHERE c.solicitud_id = v_s AND c.otra_parte_id = v_tr2;
    PERFORM pg_temp.verificar('El hilo del segundo trabajador no tiene mensajes sin leer del cliente',
        v_r.ultimo_mensaje = 'Hola, ¿cuándo puede venir? (texto de prueba)' AND v_r.mensajes_nuevos = 0);
    SELECT * INTO v_r FROM fn_conversaciones(v_tr1) c WHERE c.solicitud_id = v_s;
    PERFORM pg_temp.verificar('Para el trabajador el hilo es con el cliente, con nombre abreviado, y trae 1 sin leer',
        v_r.otra_parte_nombre = 'Carlos E.' AND v_r.mensajes_nuevos = 1 AND v_r.abierto);

    -- Marcar leídos por hilo
    v_n := fn_marcar_avisos_leidos(v_cl1, NULL, v_s, v_tr2);
    PERFORM pg_temp.verificar('Marcar el hilo de un trabajador no toca los avisos de otro',
        v_n = 0 AND (SELECT c.mensajes_nuevos FROM fn_conversaciones(v_cl1) c WHERE c.solicitud_id = v_s AND c.otra_parte_id = v_tr1) = 1);
    v_n := fn_marcar_avisos_leidos(v_cl1, NULL, v_s, v_tr1);
    PERFORM pg_temp.verificar('Marcar el hilo deja en 0 sus mensajes sin leer y deja las propuestas nuevas sin leer',
        v_n = 1
        AND (SELECT c.mensajes_nuevos FROM fn_conversaciones(v_cl1) c WHERE c.solicitud_id = v_s AND c.otra_parte_id = v_tr1) = 0
        AND EXISTS (SELECT 1 FROM avisos WHERE usuario_id = v_cl1 AND solicitud_id = v_s AND tipo = 'propuesta_nueva' AND NOT leido));

    -- Al aceptar, solo el trabajador elegido sigue escribiendo; los demás hilos quedan de solo lectura
    PERFORM fn_aceptar_oferta(v_cl1, v_o1);
    PERFORM pg_temp.espera('Un trabajador con propuesta rechazada ya no escribe: GT001', $q$
        SELECT fn_enviar_mensaje(pg_temp.ctx('tr2'), pg_temp.ctx('chat1'), 'Hola')
    $q$, 'GT001');
    PERFORM pg_temp.espera('El cliente tampoco escribe al trabajador rechazado: GT001', $q$
        SELECT fn_enviar_mensaje(pg_temp.ctx('cl1'), pg_temp.ctx('chat1'), 'Hola', pg_temp.ctx('tr2'))
    $q$, 'GT001');
    PERFORM pg_temp.verificar('El trabajador rechazado conserva su hilo para leerlo',
        (SELECT count(*) FROM fn_mensajes_de_solicitud(v_tr2, v_s) m) = 1
        AND EXISTS (SELECT 1 FROM fn_conversaciones(v_tr2) c WHERE c.solicitud_id = v_s AND NOT c.abierto));
    PERFORM pg_temp.verificar('Con el trabajo asignado, el cliente ya no necesita decir con quién habla',
        fn_enviar_mensaje(v_cl1, v_s, 'Quedamos entonces (texto de prueba)') IS NOT NULL);
    PERFORM pg_temp.verificar('Asignado, el trabajador ve al cliente con el nombre completo',
        (SELECT m.emisor_nombre FROM fn_mensajes_de_solicitud(v_tr1, v_s) m ORDER BY m.id DESC LIMIT 1) = 'Carlos Ejemplo');

    -- Retirar la propuesta o cancelar la solicitud cierra el hilo; reenviar lo vuelve a abrir
    v_s2 := fn_publicar_solicitud(v_cl1, pg_temp.ctx('oficio'), pg_temp.ctx('zacamil'), 'Cambiar foco del patio', 'Texto de prueba', 8.00, 'Dirección inventada, casa 32');
    v_o1 := fn_enviar_oferta(v_tr1, v_s2, 8.00, NULL);
    PERFORM fn_enviar_mensaje(v_tr1, v_s2, 'Buenas (texto de prueba)');
    PERFORM fn_retirar_oferta(v_tr1, v_o1);
    PERFORM pg_temp.verificar('Al retirar la propuesta el hilo queda de solo lectura',
        NOT (SELECT c.abierto FROM fn_conversaciones(v_tr1) c WHERE c.solicitud_id = v_s2)
        AND (SELECT count(*) FROM fn_mensajes_de_solicitud(v_tr1, v_s2) m) = 1);
    PERFORM fn_enviar_oferta(v_tr1, v_s2, 9.00, NULL);
    PERFORM pg_temp.verificar('Al reenviar la propuesta el hilo vuelve a abrirse',
        fn_enviar_mensaje(v_tr1, v_s2, 'Ya la reenvié (texto de prueba)') IS NOT NULL);
    PERFORM fn_cancelar_solicitud(v_cl1, v_s2);
    PERFORM pg_temp.espera('Al cancelar la solicitud el hilo deja de admitir mensajes: GT001', format($q$
        SELECT fn_enviar_mensaje(%s, %s, 'Hola')
    $q$, v_tr1, v_s2), 'GT001');
    PERFORM pg_temp.verificar('El hilo de una solicitud cancelada sigue en la lista, de solo lectura',
        EXISTS (SELECT 1 FROM fn_conversaciones(v_cl1) c WHERE c.solicitud_id = v_s2 AND NOT c.abierto AND c.ultimo_mensaje IS NOT NULL));
END $$;

-- Perfil y foto
DO $$
DECLARE
    v_mej      int := pg_temp.ctx('mejicanos');
    v_zac      int := pg_temp.ctx('zacamil');
    v_esc      int := pg_temp.ctx('escalon');
    v_mun_ss   int := (SELECT municipio_id FROM colonias WHERE id = pg_temp.ctx('escalon'));
    v_lourdes  int := (SELECT id FROM colonias WHERE nombre = 'Lourdes' AND municipio_id = pg_temp.ctx('mejicanos'));
    v_cl2      int := pg_temp.ctx('cl2');
    v_foto1    text := repeat('a1', 16) || '.jpg';
    v_foto2    text := repeat('b2', 16) || '.png';
    v_anterior text;
BEGIN
    PERFORM fn_actualizar_perfil(v_cl2, '  Diana Cambiada  ', '7000-0399', v_mej, v_lourdes);
    PERFORM pg_temp.verificar('El cliente cambia nombre, teléfono y colonia',
        EXISTS (SELECT 1 FROM usuarios
                 WHERE id = v_cl2 AND nombre = 'Diana Cambiada' AND telefono = '7000-0399' AND municipio_id = v_mej AND colonia_id = v_lourdes));
    PERFORM fn_actualizar_perfil(v_cl2, 'Diana Ejemplo', '7000-0302', v_mun_ss, v_esc);
    PERFORM pg_temp.verificar('El cliente se cambia a otro municipio con una colonia de ese municipio',
        EXISTS (SELECT 1 FROM usuarios WHERE id = v_cl2 AND municipio_id = v_mun_ss AND colonia_id = v_esc));
    PERFORM pg_temp.espera('Cliente con colonia de otro municipio: GT001', $q$
        SELECT fn_actualizar_perfil(pg_temp.ctx('cl2'), 'Diana Ejemplo', '7000-0302', pg_temp.ctx('mejicanos'), pg_temp.ctx('escalon'))
    $q$, 'GT001');
    PERFORM pg_temp.espera('Cliente sin colonia: GT001', $q$
        SELECT fn_actualizar_perfil(pg_temp.ctx('cl2'), 'Diana Ejemplo', '7000-0302', pg_temp.ctx('mejicanos'), NULL)
    $q$, 'GT001');
    PERFORM pg_temp.espera('Perfil con teléfono mal formado: GT001', $q$
        SELECT fn_actualizar_perfil(pg_temp.ctx('cl2'), 'Diana Ejemplo', '70000302', pg_temp.ctx('mejicanos'), pg_temp.ctx('zacamil'))
    $q$, 'GT001');
    PERFORM pg_temp.espera('Perfil sin nombre: GT001', $q$
        SELECT fn_actualizar_perfil(pg_temp.ctx('cl2'), '   ', '7000-0302', pg_temp.ctx('mejicanos'), pg_temp.ctx('zacamil'))
    $q$, 'GT001');
    PERFORM pg_temp.espera('Perfil con nombre de 101 caracteres: GT001', $q$
        SELECT fn_actualizar_perfil(pg_temp.ctx('cl2'), repeat('x', 101), '7000-0302', pg_temp.ctx('mejicanos'), pg_temp.ctx('zacamil'))
    $q$, 'GT001');
    PERFORM pg_temp.espera('Perfil con municipio inexistente: GT001', $q$
        SELECT fn_actualizar_perfil(pg_temp.ctx('cl2'), 'Diana Ejemplo', '7000-0302', -1, pg_temp.ctx('zacamil'))
    $q$, 'GT001');
    PERFORM pg_temp.espera('Un administrador no edita su perfil por esta vía: GT003', $q$
        SELECT fn_actualizar_perfil(pg_temp.ctx('admin'), 'X', '7000-0302', pg_temp.ctx('mejicanos'), pg_temp.ctx('zacamil'))
    $q$, 'GT003');

    PERFORM fn_actualizar_perfil(pg_temp.ctx('tr1'), 'Luis Flujo', '7000-0398', v_mej, v_zac);
    PERFORM pg_temp.verificar('El trabajador cambia sus datos, no guarda colonia propia y conserva sus colonias',
        EXISTS (SELECT 1 FROM usuarios WHERE id = pg_temp.ctx('tr1') AND telefono = '7000-0398' AND colonia_id IS NULL)
        AND (SELECT count(*) FROM trabajador_colonia WHERE usuario_id = pg_temp.ctx('tr1')) = 2);
    PERFORM fn_actualizar_perfil(pg_temp.ctx('tr3'), 'Mario Flujo', '7000-0313', v_mun_ss, NULL);
    PERFORM pg_temp.verificar('Si el trabajador cambia de municipio pierde las colonias del municipio anterior',
        EXISTS (SELECT 1 FROM usuarios WHERE id = pg_temp.ctx('tr3') AND municipio_id = v_mun_ss)
        AND NOT EXISTS (SELECT 1 FROM trabajador_colonia WHERE usuario_id = pg_temp.ctx('tr3')));
    PERFORM fn_reemplazar_colonias(pg_temp.ctx('tr3'), ARRAY[v_esc]);
    PERFORM pg_temp.verificar('Después elige colonias del municipio nuevo',
        (SELECT array_agg(colonia_id) FROM trabajador_colonia WHERE usuario_id = pg_temp.ctx('tr3')) = ARRAY[v_esc]);

    -- Foto
    v_anterior := fn_actualizar_foto(pg_temp.ctx('cl1'), v_foto1);
    PERFORM pg_temp.verificar('La primera foto se guarda y no hay foto anterior',
        v_anterior IS NULL AND (SELECT foto_ruta FROM usuarios WHERE id = pg_temp.ctx('cl1')) = v_foto1);
    v_anterior := fn_actualizar_foto(pg_temp.ctx('cl1'), v_foto2);
    PERFORM pg_temp.verificar('Cambiar la foto devuelve la anterior para borrarla',
        v_anterior = v_foto1 AND (SELECT foto_ruta FROM usuarios WHERE id = pg_temp.ctx('cl1')) = v_foto2);
    PERFORM pg_temp.espera('Foto con un nombre que no es un GUID: GT001', $q$
        SELECT fn_actualizar_foto(pg_temp.ctx('cl1'), 'foto.jpg')
    $q$, 'GT001');
    PERFORM pg_temp.espera('Foto con extensión no permitida: GT001', $q$
        SELECT fn_actualizar_foto(pg_temp.ctx('cl1'), repeat('a', 32) || '.gif')
    $q$, 'GT001');
    PERFORM pg_temp.espera('Foto con una carpeta en la ruta: GT001', $q$
        SELECT fn_actualizar_foto(pg_temp.ctx('cl1'), '../' || repeat('a', 32) || '.jpg')
    $q$, 'GT001');
    PERFORM pg_temp.espera('Un trabajador también cambia su foto', $q$
        SELECT fn_actualizar_foto(pg_temp.ctx('tr1'), repeat('c', 32) || '.png')
    $q$, 'ok');
    PERFORM pg_temp.espera('Un administrador no cambia foto por esta vía: GT003', $q$
        SELECT fn_actualizar_foto(pg_temp.ctx('admin'), repeat('a', 32) || '.jpg')
    $q$, 'GT003');
END $$;

-- Administración: catálogos, usuarios, suspensión y auditoría
DO $$
DECLARE
    v_adm      int := pg_temp.ctx('admin');
    v_lourdes  int := (SELECT id FROM colonias WHERE nombre = 'Lourdes' AND municipio_id = pg_temp.ctx('mejicanos'));
    v_id int; v_dep int; v_mun int; v_col int;
    v_r        record;
BEGIN
    -- Oficios
    v_id := fn_guardar_oficio(v_adm, NULL, '  Oficio de prueba  ', NULL);
    INSERT INTO contexto VALUES ('oficio_prueba', v_id);
    PERFORM pg_temp.verificar('El administrador crea un oficio activo',
        EXISTS (SELECT 1 FROM oficios WHERE id = v_id AND nombre = 'Oficio de prueba' AND activo));
    PERFORM fn_guardar_oficio(v_adm, v_id, NULL, false);
    PERFORM pg_temp.verificar('Desactivar un oficio conserva su nombre',
        EXISTS (SELECT 1 FROM oficios WHERE id = v_id AND nombre = 'Oficio de prueba' AND NOT activo));
    PERFORM fn_guardar_oficio(v_adm, v_id, 'Oficio de prueba editado', NULL);
    PERFORM pg_temp.verificar('Renombrar un oficio conserva su estado',
        EXISTS (SELECT 1 FROM oficios WHERE id = v_id AND nombre = 'Oficio de prueba editado' AND NOT activo));
    PERFORM pg_temp.espera('No se publica con un oficio desactivado: GT001', $q$
        SELECT fn_publicar_solicitud(pg_temp.ctx('cl1'), pg_temp.ctx('oficio_prueba'), pg_temp.ctx('zacamil'), 'T', 'D', 10, 'Dir')
    $q$, 'GT001');
    PERFORM pg_temp.espera('Crear un oficio repetido: GT001', $q$
        SELECT fn_guardar_oficio(pg_temp.ctx('admin'), NULL, 'Electricidad', NULL)
    $q$, 'GT001');
    PERFORM pg_temp.espera('Renombrar un oficio con un nombre repetido: GT001', $q$
        SELECT fn_guardar_oficio(pg_temp.ctx('admin'), pg_temp.ctx('oficio_prueba'), 'Electricidad', NULL)
    $q$, 'GT001');
    PERFORM pg_temp.espera('Crear un oficio sin nombre: GT001', $q$
        SELECT fn_guardar_oficio(pg_temp.ctx('admin'), NULL, NULL, NULL)
    $q$, 'GT001');
    PERFORM pg_temp.espera('Renombrar un oficio con un nombre vacío: GT001', $q$
        SELECT fn_guardar_oficio(pg_temp.ctx('admin'), pg_temp.ctx('oficio_prueba'), '  ', NULL)
    $q$, 'GT001');
    PERFORM pg_temp.espera('Oficio con nombre de 101 caracteres: GT001', $q$
        SELECT fn_guardar_oficio(pg_temp.ctx('admin'), NULL, repeat('x', 101), NULL)
    $q$, 'GT001');
    PERFORM pg_temp.espera('Editar un oficio inexistente: GT002', $q$
        SELECT fn_guardar_oficio(pg_temp.ctx('admin'), -1, 'Otro', NULL)
    $q$, 'GT002');
    PERFORM pg_temp.espera('Un cliente no administra oficios: GT003', $q$
        SELECT fn_guardar_oficio(pg_temp.ctx('cl1'), NULL, 'Otro', NULL)
    $q$, 'GT003');

    -- Departamentos
    v_dep := fn_guardar_departamento(v_adm, NULL, 'Departamento de prueba', NULL);
    INSERT INTO contexto VALUES ('dep_prueba', v_dep);
    PERFORM pg_temp.verificar('El administrador crea un departamento activo',
        EXISTS (SELECT 1 FROM departamentos WHERE id = v_dep AND nombre = 'Departamento de prueba' AND activo));
    PERFORM fn_guardar_departamento(v_adm, v_dep, 'Departamento de prueba editado', false);
    PERFORM pg_temp.verificar('Editar un departamento cambia nombre y estado',
        EXISTS (SELECT 1 FROM departamentos WHERE id = v_dep AND nombre = 'Departamento de prueba editado' AND NOT activo));
    PERFORM pg_temp.espera('Departamento repetido: GT001', $q$
        SELECT fn_guardar_departamento(pg_temp.ctx('admin'), NULL, 'San Salvador', NULL)
    $q$, 'GT001');
    PERFORM pg_temp.espera('Editar un departamento inexistente: GT002', $q$
        SELECT fn_guardar_departamento(pg_temp.ctx('admin'), -1, NULL, true)
    $q$, 'GT002');
    PERFORM pg_temp.espera('Un trabajador no administra departamentos: GT003', $q$
        SELECT fn_guardar_departamento(pg_temp.ctx('tr1'), NULL, 'Otro', NULL)
    $q$, 'GT003');

    -- Municipios
    v_mun := fn_guardar_municipio(v_adm, NULL, v_dep, 'Mejicanos', NULL);
    INSERT INTO contexto VALUES ('mun_prueba', v_mun);
    PERFORM pg_temp.verificar('Un nombre de municipio se puede repetir en otro departamento',
        EXISTS (SELECT 1 FROM municipios WHERE id = v_mun AND departamento_id = v_dep AND nombre = 'Mejicanos' AND activo));
    PERFORM fn_guardar_municipio(v_adm, v_mun, (SELECT id FROM departamentos WHERE nombre = 'San Salvador'), 'Municipio de prueba', false);
    PERFORM pg_temp.verificar('Editar un municipio cambia nombre y estado pero no su departamento',
        EXISTS (SELECT 1 FROM municipios WHERE id = v_mun AND departamento_id = v_dep AND nombre = 'Municipio de prueba' AND NOT activo));
    PERFORM pg_temp.espera('Municipio repetido en el mismo departamento: GT001', $q$
        SELECT fn_guardar_municipio(pg_temp.ctx('admin'), NULL,
               (SELECT departamento_id FROM municipios WHERE id = pg_temp.ctx('mejicanos')), 'Mejicanos', NULL)
    $q$, 'GT001');
    PERFORM pg_temp.espera('Municipio en un departamento inexistente: GT001', $q$
        SELECT fn_guardar_municipio(pg_temp.ctx('admin'), NULL, -1, 'Otro', NULL)
    $q$, 'GT001');
    PERFORM pg_temp.espera('Editar un municipio inexistente: GT002', $q$
        SELECT fn_guardar_municipio(pg_temp.ctx('admin'), -1, NULL, 'Otro', NULL)
    $q$, 'GT002');
    PERFORM pg_temp.espera('Un cliente no administra municipios: GT003', $q$
        SELECT fn_guardar_municipio(pg_temp.ctx('cl1'), NULL, pg_temp.ctx('dep_prueba'), 'Otro', NULL)
    $q$, 'GT003');

    -- Colonias
    v_col := fn_guardar_colonia(v_adm, NULL, v_mun, 'Colonia de prueba', NULL);
    PERFORM pg_temp.verificar('El administrador crea una colonia activa',
        EXISTS (SELECT 1 FROM colonias WHERE id = v_col AND municipio_id = v_mun AND nombre = 'Colonia de prueba' AND activo));
    PERFORM pg_temp.espera('Colonia repetida en el mismo municipio: GT001', $q$
        SELECT fn_guardar_colonia(pg_temp.ctx('admin'), NULL, pg_temp.ctx('mejicanos'), 'Zacamil', NULL)
    $q$, 'GT001');
    PERFORM pg_temp.espera('Colonia en un municipio inexistente: GT001', $q$
        SELECT fn_guardar_colonia(pg_temp.ctx('admin'), NULL, -1, 'Otra', NULL)
    $q$, 'GT001');
    PERFORM pg_temp.espera('Editar una colonia inexistente: GT002', $q$
        SELECT fn_guardar_colonia(pg_temp.ctx('admin'), -1, NULL, NULL, false)
    $q$, 'GT002');
    PERFORM pg_temp.espera('Un trabajador no administra colonias: GT003', $q$
        SELECT fn_guardar_colonia(pg_temp.ctx('tr1'), NULL, pg_temp.ctx('mejicanos'), 'Otra', NULL)
    $q$, 'GT003');
    PERFORM fn_guardar_colonia(v_adm, v_lourdes, NULL, NULL, false);
    PERFORM pg_temp.verificar('Desactivar una colonia no borra su historial',
        EXISTS (SELECT 1 FROM colonias WHERE id = v_lourdes AND nombre = 'Lourdes' AND NOT activo)
        AND EXISTS (SELECT 1 FROM trabajador_colonia WHERE colonia_id = v_lourdes AND usuario_id = pg_temp.ctx('tr1')));
    PERFORM pg_temp.espera('Un cliente no puede elegir una colonia desactivada: GT001', $q$
        SELECT fn_actualizar_perfil(pg_temp.ctx('cl1'), 'Carlos Ejemplo', '7000-0301', pg_temp.ctx('mejicanos'),
               (SELECT id FROM colonias WHERE nombre = 'Lourdes' AND municipio_id = pg_temp.ctx('mejicanos')))
    $q$, 'GT001');

    -- Buscar usuarios
    PERFORM pg_temp.verificar('Buscar por nombre no distingue mayúsculas',
        EXISTS (SELECT 1 FROM fn_buscar_usuarios(v_adm, 'CARLOS ejemplo') b WHERE b.id = pg_temp.ctx('cl1')));
    PERFORM pg_temp.verificar('Buscar por correo encuentra al usuario, con su rol, estado y promedio',
        EXISTS (SELECT 1 FROM fn_buscar_usuarios(v_adm, 'flujo.cliente1@') b
                 WHERE b.id = pg_temp.ctx('cl1') AND b.rol = 'cliente' AND b.estado = 'activo'
                   AND b.promedio_calificacion = 4.00 AND b.total_calificaciones = 1));
    PERFORM pg_temp.verificar('Sin texto la búsqueda trae usuarios, como máximo 100',
        EXISTS (SELECT 1 FROM fn_buscar_usuarios(v_adm, NULL)) AND EXISTS (SELECT 1 FROM fn_buscar_usuarios(v_adm, ''))
        AND (SELECT count(*) FROM fn_buscar_usuarios(v_adm, NULL)) <= 100);
    PERFORM pg_temp.verificar('% y _ se buscan como texto, no como comodines',
        NOT EXISTS (SELECT 1 FROM fn_buscar_usuarios(v_adm, '%'))
        AND NOT EXISTS (SELECT 1 FROM fn_buscar_usuarios(v_adm, 'flujo_cliente1')));
    PERFORM pg_temp.verificar('La búsqueda no trae correo, teléfono ni DUI',
        pg_get_function_result('fn_buscar_usuarios(integer, text)'::regprocedure) !~* 'correo|telefono|dui');
    UPDATE usuarios SET eliminado = true WHERE correo = 'cliente.nuevo@example.com';
    PERFORM pg_temp.verificar('La búsqueda no trae usuarios eliminados',
        NOT EXISTS (SELECT 1 FROM fn_buscar_usuarios(v_adm, 'cliente.nuevo@')));
    PERFORM pg_temp.espera('Un cliente no busca usuarios: GT003', $q$
        SELECT * FROM fn_buscar_usuarios(pg_temp.ctx('cl1'), NULL)
    $q$, 'GT003');

    -- Suspender y reactivar
    PERFORM fn_cambiar_estado_usuario(v_adm, pg_temp.ctx('cl2'), 'suspendido');
    PERFORM pg_temp.verificar('El administrador suspende una cuenta',
        EXISTS (SELECT 1 FROM usuarios WHERE id = pg_temp.ctx('cl2') AND estado = 'suspendido'));
    PERFORM pg_temp.espera('Un suspendido no publica: GT003', $q$
        SELECT fn_publicar_solicitud(pg_temp.ctx('cl2'), pg_temp.ctx('oficio'), pg_temp.ctx('zacamil'), 'T', 'D', 10, 'Dir')
    $q$, 'GT003');
    PERFORM pg_temp.espera('Un suspendido no edita su perfil: GT003', $q$
        SELECT fn_actualizar_perfil(pg_temp.ctx('cl2'), 'Diana Ejemplo', '7000-0302', pg_temp.ctx('mejicanos'), pg_temp.ctx('zacamil'))
    $q$, 'GT003');
    PERFORM pg_temp.espera('Un suspendido no sincroniza: GT003', $q$
        SELECT * FROM fn_sincronizar(pg_temp.ctx('cl2'), NULL)
    $q$, 'GT003');
    PERFORM fn_cambiar_estado_usuario(v_adm, pg_temp.ctx('cl2'), 'activo');
    PERFORM pg_temp.verificar('El administrador reactiva la cuenta',
        EXISTS (SELECT 1 FROM usuarios WHERE id = pg_temp.ctx('cl2') AND estado = 'activo'));
    PERFORM pg_temp.espera('Estado que no existe: GT001', $q$
        SELECT fn_cambiar_estado_usuario(pg_temp.ctx('admin'), pg_temp.ctx('cl2'), 'borrado')
    $q$, 'GT001');
    PERFORM pg_temp.espera('Suspender a un usuario inexistente: GT002', $q$
        SELECT fn_cambiar_estado_usuario(pg_temp.ctx('admin'), -1, 'suspendido')
    $q$, 'GT002');
    PERFORM pg_temp.espera('No se puede suspender a un administrador: GT001', $q$
        SELECT fn_cambiar_estado_usuario(pg_temp.ctx('admin'), pg_temp.ctx('admin'), 'suspendido')
    $q$, 'GT001');
    PERFORM pg_temp.espera('Un cliente no suspende cuentas: GT003', $q$
        SELECT fn_cambiar_estado_usuario(pg_temp.ctx('cl1'), pg_temp.ctx('cl2'), 'suspendido')
    $q$, 'GT003');

    -- Auditoría
    SELECT * INTO v_r FROM fn_auditoria_usuario(v_adm, pg_temp.ctx('cl1'));
    PERFORM pg_temp.verificar('La auditoría de un cliente trae correo, teléfono y zona con colonia',
        v_r.rol = 'cliente' AND v_r.nombre = 'Carlos Ejemplo' AND v_r.correo = 'flujo.cliente1@example.com'
        AND v_r.telefono = '7000-0301' AND v_r.dui IS NULL AND v_r.estado = 'activo'
        AND v_r.zona = 'San Salvador, Mejicanos, Col. Zacamil' AND v_r.fecha_registro IS NOT NULL);
    SELECT * INTO v_r FROM fn_auditoria_usuario(v_adm, pg_temp.ctx('tr2'));
    PERFORM pg_temp.verificar('La auditoría de un trabajador trae su DUI y la zona sin colonia',
        v_r.dui = '11111111-6' AND v_r.correo = 'flujo.trabajador2@example.com' AND v_r.zona = 'San Salvador, Mejicanos');
    SELECT * INTO v_r FROM fn_auditoria_usuario(v_adm, v_adm);
    PERFORM pg_temp.verificar('La auditoría de un administrador trae la zona en NULL',
        v_r.rol = 'administrador' AND v_r.zona IS NULL);
    PERFORM pg_temp.espera('Auditoría de un usuario inexistente: GT002', $q$
        SELECT * FROM fn_auditoria_usuario(pg_temp.ctx('admin'), -1)
    $q$, 'GT002');
    PERFORM pg_temp.espera('Un trabajador no ve la auditoría: GT003', $q$
        SELECT * FROM fn_auditoria_usuario(pg_temp.ctx('tr1'), pg_temp.ctx('cl1'))
    $q$, 'GT003');
END $$;

-- Reporte resumen (vw_reporte_resumen)
DO $$
DECLARE
    v_r record;
BEGIN
    SELECT * INTO v_r FROM vw_reporte_resumen;
    PERFORM pg_temp.verificar('El reporte resumen es una sola fila', (SELECT count(*) FROM vw_reporte_resumen) = 1);
    PERFORM pg_temp.verificar('El reporte cuenta las solicitudes por estado',
        v_r.total_solicitudes = (SELECT count(*) FROM solicitudes WHERE NOT eliminado)
        AND v_r.publicadas  = (SELECT count(*) FROM solicitudes WHERE NOT eliminado AND estado = 'publicada')
        AND v_r.asignadas   = (SELECT count(*) FROM solicitudes WHERE NOT eliminado AND estado = 'asignada')
        AND v_r.en_proceso  = (SELECT count(*) FROM solicitudes WHERE NOT eliminado AND estado = 'en_proceso')
        AND v_r.finalizadas = (SELECT count(*) FROM solicitudes WHERE NOT eliminado AND estado = 'finalizada')
        AND v_r.canceladas  = (SELECT count(*) FROM solicitudes WHERE NOT eliminado AND estado = 'cancelada')
        AND v_r.vencidas    = (SELECT count(*) FROM solicitudes WHERE NOT eliminado AND estado = 'vencida')
        AND v_r.total_solicitudes = v_r.publicadas + v_r.asignadas + v_r.en_proceso + v_r.finalizadas + v_r.canceladas + v_r.vencidas
        AND v_r.finalizadas >= 2 AND v_r.canceladas >= 2 AND v_r.vencidas >= 1);
    PERFORM pg_temp.verificar('El reporte trae el total y el promedio general de calificaciones',
        v_r.total_calificaciones = (SELECT count(*) FROM calificaciones)
        AND v_r.promedio_general = (SELECT avg(estrellas)::numeric(3,2) FROM calificaciones));
    PERFORM pg_temp.verificar('El reporte cuenta clientes, trabajadores y suspendidos',
        v_r.clientes = (SELECT count(*) FROM usuarios WHERE NOT eliminado AND rol = 'cliente')
        AND v_r.trabajadores = (SELECT count(*) FROM usuarios WHERE NOT eliminado AND rol = 'trabajador')
        AND v_r.suspendidos = (SELECT count(*) FROM usuarios WHERE NOT eliminado AND estado = 'suspendido'));
    PERFORM pg_temp.verificar('El reporte no tiene columnas de datos personales',
        NOT EXISTS (SELECT 1 FROM information_schema.columns
                     WHERE table_name = 'vw_reporte_resumen' AND column_name ~ 'correo|telefono|dui|direccion|nombre'));
END $$;

-- Un flujo completo con los permisos de gtr_api: ni las funciones ni los triggers deben chocar con permisos
DO $$
DECLARE
    v_cl      int := pg_temp.ctx('cl1');
    v_tr      int := pg_temp.ctx('tr5');
    v_tr2     int := pg_temp.ctx('tr2');
    v_adm     int := pg_temp.ctx('admin');
    v_elec    int := pg_temp.ctx('oficio');
    v_zac     int := pg_temp.ctx('zacamil');
    v_mej     int := pg_temp.ctx('mejicanos');
    v_avisos  int := (SELECT count(*) FROM avisos);
    v_s       int;
    v_o       int;
    v_error   text := 'ok';
BEGIN
    SET LOCAL ROLE gtr_api;
    BEGIN
        PERFORM set_config('app.usuario_id', v_cl::text, true);
        v_s := fn_publicar_solicitud(v_cl, v_elec, v_zac, 'Prueba de permisos', 'Texto de prueba', 10.00, 'Dirección inventada, casa 23');
        v_o := fn_enviar_oferta(v_tr, v_s, 9.00, NULL);
        PERFORM fn_enviar_oferta(v_tr2, v_s, 9.50, NULL);
        PERFORM fn_aceptar_oferta(v_cl, v_o);
        PERFORM * FROM fn_contacto_trabajo(v_cl, v_s);
        PERFORM fn_marcar_en_proceso(v_tr, v_s);
        PERFORM fn_enviar_mensaje(v_tr, v_s, 'Mensaje de prueba');
        PERFORM fn_enviar_mensaje(v_cl, v_s, 'Respuesta de prueba', v_tr);
        PERFORM * FROM fn_mensajes_de_solicitud(v_cl, v_s, NULL, v_tr);
        PERFORM * FROM fn_conversaciones(v_cl);
        PERFORM fn_marcar_avisos_leidos(v_cl, NULL, v_s, v_tr);
        PERFORM fn_finalizar_solicitud(v_cl, v_s);
        PERFORM fn_calificar(v_cl, v_s, 5, 'Comentario de prueba');
        PERFORM fn_calificar(v_tr, v_s, 5, 'Comentario de prueba');
        PERFORM * FROM fn_sincronizar(v_tr, NULL);
        PERFORM fn_marcar_avisos_leidos(v_tr);
        PERFORM fn_vencer_solicitudes();
        PERFORM fn_actualizar_perfil(v_tr, 'Raúl Flujo', '7000-0315', v_mej, NULL);
        PERFORM fn_actualizar_foto(v_tr, repeat('d', 32) || '.jpg');
        PERFORM fn_guardar_oficio(v_adm, NULL, 'Oficio de permisos', NULL);
        PERFORM * FROM fn_buscar_usuarios(v_adm, 'flujo');
        PERFORM fn_cambiar_estado_usuario(v_adm, v_tr2, 'suspendido');
        PERFORM * FROM fn_auditoria_usuario(v_adm, v_tr2);
        PERFORM * FROM vw_reporte_resumen;
        PERFORM set_config('app.usuario_id', '', true);
    EXCEPTION WHEN OTHERS THEN
        v_error := SQLSTATE || ' ' || SQLERRM;
    END;
    RESET ROLE;
    PERFORM pg_temp.verificar('Con los permisos de gtr_api el flujo completo corre sin errores'
        || CASE WHEN v_error = 'ok' THEN '' ELSE ' [' || v_error || ']' END, v_error = 'ok');
    PERFORM pg_temp.verificar('Con gtr_api los triggers escriben avisos y la bitácora con el usuario',
        (SELECT count(*) FROM avisos) > v_avisos
        AND (SELECT count(*) FROM bitacora WHERE solicitud_id = v_s AND usuario_id = v_cl) = 4);
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
    PERFORM pg_temp.verificar('gtr_api puede leer la vista pública de solicitudes',
        has_table_privilege('gtr_api', 'vw_solicitudes_publicas', 'SELECT'));
    PERFORM pg_temp.verificar('gtr_api puede leer el reporte resumen',
        has_table_privilege('gtr_api', 'vw_reporte_resumen', 'SELECT'));
    PERFORM pg_temp.verificar('gtr_api no puede escribir en las vistas',
        NOT has_table_privilege('gtr_api', 'vw_reporte_resumen', 'INSERT')
        AND NOT has_table_privilege('gtr_api', 'vw_reporte_resumen', 'UPDATE')
        AND NOT has_table_privilege('gtr_api', 'vw_solicitudes_publicas', 'INSERT'));
    PERFORM pg_temp.verificar('gtr_api puede insertar en avisos y bitácora (los triggers corren con sus permisos)',
        has_table_privilege('gtr_api', 'avisos', 'INSERT') AND has_table_privilege('gtr_api', 'bitacora', 'INSERT'));
    PERFORM pg_temp.verificar('gtr_api no puede borrar avisos, bitácora ni catálogos',
        NOT has_table_privilege('gtr_api', 'avisos', 'DELETE') AND NOT has_table_privilege('gtr_api', 'bitacora', 'DELETE')
        AND NOT has_table_privilege('gtr_api', 'oficios', 'DELETE') AND NOT has_table_privilege('gtr_api', 'colonias', 'DELETE'));
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
