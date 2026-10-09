import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'

export default async function WushuPage() {
  const supabase = await createClient()
  const { data: stats } = await supabase.rpc('get_wushu_dashboard')
  const { data: groups } = await supabase.from('wushu_groups').select('id,code,name,level,is_active').eq('is_active', true).order('name').limit(20)
  const s = stats as any ?? { groups: 0, students: 0, sessions: 0, evaluations: 0, competitions: 0 }
  return (
    <main className="page">
      <div className="page-header"><div><p className="page-subtitle">Formation physique spécialisée</p><h1 className="page-title">Wushu</h1><p className="page-subtitle">Groupes, entraînements, présences, évaluations, grades et compétitions.</p></div><div className="actions"><Link className="button button-primary" href="/wushu/entrainements">Nouvelle séance</Link></div></div>
      <section className="grid grid-4" style={{marginBottom:16}}>
        <article className="card"><div className="stat-label">Groupes actifs</div><div className="stat-value">{s.groups ?? 0}</div></article>
        <article className="card"><div className="stat-label">Élèves actifs</div><div className="stat-value">{s.students ?? 0}</div></article>
        <article className="card"><div className="stat-label">Séances (30 j)</div><div className="stat-value">{s.sessions ?? 0}</div></article>
        <article className="card"><div className="stat-label">Évaluations (90 j)</div><div className="stat-value">{s.evaluations ?? 0}</div></article>
      </section>
      <section className="grid grid-2">
        <article className="card"><h2>Accès rapides</h2><div className="grid grid-2"><Link className="button button-secondary" href="/wushu/groupes">Groupes</Link><Link className="button button-secondary" href="/wushu/eleves">Élèves Wushu</Link><Link className="button button-secondary" href="/wushu/entrainements">Entraînements</Link><Link className="button button-secondary" href="/wushu/presences">Présences</Link><Link className="button button-secondary" href="/wushu/evaluations">Évaluations / grades</Link><Link className="button button-secondary" href="/wushu/competitions">Compétitions</Link></div></article>
        <article className="card"><h2>Groupes actifs</h2>{groups?.length ? <div className="table-wrap"><table><thead><tr><th>Code</th><th>Groupe</th><th>Niveau</th></tr></thead><tbody>{groups.map(g => <tr key={g.id}><td>{g.code || '—'}</td><td>{g.name}</td><td>{g.level || '—'}</td></tr>)}</tbody></table></div> : <p className="empty">Aucun groupe actif visible.</p>}</article>
      </section>
      <section className="card" style={{marginTop:16}}><h2>Règles du module</h2><p>Les grades, échelles de score et critères de passage restent paramétrables. Aucun barème sportif n'est imposé par le cahier des charges fourni.</p></section>
    </main>
  )
}
