
BEGIN;

-- =========================================================
-- 1. RECALCUL UNIFIE DES FACTURES
-- =========================================================

CREATE OR REPLACE FUNCTION app.recalculate_invoice_total_hardened()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = pg_catalog
AS $function$
DECLARE
  v_invoice_ids uuid[];
  v_invoice_id uuid;
  v_invoice_discount numeric;
  v_subtotal numeric;
  v_lines_total numeric;
BEGIN

  -- Identifier les factures concernees.

  IF TG_OP = 'DELETE' THEN
    v_invoice_ids := ARRAY[OLD.invoice_id];

  ELSIF TG_OP = 'INSERT' THEN
    v_invoice_ids := ARRAY[NEW.invoice_id];

  ELSIF TG_OP = 'UPDATE' THEN

    IF OLD.invoice_id IS DISTINCT FROM NEW.invoice_id THEN

      -- Ordre de verrouillage stable pour les deux factures.

      v_invoice_ids := ARRAY[
        LEAST(OLD.invoice_id, NEW.invoice_id),
        GREATEST(OLD.invoice_id, NEW.invoice_id)
      ];

    ELSE
      v_invoice_ids := ARRAY[NEW.invoice_id];
    END IF;

  ELSE
    RAISE EXCEPTION 'UNSUPPORTED_TRIGGER_OPERATION: %', TG_OP;
  END IF;

  -- Recalculer chaque facture concernee.

  FOREACH v_invoice_id IN ARRAY v_invoice_ids
  LOOP

    SELECT COALESCE(i.discount, 0)
    INTO v_invoice_discount
    FROM public.invoices AS i
    WHERE i.id = v_invoice_id
    FOR UPDATE;

    IF NOT FOUND THEN
      CONTINUE;
    END IF;

    -- Subtotal brut et total apres remises par ligne.

    SELECT
      COALESCE(SUM(ii.quantity * ii.unit_amount), 0),
      COALESCE(SUM(ii.line_total), 0)
    INTO v_subtotal, v_lines_total
    FROM public.invoice_items AS ii
    WHERE ii.invoice_id = v_invoice_id;

    -- Mise a jour des totaux.

    UPDATE public.invoices AS i
    SET
      subtotal = v_subtotal,
      total = GREATEST(0, v_lines_total - v_invoice_discount),
      updated_at = pg_catalog.now()
    WHERE i.id = v_invoice_id;

  END LOOP;

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;

  RETURN NEW;

END;
$function$;


-- =========================================================
-- 2. SUPPRESSION DU TRIGGER HISTORIQUE REDONDANT
-- =========================================================

DROP TRIGGER IF EXISTS
  trg_recompute_invoice_total_insert
  ON public.invoice_items;


-- Garantir la presence du trigger unique.

DROP TRIGGER IF EXISTS
  trg_invoice_total_hardened
  ON public.invoice_items;

CREATE TRIGGER trg_invoice_total_hardened
AFTER INSERT OR UPDATE OR DELETE
ON public.invoice_items
FOR EACH ROW
EXECUTE FUNCTION app.recalculate_invoice_total_hardened();


-- =========================================================
-- 3. SECURISATION DES PRIVILEGES DES TABLES
-- =========================================================

-- Supprimer les privileges du role anon.

REVOKE ALL PRIVILEGES
ON TABLE public.invoices, public.invoice_items
FROM PUBLIC, anon;

-- Retirer les privileges directs d'ecriture aux utilisateurs
-- authentifies. Les fonctions RPC restent les points d'entree.

REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
ON TABLE public.invoices, public.invoice_items
FROM PUBLIC, anon, authenticated;

-- Conserver la consultation pour les utilisateurs connectes.

GRANT SELECT
ON TABLE public.invoices, public.invoice_items
TO authenticated;


-- =========================================================
-- 4. POLITIQUES RLS : LECTURE SEULE
-- =========================================================

-- Factures : conserver la condition de lecture existante.

DROP POLICY IF EXISTS
  education_stage_boundary
  ON public.invoices;

CREATE POLICY education_stage_boundary
ON public.invoices
AS RESTRICTIVE
FOR SELECT
TO authenticated
USING (
  (
    app.can_access_education_stage(school_id, education_stage)
    OR app.can_access_student(student_id)
  )
  AND
  (
    student_id IS NULL
    OR app.can_access_student(student_id)
  )
);


-- Lignes de factures : conserver la condition de lecture existante.

DROP POLICY IF EXISTS
  education_stage_boundary
  ON public.invoice_items;

CREATE POLICY education_stage_boundary
ON public.invoice_items
AS RESTRICTIVE
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.invoices AS i
    WHERE i.id = invoice_items.invoice_id
      AND (
        (
          i.student_id IS NULL
          AND app.can_access_education_stage(
            i.school_id,
            i.education_stage
          )
        )
        OR app.can_access_student(i.student_id)
      )
  )
);


COMMIT;
