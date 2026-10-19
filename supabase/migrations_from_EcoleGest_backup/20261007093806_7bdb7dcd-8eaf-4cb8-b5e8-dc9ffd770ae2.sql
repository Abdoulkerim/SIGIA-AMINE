CREATE TABLE public.academic_years (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), school_id uuid NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE, name varchar(30) NOT NULL, start_date date NOT NULL, end_date date NOT NULL, is_current boolean NOT NULL DEFAULT false, status text NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','active','closed')), created_by uuid, updated_by uuid, created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(), CHECK (end_date > start_date), UNIQUE (school_id, name));
CREATE TABLE public.cycles (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), school_id uuid NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE, name varchar(120) NOT NULL, code varchar(30) NOT NULL, description text, status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','inactive')), created_by uuid, updated_by uuid, created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(), UNIQUE (school_id, code));
CREATE TABLE public.levels (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), school_id uuid NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE, cycle_id uuid NOT NULL REFERENCES public.cycles(id) ON DELETE RESTRICT, name varchar(120) NOT NULL, code varchar(30) NOT NULL, order_index integer, description text, created_by uuid, updated_by uuid, created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(), UNIQUE (school_id, code));
CREATE TABLE public.classes (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), school_id uuid NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE, level_id uuid NOT NULL REFERENCES public.levels(id) ON DELETE RESTRICT, academic_year_id uuid NOT NULL REFERENCES public.academic_years(id) ON DELETE RESTRICT, name varchar(120) NOT NULL, code varchar(30), capacity integer CHECK (capacity IS NULL OR capacity > 0), description text, created_by uuid, updated_by uuid, created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE public.subjects (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), school_id uuid NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE, name varchar(120) NOT NULL, code varchar(30) NOT NULL, coefficient numeric(5,2), description text, status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','inactive')), created_by uuid, updated_by uuid, created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(), UNIQUE (school_id, code));
CREATE TABLE public.students (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), school_id uuid NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE, registration_number varchar(50), first_name varchar(100) NOT NULL, last_name varchar(100) NOT NULL, birth_date date NOT NULL, gender text CHECK (gender IN ('Féminin','Masculin')), birth_place varchar(120), address text, status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','inactive','graduated')), created_by uuid, updated_by uuid, created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(), UNIQUE (school_id, registration_number));
CREATE TABLE public.student_guardians (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), school_id uuid NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE, student_id uuid NOT NULL REFERENCES public.students(id) ON DELETE CASCADE, parent_id uuid NOT NULL REFERENCES public.parents(id) ON DELETE CASCADE, relationship text CHECK (relationship IN ('Père','Mère','Tuteur','Tutrice','Autre')), is_primary boolean NOT NULL DEFAULT false, emergency_contact boolean NOT NULL DEFAULT false, created_by uuid, updated_by uuid, created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(), UNIQUE (student_id, parent_id));
CREATE TABLE public.enrollments (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), school_id uuid NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE, student_id uuid NOT NULL REFERENCES public.students(id) ON DELETE CASCADE, class_id uuid NOT NULL REFERENCES public.classes(id) ON DELETE RESTRICT, academic_year_id uuid NOT NULL REFERENCES public.academic_years(id) ON DELETE RESTRICT, start_date date NOT NULL, status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','completed','cancelled')), notes text, created_by uuid, updated_by uuid, created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(), UNIQUE (student_id, academic_year_id));

CREATE OR REPLACE FUNCTION private.stamp_row() RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN NEW.created_by := auth.uid(); END IF;
  NEW.updated_by := auth.uid(); NEW.updated_at := now(); RETURN NEW;
END $$;

-- Empêche qu'une ligne référence un élément d'une autre école.
CREATE OR REPLACE FUNCTION private.check_same_school() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE col text; tbl text; other uuid; i int := 0;
BEGIN
  WHILE i < TG_NARGS LOOP
    col := TG_ARGV[i]; tbl := TG_ARGV[i+1];
    EXECUTE format('SELECT school_id FROM public.%I WHERE id = ($1).%I', tbl, col) INTO other USING NEW;
    IF other IS DISTINCT FROM NEW.school_id THEN RAISE EXCEPTION 'Référence % hors de votre école', col; END IF;
    i := i + 2;
  END LOOP;
  RETURN NEW;
END $$;

DO $$ DECLARE t text; BEGIN
  FOREACH t IN ARRAY ARRAY['academic_years','cycles','levels','classes','subjects','students','student_guardians','enrollments'] LOOP
    EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON public.%I TO authenticated; GRANT ALL ON public.%I TO service_role;', t, t);
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY;', t);
    EXECUTE format('CREATE INDEX ON public.%I (school_id);', t);
    EXECUTE format('CREATE POLICY "Membres de l''école : lecture" ON public.%I FOR SELECT TO authenticated USING (private.is_school_member(school_id));', t);
    EXECUTE format('CREATE POLICY "Direction : création" ON public.%I FOR INSERT TO authenticated WITH CHECK (private.has_school_role(school_id, ''school_admin'') OR private.has_school_role(school_id, ''director''));', t);
    EXECUTE format('CREATE POLICY "Direction : modification" ON public.%I FOR UPDATE TO authenticated USING (private.has_school_role(school_id, ''school_admin'') OR private.has_school_role(school_id, ''director'')) WITH CHECK (private.has_school_role(school_id, ''school_admin'') OR private.has_school_role(school_id, ''director''));', t);
    EXECUTE format('CREATE POLICY "Direction : suppression" ON public.%I FOR DELETE TO authenticated USING (private.has_school_role(school_id, ''school_admin'') OR private.has_school_role(school_id, ''director''));', t);
    EXECUTE format('CREATE TRIGGER stamp_row BEFORE INSERT OR UPDATE ON public.%I FOR EACH ROW EXECUTE FUNCTION private.stamp_row();', t);
  END LOOP;
END $$;

CREATE TRIGGER same_school BEFORE INSERT OR UPDATE ON public.levels FOR EACH ROW EXECUTE FUNCTION private.check_same_school('cycle_id','cycles');
CREATE TRIGGER same_school BEFORE INSERT OR UPDATE ON public.classes FOR EACH ROW EXECUTE FUNCTION private.check_same_school('level_id','levels','academic_year_id','academic_years');
CREATE TRIGGER same_school BEFORE INSERT OR UPDATE ON public.student_guardians FOR EACH ROW EXECUTE FUNCTION private.check_same_school('student_id','students','parent_id','parents');
CREATE TRIGGER same_school BEFORE INSERT OR UPDATE ON public.enrollments FOR EACH ROW EXECUTE FUNCTION private.check_same_school('student_id','students','class_id','classes','academic_year_id','academic_years');
CREATE INDEX ON public.enrollments (class_id); CREATE INDEX ON public.student_guardians (parent_id); CREATE INDEX ON public.levels (cycle_id); CREATE INDEX ON public.classes (level_id);;
