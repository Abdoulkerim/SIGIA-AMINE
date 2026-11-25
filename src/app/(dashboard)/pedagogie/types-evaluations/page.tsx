import { createClient } from '@/lib/supabase/server'
import { getCurrentUserContext } from '@/lib/auth/current-user'
import { createAssessmentType } from '../pedagogie-actions'

export default async function AssessmentTypesPage({ searchParams }: { searchParams: Promise<{ error?: string; created?: string }> }) {
  const context = await getCurrentUserContext()
  if (!context?.profile.school_id) return null
  const params = await searchParams
  const supabase = await createClient()
  const { data: types, error } = await supabase.from('assessment_types').select('id,code,name,is_active').eq('school_id', context.profile.school_id).order('name')
  const { data: roleAssignments } = await supabase
    .from('user_roles')
    .select('school_id,roles(code,role_permissions(permissions(code)))')
    .eq('user_id', context.profile.id)
    .eq('is_active', true)
  const isTeacher = context.roles.some((role) => role.code === 'teacher')
  const canManageTypes = !isTeacher && (
    context.roles.some((role) => ['super_admin', 'founder', 'direction', 'academic_director'].includes(role.code ?? ''))
    || (roleAssignments ?? []).some((assignment: any) =>
      (assignment.school_id === null || assignment.school_id === context.profile.school_id)
      && (assignment.roles?.role_permissions ?? []).some((item: any) => item.permissions?.code === 'assessments.manage')
    )
  )
  return (
    <main className="page">
      <div className="page-header"><div><h1 className="page-title">Types d’évaluations</h1><p className="page-subtitle">Catalogue configurable. Aucun type officiel Al Amine n'est inventé dans cette livraison.</p></div></div>
      {params.created ? <p className="success">Type créé.</p> : null}
      {params.error ? <p className="error">{params.error}</p> : null}
      {error ? <p className="error">{error.message}</p> : null}
      <section className="grid grid-2">
        {canManageTypes ? <div className="card">
          <h2 style={{ marginTop: 0 }}>Nouveau type</h2>
          <form action={createAssessmentType}>
            <label className="field"><span className="label">Code</span><input className="input" name="code" placeholder="Ex. DEVOIR" required /></label>
            <label className="field"><span className="label">Nom</span><input className="input" name="name" placeholder="Ex. Devoir surveillé" required /></label>
            <button className="button button-primary" type="submit">Créer</button>
          </form>
        </div> : null}
        <div className="card">
          <h2 style={{ marginTop: 0 }}>Catalogue</h2>
          <div className="table-wrap"><table><thead><tr><th>Code</th><th>Nom</th><th>Statut</th></tr></thead><tbody>{(types ?? []).map(t => <tr key={t.id}><td>{t.code}</td><td>{t.name}</td><td><span className="badge">{t.is_active ? 'Actif' : 'Inactif'}</span></td></tr>)}</tbody></table></div>
          {!types?.length ? <p className="empty">Aucun type configuré.</p> : null}
        </div>
      </section>
    </main>
  )
}
