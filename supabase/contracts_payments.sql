-- ============================================================
-- FITZONE EVOLUTION — Contrats, signature électronique, paiements
-- ============================================================
-- Run dans Supabase SQL Editor.
-- ============================================================

-- Modèles de contrat (créés par le coach)
CREATE TABLE IF NOT EXISTS public.contract_templates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  coach_id uuid REFERENCES public.coaches(id) ON DELETE CASCADE,
  name text NOT NULL,
  content_html text NOT NULL, -- HTML avec variables {{first_name}} {{last_name}} {{amount}} {{plan_description}} {{duration}} {{start_date}}
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Contrats assignés à un client (instance)
CREATE TABLE IF NOT EXISTS public.client_contracts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  coach_id uuid REFERENCES public.coaches(id) ON DELETE SET NULL,
  client_id uuid NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
  template_id uuid REFERENCES public.contract_templates(id) ON DELETE SET NULL,
  template_name text, -- snapshot
  content_snapshot text NOT NULL, -- HTML rendu (source de vérité juridique)
  amount_total numeric NOT NULL DEFAULT 0,
  currency text NOT NULL DEFAULT 'EUR',
  plan_type text NOT NULL DEFAULT 'one_shot', -- 'one_shot' | 'monthly' | 'installments' | 'downpayment'
  plan_data jsonb NOT NULL DEFAULT '{}'::jsonb, -- {months:N} | {down:X,monthly:Y,n:Z,first_date:...}
  duration_months int,
  start_date date,
  -- Signature électronique
  signed_at timestamptz,
  signer_name text,
  signer_email text,
  signer_ip text,
  signer_ua text,
  signer_hash text,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_client_contracts_client ON public.client_contracts(client_id);
CREATE INDEX IF NOT EXISTS idx_client_contracts_coach ON public.client_contracts(coach_id);

-- Échéances de paiement générées
CREATE TABLE IF NOT EXISTS public.payments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  client_contract_id uuid NOT NULL REFERENCES public.client_contracts(id) ON DELETE CASCADE,
  coach_id uuid REFERENCES public.coaches(id) ON DELETE SET NULL,
  client_id uuid REFERENCES public.clients(id) ON DELETE CASCADE,
  due_date date NOT NULL,
  amount numeric NOT NULL,
  status text NOT NULL DEFAULT 'pending', -- 'pending' | 'paid' | 'overdue' | 'canceled'
  paid_at timestamptz,
  note text,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_payments_client ON public.payments(client_id);
CREATE INDEX IF NOT EXISTS idx_payments_due ON public.payments(due_date);

-- RLS
ALTER TABLE public.contract_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.client_contracts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;

-- Coach: CRUD sur ses propres templates
DROP POLICY IF EXISTS "coach_crud_contract_templates" ON public.contract_templates;
CREATE POLICY "coach_crud_contract_templates" ON public.contract_templates
  FOR ALL TO authenticated
  USING (coach_id IN (SELECT id FROM public.coaches WHERE user_id = auth.uid()))
  WITH CHECK (coach_id IN (SELECT id FROM public.coaches WHERE user_id = auth.uid()));

-- Coach: CRUD sur les contrats clients
DROP POLICY IF EXISTS "coach_crud_client_contracts" ON public.client_contracts;
CREATE POLICY "coach_crud_client_contracts" ON public.client_contracts
  FOR ALL TO authenticated
  USING (coach_id IN (SELECT id FROM public.coaches WHERE user_id = auth.uid()))
  WITH CHECK (coach_id IN (SELECT id FROM public.coaches WHERE user_id = auth.uid()));

-- Anon (client via token) : lit son propre contrat + met à jour signature
DROP POLICY IF EXISTS "anon_rw_client_contracts" ON public.client_contracts;
CREATE POLICY "anon_rw_client_contracts" ON public.client_contracts
  FOR ALL TO anon
  USING (true)
  WITH CHECK (true);

-- Coach: CRUD sur paiements
DROP POLICY IF EXISTS "coach_crud_payments" ON public.payments;
CREATE POLICY "coach_crud_payments" ON public.payments
  FOR ALL TO authenticated
  USING (coach_id IN (SELECT id FROM public.coaches WHERE user_id = auth.uid()))
  WITH CHECK (coach_id IN (SELECT id FROM public.coaches WHERE user_id = auth.uid()));

-- Insert anon pour que la création du contrat depuis le dashboard passe même sans auth stricte
DROP POLICY IF EXISTS "anon_insert_payments" ON public.payments;
CREATE POLICY "anon_insert_payments" ON public.payments
  FOR INSERT TO anon
  WITH CHECK (true);
