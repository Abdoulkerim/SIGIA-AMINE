import { createClient } from '@/lib/supabase/server'
import { getCurrentUserContext } from '@/lib/auth/current-user'
import { createWushuSession, deleteWushuSession, updateWushuSession } from '../wushu-actions'
import { DeleteWushuSessionForm } from './delete-session-form'

type WushuGroup = { id: string; name: string; level: string | null; is_active: boolean }
type WushuSession = {
  id: string
  group_id: string
  session_date: string
  session_type: string
  topic: string | null
  coach_employee_id: string | null
  notes: string | null
  is_published: boolean
}

const sessionTypes = [
  ['training', 'Entraînement'],
  ['technique', 'Technique'],
  ['exam_preparation', 'Préparation examen'],
  ['competition_preparation', 'Préparation compétition'],
  ['other', 'Autre'],
] as const

export default async function WushuSessionsPage({ searchParams }: { searchParams: Promise<{ error?: string; created?: string; updated?: string; deleted?: string }> }) {
  const q = await searchParams
  const supabase = await createClient()
  const context = await getCurrentUserContext()
  const schoolId = context?.profile.school_id
  const isSuperAdmin = context?.roles.some(role => role.code === 'super_admin') ?? false

  const [groupsResult, coachesResult, sessionsResult] = await Promise.all([
    schoolId
      ? supabase.from('wushu_groups').select('id,name,level,is_active').eq('school_id', schoolId).order('name')
      : isSuperAdmin
        ? supabase.from('wushu_groups').select('id,name,level,is_active').order('name')
        : Promise.resolve({ data: null, error: null }),
    (supabase as any).rpc('list_wushu_coaches'),
    schoolId
      ? supabase.from('wushu_sessions').select('id,group_id,session_date,session_type,topic,coach_employee_id,notes,is_published').eq('school_id', schoolId).order('session_date', { ascending: false }).limit(500)
      : isSuperAdmin
        ? supabase.from('wushu_sessions').select('id,group_id,session_date,session_type,topic,coach_employee_id,notes,is_published').order('session_date', { ascending: false }).limit(500)
        : Promise.resolve({ data: null, error: null }),
  ])

  const groups = (groupsResult.data ?? []) as WushuGroup[]
  const sessions = (sessionsResult.data ?? []) as WushuSession[]
  const coaches = (coachesResult.data ?? []) as { id: string; first_name: string; last_name: string | null }[]
  const activeGroups = groups.filter(group => group.is_active)
  const groupById = new Map(groups.map(group => [group.id, group]))

  return <main className="page">
    <div className="page-header"><div><h1 className="page-title">Entraînements Wushu</h1><p className="page-subtitle">Séances, thèmes techniques, préparation et progression.</p></div></div>
    {q.error ? <p className="error">{q.error}</p> : null}
    {q.created ? <p className="success">Séance créée.</p> : null}
    {q.updated ? <p className="success">Séance mise à jour.</p> : null}
    {q.deleted ? <p className="success">Séance supprimée.</p> : null}
    {groupsResult.error ? <p className="error">Impossible de charger les groupes Wushu : {groupsResult.error.message}</p> : null}
    {sessionsResult.error ? <p className="error">Impossible de charger les séances Wushu : {sessionsResult.error.message}</p> : null}
    {coachesResult.error ? <p className="error">Impossible de charger les coachs Wushu : {coachesResult.error.message}</p> : null}
    {!schoolId && !isSuperAdmin ? <p className="error">Aucun établissement n’est associé à votre compte.</p> : null}

    <section className="card">
      <h2>Nouvelle séance</h2>
      <p className="page-subtitle">La progression se met à jour automatiquement avec les présences et les évaluations des élèves.</p>
      <form action={createWushuSession} className="grid grid-4">
        <div className="field"><label className="label">Groupe *</label><select className="select" name="groupId" required><option value="">Choisir…</option>{activeGroups.map(group => <option key={group.id} value={group.id}>{group.name}{group.level ? ` · ${group.level}` : ''}</option>)}</select></div>
        <div className="field"><label className="label">Date *</label><input className="input" type="date" name="sessionDate" required /></div>
        <div className="field"><label className="label">Type *</label><select className="select" name="sessionType"><option value="training">Entraînement</option><option value="technique">Technique</option><option value="exam_preparation">Préparation examen</option><option value="competition_preparation">Préparation compétition</option><option value="other">Autre</option></select></div>
        <div className="field"><label className="label" htmlFor="wushu-session-coach">Enseignant Wushu</label><select id="wushu-session-coach" className="select" name="coachEmployeeId"><option value="">Aucun enseignant</option>{coaches.map(coach => <option key={coach.id} value={coach.id}>{coach.last_name} {coach.first_name}</option>)}</select>{!coachesResult.error && coaches.length === 0 ? <small className="page-subtitle">Aucun enseignant actif avec une spécialité Wushu n’est disponible.</small> : null}</div>
        <div className="field" style={{ gridColumn: 'span 2' }}><label className="label">Thème</label><input className="input" name="topic" /></div>
        <div className="field" style={{ gridColumn: 'span 2' }}><label className="label">Notes</label><input className="input" name="notes" /></div>
        <div><button className="button button-primary" type="submit">Créer la séance</button></div>
      </form>
    </section>

    <section className="card" style={{ marginTop: 16 }}>
      <h2>Historique des séances ({sessions.length})</h2>
      {sessions.length ? <div className="table-wrap"><table><thead><tr><th>Date</th><th>Groupe</th><th>Enseignant Wushu</th><th>Type</th><th>Thème</th><th>Statut</th><th>Actions</th></tr></thead><tbody>{sessions.map(session => {
        const group = groupById.get(session.group_id)
        const selectedCoach = coaches.find(coach => coach.id === session.coach_employee_id)
        return <tr key={session.id}>
          <td>{session.session_date}</td>
          <td>{group ? `${group.name}${group.is_active ? '' : ' (inactif)'}` : `Groupe ${session.group_id.slice(0, 8)}`}</td>
          <td>{selectedCoach ? `${selectedCoach.last_name} ${selectedCoach.first_name}` : '—'}</td>
          <td>{sessionTypes.find(([value]) => value === session.session_type)?.[1] ?? session.session_type}</td>
          <td>{session.topic || '—'}</td>
          <td><span className="badge">{session.is_published ? 'Publié' : 'Brouillon'}</span></td>
          <td><details><summary>Modifier / supprimer</summary>
            <form action={updateWushuSession} className="grid" style={{ minWidth: 280, marginTop: 8 }}>
              <input type="hidden" name="sessionId" value={session.id} />
              <label className="field"><span className="label">Groupe</span><select className="select" name="groupId" defaultValue={session.group_id} required>{groups.filter(item => item.is_active || item.id === session.group_id).map(item => <option key={item.id} value={item.id}>{item.name}{item.level ? ` · ${item.level}` : ''}{item.is_active ? '' : ' (inactif)'}</option>)}</select></label>
              <label className="field"><span className="label">Date</span><input className="input" type="date" name="sessionDate" defaultValue={session.session_date} required /></label>
              <label className="field"><span className="label">Type</span><select className="select" name="sessionType" defaultValue={session.session_type}>{sessionTypes.map(([value, label]) => <option key={value} value={value}>{label}</option>)}</select></label>
              <label className="field"><span className="label">Enseignant Wushu</span><select className="select" name="coachEmployeeId" defaultValue={session.coach_employee_id ?? ''}><option value="">Aucun enseignant</option>{coaches.map(coach => <option key={coach.id} value={coach.id}>{coach.last_name} {coach.first_name}</option>)}</select></label>
              <label className="field"><span className="label">Thème</span><input className="input" name="topic" defaultValue={session.topic ?? ''} maxLength={300} /></label>
              <label className="field"><span className="label">Notes</span><textarea className="input" name="notes" defaultValue={session.notes ?? ''} maxLength={2000} /></label>
              <button className="button button-primary" type="submit">Enregistrer les modifications</button>
            </form>
            <DeleteWushuSessionForm action={deleteWushuSession} sessionId={session.id} />
          </details></td>
        </tr>
      })}</tbody></table></div> : sessionsResult.error ? null : <p className="empty">Aucune séance enregistrée pour cet établissement.</p>}
    </section>
  </main>
}
