import { redirect } from 'next/navigation'
import { Sidebar } from '@/components/navigation/sidebar'
import { LogoutButton } from '@/components/auth/logout-button'
import { getCurrentUserContext } from '@/lib/auth/current-user'

export default async function DashboardLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  const context = await getCurrentUserContext()

  if (!context) redirect('/login')

  const schoolId = context.profile.school_id
  const role = context.roles.find((r) => r.schoolId === schoolId) ?? context.roles[0]
  const canAccessIT = context.roles.some(({ code }) => ['it_admin', 'super_admin', 'founder'].includes(code ?? ''))
  const displayName = `${context.profile.first_name} ${context.profile.last_name}`

  return (
    <div className="app-shell">
      <Sidebar canAccessIT={canAccessIT} />
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
            <LogoutButton />
          </div>
        </header>
        <div className="container">{children}</div>
      </div>
    </div>
  )
}
