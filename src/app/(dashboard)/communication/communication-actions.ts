'use server'

import { revalidatePath } from 'next/cache'
import { redirect } from 'next/navigation'
import { z } from 'zod'
import { createClient } from '@/lib/supabase/server'
const uuid=z.string().uuid(); function fail(path:string,msg:string):never{redirect(`${path}?error=${encodeURIComponent(msg)}`)}
export async function createAnnouncement(formData:FormData){
  const title=z.string().trim().min(1).max(200).safeParse(formData.get('title')); const content=z.string().trim().min(1).max(10000).safeParse(formData.get('content')); const type=z.enum(['all_users','all_staff','all_parents','class','role','users']).safeParse(formData.get('audienceType'))
  if(!title.success||!content.success||!type.success) fail('/communication/annonces','Données invalides.')
  let audience:any={type:type.data}
  if(type.data==='class'){const c=uuid.safeParse(formData.get('classId')); const sy=uuid.safeParse(formData.get('schoolYearId')); if(!c.success||!sy.success) fail('/communication/annonces','Classe ou année invalide.'); audience.class_id=c.data; audience.school_year_id=sy.data}
  if(type.data==='role'){const role=String(formData.get('roleCode')||'').trim(); if(!role) fail('/communication/annonces','Rôle obligatoire.'); audience.role_code=role}
  if(type.data==='users'){const ids=String(formData.get('userIds')||'').split(',').map(v=>v.trim()).filter(Boolean); if(!ids.length||!ids.every(v=>uuid.safeParse(v).success)) fail('/communication/annonces','Liste utilisateurs invalide.'); audience.user_ids=ids}
  const supabase=await createClient(); const {data,error}=await supabase.rpc('create_announcement',{p_title:title.data,p_content:content.data,p_audience:audience,p_expires_at:String(formData.get('expiresAt')||'')||null}); if(error) fail('/communication/annonces',error.message)
  revalidatePath('/communication'); revalidatePath('/communication/annonces'); redirect(`/communication/annonces?created=${data}`)
}
export async function publishAnnouncement(formData:FormData){const id=uuid.safeParse(formData.get('announcementId'));if(!id.success)fail('/communication/annonces','Annonce invalide.');const supabase=await createClient();const {data,error}=await supabase.rpc('publish_announcement',{p_announcement_id:id.data});if(error)fail('/communication/annonces',error.message);revalidatePath('/communication');revalidatePath('/communication/notifications');revalidatePath('/communication/annonces');redirect(`/communication/annonces?published=${data??0}`)}
export async function archiveAnnouncement(formData:FormData){const id=uuid.safeParse(formData.get('announcementId'));if(!id.success)fail('/communication/annonces','Annonce invalide.');const supabase=await createClient();const {error}=await supabase.rpc('archive_announcement',{p_announcement_id:id.data});if(error)fail('/communication/annonces',error.message);revalidatePath('/communication/annonces');redirect('/communication/annonces?archived=1')}
export async function markNotificationRead(formData:FormData){const id=uuid.safeParse(formData.get('notificationId'));if(!id.success)fail('/communication/notifications','Notification invalide.');const supabase=await createClient();const {error}=await supabase.rpc('mark_notification_read',{p_notification_id:id.data});if(error)fail('/communication/notifications',error.message);revalidatePath('/communication/notifications');redirect('/communication/notifications?read=1')}
