-- ============================================================
-- GAMIFICATION TABLES + RPC — Fitzone Evolution
-- Execute in Supabase SQL Editor
-- ============================================================

-- 1. client_points : 1 row per client — totals, level, monthly
CREATE TABLE IF NOT EXISTS public.client_points (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id UUID NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
  coach_id UUID NOT NULL REFERENCES public.coaches(id) ON DELETE CASCADE,
  total_points INTEGER NOT NULL DEFAULT 0,
  monthly_points INTEGER NOT NULL DEFAULT 0,
  usable_balance INTEGER NOT NULL DEFAULT 0,
  level TEXT NOT NULL DEFAULT 'bronze',
  leaderboard_opt_in BOOLEAN NOT NULL DEFAULT true,
  current_month TEXT NOT NULL DEFAULT to_char(now(), 'YYYY-MM'),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(client_id)
);

-- 2. point_transactions : immutable log
CREATE TABLE IF NOT EXISTS public.point_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id UUID NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
  coach_id UUID NOT NULL REFERENCES public.coaches(id) ON DELETE CASCADE,
  action TEXT NOT NULL,
  points INTEGER NOT NULL,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3. client_badges : unlocked badges
CREATE TABLE IF NOT EXISTS public.client_badges (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id UUID NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
  badge_key TEXT NOT NULL,
  unlocked_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(client_id, badge_key)
);

-- 4. coach_rewards : reward catalog per coach
CREATE TABLE IF NOT EXISTS public.coach_rewards (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  coach_id UUID NOT NULL REFERENCES public.coaches(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  cost INTEGER NOT NULL DEFAULT 500,
  min_level TEXT NOT NULL DEFAULT 'silver',
  active BOOLEAN NOT NULL DEFAULT true,
  stock INTEGER DEFAULT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 5. reward_requests : client reward exchange requests
CREATE TABLE IF NOT EXISTS public.reward_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id UUID NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
  coach_id UUID NOT NULL REFERENCES public.coaches(id) ON DELETE CASCADE,
  reward_id UUID NOT NULL REFERENCES public.coach_rewards(id) ON DELETE CASCADE,
  reward_name TEXT NOT NULL,
  cost INTEGER NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','denied')),
  coach_note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  resolved_at TIMESTAMPTZ
);

-- 6. notifications : in-app notifications
CREATE TABLE IF NOT EXISTS public.notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id UUID NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
  type TEXT NOT NULL DEFAULT 'info',
  title TEXT NOT NULL,
  body TEXT,
  read BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- INDEXES
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_point_transactions_client_action ON public.point_transactions(client_id, action, created_at);
CREATE INDEX IF NOT EXISTS idx_notifications_client_read ON public.notifications(client_id, read);
CREATE INDEX IF NOT EXISTS idx_client_points_coach ON public.client_points(coach_id);
CREATE INDEX IF NOT EXISTS idx_reward_requests_coach_status ON public.reward_requests(coach_id, status);

-- ============================================================
-- RLS POLICIES
-- ============================================================
ALTER TABLE public.client_points ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.point_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.client_badges ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.coach_rewards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reward_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Coach sees their clients' data
CREATE POLICY "coach_read_client_points" ON public.client_points FOR SELECT TO authenticated
  USING (coach_id IN (SELECT id FROM public.coaches WHERE user_id = auth.uid()));
CREATE POLICY "coach_update_client_points" ON public.client_points FOR UPDATE TO authenticated
  USING (coach_id IN (SELECT id FROM public.coaches WHERE user_id = auth.uid()));
CREATE POLICY "coach_insert_client_points" ON public.client_points FOR INSERT TO authenticated
  WITH CHECK (coach_id IN (SELECT id FROM public.coaches WHERE user_id = auth.uid()));

CREATE POLICY "coach_read_point_transactions" ON public.point_transactions FOR SELECT TO authenticated
  USING (coach_id IN (SELECT id FROM public.coaches WHERE user_id = auth.uid()));
CREATE POLICY "coach_insert_point_transactions" ON public.point_transactions FOR INSERT TO authenticated
  WITH CHECK (coach_id IN (SELECT id FROM public.coaches WHERE user_id = auth.uid()));

CREATE POLICY "coach_read_client_badges" ON public.client_badges FOR SELECT TO authenticated
  USING (client_id IN (SELECT id FROM public.clients WHERE coach_id IN (SELECT id FROM public.coaches WHERE user_id = auth.uid())));

CREATE POLICY "coach_read_rewards" ON public.coach_rewards FOR ALL TO authenticated
  USING (coach_id IN (SELECT id FROM public.coaches WHERE user_id = auth.uid()));

CREATE POLICY "coach_read_reward_requests" ON public.reward_requests FOR ALL TO authenticated
  USING (coach_id IN (SELECT id FROM public.coaches WHERE user_id = auth.uid()));

CREATE POLICY "coach_read_notifications" ON public.notifications FOR ALL TO authenticated
  USING (client_id IN (SELECT id FROM public.clients WHERE coach_id IN (SELECT id FROM public.coaches WHERE user_id = auth.uid())));

-- Client auth reads own data
CREATE POLICY "client_read_own_points" ON public.client_points FOR SELECT TO authenticated
  USING (client_id IN (SELECT id FROM public.clients WHERE user_id = auth.uid()));
CREATE POLICY "client_update_own_points" ON public.client_points FOR UPDATE TO authenticated
  USING (client_id IN (SELECT id FROM public.clients WHERE user_id = auth.uid()));
CREATE POLICY "client_insert_own_points" ON public.client_points FOR INSERT TO authenticated
  WITH CHECK (client_id IN (SELECT id FROM public.clients WHERE user_id = auth.uid()));

CREATE POLICY "client_read_own_transactions" ON public.point_transactions FOR SELECT TO authenticated
  USING (client_id IN (SELECT id FROM public.clients WHERE user_id = auth.uid()));
CREATE POLICY "client_insert_own_transactions" ON public.point_transactions FOR INSERT TO authenticated
  WITH CHECK (client_id IN (SELECT id FROM public.clients WHERE user_id = auth.uid()));

CREATE POLICY "client_read_own_badges" ON public.client_badges FOR SELECT TO authenticated
  USING (client_id IN (SELECT id FROM public.clients WHERE user_id = auth.uid()));
CREATE POLICY "client_insert_own_badges" ON public.client_badges FOR INSERT TO authenticated
  WITH CHECK (client_id IN (SELECT id FROM public.clients WHERE user_id = auth.uid()));

CREATE POLICY "client_read_own_notifications" ON public.notifications FOR SELECT TO authenticated
  USING (client_id IN (SELECT id FROM public.clients WHERE user_id = auth.uid()));
CREATE POLICY "client_update_own_notifications" ON public.notifications FOR UPDATE TO authenticated
  USING (client_id IN (SELECT id FROM public.clients WHERE user_id = auth.uid()));

CREATE POLICY "client_read_own_reward_requests" ON public.reward_requests FOR SELECT TO authenticated
  USING (client_id IN (SELECT id FROM public.clients WHERE user_id = auth.uid()));
CREATE POLICY "client_insert_own_reward_requests" ON public.reward_requests FOR INSERT TO authenticated
  WITH CHECK (client_id IN (SELECT id FROM public.clients WHERE user_id = auth.uid()));

-- Client reads coach rewards (public catalog)
CREATE POLICY "client_read_coach_rewards" ON public.coach_rewards FOR SELECT TO authenticated
  USING (coach_id IN (SELECT coach_id FROM public.clients WHERE user_id = auth.uid()));

-- Anon leaderboard access via RPC only (no direct SELECT for anon)

-- ============================================================
-- RPC: client_award_points (SECURITY DEFINER — anon safe)
-- ============================================================
CREATE OR REPLACE FUNCTION public.client_award_points(
  p_token TEXT,
  p_action TEXT,
  p_points INTEGER,
  p_metadata JSONB DEFAULT '{}'
)
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_client RECORD;
  v_cp RECORD;
  v_current_month TEXT;
  v_new_total INTEGER;
  v_new_level TEXT;
  v_old_level TEXT;
  v_day_count INTEGER;
BEGIN
  -- Validate token
  SELECT id, coach_id INTO v_client FROM public.clients WHERE token = p_token::uuid;
  IF v_client.id IS NULL THEN
    RAISE EXCEPTION 'Token invalide';
  END IF;

  -- Validate metadata size (max 1KB)
  IF length(p_metadata::text) > 1024 THEN
    RETURN json_build_object('success', false, 'reason', 'metadata_too_large');
  END IF;

  -- Daily cap check per action
  SELECT COUNT(*) INTO v_day_count
  FROM public.point_transactions
  WHERE client_id = v_client.id
    AND action = p_action
    AND created_at::date = CURRENT_DATE;

  -- Per-action daily limits
  IF p_action IN ('daily_report','weight_logged','steps_goal','hydration_goal','nutrition_validation') AND v_day_count >= 1 THEN
    RETURN json_build_object('success', false, 'reason', 'daily_cap');
  END IF;
  IF p_action = 'exercise_progression' AND v_day_count >= 10 THEN
    RETURN json_build_object('success', false, 'reason', 'daily_cap');
  END IF;
  IF p_action = 'complementary_activity' AND v_day_count >= 2 THEN
    RETURN json_build_object('success', false, 'reason', 'daily_cap');
  END IF;
  -- Weekly caps
  IF p_action IN ('bilan_submit','bilan_photo','weekly_sessions_bonus') THEN
    DECLARE v_week_count INTEGER;
    BEGIN
      SELECT COUNT(*) INTO v_week_count
      FROM public.point_transactions
      WHERE client_id = v_client.id
        AND action = p_action
        AND created_at >= date_trunc('week', CURRENT_DATE);
      IF v_week_count >= 1 THEN
        RETURN json_build_object('success', false, 'reason', 'weekly_cap');
      END IF;
    END;
  END IF;

  -- Get or create client_points (FOR UPDATE to prevent race conditions)
  v_current_month := to_char(now(), 'YYYY-MM');
  SELECT * INTO v_cp FROM public.client_points WHERE client_id = v_client.id FOR UPDATE;
  IF v_cp.id IS NULL THEN
    INSERT INTO public.client_points (client_id, coach_id, total_points, monthly_points, usable_balance, level, current_month)
    VALUES (v_client.id, v_client.coach_id, 0, 0, 0, 'bronze', v_current_month)
    RETURNING * INTO v_cp;
  END IF;

  -- Monthly reset if needed
  IF v_cp.current_month != v_current_month THEN
    UPDATE public.client_points
    SET monthly_points = 0, current_month = v_current_month, updated_at = now()
    WHERE id = v_cp.id;
    v_cp.monthly_points := 0;
  END IF;

  -- Insert transaction
  INSERT INTO public.point_transactions (client_id, coach_id, action, points, metadata)
  VALUES (v_client.id, v_client.coach_id, p_action, p_points, p_metadata);

  -- Update counters
  v_new_total := v_cp.total_points + p_points;
  v_old_level := v_cp.level;

  -- Calculate level
  IF v_new_total >= 30000 THEN v_new_level := 'elite';
  ELSIF v_new_total >= 15000 THEN v_new_level := 'platinum';
  ELSIF v_new_total >= 5000 THEN v_new_level := 'gold';
  ELSIF v_new_total >= 1000 THEN v_new_level := 'silver';
  ELSE v_new_level := 'bronze';
  END IF;

  UPDATE public.client_points
  SET total_points = v_new_total,
      monthly_points = monthly_points + p_points,
      usable_balance = usable_balance + p_points,
      level = v_new_level,
      updated_at = now()
  WHERE id = v_cp.id;

  RETURN json_build_object(
    'success', true,
    'total_points', v_new_total,
    'monthly_points', v_cp.monthly_points + p_points,
    'usable_balance', v_cp.usable_balance + p_points,
    'level', v_new_level,
    'level_changed', v_old_level != v_new_level,
    'old_level', v_old_level
  );
END;
$$;

-- ============================================================
-- RPC: client_unlock_badge (SECURITY DEFINER — anon safe)
-- ============================================================
CREATE OR REPLACE FUNCTION public.client_unlock_badge(
  p_token TEXT,
  p_badge_key TEXT
)
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_client RECORD;
  v_inserted BOOLEAN := false;
BEGIN
  SELECT id, coach_id INTO v_client FROM public.clients WHERE token = p_token::uuid;
  IF v_client.id IS NULL THEN
    RAISE EXCEPTION 'Token invalide';
  END IF;

  -- Validate badge key against whitelist
  IF p_badge_key NOT IN ('first_workout','finisher','centurion','workout_10','workout_50','first_nutrition','week_perfect_nutrition','month_perfect_nutrition','first_report','streak_8','streak_30','photos_10','level_silver','level_gold','level_platinum','level_elite','rocket_start','bilan_5','steps_champion','champion') THEN
    RETURN json_build_object('success', false, 'reason', 'invalid_badge');
  END IF;

  INSERT INTO public.client_badges (client_id, badge_key)
  VALUES (v_client.id, p_badge_key)
  ON CONFLICT (client_id, badge_key) DO NOTHING;

  IF FOUND THEN v_inserted := true; END IF;

  RETURN json_build_object('success', true, 'inserted', v_inserted);
END;
$$;

-- ============================================================
-- RPC: client_request_reward (SECURITY DEFINER — anon safe)
-- ============================================================
CREATE OR REPLACE FUNCTION public.client_request_reward(
  p_token TEXT,
  p_reward_id UUID
)
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_client RECORD;
  v_cp RECORD;
  v_reward RECORD;
BEGIN
  SELECT id, coach_id INTO v_client FROM public.clients WHERE token = p_token::uuid;
  IF v_client.id IS NULL THEN
    RAISE EXCEPTION 'Token invalide';
  END IF;

  SELECT * INTO v_reward FROM public.coach_rewards WHERE id = p_reward_id AND active = true;
  IF v_reward.id IS NULL THEN
    RAISE EXCEPTION 'Récompense introuvable';
  END IF;

  SELECT * INTO v_cp FROM public.client_points WHERE client_id = v_client.id FOR UPDATE;
  IF v_cp.id IS NULL OR v_cp.usable_balance < v_reward.cost THEN
    RETURN json_build_object('success', false, 'reason', 'insufficient_balance');
  END IF;
  IF v_cp.level = 'bronze' THEN
    RETURN json_build_object('success', false, 'reason', 'level_too_low');
  END IF;

  INSERT INTO public.reward_requests (client_id, coach_id, reward_id, reward_name, cost, status)
  VALUES (v_client.id, v_client.coach_id, p_reward_id, v_reward.name, v_reward.cost, 'pending');

  RETURN json_build_object('success', true);
END;
$$;

-- ============================================================
-- RPC: client_get_gamification (SECURITY DEFINER — loads all gamification data)
-- ============================================================
CREATE OR REPLACE FUNCTION public.client_get_gamification(
  p_token TEXT
)
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_client RECORD;
  v_cp RECORD;
  v_current_month TEXT;
  v_badges JSON;
  v_transactions JSON;
  v_notifications JSON;
  v_leaderboard JSON;
  v_rewards JSON;
  v_requests JSON;
  v_unread_notifs INTEGER;
BEGIN
  SELECT id, coach_id INTO v_client FROM public.clients WHERE token = p_token::uuid;
  IF v_client.id IS NULL THEN
    RAISE EXCEPTION 'Token invalide';
  END IF;

  v_current_month := to_char(now(), 'YYYY-MM');

  -- Get or create client_points + monthly reset
  SELECT * INTO v_cp FROM public.client_points WHERE client_id = v_client.id;
  IF v_cp.id IS NULL THEN
    INSERT INTO public.client_points (client_id, coach_id, total_points, monthly_points, usable_balance, level, current_month)
    VALUES (v_client.id, v_client.coach_id, 0, 0, 0, 'bronze', v_current_month)
    RETURNING * INTO v_cp;
  ELSIF v_cp.current_month != v_current_month THEN
    UPDATE public.client_points SET monthly_points = 0, current_month = v_current_month, updated_at = now() WHERE id = v_cp.id;
    v_cp.monthly_points := 0;
  END IF;

  -- Badges
  SELECT json_agg(row_to_json(b)) INTO v_badges
  FROM (SELECT badge_key, unlocked_at FROM public.client_badges WHERE client_id = v_client.id ORDER BY unlocked_at) b;

  -- Last 50 transactions
  SELECT json_agg(row_to_json(t)) INTO v_transactions
  FROM (SELECT action, points, metadata, created_at FROM public.point_transactions WHERE client_id = v_client.id ORDER BY created_at DESC LIMIT 50) t;

  -- Notifications (last 30)
  SELECT json_agg(row_to_json(n)) INTO v_notifications
  FROM (SELECT id, type, title, body, read, created_at FROM public.notifications WHERE client_id = v_client.id ORDER BY created_at DESC LIMIT 30) n;

  -- Unread count
  SELECT COUNT(*) INTO v_unread_notifs FROM public.notifications WHERE client_id = v_client.id AND read = false;

  -- Leaderboard (same coach, opt-in, this month)
  SELECT json_agg(row_to_json(l)) INTO v_leaderboard
  FROM (
    SELECT cp.client_id, c.first_name, cp.monthly_points, cp.level
    FROM public.client_points cp
    JOIN public.clients c ON c.id = cp.client_id
    WHERE cp.coach_id = v_client.coach_id AND cp.leaderboard_opt_in = true
    ORDER BY cp.monthly_points DESC LIMIT 10
  ) l;

  -- Coach rewards
  SELECT json_agg(row_to_json(r)) INTO v_rewards
  FROM (SELECT id, name, description, cost FROM public.coach_rewards WHERE coach_id = v_client.coach_id AND active = true ORDER BY cost) r;

  -- My reward requests
  SELECT json_agg(row_to_json(rr)) INTO v_requests
  FROM (SELECT id, reward_name, cost, status, coach_note, created_at, resolved_at FROM public.reward_requests WHERE client_id = v_client.id ORDER BY created_at DESC LIMIT 20) rr;

  RETURN json_build_object(
    'points', json_build_object(
      'total_points', v_cp.total_points,
      'monthly_points', v_cp.monthly_points,
      'usable_balance', v_cp.usable_balance,
      'level', v_cp.level,
      'leaderboard_opt_in', v_cp.leaderboard_opt_in
    ),
    'badges', COALESCE(v_badges, '[]'::json),
    'transactions', COALESCE(v_transactions, '[]'::json),
    'notifications', COALESCE(v_notifications, '[]'::json),
    'unread_notifs', v_unread_notifs,
    'leaderboard', COALESCE(v_leaderboard, '[]'::json),
    'rewards', COALESCE(v_rewards, '[]'::json),
    'requests', COALESCE(v_requests, '[]'::json)
  );
END;
$$;

-- ============================================================
-- RPC: client_mark_notifications_read
-- ============================================================
CREATE OR REPLACE FUNCTION public.client_mark_notifications_read(
  p_token TEXT
)
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_client RECORD;
BEGIN
  SELECT id INTO v_client FROM public.clients WHERE token = p_token::uuid;
  IF v_client.id IS NULL THEN
    RAISE EXCEPTION 'Token invalide';
  END IF;

  UPDATE public.notifications SET read = true WHERE client_id = v_client.id AND read = false;
  RETURN json_build_object('success', true);
END;
$$;

-- ============================================================
-- RPC: client_toggle_leaderboard
-- ============================================================
CREATE OR REPLACE FUNCTION public.client_toggle_leaderboard(
  p_token TEXT,
  p_opt_in BOOLEAN
)
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_client RECORD;
BEGIN
  SELECT id INTO v_client FROM public.clients WHERE token = p_token::uuid;
  IF v_client.id IS NULL THEN
    RAISE EXCEPTION 'Token invalide';
  END IF;

  UPDATE public.client_points SET leaderboard_opt_in = p_opt_in WHERE client_id = v_client.id;
  RETURN json_build_object('success', true);
END;
$$;

-- ============================================================
-- GRANTS for anon + authenticated
-- ============================================================
GRANT EXECUTE ON FUNCTION public.client_award_points TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.client_unlock_badge TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.client_request_reward TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.client_get_gamification TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.client_mark_notifications_read TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.client_toggle_leaderboard TO anon, authenticated;
