import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'
import { getCurrentUserContext } from '@/lib/auth/current-user'
import { setEmployeeStatus } from '../personnel-actions'

export default async function EmployeesPage({ searchParams }: { searchParams: Promise<{ error?: string; updated?: string }> }) {
  const context = await getCurrentUserContext(); if (!context?.profile.school_id) return null
  const params = await searchParams; const supabase = await createClient()
  const { data: rows } = await supabase.from('employees').select('id,employee_number,first_name,last_name,job_title,department,phone,status,hire_date').eq('school_id',context.profile.school_id).order('last_name').order('first_name')
  return <main className="page"><div className="page-header"><div><h1 className="page-title">Dossiers employés</h1><p className="page-subtitle">Personnel administratif, pédagogique et services.</p></div><Link className="button button-primary" href="/personnel/employes/nouveau">+ Nouvel employé</Link></div>{params.error?<p className="error">{params.error}</p>:null}{params.updated?<p className="success">Statut mis à jour.</p>:null}<section className="card"><div className="table-wrap"><table><thead><tr><th>N°</th><th>Nom</th><th>Fonction</th><th>Service</th><th>Embauche</th><th>Statut</th><th></th></tr></thead><tbody>{(rows??[]).map((e:any)=><tr key={e.id}><td>{e.employee_number}</td><td>{e.last_name} {e.first_name}</td><td>{e.job_title??'—'}</td><td>{e.department??'—'}</td><td>{e.hire_date??'—'}</td><td><span className="badge">{e.status}</span></td><td className="actions"><Link className="button button-secondary" href={`/personnel/employes/${e.id}`}>Dossier</Link><form action={setEmployeeStatus}><input type="hidden" name="employeeId" value={e.id}/><input type="hidden" name="status" value={e.status==='active'?'inactive':'active'}/><button className="button button-secondary">{e.status==='active'?'Désactiver':'Activer'}</button></form></td></tr>)}{!rows?.length?<tr><td colSpan={7}><div className="empty">Aucun employé.</div></td></tr>:null}</tbody></table></div></section></main>
}
