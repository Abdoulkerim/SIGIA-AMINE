BEGIN;

DROP POLICY IF EXISTS announcements_select_step23
ON public.announcements;

CREATE POLICY announcements_select_step23
ON public.announcements
FOR SELECT
USING (
    app.can_manage_communication(school_id)
    OR (
        status = 'published'
        AND (expires_at IS NULL OR expires_at > now())
        AND EXISTS (
            SELECT 1
            FROM public.notifications AS n
            WHERE n.related_table = 'announcements'
              AND n.related_id = announcements.id
              AND n.recipient_user_id = auth.uid()
        )
    )
    OR app.is_super_admin()
);

COMMIT;
