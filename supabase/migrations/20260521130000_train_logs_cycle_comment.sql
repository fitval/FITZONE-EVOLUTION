-- La RPC client_insert_train_log et le code front (saveWorkout) écrivent
-- dans train_logs.cycle (RPE séance) et train_logs.comment (commentaire
-- séance). Ces colonnes n'existent pas en base — toute écriture en mode
-- anon plantait silencieusement avec 42703 "column does not exist",
-- expliquant pourquoi Anthony Laurent ne voyait jamais ses séances
-- enregistrées côté coach ni dans la mini-roadmap home.

ALTER TABLE public.train_logs
  ADD COLUMN IF NOT EXISTS cycle TEXT,
  ADD COLUMN IF NOT EXISTS comment TEXT;
