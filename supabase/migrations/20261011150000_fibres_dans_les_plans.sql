-- ============================================================
-- FITZONE EVOLUTION — Fibres recopiées dans les plans, échanges et recettes existants
-- ============================================================
-- Un plan garde une COPIE de chaque aliment (jsonb) : remplir aliments.fibres ne l'a pas mis à jour.
-- Ici, chaque copie reçoit la clé `fibres` de l'aliment du même nom dans la base du coach (comparaison sans
-- tenir compte des majuscules ni des espaces ; 3 variantes d'écriture rattachées à la main). Rien d'autre ne change :
-- n'ajoute `fibres` que là où elle manque. Testé en lecture seule le 2026-10-11 sur les 15 plans : 1 124 aliments sur 1 124,
-- tout le reste identique.
-- Sauvegarde avant modification dans le schéma `sauvegarde` (non exposé par l'API, aucun droit pour anon / authenticated).
-- Une instruction par ligne.
-- ============================================================

create schema if not exists sauvegarde;

revoke all on schema sauvegarde from public, anon, authenticated;

create table if not exists sauvegarde.plans_full_20261011 as select id, jours, fibres from public.plans_full;

create table if not exists sauvegarde.plan_swaps_20261011 as select id, alim from public.plan_swaps;

create table if not exists sauvegarde.repas_20261011 as select id, items, fibres from public.repas;

create table if not exists sauvegarde.client_recipes_20261011 as select id, items from public.client_recipes;

update public.plans_full p set jours = coalesce((select jsonb_agg(case when jsonb_typeof(j.value->'repas')='array' then jsonb_set(j.value,'{repas}', coalesce((select jsonb_agg(case when jsonb_typeof(r.value->'alims')='array' then jsonb_set(r.value,'{alims}', coalesce((select jsonb_agg(case when a.value->>'fibres' is null and f.fibres is not null then a.value || jsonb_build_object('fibres', f.fibres) else a.value end order by a.ordinality) from jsonb_array_elements(r.value->'alims') with ordinality a left join lateral (select x.fibres from public.aliments x where x.coach_id = p.coach_id and x.fibres is not null and lower(btrim(x.nom)) = lower(btrim(case lower(btrim(a.value->>'nom')) when 'brocoli' then 'Brocolis' when 'carré frais 0%' then 'Carré frais 0% (1 carré = 25)' when 'pates complètes (100g)' then 'Pâtes complètes (100g)' else a.value->>'nom' end)) order by x.id limit 1) f on true), '[]'::jsonb)) else r.value end order by r.ordinality) from jsonb_array_elements(j.value->'repas') with ordinality r), '[]'::jsonb)) else j.value end order by j.ordinality) from jsonb_array_elements(p.jours) with ordinality j), p.jours) where jsonb_typeof(p.jours)='array' and jsonb_array_length(p.jours) > 0;

update public.plans_full p set fibres = t.moy from (select p2.id, round(sum((a->>'fibres')::numeric * coalesce(nullif(a->>'qte','')::numeric, 100) / 100) / jsonb_array_length(p2.jours), 1) moy from public.plans_full p2, jsonb_array_elements(p2.jours) j, jsonb_array_elements(coalesce(j->'repas','[]')) r, jsonb_array_elements(coalesce(r->'alims','[]')) a where jsonb_typeof(p2.jours)='array' and jsonb_array_length(p2.jours) > 0 and a->>'fibres' is not null group by p2.id, p2.jours) t where p.id = t.id and p.fibres is null;

update public.plan_swaps s set alim = s.alim || jsonb_build_object('fibres', (select x.fibres from public.aliments x join public.clients c on c.coach_id = x.coach_id where c.id = s.client_id and x.fibres is not null and lower(btrim(x.nom)) = lower(btrim(s.alim->>'nom')) order by x.id limit 1)) where s.alim->>'fibres' is null and exists (select 1 from public.aliments x join public.clients c on c.coach_id = x.coach_id where c.id = s.client_id and x.fibres is not null and lower(btrim(x.nom)) = lower(btrim(s.alim->>'nom')));

update public.repas rp set items = coalesce((select jsonb_agg(case when a.value->>'fibres' is null and f.fibres is not null then a.value || jsonb_build_object('fibres', f.fibres) else a.value end order by a.ordinality) from jsonb_array_elements(rp.items) with ordinality a left join lateral (select x.fibres from public.aliments x where x.coach_id = rp.coach_id and x.fibres is not null and lower(btrim(x.nom)) = lower(btrim(case lower(btrim(a.value->>'nom')) when 'brocoli' then 'Brocolis' when 'carré frais 0%' then 'Carré frais 0% (1 carré = 25)' when 'pates complètes (100g)' then 'Pâtes complètes (100g)' else a.value->>'nom' end)) order by x.id limit 1) f on true), rp.items) where jsonb_typeof(rp.items)='array' and jsonb_array_length(rp.items) > 0;

update public.repas rp set fibres = t.tot from (select r2.id, round(sum((a->>'fibres')::numeric * coalesce(nullif(a->>'qte','')::numeric, 100) / 100), 1) tot from public.repas r2, jsonb_array_elements(r2.items) a where jsonb_typeof(r2.items)='array' and a->>'fibres' is not null group by r2.id) t where rp.id = t.id and rp.fibres is null;

update public.client_recipes cr set items = coalesce((select jsonb_agg(case when a.value->>'fibres' is null and f.fibres is not null then a.value || jsonb_build_object('fibres', f.fibres) else a.value end order by a.ordinality) from jsonb_array_elements(cr.items) with ordinality a left join lateral (select x.fibres from public.aliments x where x.coach_id = cr.coach_id and x.fibres is not null and lower(btrim(x.nom)) = lower(btrim(case lower(btrim(a.value->>'aliment_nom')) when 'brocoli' then 'Brocolis' when 'carré frais 0%' then 'Carré frais 0% (1 carré = 25)' when 'pates complètes (100g)' then 'Pâtes complètes (100g)' else a.value->>'aliment_nom' end)) order by x.id limit 1) f on true), cr.items) where jsonb_typeof(cr.items)='array' and jsonb_array_length(cr.items) > 0;
