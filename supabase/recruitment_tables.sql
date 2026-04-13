-- ============================================================
-- FITZONE EVOLUTION — Recruitment Module Tables
-- ============================================================

-- ------------------------------------------------------------
-- 1. recruitment_forms
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS recruitment_forms (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    coach_id    UUID        NOT NULL REFERENCES coaches(id) ON DELETE CASCADE,
    title       TEXT        NOT NULL,
    description TEXT,
    questions   JSONB       NOT NULL DEFAULT '[]',
    -- question object shape: { id, type, label, required, options }
    status              TEXT        NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'archived')),
    success_button_text TEXT,
    success_button_url  TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_recruitment_forms_coach_id
    ON recruitment_forms (coach_id);

-- ------------------------------------------------------------
-- 2. recruitment_responses
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS recruitment_responses (
    id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    form_id    UUID        NOT NULL REFERENCES recruitment_forms(id) ON DELETE CASCADE,
    coach_id   UUID        NOT NULL REFERENCES coaches(id) ON DELETE CASCADE,
    first_name TEXT        NOT NULL,
    last_name  TEXT        NOT NULL,
    email      TEXT,
    phone      TEXT,
    answers    JSONB       NOT NULL DEFAULT '{}',
    status     TEXT        NOT NULL DEFAULT 'en_attente'
                           CHECK (status IN ('en_attente', 'contacte', 'reserve', 'accepte', 'refuse')),
    notes      TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_recruitment_responses_coach_id
    ON recruitment_responses (coach_id);

CREATE INDEX IF NOT EXISTS idx_recruitment_responses_form_id
    ON recruitment_responses (form_id);

-- ------------------------------------------------------------
-- 3. Auto-update updated_at via trigger
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_recruitment_forms_updated_at ON recruitment_forms;
CREATE TRIGGER trg_recruitment_forms_updated_at
    BEFORE UPDATE ON recruitment_forms
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_recruitment_responses_updated_at ON recruitment_responses;
CREATE TRIGGER trg_recruitment_responses_updated_at
    BEFORE UPDATE ON recruitment_responses
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ------------------------------------------------------------
-- 4. Row Level Security — recruitment_forms
-- ------------------------------------------------------------
ALTER TABLE recruitment_forms ENABLE ROW LEVEL SECURITY;

-- Coach: full CRUD on their own forms
CREATE POLICY "forms_coach_select"
    ON recruitment_forms FOR SELECT
    USING (coach_id = get_my_coach_id());

CREATE POLICY "forms_coach_insert"
    ON recruitment_forms FOR INSERT
    WITH CHECK (coach_id = get_my_coach_id());

CREATE POLICY "forms_coach_update"
    ON recruitment_forms FOR UPDATE
    USING (coach_id = get_my_coach_id())
    WITH CHECK (coach_id = get_my_coach_id());

CREATE POLICY "forms_coach_delete"
    ON recruitment_forms FOR DELETE
    USING (coach_id = get_my_coach_id());

-- Admin: read all forms
CREATE POLICY "forms_admin_select"
    ON recruitment_forms FOR SELECT
    USING (is_admin());

-- Anonymous: can read a single form by id (to render the public form page)
CREATE POLICY "forms_anon_select"
    ON recruitment_forms FOR SELECT
    USING (auth.role() = 'anon');

-- ------------------------------------------------------------
-- 5. Row Level Security — recruitment_responses
-- ------------------------------------------------------------
ALTER TABLE recruitment_responses ENABLE ROW LEVEL SECURITY;

-- Coach: full CRUD on responses that belong to them
CREATE POLICY "responses_coach_select"
    ON recruitment_responses FOR SELECT
    USING (coach_id = get_my_coach_id());

CREATE POLICY "responses_coach_insert"
    ON recruitment_responses FOR INSERT
    WITH CHECK (coach_id = get_my_coach_id());

CREATE POLICY "responses_coach_update"
    ON recruitment_responses FOR UPDATE
    USING (coach_id = get_my_coach_id())
    WITH CHECK (coach_id = get_my_coach_id());

CREATE POLICY "responses_coach_delete"
    ON recruitment_responses FOR DELETE
    USING (coach_id = get_my_coach_id());

-- Admin: read all responses
CREATE POLICY "responses_admin_select"
    ON recruitment_responses FOR SELECT
    USING (is_admin());

-- Anonymous: can submit a response (public form submission)
CREATE POLICY "responses_anon_insert"
    ON recruitment_responses FOR INSERT
    WITH CHECK (auth.role() = 'anon');
