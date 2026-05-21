-- Phase 3.5 : suppression différée du mode anon
-- Programme un cron job qui s'exécute le 2026-05-28 à 09:00 UTC (dans ~7j)
-- pour DROP toutes les RPC client_* token-based et les policies anon_*
-- devenues inutiles après la migration phase 3.
-- Le job se désinscrit automatiquement à la fin.
--
-- Conservé volontairement :
--   - client_request_login_email (garde-fou pour anciens liens token)
--   - client_insert_questionnaire (peut être appelée par edge function submit-questionnaire)
--   - anon_clients_select        (questionnaire.html lit clients par token)
--   - anon_settings_select       (questionnaire.html lit q_integration)
--   - Policies client_contracts  (signature contrat pré-onboarding)
--
-- Pour annuler le job avant le 28/05 :
--   SELECT cron.unschedule('phase3-drop-anon-mode-2026-05-28');

SELECT cron.schedule(
  'phase3-drop-anon-mode-2026-05-28',
  '0 9 28 5 *',
  $sql$
    -- 1. DROP des RPC client_* token-based devenues inutiles
    DROP FUNCTION IF EXISTS public.client_get_train_logs(text);
    DROP FUNCTION IF EXISTS public.client_upsert_daily_log(text, text, jsonb, bigint);
    DROP FUNCTION IF EXISTS public.client_upsert_daily_log(text, text, jsonb, uuid);
    DROP FUNCTION IF EXISTS public.client_insert_train_log(text, text, text, jsonb, text, text);
    DROP FUNCTION IF EXISTS public.client_insert_bilan(text, text, text, jsonb, jsonb);
    DROP FUNCTION IF EXISTS public.client_update_profile(text, text, text, text, text);
    DROP FUNCTION IF EXISTS public.client_update_status(text, text);
    DROP FUNCTION IF EXISTS public.client_get_plan_swaps(text);
    DROP FUNCTION IF EXISTS public.client_upsert_plan_swap(text, bigint, int, int, int, text, jsonb);
    DROP FUNCTION IF EXISTS public.client_get_gamification(text);
    DROP FUNCTION IF EXISTS public.client_award_points(text, text, int, jsonb);
    DROP FUNCTION IF EXISTS public.client_unlock_badge(text, text);
    DROP FUNCTION IF EXISTS public.client_request_reward(text, bigint);
    DROP FUNCTION IF EXISTS public.client_mark_notifications_read(text);
    DROP FUNCTION IF EXISTS public.client_toggle_leaderboard(text, boolean);

    -- 2. DROP des policies anon SELECT sur les tables de données
    -- (data accessible auparavant en lecture publique via API anon — fuite sécurité)
    DROP POLICY IF EXISTS "anon_daily_logs_select"     ON public.daily_logs;
    DROP POLICY IF EXISTS "anon_bilans_select"         ON public.bilans;
    DROP POLICY IF EXISTS "anon_train_logs_select"     ON public.train_logs;
    DROP POLICY IF EXISTS "anon_programs_select"       ON public.programs;
    DROP POLICY IF EXISTS "anon_plans_full_select"     ON public.plans_full;
    DROP POLICY IF EXISTS "anon_plans_select"          ON public.plans;
    DROP POLICY IF EXISTS "anon_exercises_select"      ON public.exercises;
    DROP POLICY IF EXISTS "anon_aliments_select"       ON public.aliments;
    DROP POLICY IF EXISTS "anon_questionnaires_select" ON public.questionnaires;
    DROP POLICY IF EXISTS "anon_modules_select"        ON public.modules;
    DROP POLICY IF EXISTS "anon_repas_select"          ON public.repas;
    DROP POLICY IF EXISTS "anon_seances_select"        ON public.seances;

    -- 3. Self-unschedule (le job se supprime de cron.job après son exécution)
    SELECT cron.unschedule('phase3-drop-anon-mode-2026-05-28');
  $sql$
);
