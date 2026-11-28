-- 03_funciones.sql
-- Funciones de negocio. Idempotente (CREATE OR REPLACE).
-- Errores de negocio: GT001 regla incumplida (409), GT002 no encontrado (404), GT003 sin permiso (403).

-- Formato ########-# y dígito verificador: los dígitos 1 a 8 se multiplican por 9, 8, 7, 6, 5, 4, 3, 2,
-- se suman y el verificador es (10 - suma % 10) % 10.
CREATE OR REPLACE FUNCTION fn_validar_dui(p_dui text)
RETURNS boolean LANGUAGE plpgsql IMMUTABLE AS $$
DECLARE
    v_suma int := 0;
    i int;
BEGIN
    IF p_dui IS NULL OR p_dui !~ '^[0-9]{8}-[0-9]$' OR p_dui = '00000000-0' THEN
        RETURN false;
    END IF;
    FOR i IN 1..8 LOOP
        v_suma := v_suma + substr(p_dui, i, 1)::int * (10 - i);
    END LOOP;
    RETURN ((10 - (v_suma % 10)) % 10) = substr(p_dui, 10, 1)::int;
END $$;

-- Reemplaza los oficios de un trabajador. Lo usan el registro y PUT /perfil/oficios.
CREATE OR REPLACE FUNCTION fn_reemplazar_oficios(p_usuario_id int, p_oficios int[])
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM usuarios WHERE id = p_usuario_id AND rol = 'trabajador' AND NOT eliminado) THEN
        RAISE EXCEPTION 'Solo los trabajadores eligen oficios' USING ERRCODE = 'GT003';
    END IF;
    IF p_oficios IS NULL OR cardinality(p_oficios) = 0 THEN
        RAISE EXCEPTION 'Elige al menos un oficio' USING ERRCODE = 'GT001';
    END IF;
    IF (SELECT count(*) FROM oficios WHERE id = ANY (p_oficios) AND activo)
       <> (SELECT count(DISTINCT x) FROM unnest(p_oficios) AS x) THEN
        RAISE EXCEPTION 'Alguno de los oficios elegidos no existe o está inactivo' USING ERRCODE = 'GT001';
    END IF;

    DELETE FROM usuario_oficio WHERE usuario_id = p_usuario_id;
    INSERT INTO usuario_oficio (usuario_id, oficio_id)
    SELECT DISTINCT p_usuario_id, x FROM unnest(p_oficios) AS x WHERE x IS NOT NULL;
END $$;

-- Reemplaza las colonias donde trabaja un trabajador. Deben ser de su municipio.
CREATE OR REPLACE FUNCTION fn_reemplazar_colonias(p_usuario_id int, p_colonias int[])
RETURNS void LANGUAGE plpgsql AS $$
DECLARE
    v_municipio_id int;
BEGIN
    SELECT municipio_id INTO v_municipio_id
      FROM usuarios WHERE id = p_usuario_id AND rol = 'trabajador' AND NOT eliminado;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Solo los trabajadores eligen colonias de trabajo' USING ERRCODE = 'GT003';
    END IF;
    IF p_colonias IS NULL OR cardinality(p_colonias) = 0 THEN
        RAISE EXCEPTION 'Elige al menos una colonia donde trabajas' USING ERRCODE = 'GT001';
    END IF;
    IF (SELECT count(*) FROM colonias WHERE id = ANY (p_colonias) AND municipio_id = v_municipio_id AND activo)
       <> (SELECT count(DISTINCT x) FROM unnest(p_colonias) AS x) THEN
        RAISE EXCEPTION 'Alguna de las colonias elegidas no existe o no es de tu municipio' USING ERRCODE = 'GT001';
    END IF;

    DELETE FROM trabajador_colonia WHERE usuario_id = p_usuario_id;
    INSERT INTO trabajador_colonia (usuario_id, colonia_id)
    SELECT DISTINCT p_usuario_id, x FROM unnest(p_colonias) AS x WHERE x IS NOT NULL;
END $$;

-- Registro público de clientes y trabajadores. La API manda la contraseña ya con BCrypt.
-- Si algo falla se deshace todo, incluido el usuario recién insertado.
CREATE OR REPLACE FUNCTION fn_registrar_usuario(
    p_rol            text,
    p_nombre         text,
    p_correo         text,
    p_password_hash  text,
    p_telefono       text,
    p_dui            text,
    p_municipio_id   int,
    p_colonia_id     int,
    p_oficios        int[],
    p_colonias       int[])
RETURNS int LANGUAGE plpgsql AS $$
DECLARE
    v_id          int;
    v_restriccion text;
BEGIN
    IF p_rol IS NULL OR p_rol NOT IN ('cliente', 'trabajador') THEN
        RAISE EXCEPTION 'El tipo de cuenta no es válido' USING ERRCODE = 'GT001';
    END IF;
    IF p_nombre IS NULL OR char_length(btrim(p_nombre)) NOT BETWEEN 1 AND 100 THEN
        RAISE EXCEPTION 'El nombre es obligatorio y no puede pasar de 100 caracteres' USING ERRCODE = 'GT001';
    END IF;
    IF p_correo IS NULL OR btrim(p_correo) !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' THEN
        RAISE EXCEPTION 'El correo no tiene un formato válido' USING ERRCODE = 'GT001';
    END IF;
    IF p_telefono IS NULL OR p_telefono !~ '^[0-9]{4}-[0-9]{4}$' THEN
        RAISE EXCEPTION 'El teléfono debe tener el formato 0000-0000' USING ERRCODE = 'GT001';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM municipios WHERE id = p_municipio_id AND activo) THEN
        RAISE EXCEPTION 'El municipio elegido no es válido' USING ERRCODE = 'GT001';
    END IF;
    IF p_rol = 'cliente'
       AND NOT EXISTS (SELECT 1 FROM colonias WHERE id = p_colonia_id AND municipio_id = p_municipio_id AND activo) THEN
        RAISE EXCEPTION 'La colonia elegida no es válida para ese municipio' USING ERRCODE = 'GT001';
    END IF;
    IF p_rol = 'trabajador' AND NOT fn_validar_dui(p_dui) THEN
        RAISE EXCEPTION 'El DUI no es válido' USING ERRCODE = 'GT001';
    END IF;

    BEGIN
        INSERT INTO usuarios (rol, nombre, correo, password_hash, telefono, dui, municipio_id, colonia_id)
        VALUES (p_rol, btrim(p_nombre), btrim(p_correo), p_password_hash, p_telefono,
                CASE WHEN p_rol = 'trabajador' THEN p_dui END,
                p_municipio_id,
                CASE WHEN p_rol = 'cliente' THEN p_colonia_id END)
        RETURNING id INTO v_id;
    EXCEPTION WHEN unique_violation THEN
        GET STACKED DIAGNOSTICS v_restriccion = CONSTRAINT_NAME;
        IF v_restriccion = 'ix_usuarios_correo' THEN
            RAISE EXCEPTION 'Ya existe una cuenta con ese correo' USING ERRCODE = 'GT001';
        END IF;
        RAISE EXCEPTION 'Ya existe un trabajador registrado con ese DUI' USING ERRCODE = 'GT001';
    END;

    IF p_rol = 'trabajador' THEN
        PERFORM fn_reemplazar_oficios(v_id, p_oficios);
        PERFORM fn_reemplazar_colonias(v_id, p_colonias);
    END IF;
    RETURN v_id;
END $$;

-- La API la llama al arrancar con el correo y la clave del administrador tomados de la configuración.
-- Devuelve true si creó la cuenta y false si ya existía. No cambia la contraseña de una cuenta existente.
CREATE OR REPLACE FUNCTION fn_asegurar_administrador(p_nombre text, p_correo text, p_password_hash text)
RETURNS boolean LANGUAGE plpgsql AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM usuarios WHERE rol = 'administrador' AND lower(correo) = lower(btrim(p_correo))) THEN
        RETURN false;
    END IF;
    INSERT INTO usuarios (rol, nombre, correo, password_hash)
    VALUES ('administrador', btrim(p_nombre), btrim(p_correo), p_password_hash);
    RETURN true;
END $$;

-- Nombre abreviado para mostrar a la otra parte: "María Ejemplo" se muestra como "María E."
CREATE OR REPLACE FUNCTION fn_nombre_corto(p_nombre text)
RETURNS text LANGUAGE sql IMMUTABLE AS $$
    SELECT CASE WHEN a[2] IS NULL THEN a[1] ELSE a[1] || ' ' || left(a[2], 1) || '.' END
      FROM (SELECT regexp_split_to_array(btrim(p_nombre), '\s+') AS a) AS x
$$;

-- Publica una solicitud. La colonia puede ser distinta a la del perfil del cliente.
CREATE OR REPLACE FUNCTION fn_publicar_solicitud(
    p_cliente_id   int,
    p_oficio_id    int,
    p_colonia_id   int,
    p_titulo       text,
    p_descripcion  text,
    p_presupuesto  numeric,
    p_direccion    text)
RETURNS int LANGUAGE plpgsql AS $$
DECLARE
    v_id int;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM usuarios WHERE id = p_cliente_id AND rol = 'cliente' AND estado = 'activo' AND NOT eliminado) THEN
        RAISE EXCEPTION 'Solo los clientes con cuenta activa publican solicitudes' USING ERRCODE = 'GT003';
    END IF;
    IF p_titulo IS NULL OR char_length(btrim(p_titulo)) NOT BETWEEN 1 AND 100 THEN
        RAISE EXCEPTION 'El título es obligatorio y no puede pasar de 100 caracteres' USING ERRCODE = 'GT001';
    END IF;
    IF p_descripcion IS NULL OR char_length(btrim(p_descripcion)) NOT BETWEEN 1 AND 1000 THEN
        RAISE EXCEPTION 'La descripción es obligatoria y no puede pasar de 1000 caracteres' USING ERRCODE = 'GT001';
    END IF;
    IF p_presupuesto IS NULL OR p_presupuesto <= 0 OR p_presupuesto > 99999999.99 THEN
        RAISE EXCEPTION 'El presupuesto debe estar entre $0.01 y $99999999.99' USING ERRCODE = 'GT001';
    END IF;
    IF p_direccion IS NULL OR char_length(btrim(p_direccion)) NOT BETWEEN 1 AND 200 THEN
        RAISE EXCEPTION 'La dirección es obligatoria y no puede pasar de 200 caracteres' USING ERRCODE = 'GT001';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM oficios WHERE id = p_oficio_id AND activo) THEN
        RAISE EXCEPTION 'El oficio elegido no es válido' USING ERRCODE = 'GT001';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM colonias WHERE id = p_colonia_id AND activo) THEN
        RAISE EXCEPTION 'La colonia elegida no es válida' USING ERRCODE = 'GT001';
    END IF;

    INSERT INTO solicitudes (cliente_id, oficio_id, colonia_id, titulo, descripcion, presupuesto, direccion_exacta)
    VALUES (p_cliente_id, p_oficio_id, p_colonia_id, btrim(p_titulo), btrim(p_descripcion), p_presupuesto, btrim(p_direccion))
    RETURNING id INTO v_id;
    RETURN v_id;
END $$;

-- Solicitudes publicadas del municipio del trabajador, en sus colonias y oficios.
-- No devuelve teléfono ni dirección, y el nombre del cliente sale abreviado.
CREATE OR REPLACE FUNCTION fn_trabajos_por_zona(p_trabajador_id int, p_oficio_id int DEFAULT NULL)
RETURNS TABLE (
    id                    int,
    titulo                text,
    oficio                text,
    presupuesto           numeric,
    zona                  text,
    cliente_nombre        text,
    publicada_hace_horas  int,
    ya_propuse            boolean)
LANGUAGE plpgsql STABLE AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.id = p_trabajador_id AND u.rol = 'trabajador' AND u.estado = 'activo' AND NOT u.eliminado) THEN
        RAISE EXCEPTION 'Solo los trabajadores con cuenta activa ven los trabajos de su zona' USING ERRCODE = 'GT003';
    END IF;

    RETURN QUERY
    SELECT s.id,
           s.titulo,
           o.nombre,
           s.presupuesto,
           m.nombre || ', Col. ' || c.nombre,
           fn_nombre_corto(cl.nombre),
           floor(extract(epoch FROM now() - s.fecha_publicacion) / 3600)::int,
           EXISTS (SELECT 1 FROM ofertas f
                    WHERE f.solicitud_id = s.id AND f.trabajador_id = p_trabajador_id
                      AND f.estado IN ('pendiente', 'aceptada'))
      FROM usuarios t
      JOIN trabajador_colonia tc ON tc.usuario_id = t.id
      JOIN usuario_oficio uo ON uo.usuario_id = t.id
      JOIN solicitudes s ON s.colonia_id = tc.colonia_id AND s.oficio_id = uo.oficio_id
      JOIN colonias c ON c.id = s.colonia_id AND c.municipio_id = t.municipio_id
      JOIN municipios m ON m.id = c.municipio_id
      JOIN oficios o ON o.id = s.oficio_id
      JOIN usuarios cl ON cl.id = s.cliente_id
     WHERE t.id = p_trabajador_id
       AND s.estado = 'publicada' AND NOT s.eliminado
       AND (p_oficio_id IS NULL OR s.oficio_id = p_oficio_id)
     ORDER BY s.fecha_publicacion DESC;
END $$;

-- La solicitud está en el municipio del trabajador, en una de sus colonias y en uno de sus oficios.
CREATE OR REPLACE FUNCTION fn_en_zona_del_trabajador(p_trabajador_id int, p_solicitud_id int)
RETURNS boolean LANGUAGE sql STABLE AS $$
    SELECT EXISTS (
        SELECT 1
          FROM usuarios t
          JOIN trabajador_colonia tc ON tc.usuario_id = t.id
          JOIN usuario_oficio uo ON uo.usuario_id = t.id
          JOIN solicitudes s ON s.id = p_solicitud_id AND s.colonia_id = tc.colonia_id AND s.oficio_id = uo.oficio_id
          JOIN colonias c ON c.id = s.colonia_id AND c.municipio_id = t.municipio_id
         WHERE t.id = p_trabajador_id AND t.rol = 'trabajador')
$$;

-- Envía una propuesta. Si el trabajador la había retirado, se reactiva la misma con el nuevo precio.
CREATE OR REPLACE FUNCTION fn_enviar_oferta(p_trabajador_id int, p_solicitud_id int, p_precio numeric, p_mensaje text)
RETURNS int LANGUAGE plpgsql AS $$
DECLARE
    v_estado         text;
    v_oferta_id      int;
    v_estado_oferta  text;
    v_mensaje        text := NULLIF(btrim(p_mensaje), '');
BEGIN
    IF NOT EXISTS (SELECT 1 FROM usuarios WHERE id = p_trabajador_id AND rol = 'trabajador' AND estado = 'activo' AND NOT eliminado) THEN
        RAISE EXCEPTION 'Solo los trabajadores con cuenta activa envían propuestas' USING ERRCODE = 'GT003';
    END IF;
    IF p_precio IS NULL OR p_precio <= 0 OR p_precio > 99999999.99 THEN
        RAISE EXCEPTION 'El precio debe estar entre $0.01 y $99999999.99' USING ERRCODE = 'GT001';
    END IF;
    IF char_length(v_mensaje) > 300 THEN
        RAISE EXCEPTION 'El mensaje no puede pasar de 300 caracteres' USING ERRCODE = 'GT001';
    END IF;

    -- FOR SHARE hace esperar a una aceptación o cancelación en curso y evita propuestas fuera de tiempo
    SELECT estado INTO v_estado
      FROM solicitudes WHERE id = p_solicitud_id AND NOT eliminado FOR SHARE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'La solicitud no existe' USING ERRCODE = 'GT002';
    END IF;
    IF NOT fn_en_zona_del_trabajador(p_trabajador_id, p_solicitud_id) THEN
        RAISE EXCEPTION 'Esta solicitud no está en tu zona u oficios' USING ERRCODE = 'GT003';
    END IF;
    IF v_estado <> 'publicada' THEN
        RAISE EXCEPTION 'La solicitud ya no está disponible para enviar propuestas' USING ERRCODE = 'GT001';
    END IF;

    SELECT id, estado INTO v_oferta_id, v_estado_oferta
      FROM ofertas WHERE solicitud_id = p_solicitud_id AND trabajador_id = p_trabajador_id
     ORDER BY (estado IN ('pendiente', 'aceptada')) DESC, fecha DESC LIMIT 1;
    IF FOUND THEN
        IF v_estado_oferta IN ('pendiente', 'aceptada') THEN
            RAISE EXCEPTION 'Ya enviaste una propuesta para esta solicitud' USING ERRCODE = 'GT001';
        ELSIF v_estado_oferta = 'rechazada' THEN
            RAISE EXCEPTION 'El cliente ya rechazó tu propuesta para esta solicitud' USING ERRCODE = 'GT001';
        END IF;
        UPDATE ofertas SET estado = 'pendiente', precio = p_precio, mensaje = v_mensaje, fecha = now()
         WHERE id = v_oferta_id;
        RETURN v_oferta_id;
    END IF;

    BEGIN
        INSERT INTO ofertas (solicitud_id, trabajador_id, precio, mensaje)
        VALUES (p_solicitud_id, p_trabajador_id, p_precio, v_mensaje)
        RETURNING id INTO v_oferta_id;
    EXCEPTION WHEN unique_violation THEN
        RAISE EXCEPTION 'Ya enviaste una propuesta para esta solicitud' USING ERRCODE = 'GT001';
    END;
    RETURN v_oferta_id;
END $$;

-- El trabajador retira su propuesta mientras siga pendiente.
CREATE OR REPLACE FUNCTION fn_retirar_oferta(p_trabajador_id int, p_oferta_id int)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE
    v_solicitud_id   int;
    v_trabajador_id  int;
BEGIN
    SELECT solicitud_id, trabajador_id INTO v_solicitud_id, v_trabajador_id FROM ofertas WHERE id = p_oferta_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'La propuesta no existe' USING ERRCODE = 'GT002';
    END IF;
    IF v_trabajador_id <> p_trabajador_id THEN
        RAISE EXCEPTION 'No tienes permiso sobre esta propuesta' USING ERRCODE = 'GT003';
    END IF;

    -- mismo orden de bloqueo que fn_aceptar_oferta: primero la solicitud
    PERFORM 1 FROM solicitudes WHERE id = v_solicitud_id FOR UPDATE;
    UPDATE ofertas SET estado = 'retirada' WHERE id = p_oferta_id AND estado = 'pendiente';
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Solo puedes retirar propuestas pendientes' USING ERRCODE = 'GT001';
    END IF;
END $$;

-- El dueño de la solicitud rechaza una propuesta pendiente.
CREATE OR REPLACE FUNCTION fn_rechazar_oferta(p_cliente_id int, p_oferta_id int)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE
    v_solicitud_id  int;
    v_cliente_id    int;
BEGIN
    SELECT solicitud_id INTO v_solicitud_id FROM ofertas WHERE id = p_oferta_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'La propuesta no existe o ya no está pendiente' USING ERRCODE = 'GT002';
    END IF;

    SELECT cliente_id INTO v_cliente_id FROM solicitudes WHERE id = v_solicitud_id AND NOT eliminado FOR UPDATE;
    IF NOT FOUND OR v_cliente_id <> p_cliente_id THEN
        RAISE EXCEPTION 'No tienes permiso sobre esta solicitud' USING ERRCODE = 'GT003';
    END IF;

    UPDATE ofertas SET estado = 'rechazada' WHERE id = p_oferta_id AND estado = 'pendiente';
    IF NOT FOUND THEN
        RAISE EXCEPTION 'La propuesta no existe o ya no está pendiente' USING ERRCODE = 'GT002';
    END IF;
END $$;

-- Acepta una propuesta: asigna el trabajo y rechaza las demás, todo junto.
-- Bloquea la solicitud para que dos aceptaciones no se pisen y, ya con el bloqueo, confirma que
-- la propuesta siga pendiente (el trabajador pudo retirarla un instante antes).
CREATE OR REPLACE FUNCTION fn_aceptar_oferta(p_cliente_id int, p_oferta_id int)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE
    v_solicitud_id   int;
    v_trabajador_id  int;
    v_cliente_id     int;
    v_estado         text;
BEGIN
    SELECT solicitud_id INTO v_solicitud_id FROM ofertas WHERE id = p_oferta_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'La propuesta no existe o ya no está pendiente' USING ERRCODE = 'GT002';
    END IF;

    SELECT cliente_id, estado INTO v_cliente_id, v_estado
      FROM solicitudes WHERE id = v_solicitud_id AND NOT eliminado FOR UPDATE;
    IF NOT FOUND OR v_cliente_id <> p_cliente_id THEN
        RAISE EXCEPTION 'No tienes permiso sobre esta solicitud' USING ERRCODE = 'GT003';
    END IF;

    SELECT trabajador_id INTO v_trabajador_id FROM ofertas WHERE id = p_oferta_id AND estado = 'pendiente';
    IF NOT FOUND THEN
        RAISE EXCEPTION 'La propuesta no existe o ya no está pendiente' USING ERRCODE = 'GT002';
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

-- Detalle de una solicitud, sin dirección ni datos de contacto (sale de vw_solicitudes_publicas, en 05_vistas.sql).
-- Lo ve el cliente dueño, y un trabajador que la tiene en su zona y oficios mientras está publicada, que le
-- envió propuesta o que es el asignado. Para el dueño el nombre del cliente sale completo y trae el número de
-- propuestas; para el trabajador sale abreviado y trae su propia propuesta. El nombre y el id del trabajador
-- asignado solo los ven el dueño y ese trabajador. ya_califique indica si el usuario ya calificó el trabajo.
-- Se borra antes de crearla porque cambiaron sus columnas de salida.
DROP FUNCTION IF EXISTS fn_detalle_solicitud(int, int);
CREATE OR REPLACE FUNCTION fn_detalle_solicitud(p_usuario_id int, p_solicitud_id int)
RETURNS TABLE (
    id                   int,
    titulo               text,
    descripcion          text,
    oficio               text,
    zona                 text,
    presupuesto          numeric,
    estado               text,
    fecha_publicacion    timestamptz,
    cliente_id           int,
    cliente_nombre       text,
    trabajador_nombre    text,
    propuestas           int,
    mi_propuesta_id      int,
    mi_propuesta_precio  numeric,
    mi_propuesta_estado  text,
    trabajador_id        int,
    ya_califique         boolean)
LANGUAGE plpgsql STABLE AS $$
DECLARE
    v_cliente_id     int;
    v_trabajador_id  int;
    v_estado         text;
    v_es_dueno       boolean;
BEGIN
    SELECT s.cliente_id, s.trabajador_id, s.estado INTO v_cliente_id, v_trabajador_id, v_estado
      FROM solicitudes s WHERE s.id = p_solicitud_id AND NOT s.eliminado;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'La solicitud no existe' USING ERRCODE = 'GT002';
    END IF;

    v_es_dueno := v_cliente_id = p_usuario_id;
    IF NOT v_es_dueno
       AND v_trabajador_id IS DISTINCT FROM p_usuario_id
       AND NOT EXISTS (SELECT 1 FROM ofertas f WHERE f.solicitud_id = p_solicitud_id AND f.trabajador_id = p_usuario_id)
       AND NOT (v_estado = 'publicada' AND fn_en_zona_del_trabajador(p_usuario_id, p_solicitud_id)) THEN
        RAISE EXCEPTION 'No tienes permiso para ver esta solicitud' USING ERRCODE = 'GT003';
    END IF;

    RETURN QUERY
    SELECT v.id, v.titulo, v.descripcion, v.oficio, v.zona, v.presupuesto, v.estado, v.fecha_publicacion,
           v.cliente_id,
           CASE WHEN v_es_dueno THEN v.cliente_nombre ELSE fn_nombre_corto(v.cliente_nombre) END,
           CASE WHEN v_es_dueno OR v.trabajador_id = p_usuario_id THEN v.trabajador_nombre END,
           CASE WHEN v_es_dueno THEN
               (SELECT count(*)::int FROM ofertas f WHERE f.solicitud_id = v.id AND f.estado <> 'retirada')
           END,
           mia.id, mia.precio, mia.estado,
           CASE WHEN v_es_dueno OR v.trabajador_id = p_usuario_id THEN v.trabajador_id END,
           EXISTS (SELECT 1 FROM calificaciones k WHERE k.solicitud_id = v.id AND k.calificador_id = p_usuario_id)
      FROM vw_solicitudes_publicas v
      LEFT JOIN LATERAL (
            SELECT f.id, f.precio, f.estado
              FROM ofertas f
             WHERE f.solicitud_id = v.id AND f.trabajador_id = p_usuario_id
             ORDER BY f.fecha DESC
             LIMIT 1) AS mia ON true
     WHERE v.id = p_solicitud_id;
END $$;

-- Propuestas de una solicitud para su dueño, con el promedio del trabajador. No incluye las retiradas.
CREATE OR REPLACE FUNCTION fn_propuestas_de_solicitud(p_cliente_id int, p_solicitud_id int)
RETURNS TABLE (
    id                     int,
    trabajador_id          int,
    trabajador_nombre      text,
    promedio_calificacion  numeric,
    total_calificaciones   int,
    precio                 numeric,
    mensaje                text,
    estado                 text,
    fecha                  timestamptz)
LANGUAGE plpgsql STABLE AS $$
DECLARE
    v_cliente_id int;
BEGIN
    SELECT s.cliente_id INTO v_cliente_id FROM solicitudes s WHERE s.id = p_solicitud_id AND NOT s.eliminado;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'La solicitud no existe' USING ERRCODE = 'GT002';
    END IF;
    IF v_cliente_id <> p_cliente_id THEN
        RAISE EXCEPTION 'No tienes permiso sobre esta solicitud' USING ERRCODE = 'GT003';
    END IF;

    RETURN QUERY
    SELECT f.id, f.trabajador_id, u.nombre, u.promedio_calificacion, u.total_calificaciones,
           f.precio, f.mensaje, f.estado, f.fecha
      FROM ofertas f
      JOIN usuarios u ON u.id = f.trabajador_id
     WHERE f.solicitud_id = p_solicitud_id AND f.estado <> 'retirada'
     ORDER BY (f.estado = 'pendiente') DESC, f.precio, f.fecha;
END $$;

-- Tanda 3: perfil

-- Actualiza nombre, teléfono y zona. El cliente lleva una colonia de su municipio; el trabajador no lleva
-- colonia propia, y si cambia de municipio pierde las colonias de trabajo que no son del municipio nuevo.
CREATE OR REPLACE FUNCTION fn_actualizar_perfil(
    p_usuario_id    int,
    p_nombre        text,
    p_telefono      text,
    p_municipio_id  int,
    p_colonia_id    int)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE
    v_rol text;
BEGIN
    SELECT rol INTO v_rol
      FROM usuarios
     WHERE id = p_usuario_id AND rol IN ('cliente', 'trabajador') AND estado = 'activo' AND NOT eliminado
       FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Solo los clientes y trabajadores con cuenta activa editan su perfil' USING ERRCODE = 'GT003';
    END IF;
    IF p_nombre IS NULL OR char_length(btrim(p_nombre)) NOT BETWEEN 1 AND 100 THEN
        RAISE EXCEPTION 'El nombre es obligatorio y no puede pasar de 100 caracteres' USING ERRCODE = 'GT001';
    END IF;
    IF p_telefono IS NULL OR p_telefono !~ '^[0-9]{4}-[0-9]{4}$' THEN
        RAISE EXCEPTION 'El teléfono debe tener el formato 0000-0000' USING ERRCODE = 'GT001';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM municipios WHERE id = p_municipio_id AND activo) THEN
        RAISE EXCEPTION 'El municipio elegido no es válido' USING ERRCODE = 'GT001';
    END IF;
    IF v_rol = 'cliente'
       AND NOT EXISTS (SELECT 1 FROM colonias WHERE id = p_colonia_id AND municipio_id = p_municipio_id AND activo) THEN
        RAISE EXCEPTION 'La colonia elegida no es válida para ese municipio' USING ERRCODE = 'GT001';
    END IF;

    UPDATE usuarios
       SET nombre = btrim(p_nombre),
           telefono = p_telefono,
           municipio_id = p_municipio_id,
           colonia_id = CASE WHEN v_rol = 'cliente' THEN p_colonia_id END
     WHERE id = p_usuario_id;

    IF v_rol = 'trabajador' THEN
        DELETE FROM trabajador_colonia tc
         USING colonias c
         WHERE tc.usuario_id = p_usuario_id AND c.id = tc.colonia_id AND c.municipio_id <> p_municipio_id;
    END IF;
END $$;

-- Guarda el nombre de archivo de la foto de perfil y devuelve el anterior (o NULL) para que la API lo borre.
CREATE OR REPLACE FUNCTION fn_actualizar_foto(p_usuario_id int, p_foto_ruta text)
RETURNS text LANGUAGE plpgsql AS $$
DECLARE
    v_anterior text;
BEGIN
    SELECT foto_ruta INTO v_anterior
      FROM usuarios
     WHERE id = p_usuario_id AND rol IN ('cliente', 'trabajador') AND estado = 'activo' AND NOT eliminado
       FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Solo los clientes y trabajadores con cuenta activa cambian su foto' USING ERRCODE = 'GT003';
    END IF;
    IF p_foto_ruta IS NULL OR p_foto_ruta !~ '^[0-9a-f]{32}\.(jpg|png)$' THEN
        RAISE EXCEPTION 'El nombre del archivo de la foto no es válido' USING ERRCODE = 'GT001';
    END IF;

    UPDATE usuarios SET foto_ruta = p_foto_ruta WHERE id = p_usuario_id;
    RETURN v_anterior;
END $$;

-- Tanda 5: seguimiento

-- El usuario existe, no está eliminado y su cuenta está activa.
CREATE OR REPLACE FUNCTION fn_usuario_activo(p_usuario_id int)
RETURNS boolean LANGUAGE sql STABLE AS $$
    SELECT EXISTS (SELECT 1 FROM usuarios WHERE id = p_usuario_id AND estado = 'activo' AND NOT eliminado)
$$;

-- El dueño cancela una solicitud publicada o asignada. Las propuestas pendientes pasan a rechazadas;
-- la aceptada y el trabajador asignado se conservan como historial.
CREATE OR REPLACE FUNCTION fn_cancelar_solicitud(p_cliente_id int, p_solicitud_id int)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE
    v_cliente_id  int;
    v_estado      text;
BEGIN
    SELECT cliente_id, estado INTO v_cliente_id, v_estado
      FROM solicitudes WHERE id = p_solicitud_id AND NOT eliminado FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'La solicitud no existe' USING ERRCODE = 'GT002';
    END IF;
    IF v_cliente_id <> p_cliente_id OR NOT fn_usuario_activo(p_cliente_id) THEN
        RAISE EXCEPTION 'No tienes permiso sobre esta solicitud' USING ERRCODE = 'GT003';
    END IF;
    IF v_estado NOT IN ('publicada', 'asignada') THEN
        RAISE EXCEPTION 'Solo se puede cancelar una solicitud publicada o asignada' USING ERRCODE = 'GT001';
    END IF;

    UPDATE ofertas SET estado = 'rechazada' WHERE solicitud_id = p_solicitud_id AND estado = 'pendiente';
    UPDATE solicitudes SET estado = 'cancelada' WHERE id = p_solicitud_id;
END $$;

-- El trabajador asignado avisa que empezó el trabajo.
CREATE OR REPLACE FUNCTION fn_marcar_en_proceso(p_trabajador_id int, p_solicitud_id int)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE
    v_trabajador_id  int;
    v_estado         text;
BEGIN
    SELECT trabajador_id, estado INTO v_trabajador_id, v_estado
      FROM solicitudes WHERE id = p_solicitud_id AND NOT eliminado FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'La solicitud no existe' USING ERRCODE = 'GT002';
    END IF;
    IF v_trabajador_id IS DISTINCT FROM p_trabajador_id OR NOT fn_usuario_activo(p_trabajador_id) THEN
        RAISE EXCEPTION 'Solo el trabajador asignado puede marcar el trabajo en proceso' USING ERRCODE = 'GT003';
    END IF;
    IF v_estado <> 'asignada' THEN
        RAISE EXCEPTION 'Solo se puede marcar en proceso un trabajo asignado' USING ERRCODE = 'GT001';
    END IF;

    UPDATE solicitudes SET estado = 'en_proceso' WHERE id = p_solicitud_id;
END $$;

-- El dueño confirma que el trabajo terminó.
CREATE OR REPLACE FUNCTION fn_finalizar_solicitud(p_cliente_id int, p_solicitud_id int)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE
    v_cliente_id  int;
    v_estado      text;
BEGIN
    SELECT cliente_id, estado INTO v_cliente_id, v_estado
      FROM solicitudes WHERE id = p_solicitud_id AND NOT eliminado FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'La solicitud no existe' USING ERRCODE = 'GT002';
    END IF;
    IF v_cliente_id <> p_cliente_id OR NOT fn_usuario_activo(p_cliente_id) THEN
        RAISE EXCEPTION 'No tienes permiso sobre esta solicitud' USING ERRCODE = 'GT003';
    END IF;
    IF v_estado <> 'en_proceso' THEN
        RAISE EXCEPTION 'Solo se puede confirmar un trabajo que está en proceso' USING ERRCODE = 'GT001';
    END IF;

    UPDATE solicitudes SET estado = 'finalizada' WHERE id = p_solicitud_id;
END $$;

-- Teléfono y nombre completo de la otra parte, y la dirección exacta del trabajo. Solo para el cliente dueño
-- y el trabajador asignado, y solo con el trabajo asignado, en proceso o finalizado.
CREATE OR REPLACE FUNCTION fn_contacto_trabajo(p_usuario_id int, p_solicitud_id int)
RETURNS TABLE (
    rol               text,
    nombre            text,
    telefono          text,
    direccion_exacta  text)
LANGUAGE plpgsql STABLE AS $$
DECLARE
    v_cliente_id     int;
    v_trabajador_id  int;
    v_estado         text;
    v_direccion      text;
    v_es_parte       boolean;
BEGIN
    SELECT s.cliente_id, s.trabajador_id, s.estado, s.direccion_exacta
      INTO v_cliente_id, v_trabajador_id, v_estado, v_direccion
      FROM solicitudes s WHERE s.id = p_solicitud_id AND NOT s.eliminado;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'La solicitud no existe' USING ERRCODE = 'GT002';
    END IF;

    v_es_parte := COALESCE(p_usuario_id = v_cliente_id OR p_usuario_id = v_trabajador_id, false);
    IF NOT v_es_parte OR v_estado NOT IN ('asignada', 'en_proceso', 'finalizada') OR NOT fn_usuario_activo(p_usuario_id) THEN
        RAISE EXCEPTION 'Los datos de contacto solo se entregan a las dos partes de un trabajo asignado' USING ERRCODE = 'GT003';
    END IF;

    RETURN QUERY
    SELECT u.rol, u.nombre, u.telefono, v_direccion
      FROM usuarios u
     WHERE u.id = CASE WHEN p_usuario_id = v_cliente_id THEN v_trabajador_id ELSE v_cliente_id END;
END $$;

-- Una de las dos partes califica a la otra cuando el trabajo está finalizado. Una vez por solicitud.
-- El promedio del calificado lo recalcula trg_calificaciones_promedio.
CREATE OR REPLACE FUNCTION fn_calificar(p_calificador_id int, p_solicitud_id int, p_estrellas int, p_comentario text)
RETURNS int LANGUAGE plpgsql AS $$
DECLARE
    v_cliente_id     int;
    v_trabajador_id  int;
    v_estado         text;
    v_comentario     text := btrim(p_comentario);
    v_id             int;
BEGIN
    SELECT cliente_id, trabajador_id, estado INTO v_cliente_id, v_trabajador_id, v_estado
      FROM solicitudes WHERE id = p_solicitud_id AND NOT eliminado;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'La solicitud no existe' USING ERRCODE = 'GT002';
    END IF;
    IF NOT COALESCE(p_calificador_id = v_cliente_id OR p_calificador_id = v_trabajador_id, false)
       OR NOT fn_usuario_activo(p_calificador_id) THEN
        RAISE EXCEPTION 'Solo el cliente y el trabajador asignado califican este trabajo' USING ERRCODE = 'GT003';
    END IF;
    IF v_estado <> 'finalizada' THEN
        RAISE EXCEPTION 'Solo se puede calificar un trabajo finalizado' USING ERRCODE = 'GT001';
    END IF;
    IF p_estrellas IS NULL OR p_estrellas NOT BETWEEN 1 AND 5 THEN
        RAISE EXCEPTION 'La calificación debe ser de 1 a 5 estrellas' USING ERRCODE = 'GT001';
    END IF;
    IF v_comentario IS NULL OR char_length(v_comentario) NOT BETWEEN 1 AND 500 THEN
        RAISE EXCEPTION 'El comentario es obligatorio y no puede pasar de 500 caracteres' USING ERRCODE = 'GT001';
    END IF;

    BEGIN
        INSERT INTO calificaciones (solicitud_id, calificador_id, calificado_id, estrellas, comentario)
        VALUES (p_solicitud_id, p_calificador_id,
                CASE WHEN p_calificador_id = v_cliente_id THEN v_trabajador_id ELSE v_cliente_id END,
                p_estrellas, v_comentario)
        RETURNING id INTO v_id;
    EXCEPTION WHEN unique_violation THEN
        RAISE EXCEPTION 'Ya calificaste este trabajo' USING ERRCODE = 'GT001';
    END;
    RETURN v_id;
END $$;

-- Las solicitudes publicadas hace más de 72 horas sin asignar pasan a vencida y sus propuestas pendientes
-- a rechazada. La llama la API cada hora. Devuelve cuántas solicitudes venció.
CREATE OR REPLACE FUNCTION fn_vencer_solicitudes()
RETURNS int LANGUAGE plpgsql AS $$
DECLARE
    v_ids int[];
BEGIN
    WITH vencidas AS (
        UPDATE solicitudes SET estado = 'vencida'
         WHERE estado = 'publicada' AND NOT eliminado AND fecha_publicacion < now() - interval '72 hours'
        RETURNING id)
    SELECT array_agg(id) INTO v_ids FROM vencidas;

    UPDATE ofertas SET estado = 'rechazada' WHERE solicitud_id = ANY (v_ids) AND estado = 'pendiente';
    RETURN COALESCE(cardinality(v_ids), 0);
END $$;

-- Tanda 6: mensajes y avisos
--
-- El chat es un hilo por cada pareja (solicitud, trabajador): el cliente dueño y un trabajador que le envió
-- propuesta. Se abre en cuanto hay una propuesta pendiente, para ultimar detalles; al aceptar una, solo el
-- trabajador asignado puede seguir escribiendo. Los hilos de las demás propuestas y los de una solicitud
-- cancelada o vencida quedan de solo lectura.

-- Un hilo admite mensajes nuevos mientras la propuesta del trabajador esté pendiente y la solicitud publicada,
-- o mientras el trabajo esté asignado a ese trabajador (asignada, en proceso o finalizada).
CREATE OR REPLACE FUNCTION fn_hilo_abierto(p_solicitud_id int, p_trabajador_id int)
RETURNS boolean LANGUAGE sql STABLE AS $$
    SELECT EXISTS (
        SELECT 1
          FROM solicitudes s
         WHERE s.id = p_solicitud_id AND NOT s.eliminado
           AND ((s.estado = 'publicada'
                 AND EXISTS (SELECT 1 FROM ofertas o
                              WHERE o.solicitud_id = s.id AND o.trabajador_id = p_trabajador_id AND o.estado = 'pendiente'))
                OR (s.estado IN ('asignada', 'en_proceso', 'finalizada') AND s.trabajador_id = p_trabajador_id)));
$$;

-- Las dos partes de un hilo y si admite mensajes nuevos. p_usuario_id es el cliente dueño o un trabajador que
-- envió propuesta (aunque ya no esté activa). El cliente dice con quién habla en p_otro_id; si no lo dice y la
-- solicitud tiene trabajador asignado, es ese. asignado indica si el trabajador del hilo es el asignado.
CREATE OR REPLACE FUNCTION fn_hilo_chat(p_usuario_id int, p_solicitud_id int, p_otro_id int)
RETURNS TABLE (parte_cliente_id int, parte_trabajador_id int, abierto boolean, asignado boolean)
LANGUAGE plpgsql STABLE AS $$
DECLARE
    v_cliente_id     int;
    v_asignado_id    int;
    v_trabajador_id  int;
BEGIN
    SELECT s.cliente_id, s.trabajador_id INTO v_cliente_id, v_asignado_id
      FROM solicitudes s WHERE s.id = p_solicitud_id AND NOT s.eliminado;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'La solicitud no existe' USING ERRCODE = 'GT002';
    END IF;
    IF NOT fn_usuario_activo(p_usuario_id) THEN
        RAISE EXCEPTION 'Solo el cliente y un trabajador con propuesta se escriben en este trabajo' USING ERRCODE = 'GT003';
    END IF;

    IF p_usuario_id = v_cliente_id THEN
        v_trabajador_id := COALESCE(p_otro_id, v_asignado_id);
        IF v_trabajador_id IS NULL THEN
            RAISE EXCEPTION 'Elige con qué trabajador quieres hablar' USING ERRCODE = 'GT001';
        END IF;
    ELSE
        IF p_otro_id IS NOT NULL AND p_otro_id <> v_cliente_id THEN
            RAISE EXCEPTION 'Solo el cliente y un trabajador con propuesta se escriben en este trabajo' USING ERRCODE = 'GT003';
        END IF;
        v_trabajador_id := p_usuario_id;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM ofertas o WHERE o.solicitud_id = p_solicitud_id AND o.trabajador_id = v_trabajador_id) THEN
        RAISE EXCEPTION 'Solo el cliente y un trabajador con propuesta se escriben en este trabajo' USING ERRCODE = 'GT003';
    END IF;

    RETURN QUERY SELECT v_cliente_id, v_trabajador_id, fn_hilo_abierto(p_solicitud_id, v_trabajador_id),
                        v_asignado_id IS NOT DISTINCT FROM v_trabajador_id;
END $$;

-- Mensaje dentro de un hilo. El receptor es la otra parte. El cliente indica el trabajador en p_otro_id
-- (opcional si el trabajo ya está asignado); el trabajador no necesita indicar nada.
DROP FUNCTION IF EXISTS fn_enviar_mensaje(int, int, text);
CREATE OR REPLACE FUNCTION fn_enviar_mensaje(p_emisor_id int, p_solicitud_id int, p_texto text, p_otro_id int DEFAULT NULL)
RETURNS int LANGUAGE plpgsql AS $$
DECLARE
    v_hilo   record;
    v_texto  text := btrim(p_texto);
    v_id     int;
BEGIN
    SELECT * INTO v_hilo FROM fn_hilo_chat(p_emisor_id, p_solicitud_id, p_otro_id);
    IF NOT v_hilo.abierto THEN
        RAISE EXCEPTION 'Este chat ya no admite mensajes nuevos' USING ERRCODE = 'GT001';
    END IF;
    IF v_texto IS NULL OR char_length(v_texto) NOT BETWEEN 1 AND 1000 THEN
        RAISE EXCEPTION 'El mensaje es obligatorio y no puede pasar de 1000 caracteres' USING ERRCODE = 'GT001';
    END IF;

    INSERT INTO mensajes (solicitud_id, emisor_id, receptor_id, texto)
    VALUES (p_solicitud_id, p_emisor_id,
            CASE WHEN p_emisor_id = v_hilo.parte_cliente_id THEN v_hilo.parte_trabajador_id ELSE v_hilo.parte_cliente_id END,
            v_texto)
    RETURNING id INTO v_id;
    RETURN v_id;
END $$;

-- Mensajes de un hilo para una de sus dos partes, posteriores a p_desde (todos si es NULL). Un trabajador que
-- todavía no tiene el trabajo asignado ve al cliente con el nombre abreviado, igual que en el resto de la app.
DROP FUNCTION IF EXISTS fn_mensajes_de_solicitud(int, int, timestamptz);
CREATE OR REPLACE FUNCTION fn_mensajes_de_solicitud(p_usuario_id int, p_solicitud_id int, p_desde timestamptz DEFAULT NULL,
                                                    p_otro_id int DEFAULT NULL)
RETURNS TABLE (
    id             int,
    emisor_id      int,
    emisor_nombre  text,
    texto          text,
    fecha          timestamptz,
    es_mio         boolean)
LANGUAGE plpgsql STABLE AS $$
DECLARE
    v_hilo  record;
BEGIN
    SELECT * INTO v_hilo FROM fn_hilo_chat(p_usuario_id, p_solicitud_id, p_otro_id);

    RETURN QUERY
    SELECT m.id, m.emisor_id,
           CASE WHEN m.emisor_id = v_hilo.parte_cliente_id AND p_usuario_id <> v_hilo.parte_cliente_id AND NOT v_hilo.asignado
                THEN fn_nombre_corto(u.nombre) ELSE u.nombre END,
           m.texto, m.fecha, m.emisor_id = p_usuario_id
      FROM mensajes m
      JOIN usuarios u ON u.id = m.emisor_id
     WHERE m.solicitud_id = p_solicitud_id
       AND m.emisor_id IN (v_hilo.parte_cliente_id, v_hilo.parte_trabajador_id)
       AND m.receptor_id IN (v_hilo.parte_cliente_id, v_hilo.parte_trabajador_id)
       AND (p_desde IS NULL OR m.fecha > p_desde)
     ORDER BY m.fecha, m.id;
END $$;

-- Hilos de chat del usuario, uno por cada pareja (solicitud, trabajador), con el último mensaje y cuántos avisos
-- de mensaje nuevo tiene sin leer en ese hilo. Salen los que tienen mensajes, los del trabajador asignado y los
-- que están abiertos para escribir. abierto dice si todavía admite mensajes nuevos.
DROP FUNCTION IF EXISTS fn_conversaciones(int);
CREATE OR REPLACE FUNCTION fn_conversaciones(p_usuario_id int)
RETURNS TABLE (
    solicitud_id       int,
    titulo             text,
    estado             text,
    otra_parte_id      int,
    otra_parte_nombre  text,
    ultimo_mensaje     text,
    fecha_ultimo       timestamptz,
    mensajes_nuevos    int,
    abierto            boolean)
LANGUAGE plpgsql STABLE AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM usuarios u WHERE u.id = p_usuario_id AND u.rol IN ('cliente', 'trabajador')
                                              AND u.estado = 'activo' AND NOT u.eliminado) THEN
        RAISE EXCEPTION 'Solo los clientes y trabajadores con cuenta activa tienen conversaciones' USING ERRCODE = 'GT003';
    END IF;

    RETURN QUERY
    SELECT s.id, s.titulo, s.estado, otra.id,
           CASE WHEN otra.id = s.cliente_id AND s.trabajador_id IS DISTINCT FROM p_usuario_id
                THEN fn_nombre_corto(otra.nombre) ELSE otra.nombre END,
           ult.texto, ult.fecha,
           (SELECT count(*)::int FROM avisos a
             WHERE a.usuario_id = p_usuario_id AND a.solicitud_id = s.id AND a.tipo = 'mensaje_nuevo' AND NOT a.leido
               AND (a.otra_parte_id = otra.id OR a.otra_parte_id IS NULL)),
           fn_hilo_abierto(s.id, h.trabajador_id)
      FROM (SELECT DISTINCT o.solicitud_id, o.trabajador_id FROM ofertas o) h
      JOIN solicitudes s ON s.id = h.solicitud_id
      JOIN usuarios otra ON otra.id = CASE WHEN s.cliente_id = p_usuario_id THEN h.trabajador_id ELSE s.cliente_id END
      LEFT JOIN LATERAL (
            SELECT m.texto, m.fecha
              FROM mensajes m
             WHERE m.solicitud_id = s.id
               AND m.emisor_id IN (s.cliente_id, h.trabajador_id) AND m.receptor_id IN (s.cliente_id, h.trabajador_id)
             ORDER BY m.fecha DESC, m.id DESC
             LIMIT 1) AS ult ON true
     WHERE NOT s.eliminado
       AND (s.cliente_id = p_usuario_id OR h.trabajador_id = p_usuario_id)
       AND (ult.fecha IS NOT NULL OR s.trabajador_id = h.trabajador_id OR fn_hilo_abierto(s.id, h.trabajador_id))
     ORDER BY COALESCE(ult.fecha, s.fecha_asignacion, s.fecha_publicacion) DESC, s.id DESC, h.trabajador_id;
END $$;

-- Lo nuevo para el usuario al abrir la app: mensajes recibidos y avisos posteriores a p_desde. Sin p_desde
-- (primera carga), los mensajes recibidos en los últimos 7 días y los avisos sin leer.
CREATE OR REPLACE FUNCTION fn_sincronizar(p_usuario_id int, p_desde timestamptz)
RETURNS TABLE (
    clase          text,
    id             int,
    solicitud_id   int,
    titulo         text,
    tipo           text,
    texto          text,
    emisor_nombre  text,
    fecha          timestamptz,
    leido          boolean)
LANGUAGE plpgsql STABLE AS $$
BEGIN
    IF NOT fn_usuario_activo(p_usuario_id) THEN
        RAISE EXCEPTION 'Tu cuenta no está activa' USING ERRCODE = 'GT003';
    END IF;

    RETURN QUERY
    SELECT x.*
      FROM (SELECT 'mensaje'::text, m.id, m.solicitud_id, s.titulo, NULL::text, m.texto, u.nombre, m.fecha, NULL::boolean
              FROM mensajes m
              JOIN solicitudes s ON s.id = m.solicitud_id
              JOIN usuarios u ON u.id = m.emisor_id
             WHERE m.receptor_id = p_usuario_id
               AND (m.fecha > p_desde OR (p_desde IS NULL AND m.fecha > now() - interval '7 days'))
            UNION ALL
            SELECT 'aviso'::text, a.id, a.solicitud_id, s.titulo, a.tipo, a.texto, NULL::text, a.fecha, a.leido
              FROM avisos a
              LEFT JOIN solicitudes s ON s.id = a.solicitud_id
             WHERE a.usuario_id = p_usuario_id
               AND (a.fecha > p_desde OR (p_desde IS NULL AND NOT a.leido))
           ) AS x (clase, id, solicitud_id, titulo, tipo, texto, emisor_nombre, fecha, leido)
     ORDER BY x.fecha, x.clase, x.id;
END $$;

-- Marca avisos del usuario como leídos: los de una solicitud, los de la lista p_ids o, sin ninguno de los
-- dos, todos. Con p_otra_parte_id junto a la solicitud solo marca los avisos de mensaje de ese hilo del chat.
-- Devuelve cuántos estaban sin leer.
DROP FUNCTION IF EXISTS fn_marcar_avisos_leidos(int, int[], int);
CREATE OR REPLACE FUNCTION fn_marcar_avisos_leidos(p_usuario_id int, p_ids int[] DEFAULT NULL, p_solicitud_id int DEFAULT NULL,
                                                   p_otra_parte_id int DEFAULT NULL)
RETURNS int LANGUAGE plpgsql AS $$
DECLARE
    v_total int;
BEGIN
    IF NOT fn_usuario_activo(p_usuario_id) THEN
        RAISE EXCEPTION 'Tu cuenta no está activa' USING ERRCODE = 'GT003';
    END IF;

    IF p_solicitud_id IS NOT NULL AND p_otra_parte_id IS NOT NULL THEN
        -- los avisos de mensaje anteriores a la columna otra_parte_id no la traen y se marcan con cualquier hilo
        UPDATE avisos SET leido = true
         WHERE usuario_id = p_usuario_id AND solicitud_id = p_solicitud_id AND NOT leido
           AND (otra_parte_id = p_otra_parte_id OR (otra_parte_id IS NULL AND tipo = 'mensaje_nuevo'));
    ELSIF p_solicitud_id IS NOT NULL THEN
        UPDATE avisos SET leido = true WHERE usuario_id = p_usuario_id AND solicitud_id = p_solicitud_id AND NOT leido;
    ELSIF cardinality(p_ids) > 0 THEN
        UPDATE avisos SET leido = true WHERE usuario_id = p_usuario_id AND id = ANY (p_ids) AND NOT leido;
    ELSE
        UPDATE avisos SET leido = true WHERE usuario_id = p_usuario_id AND NOT leido;
    END IF;
    GET DIAGNOSTICS v_total = ROW_COUNT;
    RETURN v_total;
END $$;

-- Tanda 7: administración

CREATE OR REPLACE FUNCTION fn_exigir_administrador(p_admin_id int)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM usuarios WHERE id = p_admin_id AND rol = 'administrador' AND estado = 'activo' AND NOT eliminado) THEN
        RAISE EXCEPTION 'Solo el administrador puede hacer esto' USING ERRCODE = 'GT003';
    END IF;
END $$;

-- Nombre de un elemento de catálogo sin espacios a los lados. Es obligatorio al crear (p_id NULL); al editar,
-- NULL deja el que tenía. Si viene, debe tener de 1 a 100 caracteres.
CREATE OR REPLACE FUNCTION fn_nombre_catalogo(p_id int, p_nombre text)
RETURNS text LANGUAGE plpgsql IMMUTABLE AS $$
DECLARE
    v_nombre text := btrim(p_nombre);
BEGIN
    IF (p_id IS NULL OR v_nombre IS NOT NULL) AND char_length(COALESCE(v_nombre, '')) NOT BETWEEN 1 AND 100 THEN
        RAISE EXCEPTION 'El nombre es obligatorio y no puede pasar de 100 caracteres' USING ERRCODE = 'GT001';
    END IF;
    RETURN v_nombre;
END $$;

-- Las cuatro fn_guardar_... crean (p_id NULL) o editan un elemento de catálogo y devuelven su id.
-- Al editar, lo que viene NULL se queda igual y el padre no cambia. Nada se borra: se desactiva.
CREATE OR REPLACE FUNCTION fn_guardar_departamento(p_admin_id int, p_id int, p_nombre text, p_activo boolean)
RETURNS int LANGUAGE plpgsql AS $$
DECLARE
    v_nombre  text;
    v_id      int;
BEGIN
    PERFORM fn_exigir_administrador(p_admin_id);
    v_nombre := fn_nombre_catalogo(p_id, p_nombre);

    BEGIN
        IF p_id IS NULL THEN
            INSERT INTO departamentos (nombre, activo) VALUES (v_nombre, COALESCE(p_activo, true))
            RETURNING id INTO v_id;
        ELSE
            UPDATE departamentos SET nombre = COALESCE(v_nombre, nombre), activo = COALESCE(p_activo, activo)
             WHERE id = p_id
            RETURNING id INTO v_id;
        END IF;
    EXCEPTION WHEN unique_violation THEN
        RAISE EXCEPTION 'Ya existe un departamento con ese nombre' USING ERRCODE = 'GT001';
    END;
    IF v_id IS NULL THEN
        RAISE EXCEPTION 'El departamento no existe' USING ERRCODE = 'GT002';
    END IF;
    RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION fn_guardar_municipio(p_admin_id int, p_id int, p_departamento_id int, p_nombre text, p_activo boolean)
RETURNS int LANGUAGE plpgsql AS $$
DECLARE
    v_nombre  text;
    v_id      int;
BEGIN
    PERFORM fn_exigir_administrador(p_admin_id);
    v_nombre := fn_nombre_catalogo(p_id, p_nombre);
    IF p_id IS NULL AND NOT EXISTS (SELECT 1 FROM departamentos WHERE id = p_departamento_id) THEN
        RAISE EXCEPTION 'El departamento elegido no existe' USING ERRCODE = 'GT001';
    END IF;

    BEGIN
        IF p_id IS NULL THEN
            INSERT INTO municipios (departamento_id, nombre, activo) VALUES (p_departamento_id, v_nombre, COALESCE(p_activo, true))
            RETURNING id INTO v_id;
        ELSE
            UPDATE municipios SET nombre = COALESCE(v_nombre, nombre), activo = COALESCE(p_activo, activo)
             WHERE id = p_id
            RETURNING id INTO v_id;
        END IF;
    EXCEPTION WHEN unique_violation THEN
        RAISE EXCEPTION 'Ya existe un municipio con ese nombre en el departamento' USING ERRCODE = 'GT001';
    END;
    IF v_id IS NULL THEN
        RAISE EXCEPTION 'El municipio no existe' USING ERRCODE = 'GT002';
    END IF;
    RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION fn_guardar_colonia(p_admin_id int, p_id int, p_municipio_id int, p_nombre text, p_activo boolean)
RETURNS int LANGUAGE plpgsql AS $$
DECLARE
    v_nombre  text;
    v_id      int;
BEGIN
    PERFORM fn_exigir_administrador(p_admin_id);
    v_nombre := fn_nombre_catalogo(p_id, p_nombre);
    IF p_id IS NULL AND NOT EXISTS (SELECT 1 FROM municipios WHERE id = p_municipio_id) THEN
        RAISE EXCEPTION 'El municipio elegido no existe' USING ERRCODE = 'GT001';
    END IF;

    BEGIN
        IF p_id IS NULL THEN
            INSERT INTO colonias (municipio_id, nombre, activo) VALUES (p_municipio_id, v_nombre, COALESCE(p_activo, true))
            RETURNING id INTO v_id;
        ELSE
            UPDATE colonias SET nombre = COALESCE(v_nombre, nombre), activo = COALESCE(p_activo, activo)
             WHERE id = p_id
            RETURNING id INTO v_id;
        END IF;
    EXCEPTION WHEN unique_violation THEN
        RAISE EXCEPTION 'Ya existe una colonia con ese nombre en el municipio' USING ERRCODE = 'GT001';
    END;
    IF v_id IS NULL THEN
        RAISE EXCEPTION 'La colonia no existe' USING ERRCODE = 'GT002';
    END IF;
    RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION fn_guardar_oficio(p_admin_id int, p_id int, p_nombre text, p_activo boolean)
RETURNS int LANGUAGE plpgsql AS $$
DECLARE
    v_nombre  text;
    v_id      int;
BEGIN
    PERFORM fn_exigir_administrador(p_admin_id);
    v_nombre := fn_nombre_catalogo(p_id, p_nombre);

    BEGIN
        IF p_id IS NULL THEN
            INSERT INTO oficios (nombre, activo) VALUES (v_nombre, COALESCE(p_activo, true))
            RETURNING id INTO v_id;
        ELSE
            UPDATE oficios SET nombre = COALESCE(v_nombre, nombre), activo = COALESCE(p_activo, activo)
             WHERE id = p_id
            RETURNING id INTO v_id;
        END IF;
    EXCEPTION WHEN unique_violation THEN
        RAISE EXCEPTION 'Ya existe un oficio con ese nombre' USING ERRCODE = 'GT001';
    END;
    IF v_id IS NULL THEN
        RAISE EXCEPTION 'El oficio no existe' USING ERRCODE = 'GT002';
    END IF;
    RETURN v_id;
END $$;

-- Busca usuarios por nombre o correo sin distinguir mayúsculas; sin texto trae los más recientes.
-- No devuelve correo, teléfono ni DUI: esos salen solo por fn_auditoria_usuario.
CREATE OR REPLACE FUNCTION fn_buscar_usuarios(p_admin_id int, p_q text)
RETURNS TABLE (
    id                     int,
    rol                    text,
    nombre                 text,
    estado                 text,
    promedio_calificacion  numeric,
    total_calificaciones   int,
    fecha_registro         timestamptz)
LANGUAGE plpgsql STABLE AS $$
DECLARE
    -- % y _ se buscan como texto, no como comodines
    v_patron text := '%' || replace(replace(replace(btrim(COALESCE(p_q, '')), '\', '\\'), '%', '\%'), '_', '\_') || '%';
BEGIN
    PERFORM fn_exigir_administrador(p_admin_id);

    RETURN QUERY
    SELECT u.id, u.rol, u.nombre, u.estado, u.promedio_calificacion, u.total_calificaciones, u.fecha_registro
      FROM usuarios u
     WHERE NOT u.eliminado AND (u.nombre ILIKE v_patron OR u.correo ILIKE v_patron)
     ORDER BY u.fecha_registro DESC, u.id DESC
     LIMIT 100;
END $$;

-- Suspende o reactiva una cuenta. Un administrador no se puede suspender.
CREATE OR REPLACE FUNCTION fn_cambiar_estado_usuario(p_admin_id int, p_usuario_id int, p_estado text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE
    v_rol text;
BEGIN
    PERFORM fn_exigir_administrador(p_admin_id);
    IF p_estado IS NULL OR p_estado NOT IN ('activo', 'suspendido') THEN
        RAISE EXCEPTION 'El estado debe ser activo o suspendido' USING ERRCODE = 'GT001';
    END IF;

    SELECT rol INTO v_rol FROM usuarios WHERE id = p_usuario_id AND NOT eliminado FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'El usuario no existe' USING ERRCODE = 'GT002';
    END IF;
    IF v_rol = 'administrador' AND p_estado = 'suspendido' THEN
        RAISE EXCEPTION 'No se puede suspender a un administrador' USING ERRCODE = 'GT001';
    END IF;

    UPDATE usuarios SET estado = p_estado WHERE id = p_usuario_id;
END $$;

-- Datos de contacto e identidad de un usuario, solo para auditoría del administrador.
CREATE OR REPLACE FUNCTION fn_auditoria_usuario(p_admin_id int, p_usuario_id int)
RETURNS TABLE (
    id              int,
    rol             text,
    nombre          text,
    correo          text,
    telefono        text,
    dui             text,
    estado          text,
    fecha_registro  timestamptz,
    zona            text)
LANGUAGE plpgsql STABLE AS $$
BEGIN
    PERFORM fn_exigir_administrador(p_admin_id);

    RETURN QUERY
    SELECT u.id, u.rol, u.nombre, u.correo, u.telefono, u.dui, u.estado, u.fecha_registro,
           d.nombre || ', ' || m.nombre || COALESCE(', Col. ' || c.nombre, '')
      FROM usuarios u
      LEFT JOIN municipios m ON m.id = u.municipio_id
      LEFT JOIN departamentos d ON d.id = m.departamento_id
      LEFT JOIN colonias c ON c.id = u.colonia_id
     WHERE u.id = p_usuario_id AND NOT u.eliminado;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'El usuario no existe' USING ERRCODE = 'GT002';
    END IF;
END $$;
