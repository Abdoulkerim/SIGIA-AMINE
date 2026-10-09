'use server'

import { revalidatePath } from 'next/cache'
import { redirect } from 'next/navigation'
import { z } from 'zod'
import { createClient } from '@/lib/supabase/server'

const admissionSchema = z.object({
  admissionId: z.string().uuid(),
  parentRelationship: z.enum(['father', 'mother', 'guardian', 'tutor', 'other']).optional(),
})

const reenrollmentSchema = z.object({
  studentId: z.string().uuid(),
  schoolYearId: z.string().uuid(),
  residenceType: z.enum(['internal', 'external', 'other']),
})

const finalizeSchema = z.object({
  enrollmentId: z.string().uuid(),
  classId: z.string().uuid(),
})

export async function prepareFromAdmission(formData: FormData) {
  const parsed = admissionSchema.safeParse({
    admissionId: formData.get('admissionId'),
    parentRelationship: formData.get('parentRelationship') || undefined,
  })
  if (!parsed.success) redirect('/administration/inscriptions/nouveau?error=Préinscription invalide')

  const supabase = await createClient()
  const { data, error } = await supabase.rpc('prepare_enrollment_from_admission', {
    p_admission_id: parsed.data.admissionId,
    p_parent_relationship: parsed.data.parentRelationship || null,
  })

  if (error) {
    redirect(`/administration/inscriptions/nouveau?error=${encodeURIComponent(error.message)}`)
  }

  const result = data as { enrollment_id?: string }
  if (!result?.enrollment_id) {
    redirect('/administration/inscriptions/nouveau?error=Inscription non créée')
  }

  revalidatePath('/administration/inscriptions')
  revalidatePath(`/administration/inscriptions/${result.enrollment_id}`)
  revalidatePath('/administration/admissions')
  redirect(`/administration/inscriptions/${result.enrollment_id}?created=1`)
}

export async function prepareReenrollment(formData: FormData) {
  const parsed = reenrollmentSchema.safeParse({
    studentId: formData.get('studentId'),
    schoolYearId: formData.get('schoolYearId'),
    residenceType: formData.get('residenceType') || 'external',
  })
  if (!parsed.success) redirect('/administration/inscriptions/nouveau?error=Réinscription invalide')

  const supabase = await createClient()
  const { data, error } = await supabase.rpc('create_reenrollment_draft', {
    p_student_id: parsed.data.studentId,
    p_school_year_id: parsed.data.schoolYearId,
    p_residence_type: parsed.data.residenceType,
  })

  if (error) {
    redirect(`/administration/inscriptions/nouveau?error=${encodeURIComponent(error.message)}`)
  }

  const result = data as { enrollment_id?: string }
  if (!result?.enrollment_id) redirect('/administration/inscriptions/nouveau?error=Réinscription non créée')

  revalidatePath('/administration/inscriptions')
  revalidatePath(`/administration/inscriptions/${result.enrollment_id}`)
  redirect(`/administration/inscriptions/${result.enrollment_id}?created=1`)
}

export async function finalizeEnrollment(formData: FormData) {
  const parsed = finalizeSchema.safeParse({
    enrollmentId: formData.get('enrollmentId'),
    classId: formData.get('classId'),
  })
  if (!parsed.success) redirect('/administration/inscriptions?error=Paramètres invalides')

  const supabase = await createClient()
  const { data, error } = await supabase.rpc('finalize_enrollment', {
    p_enrollment_id: parsed.data.enrollmentId,
    p_class_id: parsed.data.classId,
  })

  if (error) {
    redirect(`/administration/inscriptions/${parsed.data.enrollmentId}?error=${encodeURIComponent(error.message)}`)
  }

  revalidatePath('/administration/inscriptions')
  revalidatePath(`/administration/inscriptions/${parsed.data.enrollmentId}`)
  redirect(`/administration/inscriptions/${parsed.data.enrollmentId}?finalized=1`)
}

export async function cancelEnrollment(formData: FormData) {
  const id = z.string().uuid().safeParse(formData.get('enrollmentId'))
  if (!id.success) redirect('/administration/inscriptions?error=Inscription invalide')

  const supabase = await createClient()
  const { error } = await supabase
    .from('enrollments')
    .update({ status: 'cancelled' })
    .eq('id', id.data)

  if (error) redirect(`/administration/inscriptions/${id.data}?error=${encodeURIComponent(error.message)}`)

  revalidatePath('/administration/inscriptions')
  revalidatePath(`/administration/inscriptions/${id.data}`)
  redirect(`/administration/inscriptions/${id.data}?cancelled=1`)
}
