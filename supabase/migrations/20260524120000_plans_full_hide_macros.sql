-- Ajoute un flag "hide_macros" sur les plans alimentaires.
-- Quand true, l'app client masque toutes les valeurs nutritionnelles (kcal + P/G/L).
ALTER TABLE plans_full
  ADD COLUMN IF NOT EXISTS hide_macros boolean NOT NULL DEFAULT false;
