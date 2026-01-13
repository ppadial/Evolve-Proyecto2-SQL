# Proyecto SQL — Arbolado Madrid

## 1. Objetivo del proyecto
El objetivo es diseñar e implementar una base de datos relacional a partir de un dataset de arbolado urbano de Madrid.

El enfoque del análisis se centra en:
- Distribución del arbolado por zonas (distritos, barrios, parques).
- Características físicas (altura, perímetro) y tipologías.
- Seguridad y mantenimiento (riesgo de caída, estado sanitario, poda, coste).
- Salud pública (alergenicidad) y seguridad para mascotas (toxicidad).
- Biodiversidad (riqueza y dominancia de especies).

## 2. Alcance y limitaciones
- El dataset original era muy grande (~800.000 filas), por lo que se ha usado una versión **truncada (~30.000 filas)** para que el repositorio sea manejable.  
- La limpieza de datos se basa en **hipótesis razonables** (por ejemplo, errores de escala en altura/perímetro) y se documenta en el script correspondiente.  
- Para completar la información del dataset se han generado de forma artificial (mediante reglas coherentes) las siguientes columnas:

### Columnas generadas artificialmente (ChatGPT)

- **Tabla `fact_arbol`**
  - `edad_arbol`
  - `estado_sanitario`
  - `riesgo_caida`
  - `necesidad_poda`
  - `fecha_ultima_poda`
  - `coste_mantenimiento`

- **Tabla `dim_especie`**
  - `polinizacion`
  - `nivel_alergenico`
  - `toxicidad_mascotas`
  - `tipo_hoja`

- **Tabla `dim_distrito`**
  - `superficie_km2`
  - `poblacion`

- **Tabla `dim_barrio`**
  - `superficie_km2`
  - `poblacion`

- **Tabla `dim_parque`**
  - `dimension_ha`

## 3. Modelo de datos (tablas y granularidad)
La base de datos se llama **`arbolado_madrid`** y sigue un esquema tipo **estrella (star schema)**.

### Tabla de hechos
**`fact_arbol`** (granularidad: 1 fila = 1 árbol inventariado)
- PK: `cod_num` (identificador único del árbol)
- Medidas: `altura`, `perimetro`, `coste_mantenimiento`
- Estado/Mantenimiento: `estado_sanitario`, `riesgo_caida`, `necesidad_poda`, `fecha_ultima_poda`
- FKs: distrito, barrio, parque, especie

### Tablas dimensión
**`dim_distrito`** (granularidad: 1 fila = 1 distrito)  
- PK: `num_distrito`
- Atributos: `nombre_distrito`, `superficie_km2`, `poblacion`

**`dim_barrio`** (granularidad: 1 fila = 1 barrio)  
- PK: `num_barrio`
- Atributos: `nombre_barrio`, `superficie_km2`, `poblacion`

**`dim_parque`** (granularidad: 1 fila = 1 parque/zona verde)  
- PK: `num_parque`
- Atributos: `nombre_parque`, `dimension_ha`

**`dim_especie`** (granularidad: 1 fila = 1 especie)  
- PK: `codigo_especie`
- Atributos: `nombre_comun`, `nombre_cientifico`, `tipo_planta`, `estado`,
  `polinizacion`, `nivel_alergenico`, `toxicidad_mascotas`, `tipo_hoja`

## 4. Relaciones (PK/FK)
- `fact_arbol.cod_especie` → `dim_especie.codigo_especie`
- `fact_arbol.n_distrito` → `dim_distrito.num_distrito`
- `fact_arbol.n_barrio` → `dim_barrio.num_barrio`
- `fact_arbol.n_parque` → `dim_parque.num_parque`

Las FKs garantizan integridad referencial: un árbol siempre apunta a valores válidos en sus dimensiones (cuando existan).

## 5. Constraints e índices
Se han usado constraints para asegurar coherencia, por ejemplo:
- rangos válidos (edad, costes no negativos, etc.)
- valores válidos en campos binarios y enums

Se incluyen índices en las columnas FK más consultadas para mejorar rendimiento:
- `n_distrito`, `n_barrio`, `n_parque`, `cod_especie`

## 6. Limpieza de datos (calidad)
Se realizan acciones típicas de calidad:
- Detección de outliers extremos (ej. alturas imposibles, perímetros absurdos).
- Normalización por reglas (por ejemplo, corregir errores de escala dividiendo entre 10 en casos plausibles).
- Uso de transacciones y tabla backup antes de aplicar cambios.

## 7. Métricas y análisis (EDA)
Ejemplos de análisis realizados:
- Top árboles más altos y dónde se encuentran.
- Volumen de árboles por distrito/barrio/parque.
- Especies dominantes por distrito y su % de representación.
- Distribución de categorías de altura.
- Distritos con mayor % de riesgo alto.
- Ranking de parques por porcentaje de alergénicos altos o tóxicos para mascotas.
- Biodiversidad por distrito (número de especies distintas).
- Especies con mayor riesgo de caída alto.

## 8. Estructura del repositorio
- `01_schema.sql` → creación de BD/tablas, constraints, índices y funciones si aplica
- `02_data.sql` → inserción/carga de datos
- `02_data_correccion.sql` → ejecución de las funciones y corrección de datos anómalos
- `03_eda.sql` → consultas de análisis exploratorio (núcleo del trabajo)
- `model.png` → diagrama ER
- `README.md` → este documento

## 9. Conclusión de negocio
Este análisis permite:
- Priorizar zonas con mayor riesgo de caída (seguridad ciudadana).
- Detectar parques con alta proporción de especies alergénicas (salud pública).
- Identificar zonas con mayor presencia de especies tóxicas para mascotas.
- Evaluar biodiversidad (evitar monocultivo y mejorar resiliencia).
