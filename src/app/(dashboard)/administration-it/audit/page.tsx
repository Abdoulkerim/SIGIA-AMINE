import { createClient } from '@/lib/supabase/server'
import { getCurrentUserContext } from '@/lib/auth/current-user'

export default async function ITAuditPage() {
  const context = await getCurrentUserContext()
  const supabase = await createClient()
  let request = supabase
    .from('audit_logs')
    .select('id,action,table_name,record_id,created_at,actor_user_id,users(first_name,last_name,email)')
    .order('created_at', { ascending: false })
    .limit(100)
  if (context?.profile.school_id) request = request.eq('school_id', context.profile.school_id)
  const { data: logs, error } = await request

  return (
    <main className="page">
      <div className="page-header"><div><h1 className="page-title">Journal d’audit</h1><p className="page-subtitle">Dernières opérations consignées par l’application.</p></div><span className="badge">{logs?.length ?? 0} événement(s)</span></div>
      {error ? <p className="error">Impossible de charger le journal : {error.message}</p> : null}
      <section className="table-wrap">
        <table>
          <thead><tr><th>Date</th><th>Utilisateur</th><th>Action</th><th>Table</th><th>Enregistrement</th></tr></thead>
          <tbody>
            {(logs ?? []).map((log: any) => (
              <tr key={log.id}>
                <td>{new Date(log.created_at).toLocaleString('fr-FR')}</td>
                <td>{log.users ? `${log.users.first_name} ${log.users.last_name}` : log.actor_user_id ?? 'Système'}</td>
                <td><span className="badge">{log.action}</span></td>
                <td>{log.table_name ?? '—'}</td>
                <td>{log.record_id ?? '—'}</td>
              </tr>
            ))}
          </tbody>
        </table>
        {!logs?.length ? <p className="empty">Aucun événement d’audit disponible.</p> : null}
      </section>
      <p className="page-subtitle" style={{ marginTop: 12 }}>Les données avant/après des événements restent masquées dans cette vue de synthèse.</p>
    </main>
  )
}
