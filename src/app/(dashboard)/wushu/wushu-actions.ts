"use server"

import { revalidatePath } from 'next/cache'
import { redirect } from 'next/navigation'
import { z } from 'zod'
import { createClient } from '@/lib/supabase/server'

const uuid = z.string().uuid()
const date = z.string().regex(/^\d{4}-\d{2}-\d{2}$/)
const num = z.coerce.number()

function fail(path: string, message: string): never {
  redirect(`${path}?error=${encodeURIComponent(message)}`)
}

export async function createWushuGroup(formData: FormData) {
  const code = z.string().trim().max(60).optional().safeParse(formData.get('code') || undefined)
  const name = z.string().trim().min(1).max(160).safeParse(formData.get('name'))
  const level = z.string().trim().max(120).optional().safeParse(formData.get('level') || undefined)
  const coach = z.string().uuid().optional().safeParse(formData.get('coachEmployeeId') || undefined)
  if (![code,name,level,coach].every(x => x.success)) fail('/wushu/groupes','Données du groupe invalides.')
  const supabase = await createClient()
  const { error } = await supabase.rpc('create_wushu_group', { p_code: code.data ?? null, p_name: name.data, p_level: level.data ?? null, p_coach_employee_id: coach.data ?? null, p_schedule: {} })
  if (error) fail('/wushu/groupes', error.message)
  revalidatePath('/wushu')
  revalidatePath('/wushu/groupes')
  redirect('/wushu/groupes?created=1')
}

export async function assignStudentWushu(formData: FormData) {
  const studentId = uuid.safeParse(formData.get('studentId'))
  const groupId = uuid.safeParse(formData.get('groupId'))
  const grade = z.string().trim().max(120).optional().safeParse(formData.get('currentGrade') || undefined)
  const startDate = date.optional().safeParse(formData.get('startDate') || undefined)
  const status = z.enum(['active','paused','completed','inactive']).safeParse(formData.get('status') || 'active')
  const progress = num.min(0).max(100).safeParse(formData.get('progress') || 0)
  const notes = z.string().trim().max(1200).optional().safeParse(formData.get('notes') || undefined)
  if (![studentId,groupId,grade,startDate,status,progress,notes].every(x => x.success)) fail('/wushu/eleves','Profil Wushu invalide.')
  const supabase = await createClient()
  const { error } = await supabase.rpc('assign_student_wushu', { p_student_id: studentId.data, p_group_id: groupId.data, p_current_grade: grade.data ?? null, p_start_date: startDate.data || null, p_status: status.data, p_progress: progress.data, p_notes: notes.data ?? null })
  if (error) fail('/wushu/eleves', error.message)
  revalidatePath('/wushu')
  revalidatePath('/wushu/eleves')
  redirect('/wushu/eleves?assigned=1')
}

export async function createWushuSession(formData: FormData) {
  const groupId = uuid.safeParse(formData.get('groupId'))
  const sessionDate = date.safeParse(formData.get('sessionDate'))
  const type = z.enum(['training','technique','exam_preparation','competition_preparation','other']).safeParse(formData.get('sessionType'))
  const topic = z.string().trim().max(300).optional().safeParse(formData.get('topic') || undefined)
  const coach = uuid.optional().safeParse(formData.get('coachEmployeeId') || undefined)
  const notes = z.string().trim().max(2000).optional().safeParse(formData.get('notes') || undefined)
  const progress = num.min(0).max(100).optional().safeParse(formData.get('progressAfter') || undefined)
  if (![groupId,sessionDate,type,topic,coach,notes,progress].every(x => x.success)) fail('/wushu/entrainements','Séance invalide.')
  const supabase = await createClient()
  const { error } = await supabase.rpc('create_wushu_session', { p_group_id: groupId.data, p_session_date: sessionDate.data, p_session_type: type.data, p_topic: topic.data ?? null, p_coach_employee_id: coach.data ?? null, p_notes: notes.data ?? null, p_progress_after: progress.data ?? null, p_is_published: false })
  if (error) fail('/wushu/entrainements', error.message)
  revalidatePath('/wushu')
  revalidatePath('/wushu/entrainements')
  redirect('/wushu/entrainements?created=1')
}

export async function recordWushuAttendance(formData: FormData) {
  const sessionId = uuid.safeParse(formData.get('sessionId'))
  const studentId = uuid.safeParse(formData.get('studentId'))
  const status = z.enum(['present','absent','late','excused']).safeParse(formData.get('status'))
  if (![sessionId,studentId,status].every(x => x.success)) fail('/wushu/presences','Présence Wushu invalide.')
  const supabase = await createClient()
  const { error } = await supabase.rpc('record_wushu_attendance', { p_session_id: sessionId.data, p_student_id: studentId.data, p_status: status.data })
  if (error) fail('/wushu/presences', error.message)
  revalidatePath('/wushu/presences')
  redirect('/wushu/presences?ok=1')
}

export async function createWushuEvaluation(formData: FormData) {
  const studentId = uuid.safeParse(formData.get('studentId'))
  const evaluationDate = date.safeParse(formData.get('evaluationDate'))
  const evaluationType = z.string().trim().min(1).max(160).safeParse(formData.get('evaluationType'))
  const score = num.min(0).optional().safeParse(formData.get('score') || undefined)
  const maxScore = num.min(0.01).optional().safeParse(formData.get('maxScore') || undefined)
  const grade = z.string().trim().max(120).optional().safeParse(formData.get('gradeAwarded') || undefined)
  const skillArea = z.string().trim().max(160).optional().safeParse(formData.get('skillArea') || undefined)
  const observation = z.string().trim().max(2000).optional().safeParse(formData.get('observation') || undefined)
  const evaluator = uuid.optional().safeParse(formData.get('evaluatorId') || undefined)
  if (![studentId,evaluationDate,evaluationType,score,maxScore,grade,skillArea,observation,evaluator].every(x => x.success)) fail('/wushu/evaluations','Évaluation Wushu invalide.')
  const supabase = await createClient()
  const { error } = await supabase.rpc('create_wushu_evaluation', { p_student_id: studentId.data, p_evaluation_date: evaluationDate.data, p_evaluation_type: evaluationType.data, p_score: score.data ?? null, p_max_score: maxScore.data ?? null, p_grade_awarded: grade.data ?? null, p_skill_area: skillArea.data ?? null, p_observation: observation.data ?? null, p_evaluator_id: evaluator.data ?? null, p_is_published: false })
  if (error) fail('/wushu/evaluations', error.message)
  revalidatePath('/wushu/evaluations')
  redirect('/wushu/evaluations?created=1')
}

export async function publishWushuEvaluation(formData: FormData) {
  const id = uuid.safeParse(formData.get('evaluationId'))
  if (!id.success) fail('/wushu/evaluations','Évaluation invalide.')
  const supabase = await createClient()
  const { error } = await supabase.rpc('set_wushu_evaluation_published', { p_evaluation_id: id.data, p_published: true })
  if (error) fail('/wushu/evaluations', error.message)
  revalidatePath('/wushu/evaluations')
  redirect('/wushu/evaluations?published=1')
}

export async function createWushuCompetition(formData: FormData) {
  const name = z.string().trim().min(1).max(200).safeParse(formData.get('name'))
  const competitionDate = date.safeParse(formData.get('competitionDate'))
  const location = z.string().trim().max(200).optional().safeParse(formData.get('location') || undefined)
  const notes = z.string().trim().max(2000).optional().safeParse(formData.get('notes') || undefined)
  if (![name,competitionDate,location,notes].every(x => x.success)) fail('/wushu/competitions','Compétition invalide.')
  const supabase = await createClient()
  const { error } = await supabase.rpc('create_wushu_competition', { p_name: name.data, p_competition_date: competitionDate.data, p_location: location.data ?? null, p_notes: notes.data ?? null })
  if (error) fail('/wushu/competitions', error.message)
  revalidatePath('/wushu/competitions')
  redirect('/wushu/competitions?created=1')
}

export async function recordWushuCompetitionResult(formData: FormData) {
  const competitionId = uuid.safeParse(formData.get('competitionId'))
  const studentId = uuid.safeParse(formData.get('studentId'))
  const category = z.string().trim().max(160).optional().safeParse(formData.get('category') || undefined)
  const result = z.string().trim().max(200).optional().safeParse(formData.get('result') || undefined)
  const rank = num.int().min(1).optional().safeParse(formData.get('rank') || undefined)
  const medal = z.string().trim().max(80).optional().safeParse(formData.get('medal') || undefined)
  const observation = z.string().trim().max(1000).optional().safeParse(formData.get('observation') || undefined)
  if (![competitionId,studentId,category,result,rank,medal,observation].every(x => x.success)) fail('/wushu/competitions','Résultat invalide.')
  const supabase = await createClient()
  const { error } = await supabase.rpc('record_wushu_competition_result', { p_competition_id: competitionId.data, p_student_id: studentId.data, p_category: category.data ?? null, p_result: result.data ?? null, p_rank: rank.data ?? null, p_medal: medal.data ?? null, p_observation: observation.data ?? null })
  if (error) fail('/wushu/competitions', error.message)
  revalidatePath('/wushu/competitions')
  redirect('/wushu/competitions?result=1')
}

export async function publishWushuCompetition(formData: FormData) {
  const id = uuid.safeParse(formData.get('competitionId'))
  if (!id.success) fail('/wushu/competitions','Compétition invalide.')
  const supabase = await createClient()
  const { error } = await supabase.rpc('publish_wushu_competition', { p_competition_id: id.data, p_published: true })
  if (error) fail('/wushu/competitions', error.message)
  revalidatePath('/wushu/competitions')
  redirect('/wushu/competitions?published=1')
}
