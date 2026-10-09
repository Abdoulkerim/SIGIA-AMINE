import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'
import { getCurrentUserContext } from '@/lib/auth/current-user'
import { createDisciplineCategory } from '../../vie-scolaire-actions'

export default async function DisciplineCategoriesPage({ searchParams }: { searchParams: Promise<{ error?: string; created?: string }> }) {
  const context = await getCurrentUserContext(); if (!context?.profile.school_id) return null
  const params = await searchParams; const supabase=await createClient(); const schoolId=context.profile.school_id
  const { data, error } = await supabase.from('discipline_categories').select('id,code,name,severity,is_active').eq('school_id',schoolId).order('name')
  return <main className="page"><div className="page-header"><div><h1 className="page-title">Catégories de discipline</h1><p className="page-subtitle">La nomenclature et les niveaux de gravité restent paramétrables par l’établissement.</p></div><Link className="button button-secondary" href="/vie-scolaire/discipline">Retour discipline</Link></div>{params.created?<p className="success">Catégorie créée.</p>:null}{params.error?<p className="error">{params.error}</p>:null}{error?<p className="error">{error.message}</p>:null}<section className="card" style={{marginBottom:16}}><form action={createDisciplineCategory}><div className="grid grid-2"><Field label="Code"><input className="input" name="code" required/></Field><Field label="Nom"><input className="input" name="name" required/></Field><Field label="Gravité (1–5)"><input className="input" type="number" min="1" max="5" defaultValue="1" name="severity" required/></Field></div><button className="button button-primary">Créer la catégorie</button></form></section><section className="card"><div className="table-wrap"><table><thead><tr><th>Code</th><th>Nom</th><th>Gravité</th><th>Actif</th></tr></thead><tbody>{(data??[]).map(c=><tr key={c.id}><td>{c.code}</td><td>{c.name}</td><td>{c.severity}/5</td><td><span className="badge">{c.is_active?'Actif':'Inactif'}</span></td></tr>)}</tbody></table></div>{!data?.length?<p className="empty">Aucune catégorie.</p>:null}</section></main>
}
function Field({label,children}:{label:string;children:React.ReactNode}){return <label className="field"><span className="label">{label}</span>{children}</label>}
