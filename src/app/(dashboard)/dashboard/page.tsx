import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'
import { getCurrentUserContext } from '@/lib/auth/current-user'

export default async function DashboardPage() {
  const context = await getCurrentUserContext()
  if (!context) return null

  const supabase = await createClient()
  const schoolId = context.profile.school_id

  const [{ count: studentsCount }, { count: classesCount }, { data: currentYear }] = await Promise.all([
    schoolId
      ? supabase.from('students').select('*', { count: 'exact', head: true }).eq('school_id', schoolId)
      : Promise.resolve({ count: 0 }),
    schoolId
      ? supabase.from('classes').select('*', { count: 'exact', head: true }).eq('school_id', schoolId).eq('is_active', true)
      : Promise.resolve({ count: 0 }),
    schoolId
      ? supabase.from('school_years').select('name').eq('school_id', schoolId).eq('is_current', true).maybeSingle()
      : Promise.resolve({ data: null }),
  ])

  return (
    <main className="page">
      <div className="page-header">
        <div>
          <h1 className="page-title">Tableau de bord</h1>
          <p className="page-subtitle">Bienvenue dans le socle opérationnel de SIGIA-AMINE.</p>
        </div>
        <span className="badge">Année : {currentYear?.name ?? 'À configurer'}</span>
      </div>

      <section className="grid grid-4">
        <div className="card"><div className="stat-label">Élèves</div><div className="stat-value">{studentsCount ?? 0}</div></div>
        <div className="card"><div className="stat-label">Classes actives</div><div className="stat-value">{classesCount ?? 0}</div></div>
        <div className="card"><div className="stat-label">Rôles actifs</div><div className="stat-value">{context.roles.length}</div></div>
        <div className="card"><div className="stat-label">Établissement</div><div className="stat-value" style={{ fontSize: 18 }}>Al Amine</div></div>
      </section>

      <section style={{ marginTop: 24 }}>
        <div className="card">
          <h2 style={{ marginTop: 0 }}>Priorité actuelle</h2>
          <p className="page-subtitle">Le développement commence par l’administration, les élèves, les parents, les inscriptions, les classes, les enseignants, les matières et l’année scolaire.</p>
          <div style={{ display: 'flex', gap: 10, marginTop: 16, flexWrap: 'wrap' }}>
            <Link className="button button-primary" href="/administration/eleves">Ouvrir les élèves</Link>
            <Link className="button button-secondary" href="/administration">Administration</Link>
          </div>
        </div>
      </section>
    </main>
  )
}
