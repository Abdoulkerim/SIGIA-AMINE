
BEGIN;

-- 1. Création d'une matière
REVOKE EXECUTE ON FUNCTION public.create_subject(
  text, text, text, numeric, numeric, text
) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.create_subject(
  text, text, text, numeric, numeric, text
) TO authenticated;

-- 2. Modification d'une matière
REVOKE EXECUTE ON FUNCTION public.update_subject(
  uuid, text, text, text, numeric, numeric, text
) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.update_subject(
  uuid, text, text, text, numeric, numeric, text
) TO authenticated;

-- 3. Activation ou désactivation d'une matière
REVOKE EXECUTE ON FUNCTION public.set_subject_active(
  uuid, boolean
) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.set_subject_active(
  uuid, boolean
) TO authenticated;

-- 4. Affectation d'une matière à une classe
REVOKE EXECUTE ON FUNCTION public.assign_subject_to_class(
  uuid, uuid, uuid, numeric, numeric, boolean
) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.assign_subject_to_class(
  uuid, uuid, uuid, numeric, numeric, boolean
) TO authenticated;

-- 5. Activation ou désactivation d'une affectation
REVOKE EXECUTE ON FUNCTION public.set_subject_class_active(
  uuid, boolean
) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.set_subject_class_active(
  uuid, boolean
) TO authenticated;

COMMIT;
