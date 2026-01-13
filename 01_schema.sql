/* =========================================================
   SECCIÓN 0: CREACION DE BASE DE DATOS
   ========================================================= */
DROP DATABASE IF EXISTS arbolado_madrid;
CREATE DATABASE arbolado_madrid;
USE arbolado_madrid;

/* =========================================================
   SECCIÓN 1: DROP
   ========================================================= */

DROP TABLE IF EXISTS fact_arbol;
DROP TABLE IF EXISTS dim_parque;
DROP TABLE IF EXISTS dim_barrio;
DROP TABLE IF EXISTS dim_distrito;
DROP TABLE IF EXISTS dim_especie;


/* =========================================================
   SECCIÓN 2: CREACIÓN DE TABLAS
   ========================================================= */

-- Dimensión especie (enriquecida)
CREATE TABLE dim_especie (
  codigo_especie      VARCHAR(10)  NOT NULL,
  nombre_comun        VARCHAR(150) NULL,
  nombre_cientifico   VARCHAR(150) NULL,
  tipo_planta         VARCHAR(30)  NULL,
  estado              VARCHAR(20)  NULL,

   -- Datos chatgpt
  polinizacion        ENUM('VIENTO','INSECTOS','MIXTA') NULL,
  nivel_alergenico    TINYINT      NULL,  -- 0-3
  toxicidad_mascotas  ENUM('TOXICO','NO_REPORTADO') NULL,
  tipo_hoja           ENUM('CADUCA','PERENNE','SEMICADUCA','DESCONOCIDA') NULL,

  PRIMARY KEY (codigo_especie),

  CONSTRAINT ck_especie_nivel_alergenico
    CHECK (nivel_alergenico IS NULL OR nivel_alergenico BETWEEN 0 AND 3)
);

-- Dimensión distrito (enriquecida)
CREATE TABLE dim_distrito (
  num_distrito     TINYINT      NOT NULL,
  nombre_distrito  VARCHAR(60)  NOT NULL,
  
    -- Datos chatgpt
  superficie_km2   DECIMAL(7,2) NULL,
  poblacion        INT          NULL,

  PRIMARY KEY (num_distrito),

  CONSTRAINT ck_distrito_superficie
    CHECK (superficie_km2 IS NULL OR superficie_km2 >= 0),
  CONSTRAINT ck_distrito_poblacion
    CHECK (poblacion IS NULL OR poblacion >= 0)
);

-- Dimensión barrio (enriquecida)
CREATE TABLE dim_barrio (
  num_barrio      INT          NOT NULL,
  nombre_barrio   VARCHAR(60)  NOT NULL,
  
  -- Datos chatgpt
  superficie_km2  DECIMAL(7,2) NULL,
  poblacion       INT          NULL,

  PRIMARY KEY (num_barrio),

  CONSTRAINT ck_barrio_superficie
    CHECK (superficie_km2 IS NULL OR superficie_km2 >= 0),
  CONSTRAINT ck_barrio_poblacion
    CHECK (poblacion IS NULL OR poblacion >= 0)
);

-- Dimensión parque (enriquecida)
CREATE TABLE dim_parque (
  num_parque     INT          NOT NULL,
  nombre_parque  VARCHAR(120) NULL,
  
  -- Datos chatgpt
  dimension_ha   DECIMAL(10,2) NULL,

  PRIMARY KEY (num_parque),

  CONSTRAINT ck_parque_dimension
    CHECK (dimension_ha IS NULL OR dimension_ha >= 0)
);

-- Tabla de hechos (enriquecida)
CREATE TABLE fact_arbol (
  cod_num            BIGINT       NOT NULL,      -- ASSETNUM
  n_parque           INT          NULL,          -- NUM_PARQUE
  n_distrito         TINYINT      NOT NULL,      -- NUM_DTO
  n_barrio           INT          NULL,          -- NUM_BARRIO
  cod_especie        VARCHAR(10)  NOT NULL,      -- CODIGO_ESPECIE
  perimetro          DECIMAL(10,2) NULL,         -- PERIMETRO (cm)
  altura             DECIMAL(6,2)  NULL,         -- ALTURA_TOTAL (m)

  -- Datos chatgpt
  edad_arbol         SMALLINT      NULL,
  estado_sanitario   ENUM('SANO','REGULAR','MALO','SECO') NULL,
  riesgo_caida       ENUM('BAJO','MEDIO','ALTO') NULL,
  necesidad_poda     TINYINT       NULL,         -- 0 -> No necesita poda / 1 -> Necesita poda
  fecha_ultima_poda  DATE          NULL,
  coste_mantenimiento DECIMAL(10,2) NULL,        -- EUR

  PRIMARY KEY (cod_num),

  CONSTRAINT fk_fact_especie
    FOREIGN KEY (cod_especie) REFERENCES dim_especie(codigo_especie),

  CONSTRAINT fk_fact_parque
    FOREIGN KEY (n_parque) REFERENCES dim_parque(num_parque),

  CONSTRAINT fk_fact_distrito
    FOREIGN KEY (n_distrito) REFERENCES dim_distrito(num_distrito),

  CONSTRAINT fk_fact_barrio
    FOREIGN KEY (n_barrio) REFERENCES dim_barrio(num_barrio),

  CONSTRAINT ck_fact_necesidad_poda
    CHECK (necesidad_poda IS NULL OR necesidad_poda IN (0,1)),

  CONSTRAINT ck_fact_edad_arbol
    CHECK (edad_arbol IS NULL OR edad_arbol BETWEEN 0 AND 200),

  CONSTRAINT ck_fact_coste
    CHECK (coste_mantenimiento IS NULL OR coste_mantenimiento >= 0)
);

-- Índices recomendados para consultas (opcionales, pero ayudan mucho)
CREATE INDEX idx_fact_distrito ON fact_arbol (n_distrito);
CREATE INDEX idx_fact_barrio   ON fact_arbol (n_barrio);
CREATE INDEX idx_fact_parque   ON fact_arbol (n_parque);
CREATE INDEX idx_fact_especie  ON fact_arbol (cod_especie);

/* =========================================================
   SECCIÓN 3: LIMPIEZA ALTURA/PERIMETRO
   ========================================================= */

DROP FUNCTION IF EXISTS fn_altura_limpia;
DROP FUNCTION IF EXISTS fn_perimetro_limpio;

DELIMITER $$

CREATE FUNCTION fn_altura_limpia(a DECIMAL(10,2))
RETURNS DECIMAL(10,2)
DETERMINISTIC
NO SQL
BEGIN
  RETURN
    CASE
      WHEN a IS NULL OR a <= 0 THEN NULL
      WHEN a <= 50 THEN a
      WHEN a <= 500 THEN
        CASE
          WHEN (a / 10) <= 60 THEN (a / 10)
          ELSE NULL
        END
      ELSE NULL
    END;
END$$
/*
	El arbol mas alto de Madrid son 48m de altura. Si sale algun arbol mayor de 50m lo divido entre 10 suponiendo que se equivocaron. Si es mayor de 500 la elimino.
*/

CREATE FUNCTION fn_perimetro_limpio(p DECIMAL(10,2))
RETURNS DECIMAL(10,2)
DETERMINISTIC
NO SQL
BEGIN
  RETURN
	CASE
	  WHEN p IS NULL OR p <= 0 THEN NULL
	  WHEN p < 1 THEN NULL                      -- demasiado pequeño para cm
	  WHEN p <= 650 THEN p                     	-- Perimetro maximo 650 cm
	  WHEN p <= 6500 THEN					
		CASE
		  WHEN (p / 10) <= 650 THEN (p / 10)    
		  ELSE NULL
		END
	  ELSE NULL
	END;
END$$

/*
	Igual que antes aparecen perimetros demasiado grandes, suponemos que hay confusion en las unidades metricas.
*/

DELIMITER ;


