import Link from 'next/link'
import { getDashboard } from '../dashboard-actions'

function n(value: unknown) { return typeof value === 'number' ? value.toLocaleString('fr-FR') : '0' }
function obj(value: unknown) { return (value && typeof value === 'object' ? value : {}) as Record<string, any> }

export default async function PedagogyDashboardPage() {
  const data = await getDashboard('pedagogy')
  const assessments=obj(data.assessments), cards=obj(data.report_cards), attendance=obj(data.attendance_30d)
  const classRows=Array.isArray(data.class_performance)?data.class_performance:[]
  const subjectRows=Array.isArray(data.subject_performance)?data.subject_performance:[]
  return <main className="page">
    <div className="page-header"><div><h1 className="page-title">Tableau de bord pédagogique</h1><p className="page-subtitle">Évaluations, notes, bulletins, résultats et assiduité.</p></div><Link href="/statistiques" className="button button-secondary">← Dashboards</Link></div>
    <section className="grid grid-4">
      {[['Évaluations',n(assessments.total)],['Évaluations publiées',n(assessments.published)],['Notes saisies',n(assessments.grades)],['Bulletins publiés',n(cards.published)],['Moyenne générale',n(cards.average)],['Présences',n(attendance.present)],['Absences',n(attendance.absent)],['Retards',n(attendance.late)]].map(([label,value])=><div className="card" key={label}><div className="stat-label">{label}</div><div className="stat-value">{value}</div></div>)}
    </section>
    <section className="grid grid-2" style={{marginTop:16}}>
      <div><h2>Résultats par classe</h2><div className="table-wrap"><table><thead><tr><th>Classe</th><th>Moyenne publiée</th><th>Bulletins</th></tr></thead><tbody>{classRows.map((r:any)=><tr key={r.class_id}><td>{r.class_name}</td><td>{r.average}</td><td>{n(r.report_cards)}</td></tr>)}</tbody></table></div></div>
      <div><h2>Résultats par matière</h2><div className="table-wrap"><table><thead><tr><th>Matière</th><th>Moyenne</th><th>Éléments</th></tr></thead><tbody>{subjectRows.map((r:any)=><tr key={r.subject_id}><td>{r.subject_name}</td><td>{r.average}</td><td>{n(r.items)}</td></tr>)}</tbody></table></div></div>
    </section>
  </main>
}
