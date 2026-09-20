-- ============================================================
-- FITZONE EVOLUTION — Suivis d'habitudes (journal quotidien de la cliente)
-- ============================================================
-- La cliente crée ses propres suivis (« salle & repos », « règles », « note du jour »…),
-- chacun avec ses libellés et ses couleurs, et colorie ses journées dans une grille annuelle.
-- Le coach peut lui aussi créer un suivi pour une cliente ; il ne remplit jamais les journées.
--
-- options = jsonb : [{key, label, color}]          → la légende du suivi (les couleurs cliquables)
-- goals   = jsonb : [{key, label, emoji, option, target, period}]  → objectifs (palier 3)
--
-- Un suivi marqué « privé » reste invisible du coach : les journées de règles ou d'humeur
-- appartiennent à la cliente. Par défaut un suivi n'est pas privé.
--
-- Une instruction par ligne. Rejouable : if not exists, drop policy if exists puis create.
-- ============================================================

-- 1. Drapeau d'activation par cliente. Désactivé par défaut : rien ne change pour les clientes
--    existantes tant que le coach ne l'active pas dans la fiche client.
alter table public.clients add column if not exists show_tracker boolean not null default false;

-- 2. Les suivis.
create table if not exists public.habit_trackers (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.clients(id) on delete cascade,
  coach_id uuid references public.coaches(id) on delete set null,
  nom text not null,
  emoji text,
  options jsonb not null default '[]'::jsonb,
  goals jsonb not null default '[]'::jsonb,
  position int not null default 0,
  private boolean not null default false,
  archived boolean not null default false,
  created_by text not null default 'client',
  created_at timestamptz default now()
);

create index if not exists idx_habit_trackers_client on public.habit_trackers(client_id, position);

-- 3. Les journées coloriées. Une ligne = un jour + une couleur.
--    Plusieurs couleurs le même jour sont autorisées (salle ET running le mardi).
create table if not exists public.habit_entries (
  id uuid primary key default gen_random_uuid(),
  tracker_id uuid not null references public.habit_trackers(id) on delete cascade,
  client_id uuid not null references public.clients(id) on delete cascade,
  date date not null,
  option_key text not null,
  created_at timestamptz default now()
);

create unique index if not exists idx_habit_entries_unique on public.habit_entries(tracker_id, date, option_key);

create index if not exists idx_habit_entries_tracker_date on public.habit_entries(tracker_id, date);

-- 4. Sécurité par ligne.
alter table public.habit_trackers enable row level security;

alter table public.habit_entries enable row level security;

-- 4a. La cliente gère ses propres suivis.
drop policy if exists "auth_client_rw_own_habit_trackers" on public.habit_trackers;

create policy "auth_client_rw_own_habit_trackers" on public.habit_trackers as permissive for all to authenticated using ((get_my_client_id() is not null) and (client_id = get_my_client_id())) with check ((get_my_client_id() is not null) and (client_id = get_my_client_id()));

-- 4b. Le coach gère les suivis de ses clientes (il en crée, il n'en remplit pas).
drop policy if exists "auth_coach_rw_client_habit_trackers" on public.habit_trackers;

create policy "auth_coach_rw_client_habit_trackers" on public.habit_trackers as permissive for all to authenticated using ((get_my_coach_id() is not null) and (client_id in (select clients.id from clients where clients.coach_id = get_my_coach_id()))) with check ((get_my_coach_id() is not null) and (client_id in (select clients.id from clients where clients.coach_id = get_my_coach_id())));

-- 4c. La cliente gère ses propres journées.
drop policy if exists "auth_client_rw_own_habit_entries" on public.habit_entries;

create policy "auth_client_rw_own_habit_entries" on public.habit_entries as permissive for all to authenticated using ((get_my_client_id() is not null) and (client_id = get_my_client_id())) with check ((get_my_client_id() is not null) and (client_id = get_my_client_id()));

-- 4d. Le coach lit les journées de ses clientes, sauf celles d'un suivi privé. Lecture seule.
drop policy if exists "auth_coach_read_client_habit_entries" on public.habit_entries;

create policy "auth_coach_read_client_habit_entries" on public.habit_entries as permissive for select to authenticated using ((get_my_coach_id() is not null) and (client_id in (select clients.id from clients where clients.coach_id = get_my_coach_id())) and (tracker_id in (select habit_trackers.id from habit_trackers where habit_trackers.private = false)));
