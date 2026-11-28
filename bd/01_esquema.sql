-- 01_esquema.sql
-- Tablas, restricciones, índices y rol de la API.
-- Idempotente: se puede ejecutar varias veces. Se corre con un usuario administrador
-- (postgres) sobre la base gestor_trabajo_rapido. Para empezar de cero ver 99_reiniciar.sql.

-- Catálogos de zona y oficios

CREATE TABLE IF NOT EXISTS departamentos (
    id      integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre  text    NOT NULL UNIQUE,
    activo  boolean NOT NULL DEFAULT true
);

CREATE TABLE IF NOT EXISTS municipios (
    id               integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    departamento_id  integer NOT NULL REFERENCES departamentos (id),
    nombre           text    NOT NULL,
    activo           boolean NOT NULL DEFAULT true,
    -- el índice de esta restricción también sirve a la llave foránea
    CONSTRAINT uq_municipios_nombre UNIQUE (departamento_id, nombre)
);

CREATE TABLE IF NOT EXISTS colonias (
    id            integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    municipio_id  integer NOT NULL REFERENCES municipios (id),
    nombre        text    NOT NULL,
    activo        boolean NOT NULL DEFAULT true,
    CONSTRAINT uq_colonias_nombre UNIQUE (municipio_id, nombre),
    -- permite que usuarios.(colonia_id, municipio_id) no se contradigan
    CONSTRAINT uq_colonias_id_municipio UNIQUE (id, municipio_id)
);

CREATE TABLE IF NOT EXISTS oficios (
    id      integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre  text    NOT NULL UNIQUE,
    activo  boolean NOT NULL DEFAULT true
);

-- Usuarios

CREATE TABLE IF NOT EXISTS usuarios (
    id                     integer      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    rol                    text         NOT NULL,
    nombre                 text         NOT NULL,
    correo                 text         NOT NULL,
    password_hash          text         NOT NULL,
    telefono               text,
    dui                    text         UNIQUE,
    foto_ruta              text,
    municipio_id           integer      REFERENCES municipios (id),
    colonia_id             integer,
    estado                 text         NOT NULL DEFAULT 'activo',
    promedio_calificacion  numeric(3,2) NOT NULL DEFAULT 0,
    total_calificaciones   integer      NOT NULL DEFAULT 0,
    fecha_registro         timestamptz  NOT NULL DEFAULT now(),
    eliminado              boolean      NOT NULL DEFAULT false,
    CONSTRAINT ck_usuarios_rol CHECK (rol IN ('cliente', 'trabajador', 'administrador')),
    CONSTRAINT ck_usuarios_estado CHECK (estado IN ('activo', 'suspendido')),
    CONSTRAINT ck_usuarios_nombre CHECK (char_length(btrim(nombre)) BETWEEN 1 AND 100),
    CONSTRAINT ck_usuarios_correo CHECK (correo ~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'),
    CONSTRAINT ck_usuarios_telefono CHECK (telefono IS NULL OR telefono ~ '^[0-9]{4}-[0-9]{4}$'),
    CONSTRAINT ck_usuarios_dui_formato CHECK (dui IS NULL OR dui ~ '^[0-9]{8}-[0-9]$'),
    -- qué datos lleva cada rol
    CONSTRAINT ck_usuarios_por_rol CHECK (
        (rol = 'cliente'       AND telefono IS NOT NULL AND municipio_id IS NOT NULL AND colonia_id IS NOT NULL AND dui IS NULL)
     OR (rol = 'trabajador'    AND telefono IS NOT NULL AND municipio_id IS NOT NULL AND colonia_id IS NULL     AND dui IS NOT NULL)
     OR (rol = 'administrador' AND telefono IS NULL     AND municipio_id IS NULL     AND colonia_id IS NULL     AND dui IS NULL)
    ),
    -- la colonia del cliente debe pertenecer a su municipio
    CONSTRAINT fk_usuarios_colonia FOREIGN KEY (colonia_id, municipio_id) REFERENCES colonias (id, municipio_id)
);

CREATE TABLE IF NOT EXISTS usuario_oficio (
    usuario_id  integer NOT NULL REFERENCES usuarios (id),
    oficio_id   integer NOT NULL REFERENCES oficios (id),
    PRIMARY KEY (usuario_id, oficio_id)
);

CREATE TABLE IF NOT EXISTS trabajador_colonia (
    usuario_id  integer NOT NULL REFERENCES usuarios (id),
    colonia_id  integer NOT NULL REFERENCES colonias (id),
    PRIMARY KEY (usuario_id, colonia_id)
);

-- Solicitudes y propuestas

CREATE TABLE IF NOT EXISTS solicitudes (
    id                 integer       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    cliente_id         integer       NOT NULL REFERENCES usuarios (id),
    oficio_id          integer       NOT NULL REFERENCES oficios (id),
    colonia_id         integer       NOT NULL REFERENCES colonias (id),
    titulo             text          NOT NULL,
    descripcion        text          NOT NULL,
    presupuesto        numeric(10,2) NOT NULL,
    direccion_exacta   text          NOT NULL,
    estado             text          NOT NULL DEFAULT 'publicada',
    trabajador_id      integer       REFERENCES usuarios (id),
    fecha_publicacion  timestamptz   NOT NULL DEFAULT now(),
    fecha_asignacion   timestamptz,
    eliminado          boolean       NOT NULL DEFAULT false,
    CONSTRAINT ck_solicitudes_estado CHECK (
        estado IN ('publicada', 'asignada', 'en_proceso', 'finalizada', 'cancelada', 'vencida')),
    CONSTRAINT ck_solicitudes_titulo CHECK (char_length(btrim(titulo)) BETWEEN 1 AND 100),
    CONSTRAINT ck_solicitudes_descripcion CHECK (char_length(btrim(descripcion)) BETWEEN 1 AND 1000),
    CONSTRAINT ck_solicitudes_presupuesto CHECK (presupuesto > 0),
    CONSTRAINT ck_solicitudes_direccion CHECK (char_length(btrim(direccion_exacta)) BETWEEN 1 AND 200),
    -- una cancelada puede o no haber tenido trabajador asignado
    CONSTRAINT ck_solicitudes_trabajador CHECK (
        CASE
            WHEN estado IN ('asignada', 'en_proceso', 'finalizada') THEN trabajador_id IS NOT NULL
            WHEN estado IN ('publicada', 'vencida') THEN trabajador_id IS NULL
            ELSE true
        END),
    CONSTRAINT ck_solicitudes_asignacion CHECK ((trabajador_id IS NULL) = (fecha_asignacion IS NULL))
);

CREATE TABLE IF NOT EXISTS ofertas (
    id            integer       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    solicitud_id  integer       NOT NULL REFERENCES solicitudes (id),
    trabajador_id integer       NOT NULL REFERENCES usuarios (id),
    precio        numeric(10,2) NOT NULL,
    mensaje       text,
    estado        text          NOT NULL DEFAULT 'pendiente',
    fecha         timestamptz   NOT NULL DEFAULT now(),
    CONSTRAINT ck_ofertas_estado CHECK (estado IN ('pendiente', 'aceptada', 'rechazada', 'retirada')),
    CONSTRAINT ck_ofertas_precio CHECK (precio > 0),
    CONSTRAINT ck_ofertas_mensaje CHECK (mensaje IS NULL OR char_length(mensaje) <= 300)
);

-- Seguimiento: calificaciones, mensajes, avisos y bitácora

CREATE TABLE IF NOT EXISTS calificaciones (
    id             integer     GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    solicitud_id   integer     NOT NULL REFERENCES solicitudes (id),
    calificador_id integer     NOT NULL REFERENCES usuarios (id),
    calificado_id  integer     NOT NULL REFERENCES usuarios (id),
    estrellas      integer     NOT NULL,
    comentario     text        NOT NULL,
    fecha          timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_calificaciones_solicitud_calificador UNIQUE (solicitud_id, calificador_id),
    CONSTRAINT ck_calificaciones_estrellas CHECK (estrellas BETWEEN 1 AND 5),
    CONSTRAINT ck_calificaciones_comentario CHECK (char_length(btrim(comentario)) BETWEEN 1 AND 500),
    CONSTRAINT ck_calificaciones_partes CHECK (calificador_id <> calificado_id)
);

CREATE TABLE IF NOT EXISTS mensajes (
    id            integer     GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    solicitud_id  integer     NOT NULL REFERENCES solicitudes (id),
    emisor_id     integer     NOT NULL REFERENCES usuarios (id),
    receptor_id   integer     NOT NULL REFERENCES usuarios (id),
    texto         text        NOT NULL,
    fecha         timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT ck_mensajes_texto CHECK (char_length(btrim(texto)) BETWEEN 1 AND 1000),
    CONSTRAINT ck_mensajes_partes CHECK (emisor_id <> receptor_id)
);

CREATE TABLE IF NOT EXISTS avisos (
    id            integer     GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    usuario_id    integer     NOT NULL REFERENCES usuarios (id),
    tipo          text        NOT NULL,
    texto         text        NOT NULL,
    solicitud_id  integer     REFERENCES solicitudes (id),
    fecha         timestamptz NOT NULL DEFAULT now(),
    leido         boolean     NOT NULL DEFAULT false
);

-- Quién originó el aviso de mensaje nuevo, para contar los no leídos de cada hilo del chat.
-- Va aparte del CREATE TABLE para que las bases que ya tenían la tabla también la reciban.
ALTER TABLE avisos ADD COLUMN IF NOT EXISTS otra_parte_id integer REFERENCES usuarios (id);

CREATE TABLE IF NOT EXISTS bitacora (
    id               integer     GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    solicitud_id     integer     NOT NULL REFERENCES solicitudes (id),
    estado_anterior  text,
    estado_nuevo     text        NOT NULL,
    usuario_id       integer     REFERENCES usuarios (id),
    fecha            timestamptz NOT NULL DEFAULT now()
);

-- Índices (las llaves foráneas sin índice propio quedan cubiertas aquí)

CREATE UNIQUE INDEX IF NOT EXISTS ix_usuarios_correo ON usuarios (lower(correo));
CREATE INDEX IF NOT EXISTS ix_usuarios_municipio ON usuarios (municipio_id);
CREATE INDEX IF NOT EXISTS ix_usuarios_colonia ON usuarios (colonia_id);

CREATE INDEX IF NOT EXISTS ix_usuario_oficio_oficio ON usuario_oficio (oficio_id);
CREATE INDEX IF NOT EXISTS ix_trabajador_colonia_colonia ON trabajador_colonia (colonia_id);

CREATE INDEX IF NOT EXISTS ix_solicitudes_estado_colonia_oficio ON solicitudes (estado, colonia_id, oficio_id);
CREATE INDEX IF NOT EXISTS ix_solicitudes_cliente ON solicitudes (cliente_id);
CREATE INDEX IF NOT EXISTS ix_solicitudes_trabajador ON solicitudes (trabajador_id);
CREATE INDEX IF NOT EXISTS ix_solicitudes_oficio ON solicitudes (oficio_id);
CREATE INDEX IF NOT EXISTS ix_solicitudes_colonia ON solicitudes (colonia_id);

-- Un trabajador no puede tener dos propuestas activas en la misma solicitud
CREATE UNIQUE INDEX IF NOT EXISTS ix_ofertas_activa
    ON ofertas (solicitud_id, trabajador_id) WHERE estado IN ('pendiente', 'aceptada');
CREATE INDEX IF NOT EXISTS ix_ofertas_trabajador ON ofertas (trabajador_id);

CREATE INDEX IF NOT EXISTS ix_calificaciones_calificado ON calificaciones (calificado_id);

CREATE INDEX IF NOT EXISTS ix_mensajes_solicitud_fecha ON mensajes (solicitud_id, fecha);
CREATE INDEX IF NOT EXISTS ix_mensajes_emisor ON mensajes (emisor_id);
CREATE INDEX IF NOT EXISTS ix_mensajes_receptor_fecha ON mensajes (receptor_id, fecha);

CREATE INDEX IF NOT EXISTS ix_avisos_usuario_fecha ON avisos (usuario_id, fecha);
CREATE INDEX IF NOT EXISTS ix_avisos_solicitud ON avisos (solicitud_id);
CREATE INDEX IF NOT EXISTS ix_avisos_otra_parte ON avisos (otra_parte_id);

CREATE INDEX IF NOT EXISTS ix_bitacora_solicitud ON bitacora (solicitud_id);
CREATE INDEX IF NOT EXISTS ix_bitacora_usuario ON bitacora (usuario_id);

-- Rol de la API: solo lo que necesita, sin superusuario y sin CREATE.
-- La contraseña no va en el script: se fija desde psql con  \password gtr_api

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'gtr_api') THEN
        CREATE ROLE gtr_api LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE;
    END IF;
END $$;

GRANT USAGE ON SCHEMA public TO gtr_api;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO gtr_api;
-- Los oficios y colonias de un trabajador se reemplazan completos
GRANT DELETE ON usuario_oficio, trabajador_colonia TO gtr_api;
