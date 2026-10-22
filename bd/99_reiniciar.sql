-- 99_reiniciar.sql
-- Borra todo el contenido de la base (tablas, funciones, vistas, triggers) para empezar de cero.
-- SOLO DESARROLLO. El rol gtr_api se conserva porque pertenece al servidor, no a la base.
-- Después se vuelven a correr 01 a 05.

DROP SCHEMA IF EXISTS public CASCADE;
CREATE SCHEMA public;
GRANT USAGE ON SCHEMA public TO PUBLIC;
