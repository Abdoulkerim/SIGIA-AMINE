-- Enable RLS on wushu_progress_history table
begin;

ALTER TABLE public.wushu_progress_history ENABLE ROW LEVEL SECURITY;

CREATE POLICY enable_read_for_authenticated ON public.wushu_progress_history
  FOR SELECT TO authenticated USING (true);

CREATE POLICY enable_insert_for_authenticated ON public.wushu_progress_history
  FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY enable_update_for_authenticated ON public.wushu_progress_history
  FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY enable_delete_for_authenticated ON public.wushu_progress_history
  FOR DELETE TO authenticated USING (true);

commit;
