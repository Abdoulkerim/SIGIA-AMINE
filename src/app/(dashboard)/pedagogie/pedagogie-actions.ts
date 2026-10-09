'use server'

import { revalidatePath } from 'next/cache'
import { redirect } from 'next/navigation'
import { z } from 'zod'
import { createClient } from '@/lib/supabase/server'

const uuid = z.string().uuid()
const day = z.coerce.number().int().min(1).max(7)

function errUrl(base: string, error: string) {
  return `${base}?error=${encodeURIComponent(error)}`
}

const timetableSchema = z.object({
  schoolYearId: uuid,
  classId: uuid,
  subjectId: uuid,
  teacherId: uuid,
  dayOfWeek: day,
  startTime: z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/),
  endTime: z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/),
  roomName: z.string().trim().max(120).optional(),
  validFrom: z.string().optional(),
  validTo: z.string().optional(),
})

export async function createTimetableSlot(formData: FormData) {
  const parsed = timetableSchema.safeParse({
    schoolYearId: formData.get('schoolYearId'),
    classId: formData.get('classId'),
    subjectId: formData.get('subjectId'),
    teacherId: formData.get('teacherId'),
    dayOfWeek: formData.get('dayOfWeek'),
    startTime: formData.get('startTime'),
    endTime: formData.get('endTime'),
    roomName: formData.get('roomName') || undefined,
    validFrom: formData.get('validFrom') || undefined,
    validTo: formData.get('validTo') || undefined,
  })
  if (!parsed.success) redirect(errUrl('/pedagogie/emploi-du-temps/nouveau', 'Créneau invalide.'))

  const supabase = await createClient()
  const { data, error } = await supabase.rpc('create_timetable_slot', {
    p_school_year_id: parsed.data.schoolYearId,
    p_class_id: parsed.data.classId,
    p_subject_id: parsed.data.subjectId,
    p_teacher_id: parsed.data.teacherId,
    p_day_of_week: parsed.data.dayOfWeek,
    p_start_time: parsed.data.startTime,
    p_end_time: parsed.data.endTime,
    p_room_name: parsed.data.roomName ?? null,
    p_valid_from: parsed.data.validFrom || null,
    p_valid_to: parsed.data.validTo || null,
  })
  if (error) redirect(errUrl('/pedagogie/emploi-du-temps/nouveau', error.message))
  revalidatePath('/pedagogie')
  revalidatePath('/pedagogie/emploi-du-temps')
  redirect(`/pedagogie/emploi-du-temps?created=${data}`)
}

export async function toggleTimetableSlot(formData: FormData) {
  const id = uuid.safeParse(formData.get('id'))
  const active = z.enum(['true','false']).safeParse(String(formData.get('active')))
  if (!id.success || !active.success) redirect('/pedagogie/emploi-du-temps?error=Paramètres invalides')
  const supabase = await createClient()
  const { error } = await supabase.rpc('set_timetable_slot_active', {
    p_slot_id: id.data,
    p_is_active: active.data === 'true',
  })
  if (error) redirect(errUrl('/pedagogie/emploi-du-temps', error.message))
  revalidatePath('/pedagogie/emploi-du-temps')
  redirect('/pedagogie/emploi-du-temps?updated=1')
}

const typeSchema = z.object({
  code: z.string().trim().min(1).max(40),
  name: z.string().trim().min(1).max(120),
})

export async function createAssessmentType(formData: FormData) {
  const parsed = typeSchema.safeParse({
    code: formData.get('code'),
    name: formData.get('name'),
  })
  if (!parsed.success) redirect(errUrl('/pedagogie/types-evaluations', 'Type d’évaluation invalide.'))
  const supabase = await createClient()
  const { data, error } = await supabase.rpc('create_assessment_type', {
    p_code: parsed.data.code,
    p_name: parsed.data.name,
  })
  if (error) redirect(errUrl('/pedagogie/types-evaluations', error.message))
  revalidatePath('/pedagogie/types-evaluations')
  redirect(`/pedagogie/types-evaluations?created=${data}`)
}

const assessmentSchema = z.object({
  schoolYearId: uuid,
  periodId: uuid,
  classId: uuid,
  subjectId: uuid,
  teacherId: uuid,
  assessmentTypeId: uuid.optional(),
  title: z.string().trim().min(1).max(200),
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  maxScore: z.coerce.number().positive(),
})

export async function createAssessment(formData: FormData) {
  const typeRaw = formData.get('assessmentTypeId')
  const parsed = assessmentSchema.safeParse({
    schoolYearId: formData.get('schoolYearId'),
    periodId: formData.get('periodId'),
    classId: formData.get('classId'),
    subjectId: formData.get('subjectId'),
    teacherId: formData.get('teacherId'),
    assessmentTypeId: typeRaw ? typeRaw : undefined,
    title: formData.get('title'),
    date: formData.get('date'),
    maxScore: formData.get('maxScore'),
  })
  if (!parsed.success) redirect(errUrl('/pedagogie/evaluations/nouveau', 'Données d’évaluation invalides.'))
  const supabase = await createClient()
  const { data, error } = await supabase.rpc('create_assessment', {
    p_school_year_id: parsed.data.schoolYearId,
    p_period_id: parsed.data.periodId,
    p_class_id: parsed.data.classId,
    p_subject_id: parsed.data.subjectId,
    p_teacher_id: parsed.data.teacherId,
    p_assessment_type_id: parsed.data.assessmentTypeId ?? null,
    p_title: parsed.data.title,
    p_assessment_date: parsed.data.date,
    p_max_score: parsed.data.maxScore,
  })
  if (error) redirect(errUrl('/pedagogie/evaluations/nouveau', error.message))
  revalidatePath('/pedagogie/evaluations')
  revalidatePath('/pedagogie')
  redirect(`/pedagogie/evaluations/${data}/notes?created=1`)
}

export async function publishAssessment(formData: FormData) {
  const id = uuid.safeParse(formData.get('id'))
  if (!id.success) redirect('/pedagogie/evaluations?error=Évaluation invalide')
  const supabase = await createClient()
  const { error } = await supabase.rpc('set_assessment_published', {
    p_assessment_id: id.data,
    p_is_published: true,
  })
  if (error) redirect(errUrl('/pedagogie/evaluations', error.message))
  revalidatePath('/pedagogie/evaluations')
  revalidatePath(`/pedagogie/evaluations/${id.data}/notes`)
  redirect('/pedagogie/evaluations?published=1')
}

export async function saveAssessmentGradesFromForm(formData: FormData) {
  const assessmentId = uuid.safeParse(formData.get('assessmentId'))
  if (!assessmentId.success) redirect('/pedagogie/evaluations?error=Évaluation invalide')
  const rows: Array<{ student_id: string; score: number; observation: string | null }> = []
  for (const [key, value] of formData.entries()) {
    const match = /^score_(.+)$/.exec(key)
    if (!match) continue
    const studentId = match[1]
    if (!uuid.safeParse(studentId).success) continue
    const raw = String(value).trim()
    if (!raw) continue
    const score = Number(raw)
    if (!Number.isFinite(score)) redirect(errUrl(`/pedagogie/evaluations/${assessmentId.data}/notes`, 'Une note saisie est invalide.'))
    rows.push({
      student_id: studentId,
      score,
      observation: formData.get(`observation_${studentId}`) ? String(formData.get(`observation_${studentId}`)).trim() : null,
    })
  }
  if (!rows.length) redirect(errUrl(`/pedagogie/evaluations/${assessmentId.data}/notes`, 'Aucune note à enregistrer.'))
  const supabase = await createClient()
  const { error } = await supabase.rpc('save_assessment_grades', {
    p_assessment_id: assessmentId.data,
    p_grades: rows,
  })
  if (error) redirect(errUrl(`/pedagogie/evaluations/${assessmentId.data}/notes`, error.message))
  revalidatePath(`/pedagogie/evaluations/${assessmentId.data}/notes`)
  revalidatePath('/pedagogie/evaluations')
  redirect(`/pedagogie/evaluations/${assessmentId.data}/notes?saved=1`)
}

const bulletinSchema = z.object({
  studentId: uuid,
  schoolYearId: uuid,
  periodId: uuid,
})

export async function generateReportCard(formData: FormData) {
  const parsed = bulletinSchema.safeParse({
    studentId: formData.get('studentId'),
    schoolYearId: formData.get('schoolYearId'),
    periodId: formData.get('periodId'),
  })
  if (!parsed.success) redirect(errUrl('/pedagogie/bulletins', 'Paramètres de bulletin invalides.'))
  const supabase = await createClient()
  const { data, error } = await supabase.rpc('generate_report_card_draft', {
    p_student_id: parsed.data.studentId,
    p_school_year_id: parsed.data.schoolYearId,
    p_period_id: parsed.data.periodId,
  })
  if (error) redirect(errUrl('/pedagogie/bulletins', error.message))
  revalidatePath('/pedagogie/bulletins')
  redirect(`/pedagogie/bulletins/${data}?generated=1`)
}

export async function publishReportCard(formData: FormData) {
  const id = uuid.safeParse(formData.get('id'))
  if (!id.success) redirect('/pedagogie/bulletins?error=Bulletin invalide')
  const supabase = await createClient()
  const { error } = await supabase.rpc('publish_report_card', { p_report_card_id: id.data })
  if (error) redirect(errUrl(`/pedagogie/bulletins/${id.data}`, error.message))
  revalidatePath('/pedagogie/bulletins')
  revalidatePath(`/pedagogie/bulletins/${id.data}`)
  redirect(`/pedagogie/bulletins/${id.data}?published=1`)
}
