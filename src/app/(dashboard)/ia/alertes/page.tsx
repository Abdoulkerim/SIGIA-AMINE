
import { getAiWorkspace, reviewAiAlert } from '../ai-actions'

export default async function AiAlertsPage() {
  const { alerts } = await getAiWorkspace()
  async function review(formData: FormData) {
    'use server'
    const id = String(formData.get('id') ?? '')
    const status = String(formData.get('status') ?? 'acknowledged') as 'acknowledged'|'resolved'|'dismissed'
    const note = String(formData.get('note') ?? '')
    await reviewAiAlert(id, status, note)
  }
  return (
    <main className="page">
      <div className="page-header">
        <div>
          <h1 className="page-title">Alertes IA</h1>
          <p className="page-subtitle">Signaux générés à partir des données autorisées. Toute alerte nécessite une revue humaine.</p>
        </div>
      </div>
      {!alerts.length && <section className="card empty">Aucune alerte IA.</section>}
      <section style={{ display: 'grid', gap: 12 }}>
        {alerts.map((a: any) => <article className="card" key={a.id}>
          <div className="page-header" style={{ marginBottom: 8 }}>
            <div>
              <div className="stat-label">SEVERITE {a.severity}/5 • {a.status}</div>
              <h2 style={{ margin: '4px 0' }}>{a.title}</h2>
            </div>
            <span className="badge">{new Date(a.generated_at).toLocaleString('fr-FR')}</span>
          </div>
          <p style={{ whiteSpace: 'pre-wrap' }}>{a.description}</p>
          {a.recommended_action && <p className="page-subtitle"><strong>Vérification proposée :</strong> {a.recommended_action}</p>}
          <details><summary>Preuves</summary><pre style={{ whiteSpace: 'pre-wrap' }}>{JSON.stringify(a.evidence ?? {}, null, 2)}</pre></details>
          {a.status === 'open' && <form action={review} className="grid grid-2" style={{ marginTop: 12 }}>
            <input type="hidden" name="id" value={a.id} />
            <input className="input" name="note" placeholder="Note de revue" />
            <div style={{ display: 'flex', gap: 8 }}>
              <button className="button button-secondary" name="status" value="acknowledged">Accuser réception</button>
              <button className="button button-primary" name="status" value="resolved">Résolue</button>
              <button className="button button-secondary" name="status" value="dismissed">Écarter</button>
            </div>
          </form>}
        </article>)}
      </section>
    </main>
  )
}
