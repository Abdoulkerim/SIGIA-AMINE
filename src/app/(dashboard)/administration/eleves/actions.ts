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
  educationStage: z.enum(['maternelle', 'primaire', 'secondaire', 'formation', 'autre']),
  classId: z.string().uuid().optional(),
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
  residenceType: z.enum(['internal', 'external', 'other']),
  status: z.enum(['prospect', 'active', 'transferred', 'graduated', 'withdrawn', 'archived']),
  emergencyName: z.string().trim().max(200),
  emergencyRelationship: z.string().trim().max(100),
  emergencyPhone: z.string().trim().max(50),
  medicalNotes: z.string().trim().max(5000),
})

const PHOTO_BUCKET = 'student-photos'
const PHOTO_MAX_SIZE = 2 * 1024 * 1024
const PHOTO_TYPES: Record<string, string> = {
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
}

function selectedPhoto(formData: FormData) {
  const value = formData.get('photoFile')
  return value instanceof File && value.size > 0 ? value : null
}

function photoExtension(file: File) {
  const extension = file.name.split('.').pop()?.toLowerCase()
  const allowedExtension = extension === 'jpg' || extension === 'jpeg' || extension === 'png' || extension === 'webp'
  if (!allowedExtension || !PHOTO_TYPES[file.type]) return null
  if ((file.type === 'image/jpeg' && !['jpg', 'jpeg'].includes(extension)) || (file.type === 'image/png' && extension !== 'png') || (file.type === 'image/webp' && extension !== 'webp')) return null
  return PHOTO_TYPES[file.type]
}

async function uploadStudentPhoto(supabase: Awaited<ReturnType<typeof createClient>>, file: File, schoolId: string) {
  const extension = photoExtension(file)
  if (!extension) throw new Error('Format incorrect. Choisissez une image JPG, JPEG, PNG ou WEBP.')
  if (file.size > PHOTO_MAX_SIZE) throw new Error('Le fichier dépasse la taille maximale de 2 Mo.')
  const path = `${schoolId}/${crypto.randomUUID()}.${extension}`
  const { error } = await supabase.storage.from(PHOTO_BUCKET).upload(path, file, {
    contentType: file.type,
    upsert: false,
  })
  if (error) throw new Error(`Échec de l’importation de la photo : ${error.message}`)
  return path
}

async function removeUploadedPhoto(supabase: Awaited<ReturnType<typeof createClient>>, path: string | null) {
  if (path) await supabase.storage.from(PHOTO_BUCKET).remove([path])
}

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
    .select('emergency_contact, photo_url')
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

  const supabasePhoto = selectedPhoto(formData)
  let uploadedPhotoPath: string | null = null
  if (supabasePhoto) {
    try {
      uploadedPhotoPath = await uploadStudentPhoto(supabase, supabasePhoto, schoolId)
    } catch (photoError) {
      redirect(`/administration/eleves/${encodeURIComponent(parsed.data.studentId)}?error=${encodeURIComponent(photoError instanceof Error ? photoError.message : 'Échec de l’importation de la photo.')}`)
    }
  }
  const removePhoto = formData.get('removePhoto') === 'true'
  const nextPhotoPath = uploadedPhotoPath ?? (removePhoto ? null : currentStudent.photo_url)

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
      photo_url: nextPhotoPath,
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
    await removeUploadedPhoto(supabase, uploadedPhotoPath)
    redirect(`/administration/eleves/${encodeURIComponent(parsed.data.studentId)}?error=${encodeURIComponent(error.message)}`)
  }

  if ((uploadedPhotoPath || removePhoto) && currentStudent.photo_url && !/^https?:\/\//i.test(currentStudent.photo_url) && currentStudent.photo_url.startsWith(`${schoolId}/`)) {
    await removeUploadedPhoto(supabase, currentStudent.photo_url)
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
    educationStage: formData.get('educationStage'),
    classId: formData.get('classId') || undefined,
    gender: formData.get('gender') || undefined,
    dateOfBirth: formData.get('dateOfBirth') || undefined,
    residenceType: formData.get('residenceType') || 'external',
  })

  if (!parsed.success) {
    redirect(`/administration/eleves/nouveau?error=${encodeURIComponent('Vérifie les champs du formulaire.')}`)
  }

  const canChooseAnyStage = context.roles.some(({ code }) => ['founder', 'super_admin'].includes(code ?? ''))
  if (!canChooseAnyStage && context.profile.education_stage !== parsed.data.educationStage) {
    redirect(`/administration/eleves/nouveau?error=${encodeURIComponent('Le cycle choisi ne correspond pas au périmètre de votre compte.')}`)
  }

  const supabase = await createClient()
  let selectedClass: { id: string; school_year_id: string; education_stage: string | null } | null = null
  if (parsed.data.classId) {
    const { data, error: classError } = await supabase
      .from('classes')
      .select('id,school_year_id,education_stage')
      .eq('id', parsed.data.classId)
      .eq('school_id', context.profile.school_id)
      .maybeSingle()

    if (classError || !data) {
      redirect(`/administration/eleves/nouveau?error=${encodeURIComponent(classError?.message ?? 'La classe sélectionnée est introuvable.')}`)
    }
    if (data.education_stage !== parsed.data.educationStage) {
      redirect(`/administration/eleves/nouveau?error=${encodeURIComponent('Le cycle de la classe doit correspondre au cycle de l’élève.')}`)
    }
    selectedClass = data
  }

  let photoPath: string | null = null
  const photo = selectedPhoto(formData)
  if (photo) {
    try {
      photoPath = await uploadStudentPhoto(supabase, photo, context.profile.school_id)
    } catch (photoError) {
      redirect(`/administration/eleves/nouveau?error=${encodeURIComponent(photoError instanceof Error ? photoError.message : 'Échec de l’importation de la photo.')}`)
    }
  }

  const { data: student, error } = await supabase.from('students').insert({
    school_id: context.profile.school_id,
    education_stage: parsed.data.educationStage,
    student_number: parsed.data.studentNumber,
    first_name: parsed.data.firstName,
    last_name: parsed.data.lastName,
    gender: parsed.data.gender ?? null,
    date_of_birth: parsed.data.dateOfBirth || null,
    residence_type: parsed.data.residenceType,
    status: 'active',
    photo_url: photoPath,
  }).select('id').single()

  if (error) {
    await removeUploadedPhoto(supabase, photoPath)
    redirect(`/administration/eleves/nouveau?error=${encodeURIComponent(error.message)}`)
  }

  let classAssigned = false
  if (selectedClass) {
    const { data: enrollment, error: enrollmentError } = await supabase.from('enrollments').insert({
      school_id: context.profile.school_id,
      student_id: student.id,
      school_year_id: selectedClass.school_year_id,
      class_id: selectedClass.id,
      residence_type: parsed.data.residenceType,
      status: 'pending',
    }).select('id').single()

    if (enrollmentError || !enrollment) {
      redirect(`/administration/eleves/${student.id}?error=${encodeURIComponent(`Élève créé, mais inscription à la classe impossible : ${enrollmentError?.message ?? 'erreur inconnue'}`)}`)
    }

    const { error: approvalError } = await supabase.from('enrollments').update({ status: 'approved' }).eq('id', enrollment.id)
    if (approvalError) {
      redirect(`/administration/eleves/${student.id}?error=${encodeURIComponent(`Élève créé, mais inscription à la classe à valider : ${approvalError.message}`)}`)
    }

    const { error: finalizeError } = await supabase.rpc('finalize_enrollment', {
      p_enrollment_id: enrollment.id,
      p_class_id: selectedClass.id,
    })
    if (finalizeError) {
      redirect(`/administration/eleves/${student.id}?error=${encodeURIComponent(`Élève créé, mais affectation à la classe à terminer : ${finalizeError.message}`)}`)
    }
    classAssigned = true
  }

  revalidatePath('/administration/eleves')
  revalidatePath(`/administration/eleves/${student.id}`)
  revalidatePath('/administration/inscriptions')
  redirect(`/administration/eleves?created=1${classAssigned ? '&classAssigned=1' : ''}`)
}
