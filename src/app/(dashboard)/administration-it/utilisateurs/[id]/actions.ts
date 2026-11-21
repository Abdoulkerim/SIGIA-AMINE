'use server'

import { revalidatePath } from 'next/cache'
import { redirect } from 'next/navigation'
import { FunctionsHttpError } from '@supabase/supabase-js'
import { z } from 'zod'
import { getCurrentUserContext } from '@/lib/auth/current-user'
import { createClient } from '@/lib/supabase/server'

export async function setTemporaryPassword(formData: FormData) {
  const parsed = z.object({ userId: z.string().uuid(), password: z.string().min(10).max(128) }).safeParse(Object.fromEntries(formData))
  if (!parsed.success) redirect('/administration-it/utilisateurs?error=Mot%20de%20passe%20invalide.')
  const context = await getCurrentUserContext()
  const allowed = context?.roles.some(({ code }) => code === 'it_admin' || code === 'super_admin')
  if (!context || !allowed) redirect('/dashboard')
  const supabase = await createClient()
  const { error } = await supabase.functions.invoke('managed-user-directory', {
    body: { action: 'set-password', userId: parsed.data.userId, password: parsed.data.password },
  })
  if (error) {
    let message = error.message
    if (error instanceof FunctionsHttpError) {
      try {
        const result = await error.context.json()
        if (typeof result?.error === 'string') message = result.error
      } catch { /* Réponse non JSON. */ }
    }
    redirect(`/administration-it/utilisateurs/${parsed.data.userId}?error=${encodeURIComponent(message)}`)
  }
  revalidatePath('/administration-it/utilisateurs')
  redirect(`/administration-it/utilisateurs/${parsed.data.userId}?updated=1`)
}

export async function linkTeacherProfile(formData: FormData) {
  const parsed = z.object({ userId: z.string().uuid(), schoolId: z.string().uuid(), employeeId: z.string().uuid() }).safeParse(Object.fromEntries(formData))
  if (!parsed.success) redirect('/administration-it/utilisateurs?error=Param%C3%A8tres%20invalides.')
  const context = await getCurrentUserContext()
  if (!context || !context.roles.some(({ code }) => code === 'it_admin' || code === 'super_admin')) redirect('/dashboard')
  const supabase = await createClient()
  const { error } = await (supabase as any).rpc('set_teacher_profile_link', {
    p_actor_user_id: context.profile.id,
    p_user_id: parsed.data.userId,
    p_school_id: parsed.data.schoolId,
    p_employee_id: parsed.data.employeeId,
  })
  if (error) {
    let message = error.message
    redirect(`/administration-it/utilisateurs/${parsed.data.userId}?error=${encodeURIComponent(message)}`)
  }
  revalidatePath('/pedagogie/evaluations')
  revalidatePath(`/administration-it/utilisateurs/${parsed.data.userId}`)
  redirect(`/administration-it/utilisateurs/${parsed.data.userId}?linked=1`)
}
