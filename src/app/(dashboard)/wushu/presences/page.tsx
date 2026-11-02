import { createClient } from '@/lib/supabase/server'
import { WushuAttendanceForm } from './attendance-form'

export default async function WushuAttendancePage({ searchParams }: { searchParams: Promise<{ error?: string; ok?: string }> }) {
  const q = await searchParams
  const supabase = await createClient()
  const [{ data: sessions }, { data: profiles }, { data: students }, { data: groups }] = await Promise.all([
    supabase.from('wushu_sessions').select('id,group_id,session_date,session_type').order('session_date', { ascending: false }).limit(100),
    supabase.from('student_wushu').select('student_id,group_id,status').in('status', ['active', 'completed']),
    supabase.from('students').select('id,first_name,last_name,student_number').eq('status', 'active').order('last_name').limit(300),
    supabase.from('wushu_groups').select('id,name'),
  ])

  const groupNames = new Map((groups ?? []).map((group) => [group.id, group.name]))
  const sessionChoices = (sessions ?? []).flatMap((session) => {
    const groupName = groupNames.get(session.group_id)
    return groupName ? [{ ...session, group_name: groupName }] : []
  })
  const studentChoices = (profiles ?? []).flatMap((profile) => {
    const student = (students ?? []).find((item) => item.id === profile.student_id)
    return student ? [{ ...student, group_id: profile.group_id }] : []
  })

  return <main className="page">
    <div className="page-header"><div><h1 className="page-title">Présences Wushu</h1><p className="page-subtitle">Présence, absence, retard ou absence justifiée pour chaque séance.</p></div></div>
    {q.error ? <p className="error">{q.error}</p> : null}
    {q.ok ? <p className="success">Présence enregistrée.</p> : null}
    <section className="card">
      <h2>Saisir une présence</h2>
      {sessionChoices.length
        ? <WushuAttendanceForm sessions={sessionChoices} students={studentChoices} />
        : <p className="empty">Créez une séance dans un groupe actif avant de saisir les présences.</p>}
    </section>
    <section className="card" style={{ marginTop: 16 }}><h2>Conseil</h2><p>La saisie d'une présence est validée par le groupe de la séance et l'affectation Wushu de l'élève.</p></section>
  </main>
}
