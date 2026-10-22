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
