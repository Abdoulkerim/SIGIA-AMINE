'use server'

import { revalidatePath } from 'next/cache'
import { redirect } from 'next/navigation'
import { z } from 'zod'
import { createClient } from '@/lib/supabase/server'

const uuid = z.string().uuid()
const date = z.string().regex(/^\d{4}-\d{2}-\d{2}$/)
const positive = z.coerce.number().positive()
const nonNegative = z.coerce.number().nonnegative()

async function currentSchoolId() {
  const supabase = await createClient()
  const claims = await supabase.auth.getClaims()
  const userId = claims.data?.claims?.sub
  if (!userId) return { supabase, schoolId: null as string | null }
  const { data } = await supabase.from('users').select('school_id').eq('id', userId).single()
  return { supabase, schoolId: data?.school_id ?? null }
}
function fail(base: string, message: string): never { redirect(`${base}?error=${encodeURIComponent(message)}`) }

export async function createMealType(formData: FormData) {
  const code=z.string().trim().min(1).max(40).safeParse(formData.get('code'))
  const name=z.string().trim().min(1).max(100).safeParse(formData.get('name'))
  const sort=z.coerce.number().int().safeParse(formData.get('sortOrder')||0)
  if(!code.success||!name.success||!sort.success) fail('/restauration/types','Type de repas invalide.')
  const {supabase,schoolId}=await currentSchoolId(); if(!schoolId) fail('/restauration/types','École introuvable.')
  const {error}=await supabase.rpc('create_meal_type',{p_school_id:schoolId,p_code:code.data,p_name:name.data,p_sort_order:sort.data})
  if(error) fail('/restauration/types',error.message)
  revalidatePath('/restauration/types'); revalidatePath('/restauration'); redirect('/restauration/types?created=1')
}

export async function createMenu(formData: FormData) {
  const d=date.safeParse(formData.get('menuDate')); const notes=z.string().trim().max(500).optional().safeParse(formData.get('notes')||undefined)
  if(!d.success||!notes.success) fail('/restauration/menus','Menu invalide.')
  const {supabase,schoolId}=await currentSchoolId(); if(!schoolId) fail('/restauration/menus','École introuvable.')
  const {data,error}=await supabase.rpc('create_catering_menu',{p_school_id:schoolId,p_menu_date:d.data,p_notes:notes.data??null})
  if(error) fail('/restauration/menus',error.message)
  revalidatePath('/restauration/menus'); revalidatePath('/restauration'); redirect(`/restauration/menus?created=${data}`)
}

export async function upsertMenuItem(formData: FormData) {
  const menuId=uuid.safeParse(formData.get('menuId')); const mealTypeId=uuid.safeParse(formData.get('mealTypeId'))
  const desc=z.string().trim().min(1).max(300).safeParse(formData.get('description'))
  const cost=nonNegative.safeParse(formData.get('estimatedCost')); const qty=z.coerce.number().positive().optional().safeParse(formData.get('plannedQuantity')||undefined)
  const unit=z.string().trim().max(30).optional().safeParse(formData.get('plannedUnit')||undefined)
  const notes=z.string().trim().max(500).optional().safeParse(formData.get('notes')||undefined)
  if(!menuId.success||!mealTypeId.success||!desc.success||!cost.success||!qty.success||!unit.success||!notes.success) fail('/restauration/menus','Ligne de menu invalide.')
  const {supabase}=await currentSchoolId(); const {error}=await supabase.rpc('upsert_catering_menu_item',{p_menu_id:menuId.data,p_meal_type_id:mealTypeId.data,p_description:desc.data,p_estimated_cost:cost.data,p_planned_quantity:qty.data??null,p_planned_unit:unit.data??null,p_notes:notes.data??null})
  if(error) fail('/restauration/menus',error.message); revalidatePath('/restauration/menus'); redirect('/restauration/menus?updated=1')
}

export async function publishMenu(formData: FormData) {
  const id=uuid.safeParse(formData.get('id')); if(!id.success) fail('/restauration/menus','Menu invalide.')
  const {supabase}=await currentSchoolId(); const {error}=await supabase.rpc('publish_catering_menu',{p_menu_id:id.data}); if(error) fail('/restauration/menus',error.message)
  revalidatePath('/restauration/menus'); revalidatePath('/restauration'); redirect('/restauration/menus?published=1')
}
export async function closeMenu(formData: FormData) {
  const id=uuid.safeParse(formData.get('id')); if(!id.success) fail('/restauration/menus','Menu invalide.')
  const {supabase}=await currentSchoolId(); const {error}=await supabase.rpc('close_catering_menu',{p_menu_id:id.data}); if(error) fail('/restauration/menus',error.message)
  revalidatePath('/restauration/menus'); revalidatePath('/restauration'); redirect('/restauration/menus?closed=1')
}

export async function recordService(formData: FormData) {
  const itemId=uuid.safeParse(formData.get('menuItemId')); const qty=nonNegative.safeParse(formData.get('servedQuantity')); const unit=z.string().trim().max(30).optional().safeParse(formData.get('unit')||undefined); const cost=nonNegative.safeParse(formData.get('actualCost')); const notes=z.string().trim().max(500).optional().safeParse(formData.get('notes')||undefined)
  if(!itemId.success||!qty.success||!unit.success||!cost.success||!notes.success) fail('/restauration/services','Service invalide.')
  const {supabase}=await currentSchoolId(); const {error}=await supabase.rpc('record_catering_service',{p_menu_item_id:itemId.data,p_served_quantity:qty.data,p_unit:unit.data??null,p_actual_cost:cost.data,p_notes:notes.data??null})
  if(error) fail('/restauration/services',error.message); revalidatePath('/restauration/services'); revalidatePath('/restauration'); redirect('/restauration/services?recorded=1')
}

export async function recordMealAttendance(formData: FormData) {
  const studentId=uuid.safeParse(formData.get('studentId')); const mealTypeId=uuid.safeParse(formData.get('mealTypeId')); const d=date.safeParse(formData.get('mealDate')); const served=z.enum(['true','false']).safeParse(formData.get('served')); const qty=nonNegative.safeParse(formData.get('quantity')||1); const notes=z.string().trim().max(300).optional().safeParse(formData.get('notes')||undefined)
  if(!studentId.success||!mealTypeId.success||!d.success||!served.success||!qty.success||!notes.success) fail('/restauration/presences','Présence repas invalide.')
  const {supabase}=await currentSchoolId(); const {error}=await supabase.rpc('set_meal_attendance',{p_student_id:studentId.data,p_meal_type_id:mealTypeId.data,p_meal_date:d.data,p_served:served.data==='true',p_quantity:qty.data,p_notes:notes.data??null})
  if(error) fail('/restauration/presences',error.message); revalidatePath('/restauration/presences'); revalidatePath('/restauration'); revalidatePath('/administration/eleves'); redirect('/restauration/presences?recorded=1')
}

export async function consumeStock(formData: FormData) {
  const itemId=uuid.safeParse(formData.get('menuItemId')); const productId=uuid.safeParse(formData.get('productId')); const locationId=uuid.safeParse(formData.get('locationId')); const qty=positive.safeParse(formData.get('quantity')); const cost=nonNegative.safeParse(formData.get('unitCost')||0); const notes=z.string().trim().max(500).optional().safeParse(formData.get('notes')||undefined)
  if(!itemId.success||!productId.success||!locationId.success||!qty.success||!cost.success||!notes.success) fail('/restauration/consommations','Consommation invalide.')
  const {supabase}=await currentSchoolId(); const {error}=await supabase.rpc('consume_catering_stock',{p_menu_item_id:itemId.data,p_product_id:productId.data,p_location_id:locationId.data,p_quantity:qty.data,p_unit_cost:cost.data,p_notes:notes.data??null})
  if(error) fail('/restauration/consommations',error.message); revalidatePath('/restauration/consommations'); revalidatePath('/restauration'); revalidatePath('/stocks'); redirect('/restauration/consommations?consumed=1')
}

export async function linkPurchase(formData: FormData) {
  const itemId=uuid.safeParse(formData.get('menuItemId')); const poId=uuid.safeParse(formData.get('purchaseOrderId')); const productId=uuid.safeParse(formData.get('productId')); const qty=positive.safeParse(formData.get('quantity'))
  if(!itemId.success||!poId.success||!productId.success||!qty.success) fail('/restauration/consommations','Lien achat invalide.')
  const {supabase}=await currentSchoolId(); const {error}=await supabase.rpc('link_catering_purchase',{p_menu_item_id:itemId.data,p_purchase_order_id:poId.data,p_product_id:productId.data,p_quantity:qty.data})
  if(error) fail('/restauration/consommations',error.message); revalidatePath('/restauration/consommations'); redirect('/restauration/consommations?linked=1')
}
