'use server'

import { revalidatePath } from 'next/cache'
import { redirect } from 'next/navigation'
import { z } from 'zod'
import { createClient } from '@/lib/supabase/server'

const uuid = z.string().uuid()
const date = z.string().regex(/^\d{4}-\d{2}-\d{2}$/)

function errUrl(base: string, error: string) {
  return `${base}?error=${encodeURIComponent(error)}`
}

async function currentSchool() {
  const supabase = await createClient()
  const claims = await supabase.auth.getClaims()
  const userId = claims.data?.claims?.sub
  if (!userId) return { supabase, schoolId: null as string | null }
  const { data } = await supabase.from('users').select('school_id').eq('id', userId).single()
  return { supabase, schoolId: data?.school_id ?? null }
}

const buildingSchema = z.object({
  code: z.string().trim().min(1).max(40),
  name: z.string().trim().min(1).max(160),
  description: z.string().trim().max(500).optional(),
})

export async function createBuilding(formData: FormData) {
  const parsed = buildingSchema.safeParse({
    code: formData.get('code'), name: formData.get('name'), description: formData.get('description') || undefined,
  })
  if (!parsed.success) redirect(errUrl('/internat/structures', 'Bâtiment invalide.'))
  const { supabase, schoolId } = await currentSchool()
  if (!schoolId) redirect(errUrl('/internat/structures', 'École introuvable.'))
  const { error } = await supabase.rpc('create_boarding_building', {
    p_school_id: schoolId, p_code: parsed.data.code, p_name: parsed.data.name, p_description: parsed.data.description ?? null,
  })
  if (error) redirect(errUrl('/internat/structures', error.message))
  revalidatePath('/internat'); revalidatePath('/internat/structures')
  redirect('/internat/structures?created=building')
}

const dormSchema = z.object({
  buildingId: uuid,
  name: z.string().trim().min(1).max(160),
  gender: z.enum(['male','female','other']).optional(),
})

export async function createDormitory(formData: FormData) {
  const parsed = dormSchema.safeParse({
    buildingId: formData.get('buildingId'), name: formData.get('name'), gender: formData.get('gender') || undefined,
  })
  if (!parsed.success) redirect(errUrl('/internat/structures', 'Dortoir invalide.'))
  const { supabase } = await currentSchool()
  const { error } = await supabase.rpc('create_boarding_dormitory', {
    p_building_id: parsed.data.buildingId, p_name: parsed.data.name, p_gender: parsed.data.gender ?? null, p_supervisor_employee_id: null,
  })
  if (error) redirect(errUrl('/internat/structures', error.message))
  revalidatePath('/internat'); revalidatePath('/internat/structures')
  redirect('/internat/structures?created=dormitory')
}

const roomSchema = z.object({
  dormitoryId: uuid, name: z.string().trim().min(1).max(80), capacity: z.coerce.number().int().positive(), floor: z.string().trim().max(50).optional(),
})

export async function createRoom(formData: FormData) {
  const parsed = roomSchema.safeParse({
    dormitoryId: formData.get('dormitoryId'), name: formData.get('name'), capacity: formData.get('capacity'), floor: formData.get('floor') || undefined,
  })
  if (!parsed.success) redirect(errUrl('/internat/structures', 'Chambre invalide.'))
  const { supabase } = await currentSchool()
  const { error } = await supabase.rpc('create_boarding_room', {
    p_dormitory_id: parsed.data.dormitoryId, p_name: parsed.data.name, p_capacity: parsed.data.capacity,
    p_floor: parsed.data.floor ?? null, p_status: 'active',
  })
  if (error) redirect(errUrl('/internat/structures', error.message))
  revalidatePath('/internat'); revalidatePath('/internat/structures')
  redirect('/internat/structures?created=room')
}

const bedSchema = z.object({ roomId: uuid, bedNumber: z.string().trim().min(1).max(40) })

export async function createBed(formData: FormData) {
  const parsed = bedSchema.safeParse({ roomId: formData.get('roomId'), bedNumber: formData.get('bedNumber') })
  if (!parsed.success) redirect(errUrl('/internat/structures', 'Lit invalide.'))
  const { supabase } = await currentSchool()
  const { error } = await supabase.rpc('create_boarding_bed', {
    p_room_id: parsed.data.roomId, p_bed_number: parsed.data.bedNumber, p_status: 'available',
  })
  if (error) redirect(errUrl('/internat/structures', error.message))
  revalidatePath('/internat'); revalidatePath('/internat/structures')
  redirect('/internat/structures?created=bed')
}

const assignmentSchema = z.object({
  studentId: uuid, bedId: uuid, startDate: date, endDate: date.optional(), notes: z.string().trim().max(500).optional(),
})

export async function assignBoarding(formData: FormData) {
  const parsed = assignmentSchema.safeParse({
    studentId: formData.get('studentId'), bedId: formData.get('bedId'), startDate: formData.get('startDate'),
    endDate: formData.get('endDate') || undefined, notes: formData.get('notes') || undefined,
  })
  if (!parsed.success) redirect(errUrl('/internat/affectations', 'Affectation invalide.'))
  const { supabase } = await currentSchool()
  const { error } = await supabase.rpc('assign_boarding_bed', {
    p_student_id: parsed.data.studentId, p_bed_id: parsed.data.bedId, p_start_date: parsed.data.startDate,
    p_end_date: parsed.data.endDate ?? null, p_notes: parsed.data.notes ?? null,
  })
  if (error) redirect(errUrl('/internat/affectations', error.message))
  revalidatePath('/internat'); revalidatePath('/internat/affectations'); revalidatePath('/internat/presences')
  revalidatePath('/administration/eleves')
  redirect('/internat/affectations?created=1')
}

const closeSchema = z.object({ assignmentId: uuid, endDate: date, notes: z.string().trim().max(500).optional() })

export async function closeBoarding(formData: FormData) {
  const parsed = closeSchema.safeParse({ assignmentId: formData.get('assignmentId'), endDate: formData.get('endDate'), notes: formData.get('notes') || undefined })
  if (!parsed.success) redirect(errUrl('/internat/affectations', 'Fin d’affectation invalide.'))
  const { supabase } = await currentSchool()
  const { error } = await supabase.rpc('close_boarding_assignment', {
    p_assignment_id: parsed.data.assignmentId, p_end_date: parsed.data.endDate, p_notes: parsed.data.notes ?? null,
  })
  if (error) redirect(errUrl('/internat/affectations', error.message))
  revalidatePath('/internat'); revalidatePath('/internat/affectations'); revalidatePath('/internat/structures')
  redirect('/internat/affectations?closed=1')
}

const movementSchema = z.object({
  studentId: uuid,
  movementType: z.enum(['entry','exit','return','temporary_leave']),
  movementAt: z.string().min(1), authorization: z.string().trim().max(300).optional(),
  destination: z.string().trim().max(200).optional(), reason: z.string().trim().max(300).optional(), notes: z.string().trim().max(500).optional(),
})

export async function recordBoardingMovement(formData: FormData) {
  const parsed = movementSchema.safeParse({
    studentId: formData.get('studentId'), movementType: formData.get('movementType'), movementAt: formData.get('movementAt'),
    authorization: formData.get('authorization') || undefined, destination: formData.get('destination') || undefined,
    reason: formData.get('reason') || undefined, notes: formData.get('notes') || undefined,
  })
  if (!parsed.success) redirect(errUrl('/internat/mouvements', 'Mouvement invalide.'))
  const { supabase } = await currentSchool()
  const { error } = await supabase.rpc('record_boarding_movement', {
    p_student_id: parsed.data.studentId, p_movement_type: parsed.data.movementType, p_movement_at: parsed.data.movementAt,
    p_authorization: parsed.data.authorization ?? null, p_destination: parsed.data.destination ?? null,
    p_reason: parsed.data.reason ?? null, p_notes: parsed.data.notes ?? null,
  })
  if (error) redirect(errUrl('/internat/mouvements', error.message))
  revalidatePath('/internat'); revalidatePath('/internat/mouvements')
  redirect('/internat/mouvements?created=1')
}

const attendanceSchema = z.object({
  studentId: uuid, attendanceDate: date, status: z.enum(['present','absent','late','excused']), notes: z.string().trim().max(500).optional(),
})

export async function setBoardingAttendance(formData: FormData) {
  const parsed = attendanceSchema.safeParse({
    studentId: formData.get('studentId'), attendanceDate: formData.get('attendanceDate'),
    status: formData.get('status'), notes: formData.get('notes') || undefined,
  })
  if (!parsed.success) redirect(errUrl('/internat/presences', 'Présence invalide.'))
  const { supabase } = await currentSchool()
  const { error } = await supabase.rpc('set_boarding_attendance', {
    p_student_id: parsed.data.studentId, p_attendance_date: parsed.data.attendanceDate,
    p_status: parsed.data.status, p_notes: parsed.data.notes ?? null,
  })
  if (error) redirect(errUrl('/internat/presences', error.message))
  revalidatePath('/internat'); revalidatePath('/internat/presences')
  redirect('/internat/presences?saved=1')
}
