import { createClient } from '@/lib/supabase/server'

export async function getCurrentUserContext() {
  const supabase = await createClient()
  const { data, error: claimsError } = await supabase.auth.getClaims()
  const claims = data?.claims

  if (claimsError || !claims?.sub) return null

  const { data: profile, error } = await supabase
    .from('users')
    .select('id, first_name, last_name, email, school_id, status')
    .eq('id', claims.sub)
    .single()

  if (error || !profile) return null

  const { data: roleRows } = await supabase
    .from('user_roles')
    .select('school_id, roles(code, name)')
    .eq('user_id', claims.sub)
    .eq('is_active', true)

  const roles = (roleRows ?? []).map((row: any) => ({
    code: row.roles?.code as string | undefined,
    name: row.roles?.name as string | undefined,
    schoolId: row.school_id as string | null,
  })).filter((r) => r.code && r.name)

  return { claims, profile, roles }
}
