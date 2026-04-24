-- Missing DELETE policy on coaches table
-- Without this, super_admin delete from dashboard silently returns 0 rows.

CREATE POLICY "auth_coaches_delete" ON public.coaches
  FOR DELETE TO authenticated
  USING (public.is_admin());
