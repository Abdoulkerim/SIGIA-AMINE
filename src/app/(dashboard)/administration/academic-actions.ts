'use server'

import { revalidatePath } from 'next/cache'
import { redirect } from 'next/navigation'
import { z } from 'zod'
import { createClient } from '@/lib/supabase/server'

const levelSchema = z.object({
  id: z.string().uuid().optional(),
  code: z.string().trim().min(1).max(50),
  name: z.string().trim().min(1).max(120),
  educationCycle: z.string().trim().max(80).optional(),
  sequenceNo: z.coerce.number().int().min(0).optional(),
})

const classSchema = z.object({
  id: z.string().uuid().optional(),
  schoolYearId: z.string().uuid(),
  name: z.string().trim().min(1).max(120),
  code: z.string().trim().min(1).max(50),
  section: z.string().trim().max(50).optional(),
  roomName: z.string().trim().max(120).optional(),
  capacity: z.coerce.number().int().positive().optional(),
})

function errUrl(base: string, error: string): string {
  return `${base}?error=${encodeURIComponent(error)}`
}

export async function createLevel(formData: FormData) {
  const parsed = levelSchema.safeParse({
    code: formData.get('code'),
    name: formData.get('name'),
    educationCycle: formData.get('educationCycle') || undefined,
    sequenceNo: formData.get('sequenceNo') || undefined,
  })
  if (!parsed.success) redirect(errUrl('/administration/niveaux/nouveau', 'Données du niveau invalides'))

  const supabase = await createClient()
  const { data, error } = await supabase.rpc('create_level', {
    p_code: parsed.data.code,
    p_name: parsed.data.name,
    p_education_cycle: parsed.data.educationCycle ?? null,
    p_sequence_no: parsed.data.sequenceNo ?? null,
  })
  if (error) redirect(errUrl('/administration/niveaux/nouveau', error.message))

  revalidatePath('/administration/niveaux')
  revalidatePath('/administration/classes')
  redirect(`/administration/niveaux?created=${data}`)
}

export async function updateLevel(formData: FormData) {
  const parsed = levelSchema.required({ id: true }).safeParse({
    id: formData.get('id'),
    code: formData.get('code'),
    name: formData.get('name'),
    educationCycle: formData.get('educationCycle') || undefined,
    sequenceNo: formData.get('sequenceNo') || undefined,
  })
  if (!parsed.success) redirect('/administration/niveaux?error=Niveau invalide')

  const supabase = await createClient()
  const { error } = await supabase.rpc('update_level', {
    p_level_id: parsed.data.id,
    p_code: parsed.data.code,
    p_name: parsed.data.name,
    p_education_cycle: parsed.data.educationCycle ?? null,
    p_sequence_no: parsed.data.sequenceNo ?? null,
  })
  if (error) redirect(errUrl('/administration/niveaux', error.message))

  revalidatePath('/administration/niveaux')
  revalidatePath('/administration/classes')
  redirect('/administration/niveaux?updated=1')
}

export async function toggleLevel(formData: FormData) {
  const id = z.string().uuid().safeParse(formData.get('id'))
  const active = z.coerce.boolean().safeParse(formData.get('active'))
  if (!id.success || !active.success) redirect('/administration/niveaux?error=Paramètres invalides')

  const supabase = await createClient()
  const { error } = await supabase.rpc('set_level_active', {
    p_level_id: id.data,
    p_is_active: active.data,
  })
  if (error) redirect(errUrl('/administration/niveaux', error.message))

  revalidatePath('/administration/niveaux')
  revalidatePath('/administration/classes')
  redirect('/administration/niveaux?updated=1')
}

export async function createClass(formData: FormData) {
  const parsed = classSchema.safeParse({
    schoolYearId: formData.get('schoolYearId'),
    name: formData.get('name'),
    code: formData.get('code'),
    section: formData.get('section') || undefined,
    roomName: formData.get('roomName') || undefined,
    capacity: formData.get('capacity') || undefined,
  })
  if (!parsed.success) redirect(errUrl('/administration/classes/nouveau', 'Données de classe invalides'))

  const supabase = await createClient()
  const { data, error } = await supabase.rpc('create_class', {
    p_school_year_id: parsed.data.schoolYearId,
    p_level_id: null,
    p_name: parsed.data.name,
    p_code: parsed.data.code,
    p_section: parsed.data.section ?? null,
    p_room_name: parsed.data.roomName ?? null,
    p_capacity: parsed.data.capacity ?? null,
  })
  if (error) redirect(errUrl('/administration/classes/nouveau', error.message))

  revalidatePath('/administration/classes')
  revalidatePath('/administration/niveaux')
  revalidatePath('/administration/inscriptions')
  redirect(`/administration/classes?created=${data}`)
}

export async function updateClass(formData: FormData) {
  const parsed = classSchema.required({ id: true }).safeParse({
    id: formData.get('id'),
    schoolYearId: formData.get('schoolYearId'),
    name: formData.get('name'),
    code: formData.get('code'),
    section: formData.get('section') || undefined,
    roomName: formData.get('roomName') || undefined,
    capacity: formData.get('capacity') || undefined,
  })
  if (!parsed.success) redirect('/administration/classes?error=Classe invalide')

  const supabase = await createClient()
  const { error } = await supabase.rpc('update_class', {
    p_class_id: parsed.data.id,
    p_school_year_id: parsed.data.schoolYearId,
    p_level_id: null,
    p_name: parsed.data.name,
    p_code: parsed.data.code,
    p_section: parsed.data.section ?? null,
    p_room_name: parsed.data.roomName ?? null,
    p_capacity: parsed.data.capacity ?? null,
  })
  if (error) redirect(errUrl(`/administration/classes/${parsed.data.id}`, error.message))

  revalidatePath('/administration/classes')
  revalidatePath(`/administration/classes/${parsed.data.id}`)
  revalidatePath('/administration/inscriptions')
  redirect(`/administration/classes/${parsed.data.id}?updated=1`)
}

export async function toggleClass(formData: FormData) {
  const id = z.string().uuid().safeParse(formData.get('id'))
  const active = z.coerce.boolean().safeParse(formData.get('active'))
  if (!id.success || !active.success) redirect('/administration/classes?error=Paramètres invalides')

  const supabase = await createClient()
  const { error } = await supabase.rpc('set_class_active', {
    p_class_id: id.data,
    p_is_active: active.data,
  })
  if (error) redirect(errUrl('/administration/classes', error.message))

  revalidatePath('/administration/classes')
  revalidatePath('/administration/inscriptions')
  redirect('/administration/classes?updated=1')
}
