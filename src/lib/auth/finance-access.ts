import { createClient } from '@/lib/supabase/server'
import { getCurrentUserContext } from '@/lib/auth/current-user'

export async function canManageFinance() {
  const context = await getCurrentUserContext()
  if (!context?.profile.school_id) return false
  if (context.roles.some((role) => role.code === 'super_admin')) return true
  const supabase = await createClient()
  const { data } = await supabase.from('user_roles')
    .select('school_id,roles(role_permissions(permissions(code)))')
    .eq('user_id', context.profile.id).eq('is_active', true)
  return data?.some((assignment: any) => (assignment.school_id === null || assignment.school_id === context.profile.school_id)
    && (assignment.roles?.role_permissions ?? []).some((item: any) => item.permissions?.code === 'finance.manage')) ?? false
}
