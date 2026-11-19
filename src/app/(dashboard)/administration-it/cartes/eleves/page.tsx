import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'
import { getCurrentUserContext } from '@/lib/auth/current-user'
import { CardManager } from '@/components/administration-it/card-manager'

export default async function StudentCardsPage() {
  const context = await getCurrentUserContext()
  if (!context?.profile.school_id) return <main className="page"><p className="empty">Aucun établissement associé à ce compte.</p></main>
  const supabase = await createClient()
  const { data: students, error } = await (supabase as any).rpc('get_student_cards')
  const cards = (students ?? []).map((student: any) => ({
    number: student.student_number,
    name: `${student.first_name} ${student.last_name}`,
    detail: student.class_name,
    status: student.status,
  }))
  return <main className="page"><div className="page-header"><div><h1 className="page-title">Cartes des élèves</h1><p className="page-subtitle">{cards.length} élève(s) · Cartes générées depuis les dossiers de l’établissement.</p></div><Link className="button button-secondary" href="/administration-it/cartes">Retour aux cartes</Link></div>{error?<p className="error">Chargement impossible : {error.message}</p>:null}<CardManager cards={cards} title="Carte scolaire" cardTitle="Carte scolaire" fileName="cartes-eleves"/></main>
}
