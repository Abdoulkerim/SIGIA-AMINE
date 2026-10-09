import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'
import { archiveDocument, uploadDocument } from './documents-actions'

export default async function DocumentsPage({searchParams}:{searchParams:Promise<Record<string,string|undefined>>}){
 const sp=await searchParams; const supabase=await createClient()
 const [{data:docs},{data:types},{data:students}]=await Promise.all([
  supabase.from('documents').select('id,title,file_name,status,created_at,issued_at,expires_at,student_id,parent_id,employee_id,document_types(name)').neq('status','archived').order('created_at',{ascending:false}).limit(50),
  supabase.from('document_types').select('id,name,code').eq('is_active',true).order('name'),
  supabase.from('students').select('id,student_number,first_name,last_name').order('last_name').limit(300),
 ])
 return <main className="page">
  <div className="page-header"><div><h1 className="page-title">Documents & archives</h1><p className="page-subtitle">Dossiers, certificats, attestations et pièces numériques avec classement, versioning et accès contrôlé.</p></div><div className="actions"><Link className="button button-secondary" href="/documents/types">Types</Link><Link className="button button-secondary" href="/documents/demandes">Demandes</Link><Link className="button button-secondary" href="/documents/archives">Archives</Link></div></div>
  {sp.error&&<div className="error">{sp.error}</div>}{sp.created&&<div className="success">Document enregistré.</div>}
  <section className="grid grid-2" style={{marginBottom:16}}><article className="card"><h2>Déposer un document</h2><form action={uploadDocument} className="grid grid-2" encType="multipart/form-data">
    <div className="field"><label className="label">Titre</label><input className="input" name="title" required /></div><div className="field"><label className="label">Type</label><select className="select" name="documentTypeId" required><option value="">—</option>{(types??[]).map((t:any)=><option key={t.id} value={t.id}>{t.name}</option>)}</select></div>
    <div className="field"><label className="label">Élève (optionnel)</label><select className="select" name="studentId"><option value="">—</option>{(students??[]).map((s:any)=><option key={s.id} value={s.id}>{s.student_number} — {s.last_name} {s.first_name}</option>)}</select></div>
    <div className="field"><label className="label">Référence</label><input className="input" name="reference" /></div>
    <div className="field"><label className="label">Date d'émission</label><input className="input" type="date" name="issuedAt" /></div><div className="field"><label className="label">Expiration</label><input className="input" type="date" name="expiresAt" /></div>
    <div className="field" style={{gridColumn:'1/-1'}}><label className="label">Fichier</label><input className="input" type="file" name="file" required /></div>
    <div style={{gridColumn:'1/-1'}}><button className="button button-primary">Téléverser</button></div>
  </form></article><article className="card"><h2>Flux documentaire</h2><p>Le document est stocké dans le bucket privé <strong>school-documents</strong> avec un chemin lié à son école et à son identifiant.</p><p>Les documents peuvent être versionnés, archivés et rattachés à un élève, un parent ou un employé.</p><p>Les demandes de documents sont suivies jusqu'à leur traitement.</p></article></section>
  <section className="table-wrap"><table><thead><tr><th>Titre</th><th>Type</th><th>État</th><th>Date</th><th>Fichier</th><th>Action</th></tr></thead><tbody>{(docs??[]).map((d:any)=><tr key={d.id}><td>{d.title}</td><td>{d.document_types?.name??'—'}</td><td><span className="badge">{d.status}</span></td><td>{d.created_at?new Date(d.created_at).toLocaleDateString('fr-FR'):'—'}</td><td>{d.file_name||'—'}</td><td><form action={archiveDocument}><input type="hidden" name="documentId" value={d.id}/><button className="button button-danger">Archiver</button></form></td></tr>)}</tbody></table>{!(docs?.length)&&<p className="empty">Aucun document actif.</p>}</section>
 </main>
}
