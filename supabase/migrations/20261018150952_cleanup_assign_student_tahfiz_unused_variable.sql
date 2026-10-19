
CREATE OR REPLACE FUNCTION public.assign_student_tahfiz(
  p_student_id uuid,
  p_tahfiz_level_id uuid DEFAULT NULL,
  p_teacher_id uuid DEFAULT NULL,
  p_start_date date DEFAULT NULL,
  p_progress numeric DEFAULT 0,
  p_status text DEFAULT 'active',
  p_notes text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_school uuid;
  v_id uuid;
BEGIN
  SELECT s.school_id
  INTO v_school
  FROM public.students s
  WHERE s.id = p_student_id;

  IF v_school IS NULL
     OR NOT app.has_permission('tahfiz.manage', v_school)
  THEN
    RAISE EXCEPTION 'Accès Tahfiz refusé';
  END IF;

  IF p_progress < 0 OR p_progress > 100 THEN
    RAISE EXCEPTION 'Progression Tahfiz invalide';
  END IF;

  INSERT INTO public.student_tahfiz (
    school_id,
    student_id,
    tahfiz_level_id,
    assigned_teacher_id,
    start_date,
    current_progress,
    status,
    notes
  )
  VALUES (
    v_school,
    p_student_id,
    p_tahfiz_level_id,
    p_teacher_id,
    p_start_date,
    p_progress,
    p_status,
    NULLIF(BTRIM(p_notes), '')
  )
  ON CONFLICT (student_id)
  DO UPDATE SET
    tahfiz_level_id = EXCLUDED.tahfiz_level_id,
    assigned_teacher_id = EXCLUDED.assigned_teacher_id,
    start_date = EXCLUDED.start_date,
    current_progress = EXCLUDED.current_progress,
    status = EXCLUDED.status,
    notes = EXCLUDED.notes,
    updated_at = NOW()
  RETURNING id INTO v_id;

  INSERT INTO public.tahfiz_progress_history (
    school_id,
    student_tahfiz_id,
    student_id,
    progress,
    note,
    recorded_by
  )
  VALUES (
    v_school,
    v_id,
    p_student_id,
    p_progress,
    'Initialisation / mise à jour du profil',
    auth.uid()
  );

  RETURN v_id;
END;
$function$;
