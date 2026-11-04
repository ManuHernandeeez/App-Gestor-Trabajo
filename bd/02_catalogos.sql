-- 02_catalogos.sql
-- Departamentos, oficios, municipios y zonas de ejemplo. Idempotente.
-- Departamentos y municipios son los oficiales. Las colonias son DE EJEMPLO, no una lista oficial:
-- el administrador agrega el resto desde la app.

INSERT INTO departamentos (nombre) VALUES
    ('Ahuachapán'), ('Santa Ana'), ('Sonsonate'), ('Chalatenango'), ('La Libertad'),
    ('San Salvador'), ('Cuscatlán'), ('La Paz'), ('Cabañas'), ('San Vicente'),
    ('Usulután'), ('San Miguel'), ('Morazán'), ('La Unión')
ON CONFLICT (nombre) DO NOTHING;

INSERT INTO oficios (nombre) VALUES
    ('Electricidad'), ('Fontanería'), ('Pintura'), ('Limpieza'), ('Acarreo'), ('Jardinería')
ON CONFLICT (nombre) DO NOTHING;

-- Municipios: los 262 de la división tradicional, que son los que la gente conoce (Mejicanos, Soyapango,
-- Santa Tecla). Desde mayo de 2024 (Ley Especial de Reestructuración Municipal, decreto 762 de junio de 2023)
-- la ley los llama "distritos" y los agrupa en 44 municipios; cada línea de abajo es uno de esos 44 y
-- su comentario lo nombra. Fuente: https://es.wikipedia.org/wiki/Anexo:Municipios_de_El_Salvador
-- Conteo por departamento: Ahuachapán 12, Santa Ana 13, Sonsonate 16, Chalatenango 33, La Libertad 22,
-- San Salvador 19, Cuscatlán 16, La Paz 22, Cabañas 9, San Vicente 13, Usulután 23, San Miguel 20,
-- Morazán 26, La Unión 18 (suman 262).
INSERT INTO municipios (departamento_id, nombre)
SELECT d.id, m.nombre
FROM (VALUES
    ('Ahuachapán', ARRAY['Atiquizaya', 'El Refugio', 'San Lorenzo', 'Turín']),                            -- Ahuachapán Norte
    ('Ahuachapán', ARRAY['Ahuachapán', 'Apaneca', 'Concepción de Ataco', 'Tacuba']),                       -- Ahuachapán Centro
    ('Ahuachapán', ARRAY['Guaymango', 'Jujutla', 'San Francisco Menéndez', 'San Pedro Puxtla']),           -- Ahuachapán Sur

    ('Santa Ana', ARRAY['Masahuat', 'Metapán', 'Santa Rosa Guachipilín', 'Texistepeque']),                 -- Santa Ana Norte
    ('Santa Ana', ARRAY['Santa Ana']),                                                                     -- Santa Ana Centro
    ('Santa Ana', ARRAY['Coatepeque', 'El Congo']),                                                        -- Santa Ana Este
    ('Santa Ana', ARRAY['Candelaria de la Frontera', 'Chalchuapa', 'El Porvenir', 'San Antonio Pajonal',
                        'San Sebastián Salitrillo', 'Santiago de la Frontera']),                           -- Santa Ana Oeste

    ('Sonsonate', ARRAY['Juayúa', 'Nahuizalco', 'Salcoatitán', 'Santa Catarina Masahuat']),                -- Sonsonate Norte
    ('Sonsonate', ARRAY['Sonsonate', 'Sonzacate', 'Nahulingo', 'San Antonio del Monte',
                        'Santo Domingo de Guzmán']),                                                       -- Sonsonate Centro
    ('Sonsonate', ARRAY['Armenia', 'Caluco', 'Cuisnahuat', 'Izalco', 'San Julián', 'Santa Isabel Ishuatán']),  -- Sonsonate Este
    ('Sonsonate', ARRAY['Acajutla']),                                                                      -- Sonsonate Oeste

    ('Chalatenango', ARRAY['Citalá', 'La Palma', 'San Ignacio']),                                          -- Chalatenango Norte
    ('Chalatenango', ARRAY['Agua Caliente', 'Dulce Nombre de María', 'El Paraíso', 'La Reina', 'Nueva Concepción',
                           'San Fernando', 'San Francisco Morazán', 'San Rafael', 'Santa Rita', 'Tejutla']),   -- Chalatenango Centro
    ('Chalatenango', ARRAY['Arcatao', 'Azacualpa', 'Cancasque', 'Chalatenango', 'Comalapa', 'Concepción Quezaltepeque',
                           'El Carrizal', 'La Laguna', 'Las Vueltas', 'Las Flores', 'Nombre de Jesús', 'Nueva Trinidad',
                           'Ojos de Agua', 'Potonico', 'San Antonio de la Cruz', 'San Antonio Los Ranchos',
                           'San Francisco Lempa', 'San Isidro Labrador', 'San Luis del Carmen',
                           'San Miguel de Mercedes']),                                                     -- Chalatenango Sur

    ('La Libertad', ARRAY['Quezaltepeque', 'San Matías', 'San Pablo Tacachico']),                          -- La Libertad Norte
    ('La Libertad', ARRAY['San Juan Opico', 'Ciudad Arce']),                                               -- La Libertad Centro
    ('La Libertad', ARRAY['Colón', 'Jayaque', 'Sacacoyo', 'Tepecoyo', 'Talnique']),                        -- La Libertad Oeste
    ('La Libertad', ARRAY['Antiguo Cuscatlán', 'Huizúcar', 'Nuevo Cuscatlán', 'San José Villanueva', 'Zaragoza']),  -- La Libertad Este
    ('La Libertad', ARRAY['Chiltiupán', 'Jicalapa', 'La Libertad', 'Tamanique', 'Teotepeque']),            -- La Libertad Costa
    ('La Libertad', ARRAY['Santa Tecla', 'Comasagua']),                                                    -- La Libertad Sur

    ('San Salvador', ARRAY['Aguilares', 'El Paisnal', 'Guazapa']),                                         -- San Salvador Norte
    ('San Salvador', ARRAY['Apopa', 'Nejapa']),                                                            -- San Salvador Oeste
    ('San Salvador', ARRAY['Ilopango', 'San Martín', 'Soyapango', 'Tonacatepeque']),                       -- San Salvador Este
    ('San Salvador', ARRAY['Ayutuxtepeque', 'Mejicanos', 'Cuscatancingo', 'Ciudad Delgado', 'San Salvador']),  -- San Salvador Centro
    ('San Salvador', ARRAY['San Marcos', 'Santo Tomás', 'Santiago Texacuangos', 'Panchimalco',
                           'Rosario de Mora']),                                                            -- San Salvador Sur

    ('Cuscatlán', ARRAY['Suchitoto', 'San José Guayabal', 'Oratorio de Concepción', 'San Bartolomé Perulapía',
                        'San Pedro Perulapán']),                                                           -- Cuscatlán Norte
    ('Cuscatlán', ARRAY['Cojutepeque', 'Candelaria', 'El Carmen', 'El Rosario', 'Monte San Juan', 'San Cristóbal',
                        'San Rafael Cedros', 'San Ramón', 'Santa Cruz Analquito', 'Santa Cruz Michapa',
                        'Tenancingo']),                                                                    -- Cuscatlán Sur

    ('La Paz', ARRAY['Cuyultitán', 'Olocuilta', 'San Juan Talpa', 'San Luis Talpa', 'San Pedro Masahuat',
                     'Tapalhuaca', 'San Francisco Chinameca']),                                            -- La Paz Oeste
    ('La Paz', ARRAY['El Rosario', 'Jerusalén', 'Mercedes La Ceiba', 'Paraíso de Osorio', 'San Antonio Masahuat',
                     'San Emigdio', 'San Juan Tepezontes', 'San Luis La Herradura', 'San Miguel Tepezontes',
                     'San Pedro Nonualco', 'Santa María Ostuma', 'Santiago Nonualco']),                    -- La Paz Centro
    ('La Paz', ARRAY['San Juan Nonualco', 'San Rafael Obrajuelo', 'Zacatecoluca']),                        -- La Paz Este

    ('Cabañas', ARRAY['Guacotecti', 'San Isidro', 'Sensuntepeque', 'Victoria', 'Dolores']),                -- Cabañas Este
    ('Cabañas', ARRAY['Cinquera', 'Ilobasco', 'Jutiapa', 'Tejutepeque']),                                  -- Cabañas Oeste

    ('San Vicente', ARRAY['Apastepeque', 'Santa Clara', 'San Ildefonso', 'San Esteban Catarina', 'San Sebastián',
                          'San Lorenzo', 'Santo Domingo']),                                                -- San Vicente Norte
    ('San Vicente', ARRAY['San Vicente', 'Guadalupe', 'San Cayetano Istepeque', 'Tecoluca', 'Tepetitán',
                          'Verapaz']),                                                                     -- San Vicente Sur

    ('Usulután', ARRAY['Alegría', 'Berlín', 'El Triunfo', 'Estanzuelas', 'Jucuapa', 'Mercedes Umaña',
                       'Nueva Granada', 'San Buenaventura', 'Santiago de María']),                         -- Usulután Norte
    ('Usulután', ARRAY['California', 'Concepción Batres', 'Ereguayquín', 'Jucuarán', 'Ozatlán', 'Santa Elena',
                       'San Dionisio', 'Santa María', 'Tecapán', 'Usulután']),                             -- Usulután Este
    ('Usulután', ARRAY['Jiquilisco', 'Puerto El Triunfo', 'San Agustín', 'San Francisco Javier']),         -- Usulután Oeste

    ('San Miguel', ARRAY['Ciudad Barrios', 'Sesori', 'Nuevo Edén de San Juan', 'San Gerardo', 'San Luis de la Reina',
                         'Carolina', 'San Antonio', 'Chapeltique']),                                       -- San Miguel Norte
    ('San Miguel', ARRAY['San Miguel', 'Comacarán', 'Uluazapa', 'Moncagua', 'Quelepa', 'Chirilagua']),     -- San Miguel Centro
    ('San Miguel', ARRAY['Chinameca', 'El Tránsito', 'Lolotique', 'Nueva Guadalupe', 'San Jorge',
                         'San Rafael Oriente']),                                                           -- San Miguel Oeste

    ('Morazán', ARRAY['Arambala', 'Cacaopera', 'Corinto', 'El Rosario', 'Joateca', 'Jocoaitique', 'Meanguera',
                      'Perquín', 'San Fernando', 'San Isidro', 'Torola']),                                 -- Morazán Norte
    ('Morazán', ARRAY['Chilanga', 'Delicias de Concepción', 'El Divisadero', 'Gualococti', 'Guatajiagua', 'Jocoro',
                      'Lolotiquillo', 'Osicala', 'San Carlos', 'San Francisco Gotera', 'San Simón', 'Sensembra',
                      'Sociedad', 'Yamabal', 'Yoloaiquín']),                                               -- Morazán Sur

    ('La Unión', ARRAY['Anamorós', 'Bolívar', 'Concepción de Oriente', 'El Sauce', 'Lislique', 'Nueva Esparta',
                       'Pasaquina', 'Polorós', 'San José', 'Santa Rosa de Lima']),                         -- La Unión Norte
    ('La Unión', ARRAY['Conchagua', 'El Carmen', 'Intipucá', 'La Unión', 'Meanguera del Golfo', 'San Alejo',
                       'Yayantique', 'Yucuaiquín'])                                                        -- La Unión Sur
) AS v (departamento, municipios)
JOIN departamentos d ON d.nombre = v.departamento
CROSS JOIN LATERAL unnest(v.municipios) AS m (nombre)
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

-- Una zona genérica "Centro" en cada municipio, para que cualquier persona pueda registrarse y trabajar
-- en el suyo mientras el administrador agrega las colonias reales. No es una colonia oficial.
INSERT INTO colonias (municipio_id, nombre)
SELECT id, 'Centro' FROM municipios
ON CONFLICT (municipio_id, nombre) DO NOTHING;
