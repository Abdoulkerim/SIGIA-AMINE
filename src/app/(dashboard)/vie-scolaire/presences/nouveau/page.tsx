import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'
import { getCurrentUserContext } from '@/lib/auth/current-user'
import { createAttendanceSession } from '../../vie-scolaire-actions'

export default async function NewAttendancePage({ searchParams }: { searchParams: Promise<{ error?: string }> }) {
  const context = await getCurrentUserContext()
  if (!context?.profile.school_id) return null
  const params = await searchParams
  const supabase = await createClient()
  const schoolId = context.profile.school_id
  const [{ data: years }, { data: classes }, { data: subjects }, { data: employees }] = await Promise.all([
    supabase.from('school_years').select('id,name,is_current').eq('school_id', schoolId).order('start_date', { ascending: false }),
    supabase.from('classes').select('id,name,code,school_year_id').eq('school_id', schoolId).eq('is_active', true).order('name'),
    supabase.from('subjects').select('id,name,code').eq('school_id', schoolId).eq('is_active', true).order('name'),
    supabase.from('employees').select('id,first_name,last_name,employee_number').eq('school_id', schoolId).eq('status', 'active').order('last_name'),
  ])
  const currentYear = years?.find((y) => y.is_current) ?? years?.[0]

  return (
    <main className="page">
      <div className="page-header"><div><h1 className="page-title">Nouvelle séance d’appel</h1><p className="page-subtitle">La base contrôlera l’école, l’année, la classe et les élèves effectivement inscrits.</p></div><Link className="button button-secondary" href="/vie-scolaire/presences">Retour</Link></div>
      {params.error ? <p className="error">{params.error}</p> : null}
      <section className="card"><form action={createAttendanceSession}><div className="grid grid-2">
        <Field label="Année scolaire"><select className="select" name="schoolYearId" defaultValue={currentYear?.id ?? ''} required>{(years ?? []).map(y => <option key={y.id} value={y.id}>{y.name}</option>)}</select></Field>
        <Field label="Classe"><select className="select" name="classId" required><option value="">Sélectionner</option>{(classes ?? []).map(c => <option key={c.id} value={c.id}>{c.name} ({c.code})</option>)}</select></Field>
        <Field label="Matière (facultatif)"><select className="select" name="subjectId"><option value="">Activité générale</option>{(subjects ?? []).map(s => <option key={s.id} value={s.id}>{s.name} ({s.code})</option>)}</select></Field>
        <Field label="Personnel responsable (facultatif)"><select className="select" name="employeeId"><option value="">Non précisé</option>{(employees ?? []).map(e => <option key={e.id} value={e.id}>{e.last_name} {e.first_name} ({e.employee_number})</option>)}</select></Field>
        <Field label="Date"><input className="input" type="date" name="sessionDate" defaultValue={new Date().toISOString().slice(0, 10)} required /></Field>
        <Field label="Activité"><input className="input" name="activityType" defaultValue="class" placeholder="Ex. cours, étude, activité" required /></Field>
        <Field label="Heure de début"><input className="input" type="time" name="startTime" /></Field>
        <Field label="Heure de fin"><input className="input" type="time" name="endTime" /></Field>
        <label className="field" style={{ gridColumn: '1 / -1' }}><span className="label">Notes</span><textarea className="input" name="notes" rows={4} placeholder="Contexte ou remarque de séance" /></label>
      </div><button className="button button-primary" type="submit">Créer la séance</button></form></section>
    </main>
  )
}
function Field({ label, children }: { label: string; children: React.ReactNode }) { return <label className="field"><span className="label">{label}</span>{children}</label> }
