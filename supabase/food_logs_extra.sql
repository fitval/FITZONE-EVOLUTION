-- ============================================================
-- FITZONE EVOLUTION — food_logs.extra (micros, barcode, brand…)
-- ============================================================
-- Ajoute une colonne JSONB `extra` à food_logs pour stocker les
-- métadonnées additionnelles d'un aliment loggé (notamment via le
-- scan de code-barres OpenFoodFacts) :
--   {
--     "source": "off" | "manual" | "aliment_db",
--     "barcode": "3017620422003",
--     "brand": "Nutella",
--     "image_url": "https://...",
--     "off_id": "3017620422003",
--     "micros": {
--       "sucre": 56.3, "fibres": 3.4, "sodium": 0.107,
--       "sat_fat": 10.6, "salt": 0.107
--     }
--   }
-- ============================================================

ALTER TABLE public.food_logs
  ADD COLUMN IF NOT EXISTS extra jsonb DEFAULT '{}'::jsonb;
