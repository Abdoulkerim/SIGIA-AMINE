import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'
import { getCurrentUserContext } from '@/lib/auth/current-user'
import { generateSpecializedReportCards, publishSpecializedReportCard } from '@/app/(dashboard)/specialized-report-card-actions'

type Module = 'wushu' | 'arabic' | 'tahfiz'

export async function SpecializedReportCards({
  module, title, backHref, searchParams,
}: {
  module: Module
  title: string
  backHref: string
  searchParams: Promise<{ error?: string; generated?: string; published?: string }>
}) {
  const query = await searchParams
  const context = await getCurrentUserContext()
  const schoolId = context?.profile.school_id
  if (!schoolId) return null
  const supabase = await createClient()
  const db = supabase as any
  const [{ data: cards }, { data: assignments }] = await Promise.all([
    db.from('specialized_report_cards')
    .select('id,student_id,period_start,period_end,average_score,evaluation_count,evaluations,status,published_at,students(first_name,last_name,student_number)')
    .eq('school_id', schoolId).eq('module', module).order('period_start', { ascending: false }).order('average_score', { ascending: false }).limit(250),
    supabase.from('user_roles').select('school_id,roles(role_permissions(permissions(code)))').eq('user_id', context!.profile.id).eq('is_active', true),
  ])
  const managePermission = `${module}.manage`
  const canManage = context.roles.some((role) => role.code === 'super_admin') || (assignments?.some((assignment: any) => (assignment.school_id === null || assignment.school_id === schoolId)
    && (assignment.roles?.role_permissions ?? []).some((item: any) => item.permissions?.code === managePermission)) ?? false)

  return <main className="page">
    <div className="page-header"><div><p className="page-subtitle">Résultats des évaluations publiées</p><h1 className="page-title">Bulletins {title}</h1><p className="page-subtitle">Générez un bulletin par élève à partir des évaluations notées de la période.</p></div><Link className="button button-secondary" href={backHref}>Retour au groupe</Link></div>
    {query.error ? <p className="error">{query.error}</p> : null}
    {query.generated !== undefined ? <p className="success">{query.generated} bulletin(s) généré(s) ou actualisé(s). Seuls les brouillons sont actualisés.</p> : null}
    {query.published ? <p className="success">Bulletin publié.</p> : null}
    {canManage ? <section className="card"><h2>Créer les bulletins de la période</h2><p className="page-subtitle">Les évaluations doivent d’abord être publiées. Une nouvelle génération actualise les brouillons, mais conserve les bulletins déjà publiés.</p>
      <form action={generateSpecializedReportCards} className="grid grid-3">
        <input type="hidden" name="module" value={module}/>
        <label className="field"><span className="label">Du</span><input className="input" type="date" name="periodStart" required defaultValue={`${new Date().getFullYear()}-01-01`}/></label>
        <label className="field"><span className="label">Au</span><input className="input" type="date" name="periodEnd" required defaultValue={new Date().toISOString().slice(0, 10)}/></label>
        <div><button className="button button-primary" type="submit">Générer les bulletins</button></div>
      </form>
    </section> : <p className="page-subtitle">Vous pouvez consulter les bulletins publiés. La génération et la publication sont réservées aux responsables du groupe.</p>}
    <section className="card" style={{ marginTop: 16 }}><h2>Bulletins créés</h2>{cards?.length ? <div className="table-wrap"><table><thead><tr><th>Élève</th><th>Période</th><th>Moyenne</th><th>Évaluations</th><th>État</th><th>Résultats</th><th>Action</th></tr></thead><tbody>{cards.map((card: any) => {
      const student = Array.isArray(card.students) ? card.students[0] : card.students
      const evaluations = Array.isArray(card.evaluations) ? card.evaluations : []
      return <tr key={card.id}><td>{student ? `${student.last_name} ${student.first_name}` : 'Élève'}</td><td>{card.period_start} – {card.period_end}</td><td>{Number(card.average_score).toLocaleString('fr-FR')}</td><td>{card.evaluation_count}</td><td><span className="badge">{card.status === 'published' ? 'Publié' : 'Brouillon'}</span></td><td><details><summary>Voir le détail</summary><ul>{evaluations.map((evaluation: any, index: number) => <li key={`${card.id}-${index}`}>{evaluation.date} · {evaluation.type}{evaluation.area ? ` (${evaluation.area})` : ''} · {evaluation.score}{evaluation.max_score ? ` / ${evaluation.max_score}` : ''}{evaluation.grade ? ` · Grade ${evaluation.grade}` : ''}{evaluation.surah ? ` · ${evaluation.surah}` : ''}{evaluation.observation ? ` — ${evaluation.observation}` : ''}</li>)}</ul></details></td><td>{module === 'arabic' ? <Link className="button button-secondary" href={`/tahfiz-arabe/arabe/bulletins/${card.id}`}>Bulletin</Link> : null}{module === 'wushu' ? <Link className="button button-secondary" href={`/wushu/bulletins/${card.id}`}>Bulletin</Link> : null}{card.status === 'draft' && canManage ? <form action={publishSpecializedReportCard}><input type="hidden" name="module" value={module}/><input type="hidden" name="reportCardId" value={card.id}/><button className="button button-secondary" type="submit">Publier</button></form> : null}{card.status !== 'draft' || !canManage ? (module === 'arabic' || module === 'wushu' ? null : '—') : null}</td></tr>
    })}</tbody></table></div> : <p className="empty">Aucun bulletin pour le moment. Choisissez une période et générez les bulletins.</p>}</section>
    <p className="page-subtitle" style={{ marginTop: 12 }}>Un bulletin ne contient que les évaluations notées et publiées pendant sa période. La moyenne est calculée à partir des notes enregistrées.</p>
  </main>
}
