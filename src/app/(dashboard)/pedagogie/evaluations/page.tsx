import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'
import { getCurrentUserContext } from '@/lib/auth/current-user'
import { publishAssessment } from '../pedagogie-actions'

export default async function AssessmentsPage({ searchParams }: { searchParams: Promise<{ error?: string; published?: string }> }) {
  const context = await getCurrentUserContext()
  if (!context?.profile.school_id) return null
  const params = await searchParams
  const supabase = await createClient()
  const { data: assessments, error } = await supabase
    .from('assessments')
    .select('id,title,assessment_date,max_score,is_published,school_years(name),academic_periods(name),classes(name,code),subjects(name,code),employees(first_name,last_name),assessment_types(name)')
    .eq('school_id', context.profile.school_id)
    .order('assessment_date', { ascending: false })
  return (
    <main className="page">
      <div className="page-header"><div><h1 className="page-title">Évaluations</h1><p className="page-subtitle">Création, saisie des notes et publication des évaluations.</p></div><Link className="button button-primary" href="/pedagogie/evaluations/nouveau">+ Nouvelle évaluation</Link></div>
      {params.published ? <p className="success">Évaluation publiée.</p> : null}{params.error ? <p className="error">{params.error}</p> : null}{error ? <p className="error">{error.message}</p> : null}
      <section className="card"><div className="table-wrap"><table><thead><tr><th>Date</th><th>Évaluation</th><th>Classe</th><th>Matière</th><th>Enseignant</th><th>Période</th><th>Barème</th><th>Statut</th><th></th></tr></thead><tbody>
        {(assessments ?? []).map((a: any) => <tr key={a.id}><td>{a.assessment_date}</td><td>{a.title}<div style={{fontSize:12,color:'var(--muted)'}}>{a.assessment_types?.name ?? 'Type non défini'}</div></td><td>{a.classes?.name ?? '—'}</td><td>{a.subjects?.name ?? '—'}</td><td>{a.employees ? `${a.employees.last_name} ${a.employees.first_name}` : '—'}</td><td>{a.academic_periods?.name ?? '—'}</td><td>{a.max_score}</td><td><span className="badge">{a.is_published ? 'Publiée' : 'Brouillon'}</span></td><td style={{display:'flex',gap:8}}><Link className="button button-secondary" href={`/pedagogie/evaluations/${a.id}/notes`}>Notes</Link>{!a.is_published ? <form action={publishAssessment}><input type="hidden" name="id" value={a.id} /><button className="button button-primary" type="submit">Publier</button></form> : null}</td></tr>)}
      </tbody></table></div>{!assessments?.length ? <p className="empty">Aucune évaluation.</p> : null}</section>
    </main>
  )
}
