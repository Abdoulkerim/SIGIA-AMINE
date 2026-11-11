import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'
import { getCurrentUserContext } from '@/lib/auth/current-user'
import { ReportActions } from '@/components/reports/report-actions'
import { ReportCardGenerator } from '@/components/reports/report-card-generator'

export default async function ReportCardsPage({ searchParams }: { searchParams: Promise<{ error?: string; generated?: string; failed?: string; classId?: string }> }) {
  const context = await getCurrentUserContext()
  if (!context?.profile.school_id) return null
  const params = await searchParams
  const supabase = await createClient()
  const schoolId = context.profile.school_id
  const years = (await supabase.from('school_years').select('id,name,is_current,start_date').eq('school_id', schoolId).order('start_date', { ascending: false })).data ?? []
  const yearIds = years.map((year) => year.id)
  const periods = yearIds.length ? (await supabase.from('academic_periods').select('id,name,school_year_id,is_closed,sequence_no').in('school_year_id', yearIds).order('sequence_no')).data ?? [] : []
  const enrollments = yearIds.length ? (await supabase.from('enrollments').select('student_id,class_id,students(first_name,last_name),school_year_id').eq('school_id', schoolId).eq('status', 'enrolled').in('school_year_id', yearIds)).data ?? [] : []
  const { data: reports, error } = await supabase.from('report_cards').select('id,status,general_average,generated_at,published_at,students(first_name,last_name,student_number),school_years(name),academic_periods(name),classes(id,name)').eq('school_id', schoolId).order('generated_at', { ascending: false })
  const { data: classes } = yearIds.length ? await supabase.from('classes').select('id,name,school_year_id').eq('school_id', schoolId).in('school_year_id', yearIds).order('name') : { data: [] }
  const visibleReports = (reports ?? []).filter((report: any) => !params.classId || report.classes?.id === params.classId)

  return <main className="page">
    <div className="page-header"><div><h1 className="page-title">Bulletins</h1><p className="page-subtitle">Générer les brouillons depuis les notes publiées, puis publier après clôture de la période.</p></div></div>
    {params.generated ? <p className="success">{params.generated} bulletin(s) généré(s).{params.failed ? ` ${params.failed} élève(s) sans bulletin : aucune note publiée pour la période ou données incomplètes.` : ''}</p> : null}
    {params.error ? <p className="error">{params.error}</p> : null}{error ? <p className="error">{error.message}</p> : null}
    <ReportCardGenerator years={years as any} periods={periods as any} classes={(classes ?? []) as any} enrollments={enrollments as any} />
    <section className="card" style={{ marginBottom: 16 }}><form method="get" className="grid grid-3"><label className="field"><span className="label">Classe</span><select className="select" name="classId" defaultValue={params.classId ?? ''}><option value="">Toutes les classes</option>{(classes ?? []).map((item: any) => <option key={item.id} value={item.id}>{item.name}</option>)}</select></label><div className="field"><span className="label">Bulletins affichés</span><span>{visibleReports.length}</span></div><div className="field" style={{ alignSelf: 'end' }}><button className="button button-secondary" type="submit">Afficher</button></div></form></section>
    <ReportActions title={`Bulletins${params.classId ? ` — ${(classes ?? []).find((item: any) => item.id === params.classId)?.name ?? ''}` : ''}`} fileName="liste-bulletins" headers={['Élève', 'Matricule', 'Année', 'Période', 'Classe', 'Moyenne générale', 'Statut']} rows={visibleReports.map((r: any) => [`${r.students?.last_name ?? ''} ${r.students?.first_name ?? ''}`.trim(), r.students?.student_number, r.school_years?.name, r.academic_periods?.name, r.classes?.name, r.general_average, r.status])} />
    <section className="card"><h2 style={{ marginTop: 0 }}>Bulletins existants</h2><div className="table-wrap"><table><thead><tr><th>Élève</th><th>Année</th><th>Période</th><th>Classe</th><th>Moyenne</th><th>Statut</th><th></th></tr></thead><tbody>{visibleReports.map((r: any) => <tr key={r.id}><td>{r.students?.last_name} {r.students?.first_name}</td><td>{r.school_years?.name}</td><td>{r.academic_periods?.name}</td><td>{r.classes?.name}</td><td>{r.general_average ?? '—'}</td><td><span className="badge">{r.status}</span></td><td><Link className="button button-secondary" href={`/pedagogie/bulletins/${r.id}`}>Ouvrir</Link></td></tr>)}</tbody></table></div>{!visibleReports.length ? <p className="empty">Aucun bulletin pour ce filtre.</p> : null}</section>
  </main>
}
