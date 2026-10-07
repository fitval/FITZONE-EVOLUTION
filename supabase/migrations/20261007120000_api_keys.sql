-- ============================================================
-- FITZONE EVOLUTION — Clés d'API en lecture seule, une par athlète
-- ============================================================
-- Servent à la fonction Edge `api` (routes /functions/v1/api/v1/…), appelée de serveur à serveur
-- par une application de l'athlète. Rien ne change pour les autres clientes : sans clé, l'API refuse tout.
--
-- Format d'une clé : fzk_<prefix>_<secret>
--   prefix = 12 caractères hexadécimaux, non secrets : servent à retrouver la ligne
--   secret = 32 octets aléatoires (base64url)
-- La clé entière n'est JAMAIS stockée : seule son empreinte SHA-256 (hex) l'est. Elle est générée dans le
-- navigateur du coach, affichée une seule fois, et seule l'empreinte part vers la base.
--
-- Une instruction par ligne. Rejouable : if not exists, drop policy if exists puis create.
-- ============================================================

-- 1. La table.
create table if not exists public.api_keys (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.clients(id) on delete cascade,
  coach_id uuid not null references public.coaches(id) on delete cascade,
  prefix text not null unique check (prefix ~ '^[0-9a-f]{12}$'),
  key_hash text not null check (key_hash ~ '^[0-9a-f]{64}$'),
  label text,
  created_at timestamptz not null default now(),
  last_used_at timestamptz,
  revoked_at timestamptz,
  rl_window timestamptz,
  rl_count integer not null default 0
);

create index if not exists idx_api_keys_client on public.api_keys(client_id, created_at desc);

-- 2. Sécurité par ligne.
alter table public.api_keys enable row level security;

-- 3. Droits par colonne. Les tables neuves de public sont ouvertes par défaut à anon et authenticated : on retire tout,
--    puis on rend juste ce qu'il faut. L'empreinte et le compteur de débit ne sont jamais lisibles depuis le navigateur ;
--    seule la date de révocation est modifiable ; aucune suppression (la révocation garde la trace).
revoke all on table public.api_keys from anon, authenticated;

grant select (id, client_id, coach_id, prefix, label, created_at, last_used_at, revoked_at) on public.api_keys to authenticated;

grant insert (client_id, coach_id, prefix, key_hash, label) on public.api_keys to authenticated;

grant update (revoked_at) on public.api_keys to authenticated;

-- 4a. Le coach voit les clés de ses clientes.
drop policy if exists "auth_coach_read_client_api_keys" on public.api_keys;

create policy "auth_coach_read_client_api_keys" on public.api_keys as permissive for select to authenticated using ((get_my_coach_id() is not null) and (coach_id = get_my_coach_id()) and (client_id in (select clients.id from clients where clients.coach_id = get_my_coach_id())));

-- 4b. Le coach crée une clé pour une de ses clientes, à son propre nom.
drop policy if exists "auth_coach_insert_client_api_keys" on public.api_keys;

create policy "auth_coach_insert_client_api_keys" on public.api_keys as permissive for insert to authenticated with check ((get_my_coach_id() is not null) and (coach_id = get_my_coach_id()) and (client_id in (select clients.id from clients where clients.coach_id = get_my_coach_id())));

-- 4c. Le coach révoque une clé de ses clientes. Une clé révoquée ne se réactive pas (revoked_at ne peut pas redevenir null).
drop policy if exists "auth_coach_revoke_client_api_keys" on public.api_keys;

create policy "auth_coach_revoke_client_api_keys" on public.api_keys as permissive for update to authenticated using ((get_my_coach_id() is not null) and (coach_id = get_my_coach_id()) and (revoked_at is null)) with check ((get_my_coach_id() is not null) and (coach_id = get_my_coach_id()) and (revoked_at is not null));

-- 5. Utilisation d'une clé par la fonction Edge : en une seule instruction atomique, note la dernière utilisation et compte
--    les appels de la minute en cours. Renvoie ce compte (null si la clé est inconnue ou révoquée).
--    Exécutable uniquement par la clé secrète des fonctions Edge.
create or replace function public.api_key_use(p_id uuid) returns integer language sql security definer set search_path = public as $$ update public.api_keys set rl_count = case when rl_window = date_trunc('minute', now()) then rl_count + 1 else 1 end, rl_window = date_trunc('minute', now()), last_used_at = now() where id = p_id and revoked_at is null returning rl_count $$;

revoke execute on function public.api_key_use(uuid) from public, anon, authenticated;

grant execute on function public.api_key_use(uuid) to service_role;
