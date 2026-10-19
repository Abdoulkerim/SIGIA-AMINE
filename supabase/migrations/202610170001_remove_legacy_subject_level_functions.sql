
BEGIN;

DROP FUNCTION IF EXISTS
    public.assign_subject_to_level(
        uuid, uuid, uuid, numeric, numeric, boolean
    );

DROP FUNCTION IF EXISTS
    public.set_subject_level_active(uuid, boolean);

COMMIT;
