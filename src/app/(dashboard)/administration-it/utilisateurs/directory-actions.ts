'use server'

import { revalidatePath } from 'next/cache'
import { redirect } from 'next/navigation'
import { FunctionsHttpError } from '@supabase/supabase-js'
import { z } from 'zod'
import { getCurrentUserContext } from '@/lib/auth/current-user'
import { createClient } from '@/lib/supabase/server'

const stages = z.enum(['maternelle','primaire','secondaire','formation','autre','parent'])
const uuid = z.string().uuid()
function back(schoolId: string, stage: string, error?: string, flag?: string) {
  const params = new URLSearchParams({ schoolId, educationStage: stage })
  if (error) params.set('error', error)
  if (flag) params.set(flag, '1')
  return `/administration-it/utilisateurs?${params.toString()}`
}
async function invokeDirectory(body: Record<string, unknown>) {
  const context = await getCurrentUserContext()
  if (!context?.roles.some(({ code }) => code === 'it_admin')) return { error: 'Seul un Administrateur informatique peut gérer les comptes.' }
  const supabase = await createClient()
  const { error } = await supabase.functions.invoke('managed-user-directory', { body })
  if (!error) return { error: null }
  if (error instanceof FunctionsHttpError) {
    try { const result = await error.context.json(); if (typeof result?.error === 'string') return { error: result.error } } catch { /* Réponse non JSON. */ }
  }
  return { error: 'La fonction de gestion des comptes est indisponible.' }
}

export async function updateManagedUserStage(formData: FormData) {
  const schoolId = uuid.safeParse(formData.get('schoolId'))
  const userId = uuid.safeParse(formData.get('userId'))
  const current = stages.safeParse(formData.get('currentStage'))
  const next = stages.safeParse(formData.get('newStage'))
  if (!schoolId.success || !userId.success || !current.success || !next.success) redirect('/administration-it/utilisateurs?error=Param%C3%A8tres%20invalides.')
  const result = await invokeDirectory({ action: 'update-stage', schoolId: schoolId.data, userId: userId.data, educationStage: current.data, newEducationStage: next.data })
  revalidatePath('/administration-it/utilisateurs')
  if (result.error) redirect(back(schoolId.data, current.data, result.error))
  redirect(back(schoolId.data, next.data, undefined, 'updated'))
}

export async function deleteManagedUser(formData: FormData) {
  const schoolId = uuid.safeParse(formData.get('schoolId'))
  const userId = uuid.safeParse(formData.get('userId'))
  const stage = stages.safeParse(formData.get('educationStage'))
  const confirmation = z.literal('SUPPRIMER').safeParse(formData.get('confirmation'))
  if (!schoolId.success || !userId.success || !stage.success || !confirmation.success) redirect('/administration-it/utilisateurs?error=Confirmation%20ou%20param%C3%A8tres%20invalides.')
  const result = await invokeDirectory({ action: 'delete', schoolId: schoolId.data, userId: userId.data, educationStage: stage.data, confirmation: confirmation.data })
  revalidatePath('/administration-it/utilisateurs')
  revalidatePath('/administration-it/acces')
  if (result.error) redirect(back(schoolId.data, stage.data, result.error))
  redirect(back(schoolId.data, stage.data, undefined, 'deleted'))
}
