import { redirect } from 'next/navigation'
import { Sidebar } from '@/components/navigation/sidebar'
import { LogoutButton } from '@/components/auth/logout-button'
import Link from 'next/link'
import { getCurrentUserContext } from '@/lib/auth/current-user'
import { createClient } from '@/lib/supabase/server'
import { cookies } from 'next/headers'
import { ArabicStageSwitch } from '@/components/tahfiz-arabe/arabic-stage-switch'

export default async function DashboardLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  const context = await getCurrentUserContext()

  if (!context) redirect('/login')

  const schoolId = context.profile.school_id
  const role = context.roles.find((r) => r.schoolId === schoolId) ?? context.roles[0]
  const supabase = await createClient()
  const cookieStore = await cookies()
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
  const { data: permissionOverrides } = schoolId
    ? await (supabase as any).from('user_permission_overrides').select('is_granted,permissions(code)').eq('user_id', context.profile.id).eq('school_id', schoolId)
    : { data: [] }
  for (const override of permissionOverrides ?? []) {
    const code = override.permissions?.code
    if (typeof code !== 'string') continue
    if (override.is_granted) permissionCodes.add(code)
    else permissionCodes.delete(code)
  }
  const canAccessIT = context.roles.some(({ code }) => code === 'it_admin' || code === 'super_admin')
  const displayName = `${context.profile.first_name} ${context.profile.last_name}`
  const isArabicManager = context.roles.some(({ code, schoolId: roleSchoolId }) =>
    code === 'arabic_manager' && (roleSchoolId === null || roleSchoolId === schoolId)
  )
  let arabicStages: { value: string; label: string }[] = []
  if (isArabicManager && schoolId) {
    const { data: stageRows } = await (supabase as any)
      .from('user_access_stages')
      .select('education_stage')
      .eq('user_id', context.profile.id)
      .eq('school_id', schoolId)
    const labels: Record<string, string> = {
      maternelle: 'Maternelle',
      primaire: 'Primaire',
      secondaire: 'Secondaire',
      formation: 'Centre de formation',
      autre: 'Autre',
    }
    const allowed = (stageRows ?? []).map((row: any) => row.education_stage as string)
    arabicStages = (allowed.length ? allowed : ['maternelle', 'primaire', 'secondaire', 'formation', 'autre'])
      .map((value: string) => ({ value, label: labels[value] ?? value }))
  }
  const persistedArabicStage = cookieStore.get('arabic-active-stage')?.value
  const selectedArabicStage = arabicStages.some((stage) => stage.value === persistedArabicStage)
    ? persistedArabicStage!
    : arabicStages.some((stage) => stage.value === context.profile.education_stage)
      ? context.profile.education_stage!
      : arabicStages[0]?.value ?? ''

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
            {arabicStages.length >= 2 ? (
              <ArabicStageSwitch stages={arabicStages} selectedStage={selectedArabicStage} />
            ) : null}
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
