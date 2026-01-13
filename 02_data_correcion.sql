
USE arbolado_madrid;
SET SQL_SAFE_UPDATES = 0;


/* =========================================================
   LIMPIEZA
   ========================================================= */

START TRANSACTION;

-- 1.2) DELETE de errores extremos (imposibles)
-- Ajuste de umbrales según tu hipótesis:
-- - altura > 500 m: imposible
-- - perímetro > 6500 cm: imposible
DELETE FROM fact_arbol
WHERE (altura IS NOT NULL AND altura > 500)
   OR (perimetro IS NOT NULL AND perimetro > 6500);

-- 1.3) UPDATE: normalización usando tus funciones
-- - Altura: corrige escala (ej: 470 -> 47) o pone NULL si no tiene sentido
-- - Perímetro: corrige escala (ej: 4800 -> 480)
UPDATE fact_arbol
SET
  altura = fn_altura_limpia(altura),
  perimetro = fn_perimetro_limpio(perimetro);
COMMIT;

SET SQL_SAFE_UPDATES = 1;
