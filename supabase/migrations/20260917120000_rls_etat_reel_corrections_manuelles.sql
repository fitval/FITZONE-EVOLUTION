-- Traçage des corrections RLS faites à la main dans le SQL Editor, absentes du dépôt.
-- État de référence relevé en base le 17/09/2026 (pg_policies). Enregistrée comme déjà appliquée
-- (npx supabase migration repair) : elle ne change rien en production, elle empêche un rejeu
-- de réinstaller en silence des règles fermées, et reproduit les règles créées à la main.
-- Une instruction par ligne. Rejouable : drop policy if exists, puis create.

-- 1. Fermetures du 17/09/2026 : accès anonymes aux contrats, fiches et réglages.
--    Créées à la main (jamais dans le dépôt) sauf anon_read_settings (settings_anon_read.sql,
--    settings_client_read.sql). anon_sign_unsigned_contracts permettait de modifier un contrat.
drop policy if exists "anon_sign_unsigned_contracts" on public.client_contracts;
drop policy if exists "anon_read_unsigned_contracts" on public.client_contracts;
drop policy if exists "anon_clients_onboarding" on public.clients;
drop policy if exists "anon_read_settings" on public.settings;

-- 2. Règles anonymes réinstallées par la chaîne de migrations (20260706120000_water_logs,
--    20260714120000_salt_logs : FOR ALL TO anon USING (true)) : lecture ET écriture anonymes sur les
--    journaux de santé. Supprimées à la main les 11 et 12/09/2026, sans trace dans le dépôt jusqu'ici.
drop policy if exists "anon_all_water_logs" on public.water_logs;
drop policy if exists "anon_all_salt_logs" on public.salt_logs;

-- 3. Règles créées par les anciens scripts manuels de supabase/ (migration.sql, rls_policies.sql,
--    rls_v2_policies.sql, contracts_payments.sql, food_tracking.sql…), absentes de la base au 17/09.
--    Dont « Allow all for authenticated » (USING true) et d'anciennes règles anonymes.
drop policy if exists "anon_rw_client_contracts" on public.client_contracts;
drop policy if exists "anon_insert_payments" on public.payments;
drop policy if exists "anon_all_food_logs" on public.food_logs;
drop policy if exists "Allow all for authenticated" on public.exercises;
drop policy if exists "Allow all for authenticated" on public.programs;
drop policy if exists "Allow all for authenticated" on public.seances;
drop policy if exists "Allow all for authenticated" on public.aliments;
drop policy if exists "Allow all for authenticated" on public.repas;
drop policy if exists "Allow all for authenticated" on public.plans_full;
drop policy if exists "Allow all for authenticated" on public.modules;
drop policy if exists "Allow all for authenticated" on public.team;
drop policy if exists "Allow all for authenticated" on public.settings;
drop policy if exists "Allow all for authenticated" on public.roadmaps;
drop policy if exists "Allow all for authenticated" on public.daily_logs;
drop policy if exists "Allow all for authenticated" on public.train_logs;
drop policy if exists "Allow all for authenticated" on public.bilans;
drop policy if exists "coach_select_own" on public.coaches;
drop policy if exists "coach_insert_own" on public.coaches;
drop policy if exists "coach_update_own" on public.coaches;
drop policy if exists "coach_clients_all" on public.clients;
drop policy if exists "anon_clients_select_by_token" on public.clients;
drop policy if exists "anon_clients_update" on public.clients;
drop policy if exists "coach_questionnaires_all" on public.questionnaires;
drop policy if exists "anon_questionnaires_select" on public.questionnaires;
drop policy if exists "anon_questionnaires_insert" on public.questionnaires;
drop policy if exists "coach_plans_all" on public.plans;
drop policy if exists "anon_plans_select" on public.plans;
drop policy if exists "coach_plans_full_all" on public.plans_full;
drop policy if exists "anon_plans_full_select" on public.plans_full;
drop policy if exists "coach_daily_logs_all" on public.daily_logs;
drop policy if exists "anon_daily_logs_select" on public.daily_logs;
drop policy if exists "anon_daily_logs_insert" on public.daily_logs;
drop policy if exists "anon_daily_logs_update" on public.daily_logs;
drop policy if exists "coach_bilans_all" on public.bilans;
drop policy if exists "anon_bilans_select" on public.bilans;
drop policy if exists "anon_bilans_insert" on public.bilans;
drop policy if exists "coach_train_logs_all" on public.train_logs;
drop policy if exists "anon_train_logs_select" on public.train_logs;
drop policy if exists "anon_train_logs_insert" on public.train_logs;
drop policy if exists "coach_programs_all" on public.programs;
drop policy if exists "anon_programs_select" on public.programs;
drop policy if exists "coach_exercises_all" on public.exercises;
drop policy if exists "anon_exercises_select" on public.exercises;
drop policy if exists "coach_seances_all" on public.seances;
drop policy if exists "anon_seances_select" on public.seances;
drop policy if exists "coach_aliments_all" on public.aliments;
drop policy if exists "anon_aliments_select" on public.aliments;
drop policy if exists "coach_repas_all" on public.repas;
drop policy if exists "anon_repas_select" on public.repas;
drop policy if exists "coach_modules_all" on public.modules;
drop policy if exists "anon_modules_select" on public.modules;
drop policy if exists "coach_roadmaps_all" on public.roadmaps;
drop policy if exists "coach_settings_all" on public.settings;
drop policy if exists "coach_team_all" on public.team;
drop policy if exists "anon_clients_select" on public.clients;

-- 4. Règles en service créées à la main, jamais présentes dans le dépôt : reproduites à l'identique.
--    Tracées telles quelles : des ajustements sont prévus (séance « verrouillage »).
drop policy if exists "auth_client_rw_own_contracts" on public.client_contracts;
create policy "auth_client_rw_own_contracts" on public.client_contracts as permissive for all to authenticated using ((client_id IN ( SELECT clients.id FROM clients WHERE (clients.user_id = auth.uid())))) with check ((client_id IN ( SELECT clients.id FROM clients WHERE (clients.user_id = auth.uid()))));
drop policy if exists "auth_client_update_own_status" on public.clients;
create policy "auth_client_update_own_status" on public.clients as permissive for update to authenticated using ((user_id = auth.uid())) with check ((user_id = auth.uid()));
drop policy if exists "authenticated_delete_clients" on public.clients;
create policy "authenticated_delete_clients" on public.clients as permissive for delete to authenticated using ((coach_id IN ( SELECT coaches.id FROM coaches WHERE (coaches.user_id = auth.uid()))));
drop policy if exists "auth_client_read_own_payments" on public.payments;
create policy "auth_client_read_own_payments" on public.payments as permissive for select to authenticated using ((client_id IN ( SELECT clients.id FROM clients WHERE (clients.user_id = auth.uid()))));
drop policy if exists "auth_repas_client" on public.repas;
create policy "auth_repas_client" on public.repas as permissive for select to authenticated using (((coach_id = ( SELECT clients.coach_id FROM clients WHERE (clients.id = get_my_client_id()))) AND (get_my_client_id() IS NOT NULL)));
drop policy if exists "auth_seances_client" on public.seances;
create policy "auth_seances_client" on public.seances as permissive for select to authenticated using (((get_my_client_id() IS NOT NULL) AND ((client_id = get_my_client_id()) OR (COALESCE(client_ids, '[]'::jsonb) @> to_jsonb((get_my_client_id())::text)))));

-- 5. Sécurité par ligne de coaches : active en base, jamais activée par un fichier du dépôt.
alter table public.coaches enable row level security;
