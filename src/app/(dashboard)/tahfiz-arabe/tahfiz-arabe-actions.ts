'use server'

import { revalidatePath } from 'next/cache'
import { redirect } from 'next/navigation'
import { z } from 'zod'
import { createClient } from '@/lib/supabase/server'

const uuid = z.string().uuid()
const date = z.string().min(1)
const num = z.coerce.number().finite()

function fail(path: string, message: string): never {
  redirect(`${path}?error=${encodeURIComponent(message)}`)
}

export async function createTahfizLevel(formData: FormData) {
  const code = z.string().trim().min(1).max(60).safeParse(formData.get('code'))
  const name = z.string().trim().min(1).max(160).safeParse(formData.get('name'))
  const sequence = num.int().min(0).safeParse(formData.get('sequenceNo') || 0)
  const description = z.string().trim().max(500).optional().safeParse(formData.get('description') || undefined)
  if (![code, name, sequence, description].every((x) => x.success)) fail('/tahfiz-arabe/tahfiz', 'Niveau Tahfiz invalide.')
  const supabase = await createClient()
  const { error } = await supabase.rpc('create_tahfiz_level', { p_code: code.data, p_name: name.data, p_sequence_no: sequence.data, p_description: description.data ?? null })
  if (error) fail('/tahfiz-arabe/tahfiz', error.message)
  revalidatePath('/tahfiz-arabe/tahfiz')
  revalidatePath('/tahfiz-arabe')
  redirect('/tahfiz-arabe/tahfiz?created=1')
}

export async function assignStudentTahfiz(formData: FormData) {
  const studentId = uuid.safeParse(formData.get('studentId'))
  const levelId = z.string().uuid().optional().safeParse(formData.get('levelId') || undefined)
  const teacherId = z.string().uuid().optional().safeParse(formData.get('teacherId') || undefined)
  const startDate = z.string().optional().safeParse(formData.get('startDate') || undefined)
  const progress = num.min(0).max(100).safeParse(formData.get('progress') || 0)
  const status = z.enum(['active','paused','completed','inactive']).safeParse(formData.get('status') || 'active')
  const notes = z.string().trim().max(1200).optional().safeParse(formData.get('notes') || undefined)
  if (![studentId, levelId, teacherId, startDate, progress, status, notes].every((x) => x.success)) fail('/tahfiz-arabe/tahfiz', 'Profil Tahfiz invalide.')
  const supabase = await createClient()
  const { error } = await supabase.rpc('assign_student_tahfiz', { p_student_id: studentId.data, p_tahfiz_level_id: levelId.data ?? null, p_teacher_id: teacherId.data ?? null, p_start_date: startDate.data || null, p_progress: progress.data, p_status: status.data, p_notes: notes.data ?? null })
  if (error) fail('/tahfiz-arabe/tahfiz', error.message)
  revalidatePath('/tahfiz-arabe/tahfiz')
  revalidatePath('/tahfiz-arabe')
  redirect('/tahfiz-arabe/tahfiz?assigned=1')
}

export async function recordTahfizSession(formData: FormData) {
  const studentId = uuid.safeParse(formData.get('studentId'))
  const sessionDate = date.safeParse(formData.get('sessionDate'))
  const sessionType = z.enum(['new_memorization','revision','recitation','evaluation']).safeParse(formData.get('sessionType'))
  const surahId = z.coerce.number().int().min(1).max(114).optional().safeParse(formData.get('surahId') || undefined)
  const fromVerse = z.coerce.number().int().min(1).optional().safeParse(formData.get('fromVerse') || undefined)
  const toVerse = z.coerce.number().int().min(1).optional().safeParse(formData.get('toVerse') || undefined)
  const score = num.min(0).optional().safeParse(formData.get('score') || undefined)
  const teacherId = z.string().uuid().optional().safeParse(formData.get('teacherId') || undefined)
  const attendance = z.enum(['present','absent','late','excused']).safeParse(formData.get('attendanceStatus') || 'present')
  const progress = num.min(0).max(100).optional().safeParse(formData.get('progressAfter') || undefined)
  const observation = z.string().trim().max(2000).optional().safeParse(formData.get('observation') || undefined)
  const published = formData.get('isPublished') === 'on'
  if (![studentId, sessionDate, sessionType, surahId, fromVerse, toVerse, score, teacherId, attendance, progress, observation].every((x) => x.success)) fail('/tahfiz-arabe/tahfiz', 'Séance Tahfiz invalide.')
  const supabase = await createClient()
  const { error } = await supabase.rpc('record_tahfiz_session', { p_student_id: studentId.data, p_session_date: sessionDate.data, p_session_type: sessionType.data, p_surah_id: surahId.data ?? null, p_from_verse: fromVerse.data ?? null, p_to_verse: toVerse.data ?? null, p_score: score.data ?? null, p_observation: observation.data ?? null, p_teacher_id: teacherId.data ?? null, p_attendance_status: attendance.data, p_progress_after: progress.data ?? null, p_is_published: published })
  if (error) fail('/tahfiz-arabe/tahfiz', error.message)
  revalidatePath('/tahfiz-arabe/tahfiz')
  revalidatePath('/tahfiz-arabe')
  redirect('/tahfiz-arabe/tahfiz?session=1')
}

export async function publishTahfizSession(formData: FormData) {
  const id = uuid.safeParse(formData.get('sessionId'))
  if (!id.success) fail('/tahfiz-arabe/tahfiz', 'Séance invalide.')
  const supabase = await createClient()
  const { error } = await supabase.rpc('set_tahfiz_session_published', { p_session_id: id.data, p_published: true })
  if (error) fail('/tahfiz-arabe/tahfiz', error.message)
  revalidatePath('/tahfiz-arabe/tahfiz')
  redirect('/tahfiz-arabe/tahfiz?published=1')
}

export async function createArabicLevel(formData: FormData) {
  const code = z.string().trim().min(1).max(60).safeParse(formData.get('code'))
  const name = z.string().trim().min(1).max(160).safeParse(formData.get('name'))
  const sequence = num.int().min(0).safeParse(formData.get('sequenceNo') || 0)
  const description = z.string().trim().max(500).optional().safeParse(formData.get('description') || undefined)
  if (![code, name, sequence, description].every((x) => x.success)) fail('/tahfiz-arabe/arabe', 'Niveau Arabe invalide.')
  const supabase = await createClient()
  const { error } = await supabase.rpc('create_arabic_level', { p_code: code.data, p_name: name.data, p_sequence_no: sequence.data, p_description: description.data ?? null })
  if (error) fail('/tahfiz-arabe/arabe', error.message)
  revalidatePath('/tahfiz-arabe/arabe')
  revalidatePath('/tahfiz-arabe')
  redirect('/tahfiz-arabe/arabe?created=1')
}

export async function assignStudentArabic(formData: FormData) {
  const studentId = uuid.safeParse(formData.get('studentId'))
  const levelId = z.string().uuid().optional().safeParse(formData.get('levelId') || undefined)
  const teacherId = z.string().uuid().optional().safeParse(formData.get('teacherId') || undefined)
  const startDate = z.string().optional().safeParse(formData.get('startDate') || undefined)
  const progress = num.min(0).max(100).safeParse(formData.get('progress') || 0)
  const status = z.enum(['active','paused','completed','inactive']).safeParse(formData.get('status') || 'active')
  const notes = z.string().trim().max(1200).optional().safeParse(formData.get('notes') || undefined)
  if (![studentId, levelId, teacherId, startDate, progress, status, notes].every((x) => x.success)) fail('/tahfiz-arabe/arabe', 'Profil Arabe invalide.')
  const supabase = await createClient()
  const { error } = await supabase.rpc('assign_student_arabic', { p_student_id: studentId.data, p_arabic_level_id: levelId.data ?? null, p_teacher_id: teacherId.data ?? null, p_start_date: startDate.data || null, p_progress: progress.data, p_status: status.data, p_notes: notes.data ?? null })
  if (error) fail('/tahfiz-arabe/arabe', error.message)
  revalidatePath('/tahfiz-arabe/arabe')
  revalidatePath('/tahfiz-arabe')
  redirect('/tahfiz-arabe/arabe?assigned=1')
}

export async function recordArabicSession(formData: FormData) {
  const studentId = uuid.safeParse(formData.get('studentId'))
  const sessionDate = date.safeParse(formData.get('sessionDate'))
  const activityType = z.string().trim().min(1).max(100).safeParse(formData.get('activityType'))
  const topic = z.string().trim().max(300).optional().safeParse(formData.get('topic') || undefined)
  const score = num.min(0).optional().safeParse(formData.get('score') || undefined)
  const teacherId = z.string().uuid().optional().safeParse(formData.get('teacherId') || undefined)
  const attendance = z.enum(['present','absent','late','excused']).safeParse(formData.get('attendanceStatus') || 'present')
  const progress = num.min(0).max(100).optional().safeParse(formData.get('progressAfter') || undefined)
  const observation = z.string().trim().max(2000).optional().safeParse(formData.get('observation') || undefined)
  const published = formData.get('isPublished') === 'on'
  if (![studentId, sessionDate, activityType, topic, score, teacherId, attendance, progress, observation].every((x) => x.success)) fail('/tahfiz-arabe/arabe', 'Séance Arabe invalide.')
  const supabase = await createClient()
  const { error } = await supabase.rpc('record_arabic_session', { p_student_id: studentId.data, p_session_date: sessionDate.data, p_activity_type: activityType.data, p_topic: topic.data ?? null, p_score: score.data ?? null, p_observation: observation.data ?? null, p_teacher_id: teacherId.data ?? null, p_attendance_status: attendance.data, p_progress_after: progress.data ?? null, p_is_published: published })
  if (error) fail('/tahfiz-arabe/arabe', error.message)
  revalidatePath('/tahfiz-arabe/arabe')
  revalidatePath('/tahfiz-arabe')
  redirect('/tahfiz-arabe/arabe?session=1')
}

export async function createArabicEvaluation(formData: FormData) {
  const studentId = uuid.safeParse(formData.get('studentId'))
  const periodId = z.string().uuid().optional().safeParse(formData.get('periodId') || undefined)
  const evaluationDate = date.safeParse(formData.get('evaluationDate'))
  const title = z.string().trim().min(1).max(200).safeParse(formData.get('title'))
  const skillArea = z.string().trim().max(160).optional().safeParse(formData.get('skillArea') || undefined)
  const score = num.min(0).optional().safeParse(formData.get('score') || undefined)
  const evaluatorId = z.string().uuid().optional().safeParse(formData.get('evaluatorId') || undefined)
  const observation = z.string().trim().max(2000).optional().safeParse(formData.get('observation') || undefined)
  const published = formData.get('isPublished') === 'on'
  if (![studentId, periodId, evaluationDate, title, skillArea, score, evaluatorId, observation].every((x) => x.success)) fail('/tahfiz-arabe/arabe', 'Évaluation Arabe invalide.')
  const supabase = await createClient()
  const { error } = await supabase.rpc('create_arabic_evaluation', { p_student_id: studentId.data, p_period_id: periodId.data ?? null, p_evaluation_date: evaluationDate.data, p_title: title.data, p_skill_area: skillArea.data ?? null, p_score: score.data ?? null, p_observation: observation.data ?? null, p_evaluator_id: evaluatorId.data ?? null, p_is_published: published })
  if (error) fail('/tahfiz-arabe/arabe', error.message)
  revalidatePath('/tahfiz-arabe/arabe')
  revalidatePath('/tahfiz-arabe')
  redirect('/tahfiz-arabe/arabe?evaluation=1')
}

export async function publishArabicEvaluation(formData: FormData) {
  const id = uuid.safeParse(formData.get('evaluationId'))
  if (!id.success) fail('/tahfiz-arabe/arabe', 'Évaluation invalide.')
  const supabase = await createClient()
  const { error } = await supabase.rpc('set_arabic_evaluation_published', { p_evaluation_id: id.data, p_published: true })
  if (error) fail('/tahfiz-arabe/arabe', error.message)
  revalidatePath('/tahfiz-arabe/arabe')
  redirect('/tahfiz-arabe/arabe?published=1')
}
