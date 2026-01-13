-- Se han eliminado una gran cantidad de datos para no hacer el fichero extremadamente grande tenía casi 800.000 filas y lo hemos dejado en unas 30.000 filas.

USE arbolado_madrid;

-- Consultas de prueba para comprobar la tabla
SELECT * FROM dim_barrio LIMIT 20;
SELECT * FROM dim_distrito LIMIT 20;
SELECT * FROM dim_especie LIMIT 20;
SELECT * FROM dim_parque LIMIT 20;
SELECT * FROM fact_arbol LIMIT 20;

-- Ponemos a mano un valor superior para comprobar que funcione la limpieza de datos
UPDATE fact_arbol
SET perimetro = 5400.0
WHERE cod_num = 2148779;

SELECT * FROM fact_arbol
WHERE cod_num = 2148779;

SELECT * FROM fact_arbol
ORDER BY perimetro DESC;

/*------------
 | CONSULTAS |
 -------------*/
 
-- Consulta 1: Top 10 árboles más altos
SELECT
  e.nombre_comun,
  f.altura,
  p.nombre_parque,
  b.nombre_barrio,
  d.nombre_distrito
FROM fact_arbol f
JOIN dim_distrito d ON d.num_distrito = f.n_distrito
JOIN dim_barrio b   ON b.num_barrio   = f.n_barrio
JOIN dim_parque p   ON p.num_parque   = f.n_parque
JOIN dim_especie e  ON e.codigo_especie = f.cod_especie
WHERE f.altura IS NOT NULL
ORDER BY f.altura DESC
LIMIT 10;
-- Análisis: Identifica los árboles más altos y localiza dónde están (parque/barrio/distrito) y de qué especie son.


-- Consulta 2: Árboles por distrito (cantidad total)
SELECT
  d.num_distrito,
  d.nombre_distrito,
  COUNT(*) AS num_arboles
FROM fact_arbol f
JOIN dim_distrito d ON d.num_distrito = f.n_distrito
GROUP BY d.num_distrito, d.nombre_distrito
ORDER BY num_arboles DESC;
-- Análisis: Mide concentración del arbolado por distrito (dónde hay más/menos árboles). Sirve para comparar volumen de arbolado entre zonas.


-- Consulta 3: Altura media y perímetro medio por distrito
SELECT
  d.num_distrito,
  d.nombre_distrito,
  COUNT(*) AS num_arboles,
  ROUND(AVG(f.altura), 2) AS altura_media,
  ROUND(AVG(f.perimetro), 2) AS perimetro_medio
FROM fact_arbol f
JOIN dim_distrito d ON d.num_distrito = f.n_distrito
GROUP BY d.num_distrito, d.nombre_distrito
ORDER BY altura_media DESC;
-- Análisis: Compara “tamaño promedio” del arbolado por distrito (altura y grosor). Permite ver distritos con árboles más desarrollados o más pequeños en promedio.


-- Consulta 4: Top 10 barrios con más árboles
SELECT
  b.nombre_barrio,
  COUNT(*) AS num_arboles
FROM fact_arbol f
JOIN dim_barrio b ON b.num_barrio = f.n_barrio
GROUP BY b.nombre_barrio
ORDER BY num_arboles DESC
LIMIT 10;
-- Análisis: Detecta barrios con mayor densidad/volumen de arbolado. Útil para enfocar análisis posteriores a nivel micro (barrios “grandes” en arbolado).


-- Consulta 5: Top 10 parques con más árboles
SELECT
  p.nombre_parque,
  COUNT(*) AS num_arboles
FROM fact_arbol f
JOIN dim_parque p ON p.num_parque = f.n_parque
GROUP BY p.nombre_parque
ORDER BY num_arboles DESC
LIMIT 10;
-- Análisis: Identifica los parques con más arbolado total. Sirve como ranking de “parques más arbolados” y para elegir parques a estudiar.


-- Consulta 7: Para cada distrito, especie más común y % del distrito
WITH conteo AS (
  SELECT
    n_distrito,
    cod_especie,
    COUNT(*) AS n
  FROM fact_arbol
  GROUP BY n_distrito, cod_especie
),
ranked AS (
  SELECT
    n_distrito,
    cod_especie,
    n,
    ROW_NUMBER() OVER (PARTITION BY n_distrito ORDER BY n DESC) AS rn,
    SUM(n) OVER (PARTITION BY n_distrito) AS total_distrito
  FROM conteo
)
SELECT
  d.nombre_distrito,
  e.nombre_comun,
  r.n AS arboles_especie,
  r.total_distrito AS total_arboles_distrito,
  ROUND(100 * r.n / r.total_distrito, 2) AS porcentaje_arbol
FROM ranked r
JOIN dim_distrito d ON d.num_distrito = r.n_distrito
JOIN dim_especie e  ON e.codigo_especie = r.cod_especie
WHERE r.rn = 1
ORDER BY porcentaje_arbol DESC;
-- Análisis: Mide “dominancia” de una especie por distrito. Si el % es alto, hay baja diversidad (riesgo de plagas, dependencia de una especie, etc.).


-- Consulta 8: Distribución de altura por categorías dentro de cada distrito
SELECT
  d.nombre_distrito,
  CASE
    WHEN f.altura IS NULL THEN 'SIN_DATO'
    WHEN f.altura < 5 THEN 'PEQUEÑO'
    WHEN f.altura < 10 THEN 'MEDIO'
    WHEN f.altura < 20 THEN 'ALTO'
    ELSE 'MUY_ALTO'
  END AS categoria_altura,
  COUNT(*) AS num_arboles
FROM fact_arbol f
JOIN dim_distrito d
  ON d.num_distrito = f.n_distrito
GROUP BY d.nombre_distrito, categoria_altura
ORDER BY
  d.nombre_distrito,
  FIELD(categoria_altura, 'PEQUEÑO', 'MEDIO', 'ALTO', 'MUY_ALTO', 'SIN_DATO');
-- Análisis: Describe el “perfil de alturas” por distrito (si predominan árboles pequeños, medianos o muy altos). Ayuda a comparar estructura del arbolado entre zonas.


-- Consulta 9: Para cada categoría de altura, barrio con mayor peso en esa categoría
WITH ranked AS (
  SELECT
    b.nombre_barrio,
    CASE
      WHEN f.altura < 5 THEN 'PEQUEÑO'
      WHEN f.altura < 10 THEN 'MEDIO'
      WHEN f.altura < 20 THEN 'ALTO'
      ELSE 'MUY_ALTO'
    END AS categoria_altura,
    COUNT(*) AS num_arboles,
    SUM(COUNT(*)) OVER (PARTITION BY
      CASE
        WHEN f.altura < 5 THEN 'PEQUEÑO'
        WHEN f.altura < 10 THEN 'MEDIO'
        WHEN f.altura < 20 THEN 'ALTO'
        ELSE 'MUY_ALTO'
      END
    ) AS total_categoria,
    ROW_NUMBER() OVER (
      PARTITION BY
        CASE
          WHEN f.altura < 5 THEN 'PEQUEÑO'
          WHEN f.altura < 10 THEN 'MEDIO'
          WHEN f.altura < 20 THEN 'ALTO'
          ELSE 'MUY_ALTO'
        END
      ORDER BY COUNT(*) DESC
    ) AS rn
  FROM fact_arbol f
  JOIN dim_barrio b ON b.num_barrio = f.n_barrio
  GROUP BY b.nombre_barrio, categoria_altura
)
SELECT
  categoria_altura,
  nombre_barrio,
  num_arboles,
  total_categoria,
  ROUND(100 * num_arboles / total_categoria, 2) AS pct_en_categoria
FROM ranked
WHERE rn = 1
ORDER BY FIELD(categoria_altura, 'PEQUEÑO', 'MEDIO', 'ALTO', 'MUY_ALTO');
-- Análisis: Identifica el barrio “más representativo” dentro de cada categoría de altura (quién aporta más árboles pequeños/medios/altos/muy altos al total de la ciudad).


-- Consulta 10: Riesgo de caída alto por distrito
SELECT
  d.nombre_distrito,
  COUNT(*) AS total_arboles,
  SUM(CASE WHEN f.riesgo_caida = 'ALTO' THEN 1 ELSE 0 END) AS num_riesgo_alto,
  ROUND(100 * AVG(CASE WHEN f.riesgo_caida = 'ALTO' THEN 1 ELSE 0 END), 2) AS pct_riesgo_alto
FROM fact_arbol f
JOIN dim_distrito d ON d.num_distrito = f.n_distrito
GROUP BY d.nombre_distrito
ORDER BY pct_riesgo_alto DESC, num_riesgo_alto DESC;
-- Análisis: Prioriza distritos con mayor proporción de árboles potencialmente peligrosos. Útil para inspecciones y planificación de mantenimiento.


-- Consulta 11: Prioridad de intervención por árbol (score) + orden por poda antigua
SELECT
  f.cod_num,
  b.nombre_barrio,
  p.nombre_parque,
  e.nombre_comun,
  f.altura,
  f.perimetro,
  f.estado_sanitario,
  f.riesgo_caida,
  f.necesidad_poda,
  f.fecha_ultima_poda,
  (
    CASE WHEN f.riesgo_caida = 'ALTO' THEN 3
         WHEN f.riesgo_caida = 'MEDIO' THEN 2
         WHEN f.riesgo_caida = 'BAJO' THEN 1
         ELSE 0 END
    +
    CASE WHEN f.estado_sanitario = 'MALO' THEN 2
         WHEN f.estado_sanitario = 'REGULAR' THEN 1
         ELSE 0 END
    +
    CASE WHEN f.necesidad_poda = 1 THEN 1 ELSE 0 END
  ) AS score_prioridad
FROM fact_arbol f
JOIN dim_barrio b   ON b.num_barrio   = f.n_barrio
JOIN dim_parque p   ON p.num_parque   = f.n_parque
JOIN dim_especie e  ON e.codigo_especie = f.cod_especie
WHERE f.riesgo_caida IN ('ALTO','MEDIO')
ORDER BY
  score_prioridad DESC,
  CASE WHEN f.fecha_ultima_poda IS NULL THEN 1 ELSE 0 END,
  f.fecha_ultima_poda ASC
LIMIT 50;
-- Análisis: Genera una lista “operativa” de árboles a revisar primero combinando riesgo, estado y necesidad de poda. El orden por poda antigua ayuda a priorizar intervenciones atrasadas.


-- Consulta 12: Parques con mayor coste medio de mantenimiento (top 10)
SELECT
  p.nombre_parque,
  COUNT(*) AS total_arboles,
  ROUND(SUM(COALESCE(f.coste_mantenimiento, 0)), 2) AS coste_total,
  ROUND(AVG(f.coste_mantenimiento), 2) AS coste_medio
FROM fact_arbol f
JOIN dim_parque p ON p.num_parque = f.n_parque
GROUP BY p.nombre_parque
ORDER BY coste_medio DESC
LIMIT 10;
-- Análisis: Identifica parques donde el mantenimiento por árbol es más caro en promedio. Útil para revisar especies, estado sanitario o condiciones del parque.


-- Consulta 13: Top 10 especies con nivel alérgico máximo (3) por número de árboles
SELECT
  e.nombre_comun,
  e.nombre_cientifico,
  e.nivel_alergenico,
  COUNT(*) AS num_arboles
FROM fact_arbol f
JOIN dim_especie e ON e.codigo_especie = f.cod_especie
WHERE e.nivel_alergenico = 3
GROUP BY e.nombre_comun, e.nombre_cientifico, e.nivel_alergenico
ORDER BY num_arboles DESC
LIMIT 10;
-- Análisis: Detecta las especies potencialmente más problemáticas para alérgicos (nivel 3) y su presencia en la ciudad. Útil para salud pública y planificación.


-- Consulta 14: Top 10 parques por % de árboles alergénicos altos (>=2)
SELECT
  p.nombre_parque,
  COUNT(*) AS total_arboles,
  SUM(CASE WHEN e.nivel_alergenico >= 2 THEN 1 ELSE 0 END) AS alergenicos_altos,
  ROUND(100 * AVG(CASE WHEN e.nivel_alergenico >= 2 THEN 1 ELSE 0 END), 2) AS pct_alergenicos_altos
FROM fact_arbol f
JOIN dim_parque p ON p.num_parque = f.n_parque
JOIN dim_especie e ON e.codigo_especie = f.cod_especie
GROUP BY p.nombre_parque
HAVING COUNT(*) >= 50
ORDER BY pct_alergenicos_altos DESC, alergenicos_altos DESC
LIMIT 10;
-- Análisis: Prioriza parques donde la proporción de especies alergénicas es mayor. Útil para recomendaciones (rutas, señalización, planificación de especies).


-- Consulta 15: Top 10 parques por % de árboles tóxicos para mascotas
SELECT
  p.nombre_parque,
  COUNT(*) AS total_arboles,
  SUM(CASE WHEN e.toxicidad_mascotas = 'TOXICO' THEN 1 ELSE 0 END) AS num_toxicos,
  ROUND(100 * AVG(CASE WHEN e.toxicidad_mascotas = 'TOXICO' THEN 1 ELSE 0 END), 2) AS pct_toxicos
FROM fact_arbol f
JOIN dim_parque p ON p.num_parque = f.n_parque
JOIN dim_especie e ON e.codigo_especie = f.cod_especie
GROUP BY p.nombre_parque
HAVING COUNT(*) >= 50
ORDER BY pct_toxicos DESC, num_toxicos DESC
LIMIT 10;
-- Análisis: Señala parques con mayor proporción de especies potencialmente peligrosas para mascotas. Útil para dueños de perros y para posibles señalizaciones.


-- Consulta 16: Top 10 especies tóxicas por número de árboles
SELECT
  e.nombre_comun,
  e.nombre_cientifico,
  COUNT(*) AS num_arboles
FROM fact_arbol f
JOIN dim_especie e ON e.codigo_especie = f.cod_especie
WHERE e.toxicidad_mascotas = 'TOXICO'
GROUP BY e.nombre_comun, e.nombre_cientifico
ORDER BY num_arboles DESC
LIMIT 10;
-- Análisis: Identifica qué especies tóxicas son más frecuentes en el inventario. Útil para focalizar campañas informativas o sustitución gradual de especies.


-- Consulta 17: Biodiversidad por distrito (nº de especies distintas)
SELECT
  d.nombre_distrito,
  COUNT(*) AS total_arboles,
  COUNT(DISTINCT f.cod_especie) AS especies_distintas
FROM fact_arbol f
JOIN dim_distrito d ON d.num_distrito = f.n_distrito
GROUP BY d.nombre_distrito
ORDER BY especies_distintas DESC;
-- Análisis: Mide biodiversidad (riqueza de especies) por distrito. Distritos con pocas especies son más vulnerables a plagas y cambios ambientales.


-- Consulta 18: Top 10 especies por altura media (mínimo 50 árboles)
SELECT
  e.nombre_comun,
  e.nombre_cientifico,
  COUNT(*) AS arboles_totales,
  ROUND(AVG(f.altura), 2) AS altura_media
FROM fact_arbol f
JOIN dim_especie e ON e.codigo_especie = f.cod_especie
WHERE f.altura IS NOT NULL
GROUP BY e.nombre_comun, e.nombre_cientifico
HAVING COUNT(*) >= 50
ORDER BY altura_media DESC
LIMIT 10;
-- Análisis: Permite comparar especies “más altas” en promedio (con tamaño de muestra mínimo). Útil para planificación urbana (sombra, paisaje, etc.).


-- Consulta 19: Top 10 especies por perímetro medio (mínimo 50 árboles)
SELECT
  e.nombre_comun,
  e.nombre_cientifico,
  COUNT(*) AS n,
  ROUND(AVG(f.perimetro), 2) AS perimetro_medio
FROM fact_arbol f
JOIN dim_especie e ON e.codigo_especie = f.cod_especie
WHERE f.perimetro IS NOT NULL
GROUP BY e.nombre_comun, e.nombre_cientifico
HAVING COUNT(*) >= 50
ORDER BY perimetro_medio DESC
LIMIT 10;
-- Análisis: Similar a la anterior pero centrada en grosor/robustez (perímetro). Puede indicar especies que triggered mayor mantenimiento o árboles maduros.


-- Consulta 20: Tipo de hoja por distrito en porcentaje
SELECT
  d.nombre_distrito,
  e.tipo_hoja,
  COUNT(*) AS num_arboles,
  ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY d.nombre_distrito), 2) AS pct_en_distrito
FROM fact_arbol f
JOIN dim_distrito d ON d.num_distrito = f.n_distrito
JOIN dim_especie e ON e.codigo_especie = f.cod_especie
GROUP BY d.nombre_distrito, e.tipo_hoja
ORDER BY d.nombre_distrito, pct_en_distrito DESC;
-- Análisis: Describe composición de hoja (caduca/perenne/etc.) por distrito. Útil para entender estacionalidad (sombra en verano, caída de hoja, limpieza, etc.).


-- Consulta 21: Especies con mayor % de riesgo de caída ALTO (mínimo 80 árboles)
SELECT
  e.nombre_comun,
  e.nombre_cientifico,
  COUNT(*) AS total,
  SUM(CASE WHEN f.riesgo_caida = 'ALTO' THEN 1 ELSE 0 END) AS num_riesgo_alto,
  ROUND(100 * AVG(CASE WHEN f.riesgo_caida = 'ALTO' THEN 1 ELSE 0 END), 2) AS pct_riesgo_alto
FROM fact_arbol f
JOIN dim_especie e ON e.codigo_especie = f.cod_especie
GROUP BY e.nombre_comun, e.nombre_cientifico
HAVING COUNT(*) >= 80
ORDER BY pct_riesgo_alto DESC, num_riesgo_alto DESC
LIMIT 15;
-- Análisis: Detecta especies “problemáticas” desde el punto de vista de seguridad (más probabilidad de riesgo ALTO). Puede justificar acciones específicas por especie (inspección, poda, sustitución).

-- Consulta 22: Árboles por hectarea en parques
SELECT
  p.nombre_parque,
  p.dimension_ha,
  COUNT(*) AS total_arboles,
  ROUND(COUNT(*) / NULLIF(p.dimension_ha, 0), 2) AS arboles_por_ha
FROM fact_arbol f
JOIN dim_parque p ON p.num_parque = f.n_parque
WHERE p.dimension_ha IS NOT NULL
GROUP BY p.nombre_parque, p.dimension_ha
HAVING p.dimension_ha > 0 AND COUNT(*) >= 50
ORDER BY arboles_por_ha DESC
LIMIT 15;
-- Análisis: ranking de parques “más densos” en árboles por superficie

-- Consulta 23: Árboles por 1000 habitantes por distrito
SELECT
  d.nombre_distrito,
  d.poblacion,
  COUNT(*) AS total_arboles,
  ROUND(1000 * COUNT(*) / NULLIF(d.poblacion, 0), 2) AS arboles_por_1000_hab
FROM fact_arbol f
JOIN dim_distrito d ON d.num_distrito = f.n_distrito
WHERE d.poblacion IS NOT NULL
GROUP BY d.nombre_distrito, d.poblacion
HAVING d.poblacion > 0
ORDER BY arboles_por_1000_hab DESC;

-- Consulta 24: Árboles por km^2
SELECT
  d.nombre_distrito,
  d.superficie_km2,
  COUNT(*) AS total_arboles,
  ROUND(COUNT(*) / NULLIF(d.superficie_km2, 0), 2) AS arboles_por_km2
FROM fact_arbol f
JOIN dim_distrito d ON d.num_distrito = f.n_distrito
WHERE d.superficie_km2 IS NOT NULL
GROUP BY d.nombre_distrito, d.superficie_km2
HAVING d.superficie_km2 > 0
ORDER BY arboles_por_km2 DESC;

-- COnsulta 25: Distritos que están por encima de la media de la ciudad en % de riesgo ALTO
SELECT
  d.nombre_distrito,
  COUNT(*) AS total_arboles,
  SUM(CASE WHEN f.riesgo_caida = 'ALTO' THEN 1 ELSE 0 END) AS num_riesgo_alto,
  ROUND(100 * AVG(CASE WHEN f.riesgo_caida = 'ALTO' THEN 1 ELSE 0 END), 2) AS pct_riesgo_alto,
  ROUND(100 * ciudad.media_riesgo_alto, 2) AS media_ciudad_pct_riesgo_alto
FROM fact_arbol f
JOIN dim_distrito d ON d.num_distrito = f.n_distrito
CROSS JOIN (
  SELECT AVG(CASE WHEN riesgo_caida = 'ALTO' THEN 1 ELSE 0 END) AS media_riesgo_alto
  FROM fact_arbol
) ciudad
GROUP BY d.nombre_distrito, ciudad.media_riesgo_alto
HAVING AVG(CASE WHEN f.riesgo_caida = 'ALTO' THEN 1 ELSE 0 END) > ciudad.media_riesgo_alto
ORDER BY pct_riesgo_alto DESC, num_riesgo_alto DESC;


