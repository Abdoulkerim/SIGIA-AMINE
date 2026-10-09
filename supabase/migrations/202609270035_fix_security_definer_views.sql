-- Fix SECURITY DEFINER on views - change to SECURITY INVOKER
-- This ensures RLS policies are applied for the current user, not the view owner

begin;

-- Drop existing views that have SECURITY DEFINER
DROP VIEW IF EXISTS public.v_student_financial_summary CASCADE;
DROP VIEW IF EXISTS public.v_class_effectives CASCADE;
DROP VIEW IF EXISTS public.purchase_order_status_v CASCADE;
DROP VIEW IF EXISTS public.stock_low_stock_v CASCADE;

-- Recreate v_student_financial_summary (views use SECURITY INVOKER by default)
CREATE VIEW public.v_student_financial_summary AS
  SELECT id AS student_id,
    school_id,
    student_number,
    first_name,
    last_name,
    COALESCE(( SELECT sum(sc.amount_due) AS sum
           FROM student_charges sc
          WHERE (sc.student_id = s.id)), (0)::numeric) AS total_due,
    COALESCE(( SELECT sum(pa.amount) AS sum
           FROM ((payment_allocations pa
             JOIN student_charges sc ON ((sc.id = pa.student_charge_id)))
             JOIN payments p ON ((p.id = pa.payment_id)))
          WHERE ((sc.student_id = s.id) AND (p.status = 'paid'::app.payment_status))), (0)::numeric) AS total_paid,
    (COALESCE(( SELECT sum(sc.amount_due) AS sum
           FROM student_charges sc
          WHERE (sc.student_id = s.id)), (0)::numeric) - COALESCE(( SELECT sum(pa.amount) AS sum
           FROM ((payment_allocations pa
             JOIN student_charges sc ON ((sc.id = pa.student_charge_id)))
             JOIN payments p ON ((p.id = pa.payment_id)))
          WHERE ((sc.student_id = s.id) AND (p.status = 'paid'::app.payment_status))), (0)::numeric)) AS balance
   FROM students s;

-- Recreate v_class_effectives
CREATE VIEW public.v_class_effectives AS
  SELECT 
    c.id,
    c.school_id,
    c.name,
    c.level_id,
    COUNT(DISTINCT e.student_id) AS effective
  FROM classes c
  LEFT JOIN enrollments e ON e.class_id = c.id AND e.status = 'enrolled'
  GROUP BY c.id, c.school_id, c.name, c.level_id;

commit;
