'use server'

import { revalidatePath } from 'next/cache'
import { redirect } from 'next/navigation'
import { z } from 'zod'
import { createClient } from '@/lib/supabase/server'

const uuid = z.string().uuid()
const text = z.string().trim().min(1)
function fail(path:string, message:string):never { redirect(`${path}?error=${encodeURIComponent(message)}`) }

export async function createDocumentType(formData: FormData) {
  const parsed = z.object({code:text.max(50),name:text.max(160),module:z.string().trim().max(80).optional(),description:z.string().trim().max(500).optional()}).safeParse({
    code:formData.get('code'),name:formData.get('name'),module:formData.get('module')||undefined,description:formData.get('description')||undefined,
  })
  if (!parsed.success) fail('/documents/types','Type de document invalide.')
  const supabase=await createClient(); const {data,error}=await supabase.rpc('create_document_type',{p_code:parsed.data.code,p_name:parsed.data.name,p_module:parsed.data.module||null,p_description:parsed.data.description||null})
  if(error) fail('/documents/types',error.message)
  revalidatePath('/documents'); revalidatePath('/documents/types'); redirect(`/documents/types?created=${data}`)
}

export async function uploadDocument(formData: FormData) {
  const title=text.max(200).safeParse(formData.get('title'))
  const typeId=uuid.safeParse(formData.get('documentTypeId'))
  const studentId=z.string().uuid().optional().safeParse(formData.get('studentId')||undefined)
  const parentId=z.string().uuid().optional().safeParse(formData.get('parentId')||undefined)
  const employeeId=z.string().uuid().optional().safeParse(formData.get('employeeId')||undefined)
  const file=formData.get('file')
  if(!title.success||!typeId.success||!studentId.success||!parentId.success||!employeeId.success||!(file instanceof File)||file.size<=0) fail('/documents','Données ou fichier invalides.')
  if([studentId.data,parentId.data,employeeId.data].filter(Boolean).length>1) fail('/documents','Sélectionnez une seule personne liée au document.')
  const supabase=await createClient(); const documentId=crypto.randomUUID()
  const claims=await supabase.auth.getClaims(); const uid=claims.data?.claims?.sub
  if(!uid) fail('/documents','Session expirée.')
  const {data:profile}=await supabase.from('users').select('school_id').eq('id',uid).single()
  if(!profile?.school_id) fail('/documents','École introuvable.')
  const safeName=file.name.replace(/[^a-zA-Z0-9._-]/g,'_')
  const path=`${profile.school_id}/${documentId}/${safeName}`
  const up=await supabase.storage.from('school-documents').upload(path,file,{contentType:file.type||'application/octet-stream',upsert:false})
  if(up.error) fail('/documents',up.error.message)
  const {error}=await supabase.rpc('register_uploaded_document',{p_document_id:documentId,p_document_type_id:typeId.data,p_student_id:studentId.data||null,p_parent_id:parentId.data||null,p_employee_id:employeeId.data||null,p_reference:String(formData.get('reference')||'').trim()||null,p_title:title.data,p_file_path:path,p_file_name:file.name,p_mime_type:file.type||null,p_file_size:file.size,p_issued_at:String(formData.get('issuedAt')||'')||null,p_expires_at:String(formData.get('expiresAt')||'')||null,p_metadata:{source:'web'}})
  if(error){ await supabase.storage.from('school-documents').remove([path]); fail('/documents',error.message) }
  revalidatePath('/documents'); revalidatePath('/documents/archives'); revalidatePath('/administration/eleves'); redirect(`/documents?created=${documentId}`)
}

export async function archiveDocument(formData: FormData){
  const id=uuid.safeParse(formData.get('documentId')); if(!id.success) fail('/documents','Document invalide.')
  const supabase=await createClient(); const {error}=await supabase.rpc('archive_document',{p_document_id:id.data,p_reason:String(formData.get('reason')||'').trim()||null})
  if(error) fail('/documents',error.message)
  revalidatePath('/documents'); revalidatePath('/documents/archives'); redirect('/documents?archived=1')
}

export async function requestDocument(formData: FormData){
  const typeId=uuid.safeParse(formData.get('documentTypeId')); const studentId=z.string().uuid().optional().safeParse(formData.get('studentId')||undefined); const parentId=z.string().uuid().optional().safeParse(formData.get('parentId')||undefined); const employeeId=z.string().uuid().optional().safeParse(formData.get('employeeId')||undefined)
  if(!typeId.success||!studentId.success||!parentId.success||!employeeId.success) fail('/documents/demandes','Paramètres invalides.')
  const owner=[studentId.data,parentId.data,employeeId.data].filter(Boolean).length; if(owner!==1) fail('/documents/demandes','Sélectionnez exactement une personne concernée.')
  const supabase=await createClient(); const {data,error}=await supabase.rpc('create_document_request',{p_document_type_id:typeId.data,p_student_id:studentId.data||null,p_parent_id:parentId.data||null,p_employee_id:employeeId.data||null,p_due_at:String(formData.get('dueAt')||'')||null,p_notes:String(formData.get('notes')||'').trim()||null})
  if(error) fail('/documents/demandes',error.message)
  revalidatePath('/documents/demandes'); redirect(`/documents/demandes?created=${data}`)
}

export async function reviewDocumentRequest(formData: FormData){
  const id=uuid.safeParse(formData.get('requestId')); const status=z.enum(['approved','rejected','fulfilled','cancelled']).safeParse(formData.get('status')); const doc=z.string().uuid().optional().safeParse(formData.get('documentId')||undefined)
  if(!id.success||!status.success||!doc.success) fail('/documents/demandes','Paramètres invalides.')
  const supabase=await createClient(); const {error}=await supabase.rpc('review_document_request',{p_request_id:id.data,p_status:status.data,p_document_id:doc.data||null,p_notes:String(formData.get('notes')||'').trim()||null})
  if(error) fail('/documents/demandes',error.message)
  revalidatePath('/documents/demandes'); redirect('/documents/demandes?updated=1')
}

export async function getDocumentUrl(formData: FormData){
  const id=uuid.safeParse(formData.get('documentId')); if(!id.success) fail('/documents','Document invalide.')
  const supabase=await createClient(); const {data:doc,error}=await supabase.from('documents').select('file_path,title').eq('id',id.data).single(); if(error||!doc) fail('/documents','Document non accessible.')
  const signed=await supabase.storage.from('school-documents').createSignedUrl(doc.file_path,300); if(signed.error) fail('/documents',signed.error.message)
  const qs=new URLSearchParams({url:signed.data.signedUrl,title:doc.title}); redirect(`/documents?open=${encodeURIComponent(qs.toString())}`)
}
