'use server'

import { revalidatePath } from 'next/cache'
import { redirect } from 'next/navigation'
import { z } from 'zod'
import { createClient } from '@/lib/supabase/server'
import { getCurrentUserContext } from '@/lib/auth/current-user'

const uuid = z.string().uuid()
const day = z.coerce.number().int().min(1).max(7)
const dateString = z.string().regex(/^\d{4}-\d{2}-\d{2}$/)

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
  const context = await getCurrentUserContext()
  const linkedTeacher = context?.profile.id
    ? await supabase.from('employees').select('id,teacher_profiles!inner(employee_id)')
      .eq('user_id', context.profile.id).eq('status', 'active').maybeSingle()
    : { data: null }
  const { data, error } = await supabase.rpc('create_assessment', {
    p_school_year_id: parsed.data.schoolYearId,
    p_period_id: parsed.data.periodId,
    p_class_id: parsed.data.classId,
    p_subject_id: parsed.data.subjectId,
    p_teacher_id: linkedTeacher.data?.id ?? parsed.data.teacherId,
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

const updateAssessmentSchema = assessmentSchema.extend({ id: uuid })

export async function updateAssessment(formData: FormData) {
  const typeRaw = formData.get('assessmentTypeId')
  const parsed = updateAssessmentSchema.safeParse({
    id: formData.get('id'),
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
  if (!parsed.success) redirect(errUrl('/pedagogie/evaluations', 'Données de modification invalides.'))

  const context = await getCurrentUserContext()
  const schoolId = context?.profile.school_id
  if (!schoolId) redirect('/login')
  const supabase = await createClient()
  const { data: current, error: currentError } = await supabase.from('assessments')
    .select('id,is_published,period_id').eq('id', parsed.data.id).eq('school_id', schoolId).maybeSingle()
  if (currentError || !current) redirect(errUrl('/pedagogie/evaluations', currentError?.message ?? 'Évaluation introuvable.'))
  if (current.is_published) redirect(errUrl(`/pedagogie/evaluations/${parsed.data.id}/modifier`, 'Dépubliez l’évaluation avant de modifier ses informations.'))
  const { data: period } = await supabase.from('academic_periods').select('is_closed').eq('id', parsed.data.periodId).maybeSingle()
  if (period?.is_closed) redirect(errUrl(`/pedagogie/evaluations/${parsed.data.id}/modifier`, 'La période choisie est clôturée.'))

  const { data, error } = await supabase.from('assessments').update({
    school_year_id: parsed.data.schoolYearId,
    period_id: parsed.data.periodId,
    class_id: parsed.data.classId,
    subject_id: parsed.data.subjectId,
    teacher_id: parsed.data.teacherId,
    assessment_type_id: parsed.data.assessmentTypeId ?? null,
    title: parsed.data.title,
    assessment_date: parsed.data.date,
    max_score: parsed.data.maxScore,
  }).eq('id', parsed.data.id).eq('school_id', schoolId).select('id').maybeSingle()
  if (error) redirect(errUrl(`/pedagogie/evaluations/${parsed.data.id}/modifier`, error.message))
  if (!data) redirect(errUrl(`/pedagogie/evaluations/${parsed.data.id}/modifier`, 'Modification refusée ou évaluation introuvable.'))

  revalidatePath('/pedagogie/evaluations')
  revalidatePath(`/pedagogie/evaluations/${parsed.data.id}/notes`)
  revalidatePath('/pedagogie/bulletins')
  redirect('/pedagogie/evaluations?updated=1')
}

export async function deleteAssessment(formData: FormData) {
  const id = uuid.safeParse(formData.get('id'))
  if (!id.success) redirect('/pedagogie/evaluations?error=Évaluation invalide.')
  const context = await getCurrentUserContext()
  const schoolId = context?.profile.school_id
  if (!schoolId) redirect('/login')
  const supabase = await createClient()
  const { data, error } = await supabase.from('assessments').delete().eq('id', id.data).eq('school_id', schoolId).select('id').maybeSingle()
  if (error) redirect(errUrl('/pedagogie/evaluations', error.message))
  if (!data) redirect(errUrl('/pedagogie/evaluations', 'Suppression refusée ou évaluation introuvable.'))
  revalidatePath('/pedagogie/evaluations')
  revalidatePath(`/pedagogie/evaluations/${id.data}/notes`)
  revalidatePath('/pedagogie/bulletins')
  redirect('/pedagogie/evaluations?deleted=1')
}

const academicPeriodSchema = z.object({
  schoolYearId: uuid,
  name: z.string().trim().min(1).max(100),
  code: z.string().trim().min(1).max(30).transform(value => value.toUpperCase()),
  startDate: dateString,
  endDate: dateString,
  sequenceNo: z.preprocess(value => value === '' || value == null ? undefined : value, z.coerce.number().int().positive().optional()),
}).refine(value => value.endDate >= value.startDate, {
  path: ['endDate'],
  message: 'La date de fin doit être postérieure ou égale à la date de début.',
})

export async function createAcademicPeriod(formData: FormData) {
  const parsed = academicPeriodSchema.safeParse({
    schoolYearId: formData.get('schoolYearId'),
    name: formData.get('name'),
    code: formData.get('code'),
    startDate: formData.get('startDate'),
    endDate: formData.get('endDate'),
    sequenceNo: formData.get('sequenceNo'),
  })
  if (!parsed.success) redirect(errUrl('/pedagogie/evaluations/nouveau', parsed.error.issues[0]?.message ?? 'Période invalide.'))

  const context = await getCurrentUserContext()
  const schoolId = context?.profile.school_id
  if (!schoolId) redirect('/login')

  const supabase = await createClient()
  const { data: year, error: yearError } = await supabase.from('school_years')
    .select('id,start_date,end_date').eq('id', parsed.data.schoolYearId).eq('school_id', schoolId).maybeSingle()
  if (yearError || !year) redirect(errUrl('/pedagogie/evaluations/nouveau', 'Année scolaire introuvable.'))
  if (parsed.data.startDate < year.start_date || parsed.data.endDate > year.end_date) {
    redirect(errUrl('/pedagogie/evaluations/nouveau', 'Les dates de la période doivent être comprises dans l’année scolaire.'))
  }

  const { data: overlap, error: overlapError } = await supabase.from('academic_periods')
    .select('id').eq('school_year_id', year.id)
    .lte('start_date', parsed.data.endDate).gte('end_date', parsed.data.startDate).limit(1).maybeSingle()
  if (overlapError) redirect(errUrl('/pedagogie/evaluations/nouveau', overlapError.message))
  if (overlap) redirect(errUrl('/pedagogie/evaluations/nouveau', 'Les dates chevauchent une période déjà créée.'))

  const { data: lastPeriod, error: lastPeriodError } = await supabase.from('academic_periods')
    .select('sequence_no').eq('school_year_id', year.id).order('sequence_no', { ascending: false }).limit(1).maybeSingle()
  if (lastPeriodError) redirect(errUrl('/pedagogie/evaluations/nouveau', lastPeriodError.message))

  const { error } = await supabase.from('academic_periods').insert({
    school_year_id: year.id,
    name: parsed.data.name,
    code: parsed.data.code,
    start_date: parsed.data.startDate,
    end_date: parsed.data.endDate,
    sequence_no: parsed.data.sequenceNo ?? (lastPeriod?.sequence_no ?? 0) + 1,
  })
  if (error) redirect(errUrl('/pedagogie/evaluations/nouveau', error.message))

  revalidatePath('/pedagogie/evaluations/nouveau')
  revalidatePath('/pedagogie/bulletins')
  redirect('/pedagogie/evaluations/nouveau?periodCreated=1')
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
  studentIds: z.array(uuid).min(1).max(500),
  schoolYearId: uuid,
  periodId: uuid,
  classId: uuid,
})

export async function generateReportCards(formData: FormData) {
  const parsed = bulletinSchema.safeParse({
    studentIds: formData.getAll('studentIds'),
    schoolYearId: formData.get('schoolYearId'),
    periodId: formData.get('periodId'),
    classId: formData.get('classId'),
  })
  if (!parsed.success) redirect(errUrl('/pedagogie/bulletins', 'Paramètres de bulletin invalides.'))
  const supabase = await createClient()
  const context = await getCurrentUserContext()
  const schoolId = context?.profile.school_id
  if (!schoolId) redirect(errUrl('/pedagogie/bulletins', 'Contexte scolaire introuvable.'))
  const studentIds = [...new Set(parsed.data.studentIds)]
  const { data: enrollments, error: enrollmentError } = await supabase.from('enrollments').select('student_id').eq('school_id', schoolId).eq('school_year_id', parsed.data.schoolYearId).eq('class_id', parsed.data.classId).eq('status', 'enrolled').in('student_id', studentIds)
  if (enrollmentError) redirect(errUrl('/pedagogie/bulletins', enrollmentError.message))
  const eligible = new Set((enrollments ?? []).map((row) => row.student_id))
  if (eligible.size !== studentIds.length) redirect(errUrl('/pedagogie/bulletins', 'La sélection contient un élève qui n’est pas inscrit dans cette classe pour cette année.'))

  let generated = 0
  let failed = 0
  let firstError = ''
  for (const studentId of studentIds) {
    const { error } = await supabase.rpc('generate_report_card_draft', {
      p_student_id: studentId,
      p_school_year_id: parsed.data.schoolYearId,
      p_period_id: parsed.data.periodId,
    })
    if (error) {
      failed += 1
      firstError ||= error.message
    } else generated += 1
  }
  if (!generated) redirect(errUrl('/pedagogie/bulletins', firstError === 'NO_PUBLISHED_GRADES' ? 'Aucune note publiée pour les élèves sélectionnés et cette période. Publiez les notes des évaluations avant de générer les bulletins.' : firstError || 'Aucun bulletin n’a pu être généré.'))
  revalidatePath('/pedagogie/bulletins')
  redirect(`/pedagogie/bulletins?generated=${generated}&failed=${failed}`)
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
