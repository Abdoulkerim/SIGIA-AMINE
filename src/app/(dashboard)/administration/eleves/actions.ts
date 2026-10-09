'use server'

import { z } from 'zod'
import { revalidatePath } from 'next/cache'
import { redirect } from 'next/navigation'
import { createClient } from '@/lib/supabase/server'
import { getCurrentUserContext } from '@/lib/auth/current-user'

const studentSchema = z.object({
  studentNumber: z.string().trim().min(1).max(50),
  firstName: z.string().trim().min(1).max(100),
  lastName: z.string().trim().min(1).max(100),
  gender: z.enum(['male', 'female', 'other']).optional(),
  dateOfBirth: z.string().optional(),
  residenceType: z.enum(['internal', 'external', 'other']).default('external'),
})

const studentUpdateSchema = z.object({
  studentId: z.string().uuid(),
  studentNumber: z.string().trim().min(1).max(50),
  firstName: z.string().trim().min(1).max(100),
  lastName: z.string().trim().min(1).max(100),
  gender: z.enum(['male', 'female', 'other']).or(z.literal('')),
  dateOfBirth: z.string().refine((value) => !value || /^\d{4}-\d{2}-\d{2}$/.test(value)),
  placeOfBirth: z.string().trim().max(150),
  nationality: z.string().trim().max(100),
  phone: z.string().trim().max(50),
  email: z.string().trim().max(254).refine((value) => !value || z.email().safeParse(value).success),
  address: z.string().trim().max(500),
  photoUrl: z.string().trim().max(1000),
  residenceType: z.enum(['internal', 'external', 'other']),
  status: z.enum(['prospect', 'active', 'transferred', 'graduated', 'withdrawn', 'archived']),
  emergencyName: z.string().trim().max(200),
  emergencyRelationship: z.string().trim().max(100),
  emergencyPhone: z.string().trim().max(50),
  medicalNotes: z.string().trim().max(5000),
})

export async function updateStudent(formData: FormData) {
  const context = await getCurrentUserContext()
  const schoolId = context?.profile.school_id
  const studentId = String(formData.get('studentId') ?? '')

  if (!schoolId) redirect('/login')

  const parsed = studentUpdateSchema.safeParse(Object.fromEntries(formData))
  if (!parsed.success) {
    redirect(`/administration/eleves/${encodeURIComponent(studentId)}?error=${encodeURIComponent('Vérifie les champs du dossier.')}`)
  }

  const supabase = await createClient()
  const { data: currentStudent, error: currentStudentError } = await supabase
    .from('students')
    .select('emergency_contact')
    .eq('id', parsed.data.studentId)
    .eq('school_id', schoolId)
    .single()

  if (currentStudentError || !currentStudent) {
    redirect(`/administration/eleves/${encodeURIComponent(parsed.data.studentId)}?error=${encodeURIComponent('Dossier introuvable ou accès non autorisé.')}`)
  }

  const currentEmergencyContact = currentStudent.emergency_contact
  const emergencyContact: Record<string, unknown> =
    currentEmergencyContact && typeof currentEmergencyContact === 'object' && !Array.isArray(currentEmergencyContact)
      ? { ...currentEmergencyContact }
      : {}

  delete emergencyContact.name
  delete emergencyContact.telephone
  emergencyContact.full_name = parsed.data.emergencyName
  emergencyContact.relationship = parsed.data.emergencyRelationship
  emergencyContact.phone = parsed.data.emergencyPhone

  const { error } = await supabase
    .from('students')
    .update({
      student_number: parsed.data.studentNumber,
      first_name: parsed.data.firstName,
      last_name: parsed.data.lastName,
      gender: parsed.data.gender || null,
      date_of_birth: parsed.data.dateOfBirth || null,
      place_of_birth: parsed.data.placeOfBirth || null,
      nationality: parsed.data.nationality || null,
      phone: parsed.data.phone || null,
      email: parsed.data.email || null,
      address: parsed.data.address || null,
      photo_url: parsed.data.photoUrl || null,
      residence_type: parsed.data.residenceType,
      status: parsed.data.status,
      emergency_contact: emergencyContact,
      medical_notes: parsed.data.medicalNotes || null,
    })
    .eq('id', parsed.data.studentId)
    .eq('school_id', schoolId)
    .select('id')
    .single()

  if (error) {
    redirect(`/administration/eleves/${encodeURIComponent(parsed.data.studentId)}?error=${encodeURIComponent(error.message)}`)
  }

  revalidatePath('/administration/eleves')
  revalidatePath(`/administration/eleves/${parsed.data.studentId}`)
  redirect(`/administration/eleves/${parsed.data.studentId}?saved=1`)
}

export async function createStudent(formData: FormData) {
  const context = await (await import('@/lib/auth/current-user')).getCurrentUserContext()
  if (!context?.profile.school_id) redirect('/login')

  const parsed = studentSchema.safeParse({
    studentNumber: formData.get('studentNumber'),
    firstName: formData.get('firstName'),
    lastName: formData.get('lastName'),
    gender: formData.get('gender') || undefined,
    dateOfBirth: formData.get('dateOfBirth') || undefined,
    residenceType: formData.get('residenceType') || 'external',
  })

  if (!parsed.success) {
    redirect(`/administration/eleves/nouveau?error=${encodeURIComponent('Vérifie les champs du formulaire.')}`)
  }

  const supabase = await createClient()
  const { error } = await supabase.from('students').insert({
    school_id: context.profile.school_id,
    student_number: parsed.data.studentNumber,
    first_name: parsed.data.firstName,
    last_name: parsed.data.lastName,
    gender: parsed.data.gender ?? null,
    date_of_birth: parsed.data.dateOfBirth || null,
    residence_type: parsed.data.residenceType,
    status: 'active',
  })

  if (error) {
    redirect(`/administration/eleves/nouveau?error=${encodeURIComponent(error.message)}`)
  }

  revalidatePath('/administration/eleves')
  redirect('/administration/eleves?created=1')
}
