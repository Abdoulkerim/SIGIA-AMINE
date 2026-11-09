'use server'

import { revalidatePath } from 'next/cache'
import { redirect } from 'next/navigation'
import { z } from 'zod'
import { createClient } from '@/lib/supabase/server'

const modules = {
  wushu: '/wushu/bulletins',
  arabic: '/tahfiz-arabe/arabe/bulletins',
  tahfiz: '/tahfiz-arabe/tahfiz/bulletins',
} as const

export async function generateSpecializedReportCards(formData: FormData) {
  const module = z.enum(['wushu', 'arabic', 'tahfiz']).safeParse(formData.get('module'))
  const start = z.string().regex(/^\d{4}-\d{2}-\d{2}$/).safeParse(formData.get('periodStart'))
  const end = z.string().regex(/^\d{4}-\d{2}-\d{2}$/).safeParse(formData.get('periodEnd'))
  if (!module.success || !start.success || !end.success || start.data > end.data) {
    redirect(`${module.success ? modules[module.data] : '/wushu/bulletins'}?error=${encodeURIComponent('Sélectionnez une période valide.')}`)
  }
  const supabase = await createClient()
  const { data: user } = await supabase.auth.getUser()
  if (!user.user) redirect('/connexion')
  const { data: profile } = await supabase.from('users').select('school_id').eq('id', user.user.id).maybeSingle()
  if (!profile?.school_id) redirect(`${modules[module.data]}?error=${encodeURIComponent('École introuvable pour ce compte.')}`)
  const { data, error } = await (supabase as any).rpc('generate_specialized_report_cards', {
    p_module: module.data,
    p_period_start: start.data,
    p_period_end: end.data,
    p_school_id: profile.school_id,
  })
  if (error) redirect(`${modules[module.data]}?error=${encodeURIComponent(error.message)}`)
  revalidatePath(modules[module.data])
  redirect(`${modules[module.data]}?generated=${Number(data ?? 0)}`)
}

export async function publishSpecializedReportCard(formData: FormData) {
  const module = z.enum(['wushu', 'arabic', 'tahfiz']).safeParse(formData.get('module'))
  const id = z.string().uuid().safeParse(formData.get('reportCardId'))
  if (!module.success || !id.success) redirect('/wushu/bulletins?error=Bulletin%20invalide.')
  const path = modules[module.data]
  const supabase = await createClient()
  const { error } = await (supabase as any).rpc('publish_specialized_report_card', { p_report_card_id: id.data })
  if (error) redirect(`${path}?error=${encodeURIComponent(error.message)}`)
  revalidatePath(path)
  redirect(`${path}?published=1`)
}
