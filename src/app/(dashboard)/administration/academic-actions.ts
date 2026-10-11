'use server'

import { revalidatePath } from 'next/cache'
import { redirect } from 'next/navigation'
import { z } from 'zod'
import { createClient } from '@/lib/supabase/server'
import { getCurrentUserContext } from '@/lib/auth/current-user'

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

const dateOnlySchema = z.string().regex(/^\d{4}-\d{2}-\d{2}$/).refine((value) => {
  const parsed = new Date(`${value}T00:00:00.000Z`)
  return Number.isFinite(parsed.getTime()) && parsed.toISOString().slice(0, 10) === value
}, 'Date invalide.')

const schoolYearSchema = z.object({
  name: z.string().trim().min(1, 'Le nom de l’année scolaire est obligatoire.').max(100),
  startDate: dateOnlySchema,
  endDate: dateOnlySchema,
  isCurrent: z.enum(['true', 'false']),
  returnTo: z.enum(['/administration/classes', '/administration/classes/nouveau']),
}).refine((value) => value.endDate >= value.startDate, {
  path: ['endDate'],
  message: 'La date de fin doit être postérieure ou égale à la date de début.',
})

function errUrl(base: string, error: string): string {
  return `${base}?error=${encodeURIComponent(error)}`
}

export async function createSchoolYear(formData: FormData) {
  const context = await getCurrentUserContext()
  const schoolId = context?.profile.school_id
  if (!schoolId) redirect('/login')

  const returnTo = formData.get('returnTo') === '/administration/classes/nouveau'
    ? '/administration/classes/nouveau'
    : '/administration/classes'
  const parsed = schoolYearSchema.safeParse({
    name: formData.get('name'),
    startDate: formData.get('startDate'),
    endDate: formData.get('endDate'),
    isCurrent: formData.get('isCurrent') === 'on' ? 'true' : 'false',
    returnTo,
  })

  if (!parsed.success) {
    const message = parsed.error.issues[0]?.message ?? 'Vérifiez les champs de l’année scolaire.'
    redirect(`${errUrl('/administration/classes/annee-scolaire/nouvelle', message)}&returnTo=${encodeURIComponent(returnTo)}`)
  }

  const supabase = await createClient()
  const { data, error } = await supabase
    .from('school_years')
    .insert({
      school_id: schoolId,
      name: parsed.data.name,
      start_date: parsed.data.startDate,
      end_date: parsed.data.endDate,
      is_current: parsed.data.isCurrent === 'true',
    })
    .select('id')
    .single()

  if (error || !data) {
    const message = error?.code === '23505'
      ? 'Une année scolaire porte déjà ce nom.'
      : error?.message ?? 'La création de l’année scolaire a échoué.'
    redirect(`${errUrl('/administration/classes/annee-scolaire/nouvelle', message)}&returnTo=${encodeURIComponent(returnTo)}`)
  }

  revalidatePath('/administration/classes')
  revalidatePath('/administration/classes/nouveau')
  revalidatePath('/administration/niveaux')
  redirect(`${parsed.data.returnTo}?year=${encodeURIComponent(data.id)}&createdYear=1`)
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
