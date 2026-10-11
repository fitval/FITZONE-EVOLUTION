-- ============================================================
-- FITZONE EVOLUTION — Fibres, 5e valeur nutritionnelle à côté de kcal / prot / carb / fat
-- ============================================================
-- Colonnes ajoutées vides (null = « non renseigné », différent de 0). Aucune donnée existante n'est modifiée.
-- Mêmes conventions que les macros de chaque table :
--   aliments.fibres, food_logs.fibres                 → grammes pour 100 g
--   repas.fibres                                      → total de la recette (déjà multiplié par les quantités)
--   plans_full.fibres                                 → moyenne par jour du plan
--   plans.fibres_g                                    → objectif quotidien du calcul macros (comme protein_g)
-- Dans les jsonb (plans_full.jours[].repas[].alims[], repas.items[], client_recipes.items[], plan_swaps.alim),
-- la clé est `fibres`, pour 100 g, sans migration.
-- Droits : accordés table par table, les nouvelles colonnes en héritent ; la RLS ne change pas.
--
-- Une instruction par ligne. Rejouable : add column if not exists.
-- ============================================================

alter table public.aliments add column if not exists fibres numeric check (fibres is null or (fibres >= 0 and fibres <= 100));

alter table public.food_logs add column if not exists fibres numeric check (fibres is null or (fibres >= 0 and fibres <= 100));

alter table public.repas add column if not exists fibres numeric check (fibres is null or fibres >= 0);

alter table public.plans_full add column if not exists fibres numeric check (fibres is null or fibres >= 0);

alter table public.plans add column if not exists fibres_g integer check (fibres_g is null or fibres_g >= 0);
