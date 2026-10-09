import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'
import { getCurrentUserContext } from '@/lib/auth/current-user'

export default async function AttendanceSessionsPage({ searchParams }: { searchParams: Promise<{ error?: string; saved?: string }> }) {
  const context = await getCurrentUserContext()
  if (!context?.profile.school_id) return null
  const params = await searchParams
  const supabase = await createClient()
  const { data, error } = await supabase
    .from('attendance_sessions')
    .select('id,session_date,start_time,end_time,activity_type,notes,classes(name,code),subjects(name,code),employees(first_name,last_name)')
    .eq('school_id', context.profile.school_id)
    .order('session_date', { ascending: false })
    .order('start_time', { ascending: false })
    .limit(100)

  return (
    <main className="page">
      <div className="page-header"><div><h1 className="page-title">Présences & appels</h1><p className="page-subtitle">Historique des séances et accès à la saisie de présence.</p></div><Link className="button button-primary" href="/vie-scolaire/presences/nouveau">+ Nouvelle séance</Link></div>
      {params.saved ? <p className="success">Présences enregistrées.</p> : null}
      {params.error ? <p className="error">{params.error}</p> : null}
      {error ? <p className="error">{error.message}</p> : null}
      <section className="card"><div className="table-wrap"><table><thead><tr><th>Date</th><th>Classe</th><th>Activité</th><th>Matière</th><th>Horaire</th><th>Agent</th><th></th></tr></thead><tbody>
        {(data ?? []).map((s: any) => <tr key={s.id}><td>{s.session_date}</td><td>{s.classes?.name ?? '—'}</td><td>{s.activity_type}</td><td>{s.subjects?.name ?? '—'}</td><td>{s.start_time ?? '—'} {s.end_time ? `→ ${s.end_time}` : ''}</td><td>{s.employees ? `${s.employees.last_name} ${s.employees.first_name}` : '—'}</td><td><Link className="button button-secondary" href={`/vie-scolaire/presences/${s.id}`}>Ouvrir</Link></td></tr>)}
      </tbody></table></div>{!data?.length ? <p className="empty">Aucune séance accessible.</p> : null}</section>
    </main>
  )
}
