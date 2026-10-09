'use server'

import { z } from 'zod'
import { revalidatePath } from 'next/cache'
import { redirect } from 'next/navigation'
import { createClient } from '@/lib/supabase/server'
import { getCurrentUserContext } from '@/lib/auth/current-user'

const nullableUuid = z.string().uuid().optional().or(z.literal(''))
const dateField = z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional().or(z.literal(''))

const admissionSchema = z.object({
  candidateFirstName: z.string().trim().min(1).max(100),
  candidateLastName: z.string().trim().min(1).max(100),
  candidateGender: z.enum(['male', 'female', 'other']).optional(),
  candidateDateOfBirth: dateField,
  candidatePlaceOfBirth: z.string().trim().max(150).optional(),
  candidateNationality: z.string().trim().max(100).optional(),
  candidateAddress: z.string().trim().max(500).optional(),
  applicantPhone: z.string().trim().max(50).optional(),
  desiredYearId: z.string().uuid(),
  desiredLevelId: nullableUuid,
  desiredLevelLabel: z.string().trim().max(150).optional(),
  desiredResidenceType: z.enum(['internal', 'external', 'other']).optional(),
  primaryParentId: nullableUuid,
  notes: z.string().trim().max(2000).optional(),
})

function blankToNull(value: string | undefined) {
  return value && value.trim() ? value.trim() : null
}

function generateApplicationNumber() {
  const d = new Date()
  const y = d.getFullYear()
  const m = String(d.getMonth() + 1).padStart(2, '0')
  const day = String(d.getDate()).padStart(2, '0')
  const token = crypto.randomUUID().replaceAll('-', '').slice(0, 8).toUpperCase()
  return `ADM-${y}${m}${day}-${token}`
}

export async function createAdmission(formData: FormData) {
  const context = await getCurrentUserContext()
  if (!context?.profile.school_id) redirect('/login')

  const parsed = admissionSchema.safeParse({
    candidateFirstName: formData.get('candidateFirstName'),
    candidateLastName: formData.get('candidateLastName'),
    candidateGender: formData.get('candidateGender') || undefined,
    candidateDateOfBirth: formData.get('candidateDateOfBirth') || '',
    candidatePlaceOfBirth: formData.get('candidatePlaceOfBirth') || undefined,
    candidateNationality: formData.get('candidateNationality') || undefined,
    candidateAddress: formData.get('candidateAddress') || undefined,
    applicantPhone: formData.get('applicantPhone') || undefined,
    desiredYearId: formData.get('desiredYearId'),
    desiredLevelId: formData.get('desiredLevelId') || '',
    desiredLevelLabel: formData.get('desiredLevelLabel') || undefined,
    desiredResidenceType: formData.get('desiredResidenceType') || undefined,
    primaryParentId: formData.get('primaryParentId') || '',
    notes: formData.get('notes') || undefined,
  })

  if (!parsed.success) {
    redirect('/administration/admissions/nouveau?error=Veuillez vérifier les champs obligatoires')
  }

  const supabase = await createClient()
  const applicationNumber = generateApplicationNumber()

  const { error } = await supabase.from('admission_applications').insert({
    school_id: context.profile.school_id,
    application_number: applicationNumber,
    candidate_first_name: parsed.data.candidateFirstName,
    candidate_last_name: parsed.data.candidateLastName,
    applicant_name: `${parsed.data.candidateFirstName} ${parsed.data.candidateLastName}`,
    applicant_phone: blankToNull(parsed.data.applicantPhone),
    candidate_gender: parsed.data.candidateGender || null,
    candidate_date_of_birth: blankToNull(parsed.data.candidateDateOfBirth),
    candidate_place_of_birth: blankToNull(parsed.data.candidatePlaceOfBirth),
    candidate_nationality: blankToNull(parsed.data.candidateNationality),
    candidate_address: blankToNull(parsed.data.candidateAddress),
    desired_level_id: blankToNull(parsed.data.desiredLevelId),
    desired_level_label: blankToNull(parsed.data.desiredLevelLabel),
    desired_year_id: parsed.data.desiredYearId,
    desired_residence_type: parsed.data.desiredResidenceType || null,
    primary_parent_id: blankToNull(parsed.data.primaryParentId),
    status: 'pending',
    notes: blankToNull(parsed.data.notes),
  })

  if (error) {
    redirect(`/administration/admissions/nouveau?error=${encodeURIComponent(error.message)}`)
  }

  revalidatePath('/administration/admissions')
  redirect(`/administration/admissions?created=1&number=${encodeURIComponent(applicationNumber)}`)
}

const reviewSchema = z.object({
  id: z.string().uuid(),
  action: z.enum(['approve', 'reject', 'cancel', 'reopen']),
})

export async function reviewAdmission(formData: FormData) {
  const context = await getCurrentUserContext()
  if (!context?.profile.school_id || !context.claims?.sub) redirect('/login')

  const parsed = reviewSchema.safeParse({
    id: formData.get('id'),
    action: formData.get('action'),
  })

  if (!parsed.success) {
    redirect('/administration/admissions?error=Action invalide')
  }

  const supabase = await createClient()
  const nextStatus = parsed.data.action === 'approve'
    ? 'approved'
    : parsed.data.action === 'reject'
      ? 'rejected'
      : parsed.data.action === 'cancel'
        ? 'cancelled'
        : 'pending'

  const updatePayload = nextStatus === 'pending'
    ? { status: nextStatus, reviewed_at: null, reviewed_by: null }
    : { status: nextStatus, reviewed_at: new Date().toISOString(), reviewed_by: context.claims.sub }

  const { error } = await supabase
    .from('admission_applications')
    .update(updatePayload)
    .eq('id', parsed.data.id)
    .eq('school_id', context.profile.school_id)

  if (error) {
    redirect(`/administration/admissions/${parsed.data.id}?error=${encodeURIComponent(error.message)}`)
  }

  revalidatePath('/administration/admissions')
  revalidatePath(`/administration/admissions/${parsed.data.id}`)
  redirect(`/administration/admissions/${parsed.data.id}?updated=1`)
}
