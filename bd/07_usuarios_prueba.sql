-- 07_usuarios_prueba.sql
-- SOLO DESARROLLO. Cuentas de ejemplo para probar la app. No se aplica con .\bd\aplicar.ps1 a secas;
-- se pide con:  .\bd\aplicar.ps1 -DatosPrueba
--
-- Todos los datos son inventados (correos example.com, teléfonos 7000-XXXX, DUI generados por fórmula).
-- La contraseña de TODAS las cuentas es  Clave12345  (abajo va solo su hash BCrypt).
-- No crea solicitudes ni propuestas: esas se llenan probando. El administrador no está aquí: la API lo
-- crea al arrancar con el correo y la clave de los secretos.
-- Idempotente: si el correo ya existe, no toca la cuenta. Requiere 01 a 03.
--
-- Cuentas:
--   Clientes      cliente.demo (María), cliente2.demo (Diana), cliente3.demo (Carlos), cliente4.demo (Sofía),
--                 suspendido.demo (Susana, para probar la suspensión desde la administración)
--   Trabajadores  trabajador.demo (Luis, electricidad), trabajador2.demo (Pedro, electricidad),
--                 trabajador3.demo (Mario, pintura), trabajador4.demo (José, fontanería y limpieza),
--                 trabajador5.demo (Raúl, jardinería y acarreo), trabajador6.demo (Ana, varios oficios)

\set ON_ERROR_STOP on

CREATE TEMP TABLE IF NOT EXISTS clave_demo (hash text NOT NULL);
TRUNCATE clave_demo;
INSERT INTO clave_demo VALUES ('$2a$11$/9jP2rI6H5BDbb6HlR74M.lBviw8TCYoLhoSRtKQ8VjyzL/TyYOpO');

CREATE OR REPLACE FUNCTION pg_temp.sembrar_usuario(
    p_rol           text,
    p_nombre        text,
    p_correo        text,
    p_telefono      text,
    p_dui           text,
    p_departamento  text,
    p_municipio     text,
    p_colonia       text,
    p_oficios       text[],
    p_colonias      text[])
RETURNS void LANGUAGE plpgsql AS $$
DECLARE
    v_municipio_id  int;
    v_colonia_id    int;
BEGIN
    IF EXISTS (SELECT 1 FROM usuarios WHERE lower(correo) = lower(p_correo)) THEN
        RETURN;
    END IF;

    SELECT m.id INTO v_municipio_id
      FROM municipios m JOIN departamentos d ON d.id = m.departamento_id
     WHERE d.nombre = p_departamento AND m.nombre = p_municipio;
    IF v_municipio_id IS NULL THEN
        RAISE EXCEPTION 'No existe el municipio % de %: corre 02_catalogos.sql', p_municipio, p_departamento;
    END IF;

    SELECT c.id INTO v_colonia_id FROM colonias c WHERE c.municipio_id = v_municipio_id AND c.nombre = p_colonia;

    PERFORM fn_registrar_usuario(
        p_rol, p_nombre, p_correo, (SELECT hash FROM clave_demo), p_telefono, p_dui, v_municipio_id, v_colonia_id,
        ARRAY(SELECT id FROM oficios WHERE nombre = ANY (p_oficios)),
        ARRAY(SELECT id FROM colonias WHERE municipio_id = v_municipio_id AND nombre = ANY (p_colonias)));
END $$;

DO $$
BEGIN
    -- Clientes: rol, nombre, correo, teléfono, DUI, departamento, municipio, colonia, oficios, colonias de trabajo
    PERFORM pg_temp.sembrar_usuario('cliente', 'María Ejemplo',  'cliente.demo@example.com',     '7000-0201', NULL, 'San Salvador', 'Mejicanos',    'Zacamil', NULL, NULL);
    PERFORM pg_temp.sembrar_usuario('cliente', 'Diana Ejemplo',  'cliente2.demo@example.com',    '7000-0204', NULL, 'San Salvador', 'Mejicanos',    'Zacamil', NULL, NULL);
    PERFORM pg_temp.sembrar_usuario('cliente', 'Carlos Ejemplo', 'cliente3.demo@example.com',    '7000-0207', NULL, 'San Salvador', 'San Salvador', 'Escalón', NULL, NULL);
    PERFORM pg_temp.sembrar_usuario('cliente', 'Sofía Ejemplo',  'cliente4.demo@example.com',    '7000-0208', NULL, 'San Salvador', 'Soyapango',    'Centro',  NULL, NULL);
    PERFORM pg_temp.sembrar_usuario('cliente', 'Susana Ejemplo', 'suspendido.demo@example.com',  '7000-0203', NULL, 'San Salvador', 'Mejicanos',    'Zacamil', NULL, NULL);


    -- Trabajadores
    PERFORM pg_temp.sembrar_usuario('trabajador', 'Luis Ejemplo',  'trabajador.demo@example.com',  '7000-0202', '12345678-4', 'San Salvador', 'Mejicanos',    NULL,
                                   ARRAY['Electricidad'], ARRAY['Zacamil', 'Lourdes']);
    PERFORM pg_temp.sembrar_usuario('trabajador', 'Pedro Ejemplo', 'trabajador2.demo@example.com', '7000-0205', '66666666-6', 'San Salvador', 'Mejicanos',    NULL,
                                   ARRAY['Electricidad'], ARRAY['Zacamil']);
    PERFORM pg_temp.sembrar_usuario('trabajador', 'Mario Ejemplo', 'trabajador3.demo@example.com', '7000-0206', '77777777-2', 'San Salvador', 'Mejicanos',    NULL,
                                   ARRAY['Pintura'], ARRAY['Zacamil']);
    PERFORM pg_temp.sembrar_usuario('trabajador', 'José Ejemplo',  'trabajador4.demo@example.com', '7000-0209', '88888888-8', 'San Salvador', 'San Salvador', NULL,
                                   ARRAY['Fontanería', 'Limpieza'], ARRAY['Escalón', 'Miramonte']);
    PERFORM pg_temp.sembrar_usuario('trabajador', 'Raúl Ejemplo',  'trabajador5.demo@example.com', '7000-0210', '99999999-4', 'La Libertad',  'Santa Tecla',  NULL,
                                   ARRAY['Jardinería', 'Acarreo'], ARRAY['Centro', 'Las Delicias']);
    PERFORM pg_temp.sembrar_usuario('trabajador', 'Ana Ejemplo',   'trabajador6.demo@example.com', '7000-0211', '10101010-6', 'San Salvador', 'Soyapango',    NULL,
                                   ARRAY['Electricidad', 'Pintura', 'Fontanería'], ARRAY['Centro']);
END $$;

DO $$
BEGIN
    RAISE NOTICE 'Cuentas en la base: % clientes, % trabajadores, % administradores',
        (SELECT count(*) FROM usuarios WHERE rol = 'cliente'),
        (SELECT count(*) FROM usuarios WHERE rol = 'trabajador'),
        (SELECT count(*) FROM usuarios WHERE rol = 'administrador');
END $$;
