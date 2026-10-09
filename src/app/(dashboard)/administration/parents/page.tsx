import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'
import { getCurrentUserContext } from '@/lib/auth/current-user'

export default async function ParentsPage({ searchParams }: { searchParams: Promise<{ created?: string }> }) {
  const context = await getCurrentUserContext()
  if (!context?.profile.school_id) return null
  const params = await searchParams
  const supabase = await createClient()

  const { data: parents, error } = await supabase
    .from('parents')
    .select('id, first_name, last_name, profession, phone, email, preferred_contact_method')
    .eq('school_id', context.profile.school_id)
    .order('last_name')
    .order('first_name')
    .limit(100)

  return (
    <main className="page">
      <div className="page-header">
        <div>
          <h1 className="page-title">Parents / Tuteurs</h1>
          <p className="page-subtitle">Gestion des responsables et tuteurs des élèves.</p>
        </div>
        <Link className="button button-primary" href="/administration/parents/nouveau">+ Nouveau parent</Link>
      </div>

      {params.created ? <p className="success">Parent enregistré avec succès.</p> : null}
      {error ? <p className="error">Erreur de lecture : {error.message}</p> : null}

      {!parents?.length ? (
        <section className="card empty">
          <h2 style={{ marginTop: 0, color: 'var(--text)' }}>Aucun parent enregistré</h2>
          <p>Commence par créer le premier responsable, puis nous relierons les enfants à son dossier.</p>
          <Link className="button button-primary" href="/administration/parents/nouveau">Créer le premier parent</Link>
        </section>
      ) : (
        <section className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Nom</th>
                <th>Prénom</th>
                <th>Profession</th>
                <th>Téléphone</th>
                <th>E-mail</th>
                <th>Contact préféré</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              {parents.map((parent) => (
                <tr key={parent.id}>
                  <td>{parent.last_name}</td>
                  <td>{parent.first_name}</td>
                  <td>{parent.profession ?? '—'}</td>
                  <td>{parent.phone ?? '—'}</td>
                  <td>{parent.email ?? '—'}</td>
                  <td>{parent.preferred_contact_method ?? '—'}</td>
                  <td><Link className="button button-secondary" href={`/administration/parents/${parent.id}`}>Ouvrir</Link></td>
                </tr>
              ))}
            </tbody>
          </table>
        </section>
      )}
    </main>
  )
}
