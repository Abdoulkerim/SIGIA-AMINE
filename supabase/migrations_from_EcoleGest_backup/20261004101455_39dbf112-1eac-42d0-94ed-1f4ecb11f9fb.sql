CREATE SCHEMA IF NOT EXISTS private;
REVOKE ALL ON SCHEMA private FROM PUBLIC, anon;
GRANT USAGE ON SCHEMA private TO authenticated, service_role;

CREATE OR REPLACE FUNCTION private.is_school_member(_school_id uuid, _user_id uuid DEFAULT auth.uid())
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.school_members
    WHERE school_id = _school_id
      AND user_id = _user_id
      AND is_active
  )
$$;
REVOKE ALL ON FUNCTION private.is_school_member(uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.is_school_member(uuid, uuid) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION private.has_school_role(_school_id uuid, _role public.school_role, _user_id uuid DEFAULT auth.uid())
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.school_members sm
    JOIN public.user_roles ur ON ur.membership_id = sm.id
    WHERE sm.school_id = _school_id
      AND sm.user_id = _user_id
      AND sm.is_active
      AND ur.role = _role
  )
$$;
REVOKE ALL ON FUNCTION private.has_school_role(uuid, public.school_role, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.has_school_role(uuid, public.school_role, uuid) TO authenticated, service_role;

DROP POLICY "Members can view their schools" ON public.schools;
CREATE POLICY "Members can view their schools"
ON public.schools FOR SELECT TO authenticated
USING (private.is_school_member(id));

DROP POLICY "Members can view memberships in their schools" ON public.school_members;
CREATE POLICY "Members can view memberships in their schools"
ON public.school_members FOR SELECT TO authenticated
USING (private.is_school_member(school_id));

DROP POLICY "Members can view roles in their schools" ON public.user_roles;
CREATE POLICY "Members can view roles in their schools"
ON public.user_roles FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.school_members own_membership
    WHERE own_membership.id = user_roles.membership_id
      AND private.is_school_member(own_membership.school_id)
  )
);

DROP POLICY "Members can view parents in their schools" ON public.parents;
CREATE POLICY "Members can view parents in their schools"
ON public.parents FOR SELECT TO authenticated
USING (private.is_school_member(school_id));

DROP POLICY "School staff can create parents" ON public.parents;
CREATE POLICY "School staff can create parents"
ON public.parents FOR INSERT TO authenticated
WITH CHECK (
  created_by = auth.uid()
  AND (
    private.has_school_role(school_id, 'school_admin')
    OR private.has_school_role(school_id, 'director')
  )
);

DROP POLICY "School staff can update parents" ON public.parents;
CREATE POLICY "School staff can update parents"
ON public.parents FOR UPDATE TO authenticated
USING (
  private.has_school_role(school_id, 'school_admin')
  OR private.has_school_role(school_id, 'director')
)
WITH CHECK (
  private.has_school_role(school_id, 'school_admin')
  OR private.has_school_role(school_id, 'director')
);

DROP POLICY "School staff can delete parents" ON public.parents;
CREATE POLICY "School staff can delete parents"
ON public.parents FOR DELETE TO authenticated
USING (
  private.has_school_role(school_id, 'school_admin')
  OR private.has_school_role(school_id, 'director')
);

REVOKE ALL ON FUNCTION public.is_school_member(uuid, uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.has_school_role(uuid, public.school_role, uuid) FROM PUBLIC, anon, authenticated;
DROP FUNCTION public.is_school_member(uuid, uuid);
DROP FUNCTION public.has_school_role(uuid, public.school_role, uuid);;
