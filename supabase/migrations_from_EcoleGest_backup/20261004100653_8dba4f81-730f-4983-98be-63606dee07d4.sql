CREATE TYPE public.school_role AS ENUM ('platform_admin', 'school_admin', 'director', 'teacher', 'parent', 'student', 'accountant', 'specialized', 'support_agent');

CREATE TABLE public.schools (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  code text NOT NULL UNIQUE,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON public.schools TO authenticated;
GRANT ALL ON public.schools TO service_role;
ALTER TABLE public.schools ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.school_members (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id uuid NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
  user_id uuid NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (school_id, user_id)
);
GRANT SELECT ON public.school_members TO authenticated;
GRANT ALL ON public.school_members TO service_role;
ALTER TABLE public.school_members ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.user_roles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  membership_id uuid NOT NULL REFERENCES public.school_members(id) ON DELETE CASCADE,
  role public.school_role NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (membership_id, role)
);
GRANT SELECT ON public.user_roles TO authenticated;
GRANT ALL ON public.user_roles TO service_role;
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.is_school_member(_school_id uuid, _user_id uuid DEFAULT auth.uid())
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.school_members
    WHERE school_id = _school_id
      AND user_id = _user_id
      AND is_active
  )
$$;
GRANT EXECUTE ON FUNCTION public.is_school_member(uuid, uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.has_school_role(_school_id uuid, _role public.school_role, _user_id uuid DEFAULT auth.uid())
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
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
GRANT EXECUTE ON FUNCTION public.has_school_role(uuid, public.school_role, uuid) TO authenticated;

CREATE POLICY "Members can view their schools"
ON public.schools FOR SELECT TO authenticated
USING (public.is_school_member(id));

CREATE POLICY "Members can view memberships in their schools"
ON public.school_members FOR SELECT TO authenticated
USING (public.is_school_member(school_id));

CREATE POLICY "Members can view roles in their schools"
ON public.user_roles FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.school_members own_membership
    WHERE own_membership.id = user_roles.membership_id
      AND public.is_school_member(own_membership.school_id)
  )
);

CREATE TABLE public.parents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id uuid NOT NULL REFERENCES public.schools(id) ON DELETE RESTRICT,
  title text,
  first_name text NOT NULL,
  last_name text NOT NULL,
  relationship text,
  phone text NOT NULL,
  secondary_phone text,
  email text,
  profession text,
  employer text,
  address text,
  city text,
  emergency_contact boolean NOT NULL DEFAULT false,
  notes text,
  status text NOT NULL DEFAULT 'active',
  created_by uuid NOT NULL DEFAULT auth.uid(),
  updated_by uuid NOT NULL DEFAULT auth.uid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.parents TO authenticated;
GRANT ALL ON public.parents TO service_role;
ALTER TABLE public.parents ENABLE ROW LEVEL SECURITY;
CREATE INDEX parents_school_id_idx ON public.parents(school_id);
CREATE INDEX parents_school_name_idx ON public.parents(school_id, last_name, first_name);
CREATE INDEX parents_school_phone_idx ON public.parents(school_id, phone);

CREATE POLICY "Members can view parents in their schools"
ON public.parents FOR SELECT TO authenticated
USING (public.is_school_member(school_id));

CREATE POLICY "School staff can create parents"
ON public.parents FOR INSERT TO authenticated
WITH CHECK (
  created_by = auth.uid()
  AND (
    public.has_school_role(school_id, 'school_admin')
    OR public.has_school_role(school_id, 'director')
  )
);

CREATE POLICY "School staff can update parents"
ON public.parents FOR UPDATE TO authenticated
USING (
  public.has_school_role(school_id, 'school_admin')
  OR public.has_school_role(school_id, 'director')
)
WITH CHECK (
  public.has_school_role(school_id, 'school_admin')
  OR public.has_school_role(school_id, 'director')
);

CREATE POLICY "School staff can delete parents"
ON public.parents FOR DELETE TO authenticated
USING (
  public.has_school_role(school_id, 'school_admin')
  OR public.has_school_role(school_id, 'director')
);

CREATE OR REPLACE FUNCTION public.set_updated_at_and_user()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  NEW.updated_at = now();
  IF auth.uid() IS NOT NULL AND to_jsonb(NEW) ? 'updated_by' THEN
    NEW.updated_by = auth.uid();
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER schools_set_updated_at
BEFORE UPDATE ON public.schools
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_user();
CREATE TRIGGER school_members_set_updated_at
BEFORE UPDATE ON public.school_members
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_user();
CREATE TRIGGER parents_set_updated_at
BEFORE UPDATE ON public.parents
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_user();;
