
BEGIN;

CREATE OR REPLACE FUNCTION public.get_dashboard_direction(
    p_school_id uuid DEFAULT NULL::uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    sid uuid;
    current_year_id uuid;
    result jsonb;
    finance jsonb;
    activities jsonb;
BEGIN
    SELECT coalesce(
        p_school_id,
        (SELECT school_id FROM public.users WHERE id = auth.uid())
    )
    INTO sid;

    IF sid IS NULL
       OR (
           NOT app.is_super_admin()
           AND sid NOT IN (SELECT app.my_school_ids())
       ) THEN
        RAISE EXCEPTION 'FORBIDDEN';
    END IF;

    IF NOT app.is_super_admin()
       AND NOT app.has_permission('dashboard.direction', sid) THEN
        RAISE EXCEPTION 'FORBIDDEN';
    END IF;

    SELECT id
    INTO current_year_id
    FROM public.school_years
    WHERE school_id = sid
      AND is_current = true
    ORDER BY start_date DESC
    LIMIT 1;

    finance := public.get_finance_dashboard(sid);

    SELECT jsonb_build_object(
        'activities',
        coalesce((
            SELECT count(*)
            FROM public.economic_activities
            WHERE school_id = sid AND status = 'active'
        ), 0),

        'agriculture',
        coalesce((
            SELECT count(*)
            FROM public.economic_activities
            WHERE school_id = sid
              AND activity_type = 'agriculture'
              AND status = 'active'
        ), 0),

        'livestock',
        coalesce((
            SELECT count(*)
            FROM public.economic_activities
            WHERE school_id = sid
              AND activity_type = 'livestock'
              AND status = 'active'
        ), 0),

        'agr',
        coalesce((
            SELECT count(*)
            FROM public.economic_activities
            WHERE school_id = sid
              AND activity_type = 'agr'
              AND status = 'active'
        ), 0),

        'productions',
        coalesce((
            SELECT sum(p.quantity)
            FROM public.productions p
            JOIN public.economic_activities ea
              ON ea.id = p.activity_id
            WHERE ea.school_id = sid
        ), 0),

        'livestock_units',
        coalesce((
            SELECT sum(l.quantity)
            FROM public.livestock l
            JOIN public.economic_activities ea
              ON ea.id = l.activity_id
            WHERE ea.school_id = sid
              AND l.status = 'active'
        ), 0),

        'revenue',
        coalesce((
            SELECT sum(s.amount)
            FROM public.sales s
            WHERE s.school_id = sid
        ), 0),

        'expenses',
        coalesce((
            SELECT sum(e.amount)
            FROM public.economic_activity_expenses e
            WHERE e.school_id = sid
        ), 0),

        'result',
        coalesce((
            SELECT sum(s.amount)
            FROM public.sales s
            WHERE s.school_id = sid
        ), 0)
        -
        coalesce((
            SELECT sum(e.amount)
            FROM public.economic_activity_expenses e
            WHERE e.school_id = sid
        ), 0)
    )
    INTO activities;

    SELECT jsonb_build_object(
        'school_id', sid,

        'school_year',
        coalesce((
            SELECT jsonb_build_object(
                'id', sy.id,
                'name', sy.name,
                'start_date', sy.start_date,
                'end_date', sy.end_date
            )
            FROM public.school_years sy
            WHERE sy.id = current_year_id
        ), '{}'::jsonb),

        'students',
        jsonb_build_object(
            'enrolled',
            coalesce((
                SELECT count(*)
                FROM public.enrollments e
                WHERE e.school_id = sid
                  AND e.school_year_id = current_year_id
                  AND e.status = 'enrolled'
            ), 0),

            'active_profiles',
            coalesce((
                SELECT count(*)
                FROM public.students s
                WHERE s.school_id = sid
                  AND s.status = 'active'
            ), 0),

            'internal',
            coalesce((
                SELECT count(*)
                FROM public.enrollments e
                WHERE e.school_id = sid
                  AND e.school_year_id = current_year_id
                  AND e.status = 'enrolled'
                  AND e.residence_type = 'internal'
            ), 0),

            'external',
            coalesce((
                SELECT count(*)
                FROM public.enrollments e
                WHERE e.school_id = sid
                  AND e.school_year_id = current_year_id
                  AND e.status = 'enrolled'
                  AND e.residence_type = 'external'
            ), 0)
        ),

        'classes',
        coalesce((
            SELECT count(*)
            FROM public.classes c
            WHERE c.school_id = sid
              AND c.school_year_id = current_year_id
              AND c.is_active = true
        ), 0),

        'employees',
        coalesce((
            SELECT count(*)
            FROM public.employees e
            WHERE e.school_id = sid
              AND e.status = 'active'
        ), 0),

        'results',
        jsonb_build_object(
            'published_report_cards',
            coalesce((
                SELECT count(*)
                FROM public.report_cards r
                WHERE r.school_id = sid
                  AND r.school_year_id = current_year_id
                  AND r.status = 'published'
            ), 0),

            'general_average',
            coalesce((
                SELECT round(avg(r.general_average), 2)
                FROM public.report_cards r
                WHERE r.school_id = sid
                  AND r.school_year_id = current_year_id
                  AND r.status = 'published'
                  AND r.general_average IS NOT NULL
            ), 0)
        ),

        'attendance_30d',
        jsonb_build_object(
            'present',
            coalesce((
                SELECT count(*)
                FROM public.attendance_records ar
                JOIN public.attendance_sessions a
                  ON a.id = ar.session_id
                WHERE a.school_id = sid
                  AND a.session_date >= current_date - 29
                  AND ar.status = 'present'
            ), 0),

            'absent',
            coalesce((
                SELECT count(*)
                FROM public.attendance_records ar
                JOIN public.attendance_sessions a
                  ON a.id = ar.session_id
                WHERE a.school_id = sid
                  AND a.session_date >= current_date - 29
                  AND ar.status = 'absent'
            ), 0),

            'late',
            coalesce((
                SELECT count(*)
                FROM public.attendance_records ar
                JOIN public.attendance_sessions a
                  ON a.id = ar.session_id
                WHERE a.school_id = sid
                  AND a.session_date >= current_date - 29
                  AND ar.status = 'late'
            ), 0),

            'excused',
            coalesce((
                SELECT count(*)
                FROM public.attendance_records ar
                JOIN public.attendance_sessions a
                  ON a.id = ar.session_id
                WHERE a.school_id = sid
                  AND a.session_date >= current_date - 29
                  AND ar.status = 'excused'
            ), 0)
        ),

        'boarding',
        jsonb_build_object(
            'active_assignments',
            coalesce((
                SELECT count(*)
                FROM public.boarding_assignments
                WHERE school_id = sid
                  AND status = 'active'
            ), 0),

            'beds',
            coalesce((
                SELECT count(*)
                FROM public.boarding_beds b
                JOIN public.boarding_rooms r ON r.id = b.room_id
                JOIN public.boarding_dormitories d
                  ON d.id = r.dormitory_id
                JOIN public.boarding_buildings bb
                  ON bb.id = d.building_id
                WHERE bb.school_id = sid
            ), 0)
        ),

        'finance', finance,
        'activities', activities,

        'top_classes',
        coalesce((
            SELECT jsonb_agg(
                x ORDER BY x.active_students DESC, x.class_name
            )
            FROM (
                SELECT
                    v.id AS class_id,
                    v.name AS class_name,
                    v.effective AS active_students
                FROM public.v_class_effectives v
                JOIN public.classes c ON c.id = v.id
                WHERE v.school_id = sid
                  AND c.school_year_id = current_year_id
                  AND c.is_active = true
                ORDER BY v.effective DESC, v.name
                LIMIT 10
            ) x
        ), '[]'::jsonb)
    )
    INTO result;

    RETURN result;
END;
$function$;

COMMIT;
