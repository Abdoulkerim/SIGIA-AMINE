import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'

export default async function InternatPage() {
  const supabase = await createClient()
  const claims = await supabase.auth.getClaims()
  const userId = claims.data?.claims?.sub
  const { data: profile } = userId ? await supabase.from('users').select('school_id').eq('id', userId).single() : { data: null }
  const schoolId = profile?.school_id

  const { data: dashboard } = schoolId ? await supabase.rpc('get_boarding_dashboard', { p_school_id: schoolId }) : { data: null }
  const { data: assignments } = schoolId ? await supabase
    .from('boarding_assignments')
    .select('id,start_date,notes,students(student_number,first_name,last_name),boarding_beds(bed_number,boarding_rooms(name,floor,boarding_dormitories(name,boarding_buildings(name,code))))')
    .eq('school_id', schoolId)
    .eq('status','active')
    .order('start_date', { ascending: false })
    .limit(20) : { data: [] }

  return (
    <main className="page">
      <div className="page-header">
        <div>
          <h1 className="page-title">Internat</h1>
          <p className="page-subtitle">Structures, affectations, mouvements et présences des élèves internes.</p>
        </div>
        <div className="page-actions" style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
          <Link className="button button-secondary" href="/internat/structures">Structures</Link>
          <Link className="button button-secondary" href="/internat/affectations">Affectations</Link>
          <Link className="button button-secondary" href="/internat/mouvements">Mouvements</Link>
          <Link className="button button-primary" href="/internat/presences">Présences</Link>
        </div>
      </div>

      <section className="grid grid-4">
        {[
          ['Bâtiments', dashboard?.buildings ?? 0],
          ['Chambres', dashboard?.rooms ?? 0],
          ['Lits occupés', dashboard?.occupied_beds ?? 0],
          ['Affectations actives', dashboard?.active_assignments ?? 0],
        ].map(([label, value]) => <div className="card" key={label}><strong>{label}</strong><div style={{ fontSize: 30, marginTop: 8 }}>{value}</div></div>)}
      </section>

      <section className="grid grid-2" style={{ marginTop: 16 }}>
        <div className="card">
          <h2 style={{ marginTop: 0 }}>Capacité</h2>
          <p>Lits : <strong>{dashboard?.beds ?? 0}</strong></p>
          <p>Disponibles : <strong>{dashboard?.available_beds ?? 0}</strong></p>
          <p>Présences enregistrées aujourd’hui : <strong>{dashboard?.today_attendance ?? 0}</strong></p>
        </div>
        <div className="card">
          <h2 style={{ marginTop: 0 }}>Workflow</h2>
          <p>Élève interne → structure → lit → affectation → présence → sortie/retour.</p>
          <p className="page-subtitle" style={{ marginBottom: 0 }}>Les écritures sensibles passent par les RPC sécurisées de l’étape 16.</p>
        </div>
      </section>

      <section className="card" style={{ marginTop: 16 }}>
        <div className="page-header" style={{ marginBottom: 12 }}>
          <div><h2 style={{ margin: 0 }}>Affectations actives</h2><p className="page-subtitle">Les 20 dernières.</p></div>
        </div>
        <div className="table-wrap">
          <table className="table">
            <thead><tr><th>Élève</th><th>Structure</th><th>Chambre</th><th>Lit</th><th>Depuis</th></tr></thead>
            <tbody>
              {(assignments ?? []).map((a: any) => {
                const s = a.students
                const bed = a.boarding_beds
                const room = bed?.boarding_rooms
                const dorm = room?.boarding_dormitories
                const building = dorm?.boarding_buildings
                return <tr key={a.id}><td>{s?.student_number} — {s?.first_name} {s?.last_name}</td><td>{building?.code} — {building?.name} / {dorm?.name}</td><td>{room?.name}</td><td>{bed?.bed_number}</td><td>{a.start_date}</td></tr>
              })}
              {(!assignments || assignments.length === 0) && <tr><td colSpan={5}><div className="empty">Aucune affectation active.</div></td></tr>}
            </tbody>
          </table>
        </div>
      </section>
    </main>
  )
}
