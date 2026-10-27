import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'
import { getCurrentUserContext } from '@/lib/auth/current-user'
import { createWushuGroup } from '../wushu-actions'

const stages = [
  ['maternelle', 'Maternelle'],
  ['primaire', 'Primaire'],
  ['secondaire', 'Secondaire'],
  ['formation', 'Centre de formation'],
  ['autre', 'Autre'],
] as const

const stageLabels = Object.fromEntries(stages) as Record<string, string>

export default async function WushuGroupsPage({ searchParams }: { searchParams: Promise<{ error?: string; created?: string }> }) {
  const [params, context, supabase] = await Promise.all([searchParams, getCurrentUserContext(), createClient()])
  const isSuperAdmin = context?.roles.some(({ code }) => code === 'super_admin') ?? false
  const userStage = context?.profile.education_stage ?? null
  const availableStages = isSuperAdmin ? stages : stages.filter(([value]) => value === userStage)
  const defaultStage = availableStages.length === 1 ? availableStages[0][0] : ''

  const [{ data: groups }, { data: coaches }] = await Promise.all([
    supabase.from('wushu_groups').select('id,code,name,level,education_stage,coach_employee_id,is_active,created_at').order('name'),
    supabase.from('employees').select('id,first_name,last_name,employee_number').eq('status','active').order('last_name').limit(200),
  ])

  return <main className="page">
    <div className="page-header">
      <div><h1 className="page-title">Groupes Wushu</h1><p className="page-subtitle">Organisation des groupes, niveaux et responsables.</p></div>
    </div>
    {params.error ? <p className="error">{params.error}</p> : null}
    {params.created ? <p className="success">Groupe créé.</p> : null}
    {!isSuperAdmin && !userStage ? <p className="error">Attribuez d’abord un cycle à votre compte dans <Link href="/administration-it/acces">Administration IT → Accès</Link> pour créer un groupe Wushu.</p> : null}

    <section className="card">
      <h2>Nouveau groupe</h2>
      <form action={createWushuGroup} className="grid grid-4">
        <div className="field"><label className="label" htmlFor="wushu-code">Code</label><input className="input" id="wushu-code" name="code" /></div>
        <div className="field"><label className="label" htmlFor="wushu-name">Nom *</label><input className="input" id="wushu-name" name="name" required /></div>
        <div className="field"><label className="label" htmlFor="wushu-level">Niveau</label><input className="input" id="wushu-level" name="level" /></div>
        <div className="field"><label className="label" htmlFor="wushu-stage">Cycle scolaire *</label><select className="select" id="wushu-stage" name="educationStage" required defaultValue={defaultStage} disabled={!availableStages.length}><option value="" disabled>Choisir un cycle</option>{availableStages.map(([value, label]) => <option key={value} value={value}>{label}</option>)}</select></div>
        <div className="field"><label className="label" htmlFor="wushu-coach">Coach</label><select className="select" id="wushu-coach" name="coachEmployeeId"><option value="">—</option>{coaches?.map(c => <option key={c.id} value={c.id}>{c.last_name} {c.first_name} · {c.employee_number}</option>)}</select></div>
        <div><button className="button button-primary" type="submit" disabled={!availableStages.length}>Créer</button></div>
      </form>
    </section>

    <section className="card" style={{marginTop:16}}>
      <h2>Groupes enregistrés</h2>
      {groups?.length ? <div className="table-wrap"><table><thead><tr><th>Code</th><th>Nom</th><th>Cycle</th><th>Niveau</th><th>Coach</th><th>Actif</th></tr></thead><tbody>{groups.map(g => <tr key={g.id}><td>{g.code || '—'}</td><td>{g.name}</td><td>{g.education_stage ? stageLabels[g.education_stage] ?? g.education_stage : '—'}</td><td>{g.level || '—'}</td><td>{coaches?.find(c => c.id === g.coach_employee_id)?.last_name || '—'}</td><td><span className="badge">{g.is_active ? 'Actif' : 'Inactif'}</span></td></tr>)}</tbody></table></div> : <p className="empty">Aucun groupe.</p>}
    </section>
  </main>
}
