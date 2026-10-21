import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'
import { getCurrentUserContext } from '@/lib/auth/current-user'
import { CardManager } from '@/components/administration-it/card-manager'

export default async function StudentCardsPage() {
  const context = await getCurrentUserContext(); const schoolId = context?.profile.school_id
  if (!schoolId) return <main className="page"><p className="empty">Aucun établissement associé à ce compte.</p></main>
  const supabase = await createClient()
  const [{data: students,error}, {data: enrollments}] = await Promise.all([
    supabase.from('students').select('id,student_number,first_name,last_name,status').eq('school_id',schoolId).order('last_name').order('first_name').limit(1000),
    supabase.from('enrollments').select('student_id,classes(name)').eq('school_id',schoolId).eq('status','enrolled').limit(2000),
  ])
  const classByStudent = new Map((enrollments??[]).map((e:any)=>[e.student_id,e.classes?.name ?? 'Non inscrit']))
  const cards = (students??[]).map((s)=>({number:s.student_number,name:`${s.first_name} ${s.last_name}`,detail:String(classByStudent.get(s.id)??'Non inscrit'),status:s.status}))
  return <main className="page"><div className="page-header"><div><h1 className="page-title">Cartes des élèves</h1><p className="page-subtitle">{cards.length} élève(s) · Cartes générées depuis les dossiers de l’établissement.</p></div><Link className="button button-secondary" href="/administration-it/cartes">Retour aux cartes</Link></div>{error?<p className="error">Chargement impossible : {error.message}</p>:null}<CardManager cards={cards} title="Carte scolaire" cardTitle="Carte scolaire" fileName="cartes-eleves"/></main>
}
