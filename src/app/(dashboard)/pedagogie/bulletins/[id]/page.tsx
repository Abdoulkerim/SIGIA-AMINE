import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'
import { getCurrentUserContext } from '@/lib/auth/current-user'
import { publishReportCard } from '../../pedagogie-actions'

export default async function ReportCardDetailPage({ params, searchParams }: { params: Promise<{ id: string }>; searchParams: Promise<{ error?: string; generated?: string; published?: string }> }) {
  const { id } = await params
  const query = await searchParams
  const context = await getCurrentUserContext()
  if (!context?.profile.school_id) return null
  const supabase = await createClient()
  const { data: report, error } = await supabase.from('report_cards').select('id,status,general_average,rank,decision,overall_observation,generated_at,published_at,students!report_cards_student_id_fkey(first_name,last_name,student_number),school_years!report_cards_school_year_id_fkey(name),academic_periods!report_cards_period_id_fkey(name,is_closed),classes!report_cards_class_id_fkey(name,code)').eq('id',id).single().overrideTypes<{
    students: { first_name: string; last_name: string; student_number: string | null } | null
    school_years: { name: string } | null
    academic_periods: { name: string; is_closed: boolean } | null
    classes: { name: string; code: string } | null
  }>()
  const { data: items } = await supabase.from('report_card_items').select('id,average,coefficient,rank,teacher_comment,subjects(name,code)').eq('report_card_id',id).order('id')
  if (error || !report) return <main className="page"><p className="error">Bulletin introuvable.</p></main>
  const periodClosed = report.academic_periods?.is_closed
  return (
    <main className="page">
      <div className="page-header"><div><h1 className="page-title">Bulletin</h1><p className="page-subtitle">{report.students?.last_name} {report.students?.first_name} · {report.academic_periods?.name} · {report.school_years?.name}</p></div><Link className="button button-secondary" href="/pedagogie/bulletins">Retour</Link></div>
      {query.generated ? <p className="success">Brouillon généré.</p> : null}{query.published ? <p className="success">Bulletin publié.</p> : null}{query.error ? <p className="error">{query.error}</p> : null}
      <section className="grid grid-4"><Stat label="Moyenne générale" value={report.general_average ?? '—'} /><Stat label="Rang" value={report.rank ?? '—'} /><Stat label="Décision" value={report.decision ?? '—'} /><Stat label="Statut" value={report.status} /></section>
      <section className="card" style={{marginTop:20}}><div className="table-wrap"><table><thead><tr><th>Matière</th><th>Moyenne</th><th>Coef.</th><th>Rang</th><th>Commentaire</th></tr></thead><tbody>{(items ?? []).map((item:any)=><tr key={item.id}><td>{item.subjects?.name ?? '—'}</td><td>{item.average ?? '—'}</td><td>{item.coefficient}</td><td>{item.rank ?? '—'}</td><td>{item.teacher_comment ?? '—'}</td></tr>)}</tbody></table></div>{!items?.length ? <p className="empty">Aucune ligne de bulletin.</p> : null}</section>
      <section className="card" style={{marginTop:20}}>
        <p style={{marginTop:0,color:'var(--muted)'}}>Règles officielles non fournies : le rang et la décision restent volontairement non calculés.</p>
        <div style={{display:'flex',gap:10,flexWrap:'wrap'}}>
          {report.status !== 'published' ? <form action={publishReportCard}><input type="hidden" name="id" value={report.id} /><button className="button button-primary" type="submit">Publier le bulletin</button></form> : <span className="badge">Bulletin publié</span>}
          {!periodClosed && report.status !== 'published' ? <span className="badge">La période doit être clôturée avant publication</span> : null}
        </div>
      </section>
    </main>
  )
}
function Stat({label,value}:{label:string;value:React.ReactNode}){return <div className="card"><div className="stat-label">{label}</div><div className="stat-value" style={{fontSize:22}}>{value}</div></div>}
