
CREATE OR REPLACE FUNCTION public.review_document_request(
  p_request_id uuid,
  p_status text,
  p_document_id uuid DEFAULT NULL,
  p_notes text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'app'
AS $function$
DECLARE
  v_school uuid;
BEGIN
  SELECT school_id
  INTO v_school
  FROM public.document_requests
  WHERE id = p_request_id;

  IF v_school IS NULL
     OR NOT app.can_manage_documents(v_school)
  THEN
    RAISE EXCEPTION 'FORBIDDEN';
  END IF;

  IF p_status NOT IN (
    'approved',
    'rejected',
    'fulfilled',
    'cancelled'
  ) THEN
    RAISE EXCEPTION 'INVALID_STATUS';
  END IF;

  IF p_status = 'fulfilled' AND p_document_id IS NULL THEN
    RAISE EXCEPTION 'DOCUMENT_REQUIRED';
  END IF;

  IF p_document_id IS NOT NULL
     AND NOT EXISTS (
       SELECT 1
       FROM public.documents d
       WHERE d.id = p_document_id
         AND d.school_id = v_school
     )
  THEN
    RAISE EXCEPTION 'CROSS_SCHOOL: document';
  END IF;

  UPDATE public.document_requests
  SET
    status = p_status,
    reviewed_by = auth.uid(),
    reviewed_at = now(),
    fulfilled_document_id = CASE
      WHEN p_status = 'fulfilled' THEN p_document_id
      ELSE fulfilled_document_id
    END,
    notes = COALESCE(
      NULLIF(TRIM(p_notes), ''),
      notes
    )
  WHERE id = p_request_id;
END;
$function$;
