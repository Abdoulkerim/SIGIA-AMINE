import { redirect } from 'next/navigation'
import { Sidebar } from '@/components/navigation/sidebar'
import { LogoutButton } from '@/components/auth/logout-button'
import Link from 'next/link'
import { getCurrentUserContext } from '@/lib/auth/current-user'
import { createClient } from '@/lib/supabase/server'

export default async function DashboardLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  const context = await getCurrentUserContext()

  if (!context) redirect('/login')

  const schoolId = context.profile.school_id
  const role = context.roles.find((r) => r.schoolId === schoolId) ?? context.roles[0]
  const canAccessIT = context.roles.some(({ code }) => code === 'it_admin')
  const supabase = await createClient()
  const { data: roleAssignments } = await supabase
    .from('user_roles')
    .select('school_id,roles(role_permissions(permissions(code)))')
    .eq('user_id', context.profile.id)
    .eq('is_active', true)
  const permissionCodes = new Set<string>()
  for (const assignment of roleAssignments ?? []) {
    if (assignment.school_id !== null && assignment.school_id !== schoolId) continue
    const assignedRole = assignment.roles as any
    for (const item of assignedRole?.role_permissions ?? []) {
      const code = item.permissions?.code
      if (typeof code === 'string') permissionCodes.add(code)
    }
  }
  const displayName = `${context.profile.first_name} ${context.profile.last_name}`

  return (
    <div className="app-shell">
      <Sidebar canAccessIT={canAccessIT} permissionCodes={[...permissionCodes]} />
      <div className="main">
        <header className="topbar">
          <div>
            <div className="user-name">Complexe Scolaire Al Amine</div>
            <div className="user-role">Espace sécurisé SIGIA-AMINE</div>
          </div>
          <div className="user-chip">
            <div>
              <div className="user-name">{displayName}</div>
              <div className="user-role">{role?.name ?? 'Utilisateur'}</div>
            </div>
            <Link className="button button-secondary" href="/mon-compte">Mon compte</Link>
            <LogoutButton />
          </div>
        </header>
        <div className="container">{children}</div>
      </div>
    </div>
  )
}
