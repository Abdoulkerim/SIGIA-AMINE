import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'
import { getCurrentUserContext } from '@/lib/auth/current-user'
import { generateReportCard } from '../pedagogie-actions'

export default async function ReportCardsPage({ searchParams }: { searchParams: Promise<{ error?: string; generated?: string }> }) {
  const context = await getCurrentUserContext()
  if (!context?.profile.school_id) return null
  const params = await searchParams
  const supabase = await createClient()
  const schoolId = context.profile.school_id
  const years = (await supabase.from('school_years').select('id,name,is_current,start_date').eq('school_id', schoolId).order('start_date',{ascending:false})).data ?? []
  const yearIds = years.map(y=>y.id)
  const periods = (await supabase.from('academic_periods').select('id,name,school_year_id,is_closed,sequence_no').in('school_year_id',yearIds).order('sequence_no')).data ?? []
  const students = (await supabase.from('enrollments').select('student_id,students(id,first_name,last_name,student_number),school_year_id').eq('status','enrolled').in('school_year_id',yearIds)).data ?? []
  const { data: reports, error } = await supabase.from('report_cards').select('id,status,general_average,generated_at,published_at,students(first_name,last_name,student_number),school_years(name),academic_periods(name),classes(name)').eq('school_id',schoolId).order('generated_at',{ascending:false})
  return (
    <main className="page">
      <div className="page-header"><div><h1 className="page-title">Bulletins</h1><p className="page-subtitle">Générer les brouillons depuis les notes publiées, puis publier après clôture de la période.</p></div></div>
      {params.generated ? <p className="success">Bulletin généré.</p> : null}{params.error ? <p className="error">{params.error}</p> : null}{error ? <p className="error">{error.message}</p> : null}
      <section className="card" style={{marginBottom:20}}>
        <h2 style={{marginTop:0}}>Générer un bulletin</h2>
        <form action={generateReportCard}>
          <div className="grid grid-2">
            <label className="field"><span className="label">Élève</span><select className="select" name="studentId" required><option value="">Sélectionner</option>{students.map((row:any)=><option key={`${row.student_id}-${row.school_year_id}`} value={row.student_id}>{row.students?.student_number ?? '—'} — {row.students?.last_name} {row.students?.first_name} · année {row.school_year_id.slice(0,8)}</option>)}</select></label>
            <label className="field"><span className="label">Année scolaire</span><select className="select" name="schoolYearId" required><option value="">Sélectionner</option>{years.map(y=><option key={y.id} value={y.id}>{y.name}</option>)}</select></label>
            <label className="field"><span className="label">Période</span><select className="select" name="periodId" required><option value="">Sélectionner</option>{periods.map(p=><option key={p.id} value={p.id}>{p.name}{p.is_closed ? ' — clôturée' : ''}</option>)}</select></label>
          </div>
          <button className="button button-primary" type="submit">Générer le brouillon</button>
        </form>
      </section>
      <section className="card"><h2 style={{marginTop:0}}>Bulletins existants</h2><div className="table-wrap"><table><thead><tr><th>Élève</th><th>Année</th><th>Période</th><th>Classe</th><th>Moyenne</th><th>Statut</th><th></th></tr></thead><tbody>{(reports ?? []).map((r:any)=><tr key={r.id}><td>{r.students?.last_name} {r.students?.first_name}</td><td>{r.school_years?.name}</td><td>{r.academic_periods?.name}</td><td>{r.classes?.name}</td><td>{r.general_average ?? '—'}</td><td><span className="badge">{r.status}</span></td><td><Link className="button button-secondary" href={`/pedagogie/bulletins/${r.id}`}>Ouvrir</Link></td></tr>)}</tbody></table></div>{!reports?.length ? <p className="empty">Aucun bulletin.</p> : null}</section>
    </main>
  )
}
