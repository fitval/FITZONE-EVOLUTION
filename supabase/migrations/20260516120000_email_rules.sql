-- ============================================================
-- FITZONE EVOLUTION — Règles d'emails automatiques aux clients
-- ============================================================
-- Chaque règle email_rules[] :
-- {
--   "id": "er_xxx",
--   "label": "Programme prêt",
--   "enabled": true,
--   "trigger": {
--     "type": "event" | "scheduled" | "random_weekly",
--     "event": "program_ready" | "nutrition_plan_ready",   -- si event
--     "weekday": 6, "hour": 11,                              -- si scheduled (0=dim, 6=sam)
--     "condition": "no_bilan_this_week"                      -- si scheduled (optionnel)
--   },
--   "subject": "Ton programme est prêt 💪",
--   "body": "Hello {first_name}, ton nouveau programme...",
--   "messages": [ {"subject":"...", "body":"..."}, ... ]    -- si random_weekly
-- }
-- ============================================================

ALTER TABLE public.settings
  ADD COLUMN IF NOT EXISTS email_rules JSONB DEFAULT '[]'::jsonb;

-- Log des envois (audit + dédup pour règles hebdo)
CREATE TABLE IF NOT EXISTS public.email_logs (
  id BIGSERIAL PRIMARY KEY,
  coach_id UUID NOT NULL,
  client_id UUID,
  rule_id TEXT NOT NULL,
  event TEXT NOT NULL,
  week_iso TEXT,
  email TEXT NOT NULL,
  subject TEXT,
  status TEXT DEFAULT 'sent',
  error TEXT,
  sent_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_email_logs_coach_date
  ON public.email_logs(coach_id, sent_at DESC);

-- Index unique partiel pour dédup hebdomadaire (par règle / client / semaine)
CREATE UNIQUE INDEX IF NOT EXISTS uniq_email_logs_weekly
  ON public.email_logs(coach_id, COALESCE(client_id, '00000000-0000-0000-0000-000000000000'::uuid), rule_id, week_iso)
  WHERE week_iso IS NOT NULL;

ALTER TABLE public.email_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "coach_read_own_email_logs" ON public.email_logs;
CREATE POLICY "coach_read_own_email_logs" ON public.email_logs
  FOR SELECT TO authenticated
  USING (coach_id IN (SELECT id FROM public.coaches WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "service_role_all_email_logs" ON public.email_logs;
CREATE POLICY "service_role_all_email_logs" ON public.email_logs
  FOR ALL TO service_role
  USING (true) WITH CHECK (true);

-- ============================================================
-- pg_cron : déclencheur horaire des emails programmés
-- ============================================================
-- À exécuter une seule fois après le déploiement de la fonction
-- process-scheduled-emails. Nécessite les extensions pg_cron et
-- pg_net activées dans Settings > Database > Extensions.
--
-- Remplacer YOUR_SERVICE_ROLE_KEY par la clé de service du projet
-- (Settings > API > service_role secret).
--
-- SELECT cron.schedule(
--   'fitzone-process-scheduled-emails',
--   '0 * * * *',
--   $$
--     SELECT net.http_post(
--       url := 'https://wsrykmutyhjxdnhnyexl.supabase.co/functions/v1/process-scheduled-emails',
--       headers := jsonb_build_object(
--         'Authorization', 'Bearer YOUR_SERVICE_ROLE_KEY',
--         'Content-Type', 'application/json'
--       ),
--       body := '{}'::jsonb
--     );
--   $$
-- );
