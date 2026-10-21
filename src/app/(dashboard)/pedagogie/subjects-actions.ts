'use server'

import { revalidatePath } from 'next/cache'
import { redirect } from 'next/navigation'
import { z } from 'zod'
import { createClient } from '@/lib/supabase/server'

const subjectSchema = z.object({
  id: z.string().uuid().optional(),
  code: z.string().trim().min(1).max(50),
  name: z.string().trim().min(1).max(120),
  domain: z.string().trim().min(1).max(80),
  weeklyHours: z.coerce.number().positive().optional(),
  description: z.string().trim().max(5000).optional(),
})

function errUrl(base: string, error: string) {
  return `${base}?error=${encodeURIComponent(error)}`
}

export async function createSubject(formData: FormData) {
  const parsed = subjectSchema.safeParse({
    code: formData.get('code'),
    name: formData.get('name'),
    domain: formData.get('domain'),
    weeklyHours: formData.get('weeklyHours') || undefined,
    description: formData.get('description') || undefined,
  })
  if (!parsed.success) redirect(errUrl('/pedagogie/matieres/nouveau', 'Données de matière invalides'))

  const supabase = await createClient()
  const { data, error } = await supabase.rpc('create_subject', {
    p_code: parsed.data.code,
    p_name: parsed.data.name,
    p_domain: parsed.data.domain,
    // Legacy catalogue column retained for database compatibility; weighting belongs to each class assignment.
    p_coefficient: 1,
    p_weekly_hours: parsed.data.weeklyHours ?? null,
    p_description: parsed.data.description ?? null,
  })
  if (error) redirect(errUrl('/pedagogie/matieres/nouveau', error.message))

  revalidatePath('/pedagogie/matieres')
  redirect(`/pedagogie/matieres/${data}?created=1`)
}

export async function updateSubject(formData: FormData) {
  const parsed = subjectSchema.required({ id: true }).safeParse({
    id: formData.get('id'),
    code: formData.get('code'),
    name: formData.get('name'),
    domain: formData.get('domain'),
    weeklyHours: formData.get('weeklyHours') || undefined,
    description: formData.get('description') || undefined,
  })
  if (!parsed.success) redirect('/pedagogie/matieres?error=Matière invalide')

  const supabase = await createClient()
  const { error } = await supabase.rpc('update_subject', {
    p_subject_id: parsed.data.id,
    p_code: parsed.data.code,
    p_name: parsed.data.name,
    p_domain: parsed.data.domain,
    // Legacy catalogue column retained for database compatibility; weighting belongs to each class assignment.
    p_coefficient: 1,
    p_weekly_hours: parsed.data.weeklyHours ?? null,
    p_description: parsed.data.description ?? null,
  })
  if (error) redirect(errUrl(`/pedagogie/matieres/${parsed.data.id}`, error.message))

  revalidatePath('/pedagogie/matieres')
  revalidatePath(`/pedagogie/matieres/${parsed.data.id}`)
  revalidatePath('/pedagogie')
  redirect(`/pedagogie/matieres/${parsed.data.id}?updated=1`)
}

export async function toggleSubject(formData: FormData) {
  const id = z.string().uuid().safeParse(formData.get('id'))
  const active = z.coerce.boolean().safeParse(formData.get('active'))
  if (!id.success || !active.success) redirect('/pedagogie/matieres?error=Paramètres invalides')

  const supabase = await createClient()
  const { error } = await supabase.rpc('set_subject_active', {
    p_subject_id: id.data,
    p_is_active: active.data,
  })
  if (error) redirect(errUrl('/pedagogie/matieres', error.message))

  revalidatePath('/pedagogie/matieres')
  revalidatePath(`/pedagogie/matieres/${id.data}`)
  redirect('/pedagogie/matieres?updated=1')
}

const assignmentSchema = z.object({
  schoolYearId: z.string().uuid(),
  classId: z.string().uuid(),
  subjectId: z.string().uuid(),
  coefficientOverride: z.coerce.number().positive(),
  weeklyHoursOverride: z.coerce.number().positive().optional(),
  isRequired: z.coerce.boolean(),
})

export async function assignSubjectToClass(formData: FormData) {
  const parsed = assignmentSchema.safeParse({
    schoolYearId: formData.get('schoolYearId'),
    classId: formData.get('classId'),
    subjectId: formData.get('subjectId'),
    coefficientOverride: formData.get('coefficientOverride'),
    weeklyHoursOverride: formData.get('weeklyHoursOverride') || undefined,
    isRequired: formData.get('isRequired') === 'true',
  })
  if (!parsed.success) redirect(errUrl(`/pedagogie/matieres/${formData.get('subjectId')}`, 'Configuration classe/matière invalide'))

  const supabase = await createClient()
  const { error } = await supabase.rpc('assign_subject_to_class', {
    p_school_year_id: parsed.data.schoolYearId,
    p_class_id: parsed.data.classId,
    p_subject_id: parsed.data.subjectId,
    p_coefficient_override: parsed.data.coefficientOverride ?? null,
    p_weekly_hours_override: parsed.data.weeklyHoursOverride ?? null,
    p_is_required: parsed.data.isRequired,
  })
  if (error) redirect(errUrl(`/pedagogie/matieres/${parsed.data.subjectId}`, error.message))

  revalidatePath(`/pedagogie/matieres/${parsed.data.subjectId}`)
  revalidatePath('/pedagogie/matieres')
  redirect(`/pedagogie/matieres/${parsed.data.subjectId}?assigned=1`)
}

export async function toggleSubjectClassAssignment(formData: FormData) {
  const id = z.string().uuid().safeParse(formData.get('assignmentId'))
  const active = z.coerce.boolean().safeParse(formData.get('active'))
  const subjectId = z.string().uuid().safeParse(formData.get('subjectId'))
  if (!id.success || !active.success || !subjectId.success) redirect('/pedagogie/matieres')

  const supabase = await createClient()
  const { error } = await supabase.rpc('set_subject_class_active', {
    p_assignment_id: id.data,
    p_is_active: active.data,
  })
  if (error) redirect(errUrl(`/pedagogie/matieres/${subjectId.data}`, error.message))

  revalidatePath(`/pedagogie/matieres/${subjectId.data}`)
  redirect(`/pedagogie/matieres/${subjectId.data}?updated=1`)
}
