-- ============================================================
-- FITZONE EVOLUTION — Security Fix: Remove dangerous anon policies
-- ============================================================
-- PROBLÈME : les policies anon USING(true) permettent à n'importe qui
-- de lire/modifier les données via l'API Supabase sans authentification.
--
-- SOLUTION :
-- 1. Supprimer toutes les policies anon d'écriture (INSERT/UPDATE)
-- 2. Créer des fonctions RPC SECURITY DEFINER qui valident le token
-- 3. Garder les policies anon SELECT (nécessaires pour le mode token legacy)
--    → À supprimer quand tous les clients seront migrés vers l'auth
-- ============================================================

-- ────────────────────────────────────────────────────────
-- ÉTAPE 1 : Supprimer les policies anon DANGEREUSES (écriture)
-- ────────────────────────────────────────────────────────

-- CRITIQUE : n'importe qui peut modifier n'importe quel client !
DROP POLICY IF EXISTS "anon_clients_update" ON public.clients;

-- N'importe qui peut insérer/modifier des daily logs
DROP POLICY IF EXISTS "anon_daily_logs_insert" ON public.daily_logs;
DROP POLICY IF EXISTS "anon_daily_logs_update" ON public.daily_logs;

-- N'importe qui peut insérer des bilans
DROP POLICY IF EXISTS "anon_bilans_insert" ON public.bilans;

-- N'importe qui peut insérer des train logs
DROP POLICY IF EXISTS "anon_train_logs_insert" ON public.train_logs;

-- N'importe qui peut insérer des questionnaires
DROP POLICY IF EXISTS "anon_questionnaires_insert" ON public.questionnaires;

-- ────────────────────────────────────────────────────────
-- ÉTAPE 2 : Fonctions RPC sécurisées (SECURITY DEFINER)
-- Ces fonctions valident le token avant toute opération
-- ────────────────────────────────────────────────────────

-- 2a. Mise à jour profil client (client.html → saveProfile)
CREATE OR REPLACE FUNCTION public.client_update_profile(
  p_token TEXT,
  p_first_name TEXT,
  p_last_name TEXT,
  p_email TEXT,
  p_photo TEXT DEFAULT NULL
)
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_client_id UUID;
BEGIN
  SELECT id INTO v_client_id FROM public.clients WHERE token = p_token;
  IF v_client_id IS NULL THEN
    RAISE EXCEPTION 'Token invalide';
  END IF;

  UPDATE public.clients
  SET first_name = p_first_name,
      last_name = p_last_name,
      email = p_email,
      photo = p_photo
  WHERE id = v_client_id;

  RETURN json_build_object('success', true);
END;
$$;

-- 2b. Mise à jour statut client (questionnaire.html → après soumission)
CREATE OR REPLACE FUNCTION public.client_update_status(
  p_token TEXT,
  p_status TEXT
)
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_client_id UUID;
BEGIN
  SELECT id INTO v_client_id FROM public.clients WHERE token = p_token;
  IF v_client_id IS NULL THEN
    RAISE EXCEPTION 'Token invalide';
  END IF;

  -- N'autoriser que certains statuts
  IF p_status NOT IN ('questionnaire_done', 'active') THEN
    RAISE EXCEPTION 'Statut non autorisé';
  END IF;

  UPDATE public.clients SET status = p_status WHERE id = v_client_id;
  RETURN json_build_object('success', true);
END;
$$;

-- 2c. Insert train log (client.html → saveWorkout)
CREATE OR REPLACE FUNCTION public.client_insert_train_log(
  p_token TEXT,
  p_session_name TEXT,
  p_date TEXT,
  p_exercises JSONB,
  p_cycle TEXT DEFAULT NULL,
  p_comment TEXT DEFAULT NULL
)
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_client RECORD;
BEGIN
  SELECT id, coach_id INTO v_client FROM public.clients WHERE token = p_token;
  IF v_client.id IS NULL THEN
    RAISE EXCEPTION 'Token invalide';
  END IF;

  INSERT INTO public.train_logs (coach_id, client_id, session_name, date, exercises, cycle, comment)
  VALUES (v_client.coach_id, v_client.id, p_session_name, p_date::date, p_exercises, p_cycle, p_comment);

  RETURN json_build_object('success', true);
END;
$$;

-- 2d. Upsert daily log (client.html → saveSuivi, saveWorkout)
CREATE OR REPLACE FUNCTION public.client_upsert_daily_log(
  p_token TEXT,
  p_date TEXT,
  p_data JSONB,
  p_existing_id UUID DEFAULT NULL
)
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_client RECORD;
  v_owner UUID;
BEGIN
  SELECT id, coach_id INTO v_client FROM public.clients WHERE token = p_token;
  IF v_client.id IS NULL THEN
    RAISE EXCEPTION 'Token invalide';
  END IF;

  IF p_existing_id IS NOT NULL THEN
    -- Vérifier que le daily_log appartient bien à ce client
    SELECT client_id INTO v_owner FROM public.daily_logs WHERE id = p_existing_id;
    IF v_owner != v_client.id THEN
      RAISE EXCEPTION 'Non autorisé';
    END IF;

    UPDATE public.daily_logs SET data = p_data WHERE id = p_existing_id;
  ELSE
    INSERT INTO public.daily_logs (coach_id, client_id, date, data)
    VALUES (v_client.coach_id, v_client.id, p_date::date, p_data);
  END IF;

  RETURN json_build_object('success', true);
END;
$$;

-- 2e. Insert bilan (client.html → submitBilan)
CREATE OR REPLACE FUNCTION public.client_insert_bilan(
  p_token TEXT,
  p_titre TEXT,
  p_date TEXT,
  p_photos JSONB,
  p_reponses JSONB
)
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_client RECORD;
BEGIN
  SELECT id, coach_id INTO v_client FROM public.clients WHERE token = p_token;
  IF v_client.id IS NULL THEN
    RAISE EXCEPTION 'Token invalide';
  END IF;

  INSERT INTO public.bilans (coach_id, client_id, titre, date, photos, reponses, read)
  VALUES (v_client.coach_id, v_client.id, p_titre, p_date::date, p_photos, p_reponses, false);

  RETURN json_build_object('success', true);
END;
$$;

-- 2f. Insert questionnaire (questionnaire.html → submit)
CREATE OR REPLACE FUNCTION public.client_insert_questionnaire(
  p_token TEXT,
  p_data JSONB
)
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_client RECORD;
  v_payload JSONB;
BEGIN
  SELECT id, coach_id INTO v_client FROM public.clients WHERE token = p_token;
  IF v_client.id IS NULL THEN
    RAISE EXCEPTION 'Token invalide';
  END IF;

  -- Injecter client_id dans le payload
  v_payload = p_data || jsonb_build_object('client_id', v_client.id);

  INSERT INTO public.questionnaires
  SELECT * FROM jsonb_populate_record(NULL::public.questionnaires, v_payload);

  RETURN json_build_object('success', true);
END;
$$;

-- ────────────────────────────────────────────────────────
-- ÉTAPE 3 : Autoriser les appels RPC pour anon
-- ────────────────────────────────────────────────────────
GRANT EXECUTE ON FUNCTION public.client_update_profile TO anon;
GRANT EXECUTE ON FUNCTION public.client_update_status TO anon;
GRANT EXECUTE ON FUNCTION public.client_insert_train_log TO anon;
GRANT EXECUTE ON FUNCTION public.client_upsert_daily_log TO anon;
GRANT EXECUTE ON FUNCTION public.client_insert_bilan TO anon;
GRANT EXECUTE ON FUNCTION public.client_insert_questionnaire TO anon;

-- ────────────────────────────────────────────────────────
-- NOTE : Policies anon SELECT restantes (à traiter plus tard)
-- ────────────────────────────────────────────────────────
-- Les policies suivantes restent en place car le mode token
-- legacy en a besoin pour les lectures. Elles exposent les
-- données en lecture seule à quiconque connaît l'API.
-- → À supprimer quand tous les clients utilisent l'auth :
--
-- anon_clients_select     (expose noms, emails, téléphones)
-- anon_daily_logs_select
-- anon_bilans_select
-- anon_train_logs_select
-- anon_programs_select
-- anon_exercises_select
-- anon_seances_select
-- anon_aliments_select
-- anon_modules_select
-- anon_plans_select
-- anon_plans_full_select
-- anon_questionnaires_select
-- anon_repas_select
