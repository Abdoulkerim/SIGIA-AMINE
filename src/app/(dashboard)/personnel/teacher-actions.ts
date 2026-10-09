'use server'

import { revalidatePath } from 'next/cache'
import { redirect } from 'next/navigation'
import { z } from 'zod'
import { createClient } from '@/lib/supabase/server'

const teacherSchema = z.object({
  id: z.string().uuid().optional(),
  employeeNumber: z.string().trim().min(1).max(50),
  firstName: z.string().trim().min(1).max(120),
  lastName: z.string().trim().min(1).max(120),
  gender: z.enum(['male', 'female', 'other']).optional(),
  dateOfBirth: z.string().optional(),
  placeOfBirth: z.string().trim().max(120).optional(),
  phone: z.string().trim().max(50).optional(),
  email: z.string().trim().email().max(255).optional(),
  address: z.string().trim().max(500).optional(),
  qualification: z.string().trim().max(255).optional(),
  hireDate: z.string().optional(),
  speciality: z.string().trim().max(255).optional(),
  diploma: z.string().trim().max(255).optional(),
  pedagogicalRole: z.string().trim().max(255).optional(),
  biography: z.string().trim().max(5000).optional(),
})

const assignmentSchema = z.object({
  schoolYearId: z.string().uuid(),
  teacherId: z.string().uuid(),
  classId: z.string().uuid(),
  subjectId: z.string().uuid(),
  weeklyHours: z.coerce.number().positive().optional(),
  isPrimary: z.enum(['true', 'false']).transform((value) => value === 'true'),
})

function errUrl(base: string, error: string) {
  return `${base}?error=${encodeURIComponent(error)}`
}

export async function createTeacher(formData: FormData) {
  const parsed = teacherSchema.safeParse({
    employeeNumber: formData.get('employeeNumber'),
    firstName: formData.get('firstName'),
    lastName: formData.get('lastName'),
    gender: formData.get('gender') || undefined,
    dateOfBirth: formData.get('dateOfBirth') || undefined,
    placeOfBirth: formData.get('placeOfBirth') || undefined,
    phone: formData.get('phone') || undefined,
    email: formData.get('email') || undefined,
    address: formData.get('address') || undefined,
    qualification: formData.get('qualification') || undefined,
    hireDate: formData.get('hireDate') || undefined,
    speciality: formData.get('speciality') || undefined,
    diploma: formData.get('diploma') || undefined,
    pedagogicalRole: formData.get('pedagogicalRole') || undefined,
    biography: formData.get('biography') || undefined,
  })

  if (!parsed.success) redirect(errUrl('/personnel/enseignants/nouveau', 'Données enseignant invalides'))

  const supabase = await createClient()
  const { data, error } = await supabase.rpc('create_teacher', {
    p_employee_number: parsed.data.employeeNumber,
    p_first_name: parsed.data.firstName,
    p_last_name: parsed.data.lastName,
    p_gender: parsed.data.gender ?? null,
    p_date_of_birth: parsed.data.dateOfBirth || null,
    p_place_of_birth: parsed.data.placeOfBirth || null,
    p_phone: parsed.data.phone || null,
    p_email: parsed.data.email || null,
    p_address: parsed.data.address || null,
    p_qualification: parsed.data.qualification || null,
    p_hire_date: parsed.data.hireDate || null,
    p_speciality: parsed.data.speciality || null,
    p_diploma: parsed.data.diploma || null,
    p_pedagogical_role: parsed.data.pedagogicalRole || null,
    p_biography: parsed.data.biography || null,
  })

  if (error) redirect(errUrl('/personnel/enseignants/nouveau', error.message))

  revalidatePath('/personnel/enseignants')
  redirect(`/personnel/enseignants/${data}?created=1`)
}

export async function updateTeacher(formData: FormData) {
  const parsed = teacherSchema.required({ id: true }).safeParse({
    id: formData.get('id'),
    employeeNumber: formData.get('employeeNumber'),
    firstName: formData.get('firstName'),
    lastName: formData.get('lastName'),
    gender: formData.get('gender') || undefined,
    dateOfBirth: formData.get('dateOfBirth') || undefined,
    placeOfBirth: formData.get('placeOfBirth') || undefined,
    phone: formData.get('phone') || undefined,
    email: formData.get('email') || undefined,
    address: formData.get('address') || undefined,
    qualification: formData.get('qualification') || undefined,
    hireDate: formData.get('hireDate') || undefined,
    speciality: formData.get('speciality') || undefined,
    diploma: formData.get('diploma') || undefined,
    pedagogicalRole: formData.get('pedagogicalRole') || undefined,
    biography: formData.get('biography') || undefined,
  })
  if (!parsed.success) redirect('/personnel/enseignants?error=Enseignant invalide')

  const supabase = await createClient()
  const { error } = await supabase.rpc('update_teacher', {
    p_teacher_id: parsed.data.id,
    p_employee_number: parsed.data.employeeNumber,
    p_first_name: parsed.data.firstName,
    p_last_name: parsed.data.lastName,
    p_gender: parsed.data.gender ?? null,
    p_date_of_birth: parsed.data.dateOfBirth || null,
    p_place_of_birth: parsed.data.placeOfBirth || null,
    p_phone: parsed.data.phone || null,
    p_email: parsed.data.email || null,
    p_address: parsed.data.address || null,
    p_qualification: parsed.data.qualification || null,
    p_hire_date: parsed.data.hireDate || null,
    p_speciality: parsed.data.speciality || null,
    p_diploma: parsed.data.diploma || null,
    p_pedagogical_role: parsed.data.pedagogicalRole || null,
    p_biography: parsed.data.biography || null,
  })

  if (error) redirect(errUrl(`/personnel/enseignants/${parsed.data.id}`, error.message))

  revalidatePath('/personnel/enseignants')
  revalidatePath(`/personnel/enseignants/${parsed.data.id}`)
  redirect(`/personnel/enseignants/${parsed.data.id}?updated=1`)
}

export async function toggleTeacher(formData: FormData) {
  const id = z.string().uuid().safeParse(formData.get('id'))
  const active = z.coerce.boolean().safeParse(formData.get('active'))
  if (!id.success || !active.success) redirect('/personnel/enseignants?error=Paramètres invalides')

  const supabase = await createClient()
  const { error } = await supabase.rpc('set_teacher_active', {
    p_teacher_id: id.data,
    p_is_active: active.data,
  })
  if (error) redirect(errUrl('/personnel/enseignants', error.message))

  revalidatePath('/personnel/enseignants')
  revalidatePath(`/personnel/enseignants/${id.data}`)
  revalidatePath('/pedagogie/affectations')
  redirect('/personnel/enseignants?updated=1')
}

export async function assignTeacher(formData: FormData) {
  const parsed = assignmentSchema.safeParse({
    schoolYearId: formData.get('schoolYearId'),
    teacherId: formData.get('teacherId'),
    classId: formData.get('classId'),
    subjectId: formData.get('subjectId'),
    weeklyHours: formData.get('weeklyHours') || undefined,
    isPrimary: formData.get('isPrimary') || 'false',
  })
  if (!parsed.success) redirect('/pedagogie/affectations/nouveau?error=Affectation invalide')

  const supabase = await createClient()
  const { data, error } = await supabase.rpc('assign_teacher', {
    p_school_year_id: parsed.data.schoolYearId,
    p_teacher_id: parsed.data.teacherId,
    p_class_id: parsed.data.classId,
    p_subject_id: parsed.data.subjectId,
    p_weekly_hours: parsed.data.weeklyHours ?? null,
    p_is_primary: parsed.data.isPrimary,
  })
  if (error) redirect(errUrl('/pedagogie/affectations/nouveau', error.message))

  revalidatePath('/pedagogie/affectations')
  revalidatePath(`/personnel/enseignants/${parsed.data.teacherId}`)
  redirect(`/pedagogie/affectations?created=${data}`)
}

export async function toggleTeacherAssignment(formData: FormData) {
  const id = z.string().uuid().safeParse(formData.get('id'))
  const active = z.coerce.boolean().safeParse(formData.get('active'))
  if (!id.success || !active.success) redirect('/pedagogie/affectations?error=Paramètres invalides')

  const supabase = await createClient()
  const { error } = await supabase.rpc('set_teacher_assignment_active', {
    p_assignment_id: id.data,
    p_is_active: active.data,
  })
  if (error) redirect(errUrl('/pedagogie/affectations', error.message))

  revalidatePath('/pedagogie/affectations')
  redirect('/pedagogie/affectations?updated=1')
}
