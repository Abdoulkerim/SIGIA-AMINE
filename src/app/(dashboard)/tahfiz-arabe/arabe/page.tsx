import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'
import { getCurrentUserContext } from '@/lib/auth/current-user'
import { createArabicLevel, assignStudentArabic, recordArabicSession, createArabicEvaluation, publishArabicEvaluation } from '../tahfiz-arabe-actions'

const statuses: Record<string,string> = { active:'Actif', paused:'Suspendu', completed:'Terminé', inactive:'Inactif' }
const attendance: Record<string,string> = { present:'Présent', absent:'Absent', late:'Retard', excused:'Excusé' }
function text(v: unknown) { return v === null || v === undefined || v === '' ? '—' : String(v) }

export default async function ArabicPage({ searchParams }: { searchParams: Promise<{ error?: string; created?: string; assigned?: string; session?: string; evaluation?: string; published?: string }> }) {
  const query = await searchParams
  const context = await getCurrentUserContext()
  if (!context?.profile.school_id) return null
  const supabase = await createClient()
  const schoolId = context.profile.school_id
  const [{ data: levels }, { data: students }, { data: staffJson }, { data: periodsJson }, { data: profiles }, { data: sessions }, { data: evaluations }] = await Promise.all([
    supabase.from('arabic_levels').select('id,code,name,sequence_no,is_active').eq('school_id',schoolId).eq('is_active',true).order('sequence_no').order('name'),
    supabase.from('students').select('id,student_number,first_name,last_name').eq('school_id',schoolId).order('last_name').order('first_name').limit(500),
    supabase.rpc('get_specialized_staff', { p_module: 'arabic' }),
    supabase.rpc('get_specialized_periods'),
    supabase.from('student_arabic').select('id,student_id,arabic_level_id,assigned_teacher_id,start_date,current_progress,status,notes,students(first_name,last_name,student_number),arabic_levels(name),employees(first_name,last_name)').eq('school_id',schoolId).order('updated_at',{ascending:false}).limit(100),
    supabase.from('arabic_sessions').select('id,student_id,session_date,activity_type,topic,score,observation,teacher_id,attendance_status,progress_after,is_published,students(first_name,last_name),employees(first_name,last_name)').eq('school_id',schoolId).order('session_date',{ascending:false}).limit(30),
    supabase.from('arabic_evaluations').select('id,student_id,period_id,evaluation_date,title,skill_area,score,observation,evaluator_id,is_published,published_at,students(first_name,last_name),academic_periods(name)').eq('school_id',schoolId).order('evaluation_date',{ascending:false}).limit(30),
  ])
  const teachers = (staffJson as any[]) ?? []
  const periods = (periodsJson as any[]) ?? []
  return <main className="page">
    <div className="page-header"><div><p className="page-subtitle">Formation spécialisée</p><h1 className="page-title">Arabe</h1><p className="page-subtitle">Niveaux, parcours, séances, présence, évaluations et progression. Les domaines précis restent configurables.</p></div><Link className="button button-secondary" href="/tahfiz-arabe">Retour Tahfiz / Arabe</Link></div>
    {query.error ? <p className="error">{query.error}</p> : null}
    {query.created || query.assigned || query.session || query.evaluation || query.published ? <p className="success">Opération enregistrée.</p> : null}

    <section className="grid grid-2">
      <article className="card"><h2>Créer un niveau Arabe</h2><form action={createArabicLevel} className="grid grid-2">
        <div className="field"><label className="label">Code</label><input className="input" name="code" required placeholder="A1" /></div>
        <div className="field"><label className="label">Nom</label><input className="input" name="name" required placeholder="Niveau 1" /></div>
        <div className="field"><label className="label">Ordre</label><input className="input" name="sequenceNo" type="number" min="0" defaultValue="0" /></div>
        <div className="field"><label className="label">Description</label><input className="input" name="description" placeholder="Description facultative" /></div>
        <button className="button button-primary" type="submit">Créer le niveau</button>
      </form></article>
      <article className="card"><h2>Niveaux configurés</h2>{levels?.length ? <div className="table-wrap"><table><thead><tr><th>Code</th><th>Niveau</th><th>Ordre</th></tr></thead><tbody>{levels.map((l:any)=><tr key={l.id}><td>{l.code}</td><td>{l.name}</td><td>{l.sequence_no}</td></tr>)}</tbody></table></div> : <p className="empty">Aucun niveau Arabe configuré.</p>}</article>
    </section>

    <section className="card" style={{marginTop:16}}><h2>Affecter / mettre à jour un élève</h2><form action={assignStudentArabic} className="grid grid-3">
      <div className="field"><label className="label">Élève</label><select className="select" name="studentId" required><option value="">Choisir</option>{students?.map((s:any)=><option key={s.id} value={s.id}>{s.student_number} — {s.last_name} {s.first_name}</option>)}</select></div>
      <div className="field"><label className="label">Niveau</label><select className="select" name="levelId"><option value="">Non défini</option>{levels?.map((l:any)=><option key={l.id} value={l.id}>{l.code} — {l.name}</option>)}</select></div>
      <div className="field"><label className="label">Responsable</label><select className="select" name="teacherId"><option value="">Non défini</option>{teachers?.map((t:any)=><option key={t.id} value={t.id}>{t.last_name} {t.first_name} — {text(t.job_title)}</option>)}</select></div>
      <div className="field"><label className="label">Début</label><input className="input" name="startDate" type="date" /></div>
      <div className="field"><label className="label">Progression (%)</label><input className="input" name="progress" type="number" min="0" max="100" step="0.01" defaultValue="0" /></div>
      <div className="field"><label className="label">Statut</label><select className="select" name="status"><option value="active">Actif</option><option value="paused">Suspendu</option><option value="completed">Terminé</option><option value="inactive">Inactif</option></select></div>
      <div className="field" style={{gridColumn:'1 / -1'}}><label className="label">Notes</label><textarea className="input" name="notes" rows={3} /></div>
      <button className="button button-primary" type="submit">Enregistrer le profil</button>
    </form></section>

    <section className="card" style={{marginTop:16}}><h2>Profils Arabe</h2>{profiles?.length ? <div className="table-wrap"><table><thead><tr><th>Élève</th><th>Niveau</th><th>Responsable</th><th>Progression</th><th>Statut</th></tr></thead><tbody>{profiles.map((p:any)=><tr key={p.id}><td>{p.students?.last_name} {p.students?.first_name}</td><td>{text(p.arabic_levels?.name)}</td><td>{text(p.employees ? `${p.employees.last_name} ${p.employees.first_name}` : null)}</td><td>{p.current_progress}%</td><td><span className="badge">{statuses[p.status] || p.status}</span></td></tr>)}</tbody></table></div> : <p className="empty">Aucun profil Arabe.</p>}</section>

    <section className="card" style={{marginTop:16}}><h2>Enregistrer une séance</h2><form action={recordArabicSession} className="grid grid-3">
      <div className="field"><label className="label">Élève</label><select className="select" name="studentId" required><option value="">Choisir</option>{profiles?.map((p:any)=><option key={p.student_id} value={p.student_id}>{p.students?.last_name} {p.students?.first_name}</option>)}</select></div>
      <div className="field"><label className="label">Date</label><input className="input" name="sessionDate" type="date" required /></div>
      <div className="field"><label className="label">Activité</label><input className="input" name="activityType" required placeholder="Ex. lecture, grammaire, vocabulaire…" /></div>
      <div className="field"><label className="label">Thème / contenu</label><input className="input" name="topic" /></div>
      <div className="field"><label className="label">Score</label><input className="input" name="score" type="number" min="0" step="0.01" /></div>
      <div className="field"><label className="label">Présence</label><select className="select" name="attendanceStatus">{Object.entries(attendance).map(([k,v])=><option key={k} value={k}>{v}</option>)}</select></div>
      <div className="field"><label className="label">Progression après séance (%)</label><input className="input" name="progressAfter" type="number" min="0" max="100" step="0.01" /></div>
      <div className="field"><label className="label">Responsable</label><select className="select" name="teacherId"><option value="">Non défini</option>{teachers?.map((t:any)=><option key={t.id} value={t.id}>{t.last_name} {t.first_name}</option>)}</select></div>
      <div className="field" style={{gridColumn:'1 / -1'}}><label className="label">Observation</label><textarea className="input" name="observation" rows={3} /></div>
      <label style={{display:'flex',alignItems:'center',gap:8}}><input type="checkbox" name="isPublished" /> Publier pour les espaces autorisés</label>
      <button className="button button-primary" type="submit">Enregistrer la séance</button>
    </form></section>

    <section className="card" style={{marginTop:16}}><h2>Évaluation Arabe</h2><form action={createArabicEvaluation} className="grid grid-3">
      <div className="field"><label className="label">Élève</label><select className="select" name="studentId" required><option value="">Choisir</option>{profiles?.map((p:any)=><option key={p.student_id} value={p.student_id}>{p.students?.last_name} {p.students?.first_name}</option>)}</select></div>
      <div className="field"><label className="label">Période</label><select className="select" name="periodId"><option value="">Non définie</option>{periods?.map((p:any)=><option key={p.id} value={p.id}>{p.name}</option>)}</select></div>
      <div className="field"><label className="label">Date</label><input className="input" name="evaluationDate" type="date" required /></div>
      <div className="field"><label className="label">Titre</label><input className="input" name="title" required placeholder="Évaluation" /></div>
      <div className="field"><label className="label">Domaine évalué</label><input className="input" name="skillArea" placeholder="Domaine / compétence" /></div>
      <div className="field"><label className="label">Score</label><input className="input" name="score" type="number" min="0" step="0.01" /></div>
      <div className="field" style={{gridColumn:'1 / -1'}}><label className="label">Observation</label><textarea className="input" name="observation" rows={3} /></div>
      <div className="field"><label className="label">Évaluateur</label><select className="select" name="evaluatorId"><option value="">Non défini</option>{teachers?.map((t:any)=><option key={t.id} value={t.id}>{t.last_name} {t.first_name}</option>)}</select></div>
      <label style={{display:'flex',alignItems:'center',gap:8}}><input type="checkbox" name="isPublished" /> Publier</label>
      <button className="button button-primary" type="submit">Enregistrer l’évaluation</button>
    </form></section>

    <section className="grid grid-2" style={{marginTop:16}}>
      <article className="card"><h2>Dernières séances</h2>{sessions?.length ? <div className="table-wrap"><table><thead><tr><th>Date</th><th>Élève</th><th>Activité</th><th>Présence</th><th>Progression</th><th>Publication</th></tr></thead><tbody>{sessions.map((s:any)=><tr key={s.id}><td>{s.session_date}</td><td>{s.students?.last_name} {s.students?.first_name}</td><td>{s.activity_type}</td><td>{attendance[s.attendance_status] || s.attendance_status}</td><td>{text(s.progress_after)}{s.progress_after !== null ? '%' : ''}</td><td>{s.is_published ? 'Publié' : 'Brouillon'}</td></tr>)}</tbody></table></div> : <p className="empty">Aucune séance.</p>}</article>
      <article className="card"><h2>Dernières évaluations</h2>{evaluations?.length ? <div className="table-wrap"><table><thead><tr><th>Date</th><th>Élève</th><th>Titre</th><th>Domaine</th><th>Score</th><th>Publication</th><th></th></tr></thead><tbody>{evaluations.map((e:any)=><tr key={e.id}><td>{e.evaluation_date}</td><td>{e.students?.last_name} {e.students?.first_name}</td><td>{e.title}</td><td>{text(e.skill_area)}</td><td>{text(e.score)}</td><td>{e.is_published ? 'Publié' : 'Brouillon'}</td><td>{!e.is_published ? <form action={publishArabicEvaluation}><input type="hidden" name="evaluationId" value={e.id}/><button className="button button-secondary" type="submit">Publier</button></form> : null}</td></tr>)}</tbody></table></div> : <p className="empty">Aucune évaluation.</p>}</article>
    </section>
  </main>
}
