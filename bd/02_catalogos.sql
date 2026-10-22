-- 02_catalogos.sql
-- Departamentos, oficios y zonas de ejemplo. Idempotente.
-- Los municipios y colonias de abajo son DE EJEMPLO, no una lista oficial.
-- El administrador agrega el resto desde la app.

INSERT INTO departamentos (nombre) VALUES
    ('Ahuachapán'), ('Santa Ana'), ('Sonsonate'), ('Chalatenango'), ('La Libertad'),
    ('San Salvador'), ('Cuscatlán'), ('La Paz'), ('Cabañas'), ('San Vicente'),
    ('Usulután'), ('San Miguel'), ('Morazán'), ('La Unión')
ON CONFLICT (nombre) DO NOTHING;

INSERT INTO oficios (nombre) VALUES
    ('Electricidad'), ('Fontanería'), ('Pintura'), ('Limpieza'), ('Acarreo'), ('Jardinería')
ON CONFLICT (nombre) DO NOTHING;

-- Municipios de ejemplo (no oficiales)
INSERT INTO municipios (departamento_id, nombre)
SELECT d.id, v.municipio
FROM (VALUES
    ('San Salvador', 'Mejicanos'),
    ('San Salvador', 'San Salvador'),
    ('La Libertad',  'Santa Tecla')
) AS v (departamento, municipio)
JOIN departamentos d ON d.nombre = v.departamento
ON CONFLICT (departamento_id, nombre) DO NOTHING;

-- Colonias de ejemplo (no oficiales)
INSERT INTO colonias (municipio_id, nombre)
SELECT m.id, v.colonia
FROM (VALUES
    ('San Salvador', 'Mejicanos',    'Zacamil'),
    ('San Salvador', 'Mejicanos',    'San Ramón'),
    ('San Salvador', 'Mejicanos',    'Lourdes'),
    ('San Salvador', 'San Salvador', 'Escalón'),
    ('San Salvador', 'San Salvador', 'Miramonte'),
    ('San Salvador', 'San Salvador', 'San Benito'),
    ('La Libertad',  'Santa Tecla',  'Centro'),
    ('La Libertad',  'Santa Tecla',  'Las Delicias')
) AS v (departamento, municipio, colonia)
JOIN departamentos d ON d.nombre = v.departamento
JOIN municipios m ON m.departamento_id = d.id AND m.nombre = v.municipio
ON CONFLICT (municipio_id, nombre) DO NOTHING;
