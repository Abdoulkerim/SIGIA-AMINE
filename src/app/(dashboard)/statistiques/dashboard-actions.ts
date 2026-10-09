'use server'

import { createClient } from '@/lib/supabase/server'
import { getCurrentUserContext } from '@/lib/auth/current-user'

export type DashboardCode = 'direction' | 'pedagogy' | 'finance' | 'boarding' | 'activities'

export async function getDashboard(code: DashboardCode) {
  const context = await getCurrentUserContext()
  if (!context?.profile.school_id) throw new Error('Session ou établissement introuvable.')

  const supabase = await createClient()
  const rpcByCode: Record<DashboardCode, string> = {
    direction: 'get_dashboard_direction',
    pedagogy: 'get_dashboard_pedagogy',
    finance: 'get_dashboard_finance',
    boarding: 'get_dashboard_boarding',
    activities: 'get_dashboard_activities',
  }

  const { data, error } = await supabase.rpc(rpcByCode[code], { p_school_id: context.profile.school_id })
  if (error) throw new Error(error.message)
  return data as Record<string, unknown>
}

export async function getAvailableDashboards() {
  const context = await getCurrentUserContext()
  if (!context?.profile.school_id) return [] as string[]

  const supabase = await createClient()
  const { data, error } = await supabase.rpc('get_available_dashboards', { p_school_id: context.profile.school_id })
  if (error) throw new Error(error.message)
  return Array.isArray(data) ? (data as string[]) : []
}
