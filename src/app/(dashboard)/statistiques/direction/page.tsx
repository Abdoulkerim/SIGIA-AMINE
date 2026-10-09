import Link from 'next/link'
import { getDashboard } from '../dashboard-actions'

function n(value: unknown) { return typeof value === 'number' ? value.toLocaleString('fr-FR') : '0' }
function money(value: unknown) { return typeof value === 'number' ? value.toLocaleString('fr-FR', { minimumFractionDigits: 0, maximumFractionDigits: 2 }) : '0' }
function obj(value: unknown) { return (value && typeof value === 'object' ? value : {}) as Record<string, any> }
function pct(a: number, b: number) { return b > 0 ? Math.round((a / b) * 100) : 0 }

export default async function DirectionDashboardPage() {
  const data = await getDashboard('direction')
  const students = obj(data.students)
  const results = obj(data.results)
  const attendance = obj(data.attendance_30d)
  const finance = obj(data.finance)
  const activities = obj(data.activities)
  const topClasses = Array.isArray(data.top_classes) ? data.top_classes : []
  const totalAttendance = ['present','absent','late','excused'].reduce((s,k)=>s+(Number(attendance[k])||0),0)

  return <main className="page">
    <div className="page-header">
      <div><h1 className="page-title">Direction / Coordination</h1><p className="page-subtitle">Vue globale de pilotage de l&apos;établissement.</p></div>
      <Link href="/statistiques" className="button button-secondary">← Dashboards</Link>
    </div>

    <section className="grid grid-4">
      {[
        ['Élèves inscrits', n(students.enrolled)],
        ['Classes actives', n(data.classes)],
        ['Personnel actif', n(data.employees)],
        ['Internes', n(students.internal)],
        ['Moyenne publiée', money(results.general_average)],
        ['Bulletins publiés', n(results.published_report_cards)],
        ['Créances', money(finance.invoice_receivable)],
        ['Recettes du jour', money(finance.payments_today)],
      ].map(([label,value])=><div className="card" key={label}><div className="stat-label">{label}</div><div className="stat-value">{value}</div></div>)}
    </section>

    <section className="grid grid-2" style={{ marginTop: 16 }}>
      <div className="card">
        <h2 style={{ marginTop: 0 }}>Assiduité — 30 derniers jours</h2>
        {['present','absent','late','excused'].map((key)=><div key={key} style={{ marginTop: 12 }}><div style={{ display:'flex', justifyContent:'space-between' }}><span>{key}</span><strong>{n(attendance[key])}</strong></div><div style={{ height: 8, background: '#e2e8f0', borderRadius: 99, marginTop: 5 }}><div style={{ height: 8, width: `${pct(Number(attendance[key])||0,totalAttendance)}%`, background: 'var(--primary)', borderRadius: 99 }} /></div></div>)}
      </div>
      <div className="card">
        <h2 style={{ marginTop: 0 }}>Activités économiques</h2>
        <div className="grid grid-2">
          <div><div className="stat-label">Activités</div><div className="stat-value">{n(activities.activities)}</div></div>
          <div><div className="stat-label">Productions</div><div className="stat-value">{n(activities.productions)}</div></div>
          <div><div className="stat-label">Recettes</div><div className="stat-value">{money(activities.revenue)}</div></div>
          <div><div className="stat-label">Résultat</div><div className="stat-value">{money(activities.result)}</div></div>
        </div>
      </div>
    </section>

    <section style={{ marginTop: 16 }}>
      <div className="table-wrap"><table><thead><tr><th>Classe</th><th>Effectif inscrit</th></tr></thead><tbody>{topClasses.map((row:any)=><tr key={row.class_id}><td>{row.class_name}</td><td>{n(row.active_students)}</td></tr>)}</tbody></table></div>
    </section>
  </main>
}
