-- Autorisation des équivalences alimentaires (swaps) côté client, par plan complet.
-- true = le client peut remplacer un aliment par un équivalent en restant dans ses macros.
-- Défaut true → comportement actuel inchangé pour les plans existants.
ALTER TABLE public.plans_full
  ADD COLUMN IF NOT EXISTS allow_swaps boolean DEFAULT true;
