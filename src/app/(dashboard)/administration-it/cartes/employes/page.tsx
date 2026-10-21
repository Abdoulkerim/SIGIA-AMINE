import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'
import { getCurrentUserContext } from '@/lib/auth/current-user'
import { CardManager } from '@/components/administration-it/card-manager'

export default async function EmployeeCardsPage() {
  const context=await getCurrentUserContext(); const schoolId=context?.profile.school_id
  if(!schoolId)return <main className="page"><p className="empty">Aucun établissement associé à ce compte.</p></main>
  const supabase=await createClient(); const {data:employees,error}=await supabase.from('employees').select('employee_number,first_name,last_name,job_title,department,status').eq('school_id',schoolId).order('last_name').order('first_name').limit(1000)
  const cards=(employees??[]).map((e)=>({number:e.employee_number,name:`${e.first_name} ${e.last_name}`,detail:e.job_title??e.department??'Personnel',status:e.status}))
  return <main className="page"><div className="page-header"><div><h1 className="page-title">Cartes des employés</h1><p className="page-subtitle">{cards.length} employé(s) · Cartes générées depuis les dossiers du personnel.</p></div><Link className="button button-secondary" href="/administration-it/cartes">Retour aux cartes</Link></div>{error?<p className="error">Chargement impossible : {error.message}</p>:null}<CardManager cards={cards} title="Carte du personnel" cardTitle="Carte du personnel" fileName="cartes-employes"/></main>
}
