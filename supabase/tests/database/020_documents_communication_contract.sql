-- Contract tests: Step 23 - Documents / Communication
select plan(24);

select has_table('public','document_versions','document_versions');
select has_table('public','document_requests','document_requests');
select has_table('public','document_access_logs','document_access_logs');
select has_table('public','announcement_deliveries','announcement_deliveries');
select has_function('public','create_document_type'::name);
select has_function('public','register_uploaded_document'::name);
select has_function('public','archive_document'::name);
select has_function('public','create_document_request'::name);
select has_function('public','review_document_request'::name);
select has_function('public','create_announcement'::name);
select has_function('public','publish_announcement'::name);
select has_function('public','archive_announcement'::name);
select has_function('public','mark_notification_read'::name);
select has_function('app','storage_document_id',array['text'],'storage document path parser');
select ok((select relrowsecurity from pg_class where oid='public.document_versions'::regclass),'RLS document_versions');
select ok((select relrowsecurity from pg_class where oid='public.document_requests'::regclass),'RLS document_requests');
select ok((select relrowsecurity from pg_class where oid='public.document_access_logs'::regclass),'RLS document_access_logs');
select ok((select relrowsecurity from pg_class where oid='public.announcement_deliveries'::regclass),'RLS announcement_deliveries');
select has_index('public','document_versions','idx_document_versions_document','document version index');
select has_index('public','document_requests','idx_document_requests_school_status','document request index');
select has_index('public','document_access_logs','idx_document_access_document','document access index');
select has_index('public','announcement_deliveries','idx_announcement_deliveries_recipient','announcement recipient index');
select has_index('public','announcement_deliveries','idx_announcement_deliveries_announcement','announcement delivery index');
select has_index('public','documents','idx_documents_type_status','document type status index');
select * from finish();
