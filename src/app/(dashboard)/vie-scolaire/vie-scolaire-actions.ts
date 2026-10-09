'use server'

import { revalidatePath } from 'next/cache'
import { redirect } from 'next/navigation'
import { z } from 'zod'
import { createClient } from '@/lib/supabase/server'

const uuid = z.string().uuid()
const date = z.string().regex(/^\d{4}-\d{2}-\d{2}$/)
const time = z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/)

function errUrl(base: string, error: string) {
  return `${base}?error=${encodeURIComponent(error)}`
}

const attendanceSessionSchema = z.object({
  schoolYearId: uuid,
  classId: uuid,
  subjectId: z.string().uuid().optional(),
  employeeId: z.string().uuid().optional(),
  sessionDate: date,
  startTime: z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/).optional(),
  endTime: z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/).optional(),
  activityType: z.string().trim().min(1).max(80),
  notes: z.string().trim().max(500).optional(),
})

export async function createAttendanceSession(formData: FormData) {
  const parsed = attendanceSessionSchema.safeParse({
    schoolYearId: formData.get('schoolYearId'),
    classId: formData.get('classId'),
    subjectId: formData.get('subjectId') || undefined,
    employeeId: formData.get('employeeId') || undefined,
    sessionDate: formData.get('sessionDate'),
    startTime: formData.get('startTime') || undefined,
    endTime: formData.get('endTime') || undefined,
    activityType: formData.get('activityType') || 'class',
    notes: formData.get('notes') || undefined,
  })
  if (!parsed.success) redirect(errUrl('/vie-scolaire/presences/nouveau', 'Données de séance invalides.'))

  const supabase = await createClient()
  const { data, error } = await supabase.rpc('create_attendance_session', {
    p_school_year_id: parsed.data.schoolYearId,
    p_class_id: parsed.data.classId,
    p_subject_id: parsed.data.subjectId ?? null,
    p_employee_id: parsed.data.employeeId ?? null,
    p_session_date: parsed.data.sessionDate,
    p_start_time: parsed.data.startTime ?? null,
    p_end_time: parsed.data.endTime ?? null,
    p_activity_type: parsed.data.activityType,
    p_notes: parsed.data.notes ?? null,
  })
  if (error) redirect(errUrl('/vie-scolaire/presences/nouveau', error.message))
  revalidatePath('/vie-scolaire')
  revalidatePath('/vie-scolaire/presences')
  redirect(`/vie-scolaire/presences/${data}`)
}

const attendanceStatus = z.enum(['present', 'absent', 'late', 'excused'])

export async function saveAttendanceRecords(formData: FormData) {
  const sessionId = uuid.safeParse(formData.get('sessionId'))
  if (!sessionId.success) redirect('/vie-scolaire/presences?error=Séance invalide')

  const rows: Array<{ student_id: string; status: string; arrival_time?: string | null; departure_time?: string | null; reason?: string | null }> = []
  for (const [key, value] of formData.entries()) {
    const match = /^status_(.+)$/.exec(key)
    if (!match) continue
    const studentId = match[1]
    if (!uuid.safeParse(studentId).success) continue
    const status = attendanceStatus.safeParse(String(value))
    if (!status.success) redirect(errUrl(`/vie-scolaire/presences/${sessionId.data}`, 'Statut de présence invalide.'))
    const arrivalRaw = String(formData.get(`arrival_${studentId}`) ?? '').trim()
    const departureRaw = String(formData.get(`departure_${studentId}`) ?? '').trim()
    const reasonRaw = String(formData.get(`reason_${studentId}`) ?? '').trim()
    if (arrivalRaw && !time.safeParse(arrivalRaw).success) redirect(errUrl(`/vie-scolaire/presences/${sessionId.data}`, 'Heure d’arrivée invalide.'))
    if (departureRaw && !time.safeParse(departureRaw).success) redirect(errUrl(`/vie-scolaire/presences/${sessionId.data}`, 'Heure de départ invalide.'))
    rows.push({ student_id: studentId, status: status.data, arrival_time: arrivalRaw || null, departure_time: departureRaw || null, reason: reasonRaw || null })
  }
  if (!rows.length) redirect(errUrl(`/vie-scolaire/presences/${sessionId.data}`, 'Aucun élève à enregistrer.'))

  const supabase = await createClient()
  const { error } = await supabase.rpc('save_attendance_records', {
    p_session_id: sessionId.data,
    p_records: rows,
  })
  if (error) redirect(errUrl(`/vie-scolaire/presences/${sessionId.data}`, error.message))
  revalidatePath('/vie-scolaire')
  revalidatePath('/vie-scolaire/presences')
  revalidatePath(`/vie-scolaire/presences/${sessionId.data}`)
  redirect(`/vie-scolaire/presences/${sessionId.data}?saved=1`)
}

export async function reviewAbsenceJustification(formData: FormData) {
  const id = uuid.safeParse(formData.get('id'))
  const status = z.enum(['approved', 'rejected', 'cancelled']).safeParse(String(formData.get('status')))
  if (!id.success || !status.success) redirect('/vie-scolaire/justificatifs?error=Paramètres invalides')
  const supabase = await createClient()
  const { error } = await supabase.rpc('review_absence_justification', { p_justification_id: id.data, p_status: status.data })
  if (error) redirect(errUrl('/vie-scolaire/justificatifs', error.message))
  revalidatePath('/vie-scolaire/justificatifs')
  revalidatePath('/vie-scolaire')
  redirect('/vie-scolaire/justificatifs?updated=1')
}

const categorySchema = z.object({
  code: z.string().trim().min(1).max(50),
  name: z.string().trim().min(1).max(120),
  severity: z.coerce.number().int().min(1).max(5),
})

export async function createDisciplineCategory(formData: FormData) {
  const parsed = categorySchema.safeParse({
    code: formData.get('code'),
    name: formData.get('name'),
    severity: formData.get('severity'),
  })
  if (!parsed.success) redirect(errUrl('/vie-scolaire/discipline/categories', 'Catégorie de discipline invalide.'))
  const supabase = await createClient()
  const { data: school } = await supabase.from('users').select('school_id').eq('id', (await supabase.auth.getClaims()).data?.claims?.sub ?? '').single()
  if (!school?.school_id) redirect(errUrl('/vie-scolaire/discipline/categories', 'École introuvable.'))
  const { error } = await supabase.from('discipline_categories').insert({ school_id: school.school_id, code: parsed.data.code, name: parsed.data.name, severity: parsed.data.severity })
  if (error) redirect(errUrl('/vie-scolaire/discipline/categories', error.message))
  revalidatePath('/vie-scolaire/discipline/categories')
  revalidatePath('/vie-scolaire/discipline')
  redirect('/vie-scolaire/discipline/categories?created=1')
}

const disciplineSchema = z.object({
  studentId: uuid,
  categoryId: z.string().uuid().optional(),
  eventDate: date,
  eventTime: z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/).optional(),
  eventType: z.string().trim().min(1).max(120),
  description: z.string().trim().min(1).max(2000),
  actionTaken: z.string().trim().max(2000).optional(),
  responsibleEmployeeId: z.string().uuid().optional(),
})

export async function createDisciplineEvent(formData: FormData) {
  const parsed = disciplineSchema.safeParse({
    studentId: formData.get('studentId'),
    categoryId: formData.get('categoryId') || undefined,
    eventDate: formData.get('eventDate'),
    eventTime: formData.get('eventTime') || undefined,
    eventType: formData.get('eventType'),
    description: formData.get('description'),
    actionTaken: formData.get('actionTaken') || undefined,
    responsibleEmployeeId: formData.get('responsibleEmployeeId') || undefined,
  })
  if (!parsed.success) redirect(errUrl('/vie-scolaire/discipline', 'Événement disciplinaire invalide.'))
  const supabase = await createClient()
  const { data, error } = await supabase.rpc('create_discipline_event', {
    p_student_id: parsed.data.studentId,
    p_category_id: parsed.data.categoryId ?? null,
    p_event_date: parsed.data.eventDate,
    p_event_time: parsed.data.eventTime ?? null,
    p_event_type: parsed.data.eventType,
    p_description: parsed.data.description,
    p_action_taken: parsed.data.actionTaken ?? null,
    p_responsible_employee_id: parsed.data.responsibleEmployeeId ?? null,
  })
  if (error) redirect(errUrl('/vie-scolaire/discipline', error.message))
  revalidatePath('/vie-scolaire')
  revalidatePath('/vie-scolaire/discipline')
  redirect(`/vie-scolaire/discipline?created=${data}`)
}

const followupSchema = z.object({
  studentId: uuid,
  followupDate: date,
  category: z.string().trim().min(1).max(120),
  observation: z.string().trim().min(1).max(3000),
  actionPlan: z.string().trim().max(3000).optional(),
  nextReviewDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
  responsibleEmployeeId: z.string().uuid().optional(),
})

export async function createStudentFollowup(formData: FormData) {
  const parsed = followupSchema.safeParse({
    studentId: formData.get('studentId'),
    followupDate: formData.get('followupDate'),
    category: formData.get('category'),
    observation: formData.get('observation'),
    actionPlan: formData.get('actionPlan') || undefined,
    nextReviewDate: formData.get('nextReviewDate') || undefined,
    responsibleEmployeeId: formData.get('responsibleEmployeeId') || undefined,
  })
  if (!parsed.success) redirect(errUrl('/vie-scolaire/suivi-educatif', 'Suivi éducatif invalide.'))
  const supabase = await createClient()
  const { data, error } = await supabase.rpc('create_student_followup', {
    p_student_id: parsed.data.studentId,
    p_followup_date: parsed.data.followupDate,
    p_category: parsed.data.category,
    p_observation: parsed.data.observation,
    p_action_plan: parsed.data.actionPlan ?? null,
    p_next_review_date: parsed.data.nextReviewDate ?? null,
    p_responsible_employee_id: parsed.data.responsibleEmployeeId ?? null,
  })
  if (error) redirect(errUrl('/vie-scolaire/suivi-educatif', error.message))
  revalidatePath('/vie-scolaire')
  revalidatePath('/vie-scolaire/suivi-educatif')
  redirect(`/vie-scolaire/suivi-educatif?created=${data}`)
}

export async function updateFollowupStatus(formData: FormData) {
  const id = uuid.safeParse(formData.get('id'))
  const status = z.enum(['open', 'in_progress', 'closed', 'cancelled']).safeParse(String(formData.get('status')))
  if (!id.success || !status.success) redirect('/vie-scolaire/suivi-educatif?error=Paramètres invalides')
  const supabase = await createClient()
  const { error } = await supabase.from('student_followups').update({ status: status.data }).eq('id', id.data)
  if (error) redirect(errUrl('/vie-scolaire/suivi-educatif', error.message))
  revalidatePath('/vie-scolaire/suivi-educatif')
  redirect('/vie-scolaire/suivi-educatif?updated=1')
}

const rewardSchema = z.object({
  studentId: uuid,
  rewardDate: date,
  title: z.string().trim().min(1).max(160),
  description: z.string().trim().max(2000).optional(),
  category: z.string().trim().max(120).optional(),
})

export async function createStudentReward(formData: FormData) {
  const parsed = rewardSchema.safeParse({
    studentId: formData.get('studentId'),
    rewardDate: formData.get('rewardDate'),
    title: formData.get('title'),
    description: formData.get('description') || undefined,
    category: formData.get('category') || undefined,
  })
  if (!parsed.success) redirect(errUrl('/vie-scolaire/recompenses', 'Récompense invalide.'))
  const supabase = await createClient()
  const { data, error } = await supabase.rpc('create_student_reward', {
    p_student_id: parsed.data.studentId,
    p_reward_date: parsed.data.rewardDate,
    p_title: parsed.data.title,
    p_description: parsed.data.description ?? null,
    p_category: parsed.data.category ?? null,
  })
  if (error) redirect(errUrl('/vie-scolaire/recompenses', error.message))
  revalidatePath('/vie-scolaire')
  revalidatePath('/vie-scolaire/recompenses')
  redirect(`/vie-scolaire/recompenses?created=${data}`)
}
