import Link from 'next/link'
import { notFound } from 'next/navigation'
import { createClient } from '@/lib/supabase/server'
import { getCurrentUserContext } from '@/lib/auth/current-user'

export default async function ParentDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const context = await getCurrentUserContext()
  if (!context?.profile.school_id) return null
  const { id } = await params
  const supabase = await createClient()

  const { data: parent, error } = await supabase
    .from('parents')
    .select('id, first_name, last_name, gender, profession, phone, email, address, preferred_contact_method, notes')
    .eq('id', id)
    .eq('school_id', context.profile.school_id)
    .single()

  if (error || !parent) notFound()

  const { data: relations } = await supabase
    .from('student_parents')
    .select('relationship, is_primary, has_financial_responsibility, receives_notifications, students(id, student_number, first_name, last_name)')
    .eq('parent_id', parent.id)

  return (
    <main className="page">
      <div className="page-header">
        <div>
          <h1 className="page-title">{parent.first_name} {parent.last_name}</h1>
          <p className="page-subtitle">Dossier parent / tuteur</p>
        </div>
        <Link className="button button-secondary" href="/administration/parents">Retour à la liste</Link>
      </div>

      <section className="grid grid-2">
        <div className="card">
          <h2>Informations</h2>
          <p><strong>Nom :</strong> {parent.last_name}</p>
          <p><strong>Prénom :</strong> {parent.first_name}</p>
          <p><strong>Genre :</strong> {parent.gender ?? '—'}</p>
          <p><strong>Profession :</strong> {parent.profession ?? '—'}</p>
          <p><strong>Téléphone :</strong> {parent.phone ?? '—'}</p>
          <p><strong>E-mail :</strong> {parent.email ?? '—'}</p>
          <p><strong>Contact préféré :</strong> {parent.preferred_contact_method ?? '—'}</p>
          <p><strong>Adresse :</strong> {parent.address ?? '—'}</p>
        </div>
        <div className="card">
          <h2>Enfants liés</h2>
          {!relations?.length ? <p>Aucun enfant n'est encore lié à ce dossier.</p> : (
            <div className="table-wrap">
              <table>
                <thead><tr><th>Matricule</th><th>Nom</th><th>Lien</th><th>Responsable principal</th></tr></thead>
                <tbody>
                  {relations.map((relation: any) => (
                    <tr key={relation.students?.id}>
                      <td>{relation.students?.student_number ?? '—'}</td>
                      <td>{relation.students?.last_name} {relation.students?.first_name}</td>
                      <td>{relation.relationship}</td>
                      <td>{relation.is_primary ? 'Oui' : 'Non'}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      </section>
    </main>
  )
}
