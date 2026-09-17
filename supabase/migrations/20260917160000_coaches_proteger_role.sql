-- Protège la colonne coaches.role : un rôle ne s'attribue qu'à la création (toujours « coach ») et ne se
-- modifie que par un super_admin. Les écritures serveur (rôles qui contournent la RLS : clé secrète des
-- fonctions Edge, SQL Editor) ne sont pas concernées.
-- Appliquée dans le SQL Editor le 17/09/2026, enregistrée comme déjà appliquée. Une instruction par ligne.
-- Retour arrière : drop trigger if exists coaches_proteger_role on public.coaches;
create or replace function public.coaches_proteger_role() returns trigger language plpgsql set search_path = public as $$ begin if exists (select 1 from pg_catalog.pg_roles r where r.rolname = current_user and r.rolbypassrls) then return new; end if; if tg_op = 'INSERT' then new.role := 'coach'; return new; end if; if new.role is distinct from old.role and not exists (select 1 from public.coaches c where c.user_id = auth.uid() and c.role = 'super_admin') then raise exception 'Seul un super_admin peut modifier un rôle' using errcode = '42501'; end if; return new; end; $$;
drop trigger if exists coaches_proteger_role on public.coaches;
create trigger coaches_proteger_role before insert or update on public.coaches for each row execute function public.coaches_proteger_role();
