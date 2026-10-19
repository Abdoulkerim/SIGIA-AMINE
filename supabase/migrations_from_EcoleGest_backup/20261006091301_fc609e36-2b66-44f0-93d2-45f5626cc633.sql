CREATE OR REPLACE FUNCTION public.create_first_school(_name text, _code text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE uid uuid := auth.uid(); sid uuid; mid uuid;
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION 'Connexion requise'; END IF;
  IF length(trim(coalesce(_name,''))) < 2 OR length(trim(coalesce(_code,''))) < 2 THEN RAISE EXCEPTION 'Nom et code requis'; END IF;
  IF EXISTS (SELECT 1 FROM school_members WHERE user_id = uid AND is_active) THEN
    RAISE EXCEPTION 'Votre compte est déjà rattaché à une école';
  END IF;
  INSERT INTO schools(name, code) VALUES (trim(_name), upper(trim(_code))) RETURNING id INTO sid;
  INSERT INTO school_members(school_id, user_id) VALUES (sid, uid) RETURNING id INTO mid;
  INSERT INTO user_roles(membership_id, role) VALUES (mid, 'school_admin');
  RETURN sid;
END $$;
REVOKE ALL ON FUNCTION public.create_first_school(text, text) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.create_first_school(text, text) TO authenticated;;
