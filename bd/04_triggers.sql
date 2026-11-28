-- 04_triggers.sql
-- Bitácora de estados, avisos y promedio de calificaciones. Idempotente (CREATE OR REPLACE).
-- Los triggers corren con los permisos de quien hace el cambio (gtr_api), que puede insertar en avisos y bitácora.
-- Todos los avisos llevan la solicitud; el texto usa el nombre abreviado de la otra parte ("María E.").

-- Bitácora: cada INSERT y cada cambio de estado de una solicitud. El usuario lo fija la API al inicio de la
-- transacción con set_config('app.usuario_id', ...); vacío o sin fijar queda NULL (tarea automática).
CREATE OR REPLACE FUNCTION fn_trg_bitacora() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
    v_anterior text;
BEGIN
    IF TG_OP = 'UPDATE' THEN
        IF NEW.estado = OLD.estado THEN
            RETURN NULL;
        END IF;
        v_anterior := OLD.estado;
    END IF;

    INSERT INTO bitacora (solicitud_id, estado_anterior, estado_nuevo, usuario_id)
    VALUES (NEW.id, v_anterior, NEW.estado, NULLIF(current_setting('app.usuario_id', true), '')::int);
    RETURN NULL;
END $$;

CREATE OR REPLACE TRIGGER trg_solicitudes_bitacora
AFTER INSERT OR UPDATE OF estado ON solicitudes
FOR EACH ROW EXECUTE FUNCTION fn_trg_bitacora();

-- Aviso al cliente cuando llega una propuesta nueva o una retirada vuelve a quedar pendiente.
CREATE OR REPLACE FUNCTION fn_trg_ofertas_aviso() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
    v_cliente_id  int;
    v_titulo      text;
    v_trabajador  text;
BEGIN
    IF TG_OP = 'UPDATE' THEN
        IF NEW.estado <> 'pendiente' OR OLD.estado = 'pendiente' THEN
            RETURN NULL;
        END IF;
    END IF;

    SELECT cliente_id, titulo INTO v_cliente_id, v_titulo FROM solicitudes WHERE id = NEW.solicitud_id;
    SELECT fn_nombre_corto(nombre) INTO v_trabajador FROM usuarios WHERE id = NEW.trabajador_id;

    INSERT INTO avisos (usuario_id, tipo, texto, solicitud_id)
    VALUES (v_cliente_id, 'propuesta_nueva',
            v_trabajador || ' envió una propuesta de $' || to_char(NEW.precio, 'FM99999990.00') || ' para «' || v_titulo || '»',
            NEW.solicitud_id);
    RETURN NULL;
END $$;

CREATE OR REPLACE TRIGGER trg_ofertas_aviso
AFTER INSERT OR UPDATE OF estado ON ofertas
FOR EACH ROW EXECUTE FUNCTION fn_trg_ofertas_aviso();

-- Aviso al trabajador cuando su propuesta es aceptada o rechazada.
CREATE OR REPLACE FUNCTION fn_trg_ofertas_estado_aviso() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
    v_titulo text;
BEGIN
    IF NEW.estado = OLD.estado OR NEW.estado NOT IN ('aceptada', 'rechazada') THEN
        RETURN NULL;
    END IF;

    SELECT titulo INTO v_titulo FROM solicitudes WHERE id = NEW.solicitud_id;
    IF NEW.estado = 'aceptada' THEN
        INSERT INTO avisos (usuario_id, tipo, texto, solicitud_id)
        VALUES (NEW.trabajador_id, 'propuesta_aceptada', 'El cliente aceptó tu propuesta para «' || v_titulo || '»', NEW.solicitud_id);
    ELSE
        INSERT INTO avisos (usuario_id, tipo, texto, solicitud_id)
        VALUES (NEW.trabajador_id, 'propuesta_rechazada', 'Tu propuesta para «' || v_titulo || '» fue rechazada', NEW.solicitud_id);
    END IF;
    RETURN NULL;
END $$;

CREATE OR REPLACE TRIGGER trg_ofertas_estado_aviso
AFTER UPDATE OF estado ON ofertas
FOR EACH ROW EXECUTE FUNCTION fn_trg_ofertas_estado_aviso();

-- Aviso a la otra parte cuando la solicitud pasa a en proceso, finalizada, cancelada o vencida.
CREATE OR REPLACE FUNCTION fn_trg_solicitudes_aviso() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
    v_usuario_id  int;
    v_tipo        text;
    v_texto       text;
BEGIN
    IF NEW.estado = OLD.estado THEN
        RETURN NULL;
    END IF;

    IF NEW.estado = 'en_proceso' THEN
        v_usuario_id := NEW.cliente_id;
        v_tipo := 'solicitud_en_proceso';
        v_texto := (SELECT fn_nombre_corto(nombre) FROM usuarios WHERE id = NEW.trabajador_id)
                   || ' marcó en proceso «' || NEW.titulo || '»';
    ELSIF NEW.estado = 'finalizada' THEN
        v_usuario_id := NEW.trabajador_id;
        v_tipo := 'solicitud_finalizada';
        v_texto := 'El cliente confirmó que «' || NEW.titulo || '» terminó. Ya puedes calificar al cliente';
    ELSIF NEW.estado = 'cancelada' THEN
        v_usuario_id := NEW.trabajador_id;
        v_tipo := 'solicitud_cancelada';
        v_texto := 'El cliente canceló «' || NEW.titulo || '»';
    ELSIF NEW.estado = 'vencida' THEN
        v_usuario_id := NEW.cliente_id;
        v_tipo := 'solicitud_vencida';
        v_texto := 'Tu solicitud «' || NEW.titulo || '» venció porque pasaron 72 horas sin asignarse';
    END IF;

    -- una cancelada sin trabajador asignado no avisa a nadie
    IF v_usuario_id IS NOT NULL THEN
        INSERT INTO avisos (usuario_id, tipo, texto, solicitud_id)
        VALUES (v_usuario_id, v_tipo, v_texto, NEW.id);
    END IF;
    RETURN NULL;
END $$;

CREATE OR REPLACE TRIGGER trg_solicitudes_aviso
AFTER UPDATE OF estado ON solicitudes
FOR EACH ROW EXECUTE FUNCTION fn_trg_solicitudes_aviso();

-- Aviso al receptor de un mensaje.
CREATE OR REPLACE FUNCTION fn_trg_mensajes_aviso() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
    v_titulo  text;
    v_emisor  text;
BEGIN
    SELECT titulo INTO v_titulo FROM solicitudes WHERE id = NEW.solicitud_id;
    SELECT fn_nombre_corto(nombre) INTO v_emisor FROM usuarios WHERE id = NEW.emisor_id;

    INSERT INTO avisos (usuario_id, tipo, texto, solicitud_id, otra_parte_id)
    VALUES (NEW.receptor_id, 'mensaje_nuevo', 'Mensaje nuevo de ' || v_emisor || ' sobre «' || v_titulo || '»',
            NEW.solicitud_id, NEW.emisor_id);
    RETURN NULL;
END $$;

CREATE OR REPLACE TRIGGER trg_mensajes_aviso
AFTER INSERT ON mensajes
FOR EACH ROW EXECUTE FUNCTION fn_trg_mensajes_aviso();

-- Recalcula el promedio y el total de calificaciones del calificado.
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
