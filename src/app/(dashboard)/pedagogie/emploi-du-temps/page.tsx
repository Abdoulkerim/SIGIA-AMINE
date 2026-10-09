import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'
import { getCurrentUserContext } from '@/lib/auth/current-user'
import { toggleTimetableSlot } from '../pedagogie-actions'

const days: Record<number, string> = { 1: 'Lundi', 2: 'Mardi', 3: 'Mercredi', 4: 'Jeudi', 5: 'Vendredi', 6: 'Samedi', 7: 'Dimanche' }

export default async function TimetablePage({ searchParams }: { searchParams: Promise<{ error?: string; created?: string; updated?: string }> }) {
  const context = await getCurrentUserContext()
  if (!context?.profile.school_id) return null
  const params = await searchParams
  const supabase = await createClient()
  const { data: slots, error } = await supabase
    .from('timetable_slots')
    .select('id, day_of_week, start_time, end_time, room_name, is_active, school_years(name), classes(name, code), subjects(name, code), employees(first_name,last_name,employee_number)')
    .eq('school_id', context.profile.school_id)
    .order('day_of_week')
    .order('start_time')

  return (
    <main className="page">
      <div className="page-header">
        <div><h1 className="page-title">Emploi du temps</h1><p className="page-subtitle">Créneaux sécurisés avec détection des conflits.</p></div>
        <Link className="button button-primary" href="/pedagogie/emploi-du-temps/nouveau">+ Nouveau créneau</Link>
      </div>
      {params.created ? <p className="success">Créneau enregistré.</p> : null}
      {params.updated ? <p className="success">Statut du créneau modifié.</p> : null}
      {params.error ? <p className="error">{params.error}</p> : null}
      {error ? <p className="error">Erreur : {error.message}</p> : null}
      <section className="card">
        <div className="table-wrap">
          <table>
            <thead><tr><th>Jour</th><th>Heure</th><th>Année</th><th>Classe</th><th>Matière</th><th>Enseignant</th><th>Salle</th><th>Statut</th><th></th></tr></thead>
            <tbody>
              {(slots ?? []).map((s: any) => (
                <tr key={s.id}>
                  <td>{days[s.day_of_week] ?? s.day_of_week}</td>
                  <td>{String(s.start_time).slice(0,5)}–{String(s.end_time).slice(0,5)}</td>
                  <td>{s.school_years?.name ?? '—'}</td>
                  <td>{s.classes?.name ?? s.classes?.code ?? '—'}</td>
                  <td>{s.subjects?.name ?? '—'}</td>
                  <td>{s.employees ? `${s.employees.last_name} ${s.employees.first_name}` : '—'}</td>
                  <td>{s.room_name ?? '—'}</td>
                  <td><span className="badge">{s.is_active ? 'Actif' : 'Inactif'}</span></td>
                  <td>
                    <form action={toggleTimetableSlot}>
                      <input type="hidden" name="id" value={s.id} />
                      <input type="hidden" name="active" value={String(!s.is_active)} />
                      <button className="button button-secondary" type="submit">{s.is_active ? 'Désactiver' : 'Réactiver'}</button>
                    </form>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        {!slots?.length ? <p className="empty">Aucun créneau. Les affectations enseignant/matière/classe doivent exister avant la création.</p> : null}
      </section>
    </main>
  )
}
