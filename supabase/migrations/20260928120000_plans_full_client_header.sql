-- Chiffre affiché en haut d'un plan alimentaire dans l'app cliente.
-- NULL = comportement historique (objectif du calcul macros, sinon moyenne du plan).
-- {"mode":"plan"} = moyenne réelle du plan · {"mode":"hidden"} = en-tête masqué
-- {"mode":"manual","kcal":2600,"prot":177,"carb":336,"fat":58} = valeurs saisies par le coach
ALTER TABLE plans_full ADD COLUMN IF NOT EXISTS client_header jsonb;
