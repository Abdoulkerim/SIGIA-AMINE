import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'
import { getCurrentUserContext } from '@/lib/auth/current-user'
import { createTimetableSlot } from '../../pedagogie-actions'

export default async function NewTimetableSlotPage({ searchParams }: { searchParams: Promise<{ error?: string }> }) {
  const context = await getCurrentUserContext()
  if (!context?.profile.school_id) return null
  const params = await searchParams
  const supabase = await createClient()
  const schoolId = context.profile.school_id
  const [{ data: years }, { data: classes }, { data: subjects }, { data: teachers }] = await Promise.all([
    supabase.from('school_years').select('id,name,is_current,start_date,end_date').eq('school_id', schoolId).order('start_date',{ascending:false}),
    supabase.from('classes').select('id,name,code,school_year_id').eq('school_id', schoolId).eq('is_active',true).order('name'),
    supabase.from('subjects').select('id,name,code').eq('school_id', schoolId).eq('is_active',true).order('name'),
    supabase.from('employees').select('id,first_name,last_name,employee_number').eq('school_id', schoolId).eq('status','active').order('last_name'),
  ])
  const currentYear = years?.find((y) => y.is_current) ?? years?.[0]
  return (
    <main className="page">
      <div className="page-header"><div><h1 className="page-title">Nouveau créneau</h1><p className="page-subtitle">Le serveur vérifiera l'affectation et tous les conflits avant insertion.</p></div><Link className="button button-secondary" href="/pedagogie/emploi-du-temps">Retour</Link></div>
      {params.error ? <p className="error">{params.error}</p> : null}
      <section className="card">
        <form action={createTimetableSlot}>
          <div className="grid grid-2">
            <Field label="Année scolaire"><select className="select" name="schoolYearId" defaultValue={currentYear?.id ?? ''} required>{(years ?? []).map(y => <option key={y.id} value={y.id}>{y.name}</option>)}</select></Field>
            <Field label="Classe"><select className="select" name="classId" required><option value="">Sélectionner</option>{(classes ?? []).map(c => <option key={c.id} value={c.id}>{c.name} ({c.code})</option>)}</select></Field>
            <Field label="Matière"><select className="select" name="subjectId" required><option value="">Sélectionner</option>{(subjects ?? []).map(s => <option key={s.id} value={s.id}>{s.name} ({s.code})</option>)}</select></Field>
            <Field label="Enseignant"><select className="select" name="teacherId" required><option value="">Sélectionner</option>{(teachers ?? []).map(t => <option key={t.id} value={t.id}>{t.last_name} {t.first_name} ({t.employee_number})</option>)}</select></Field>
            <Field label="Jour"><select className="select" name="dayOfWeek" defaultValue="1" required>{[['1','Lundi'],['2','Mardi'],['3','Mercredi'],['4','Jeudi'],['5','Vendredi'],['6','Samedi'],['7','Dimanche']].map(([v,l]) => <option key={v} value={v}>{l}</option>)}</select></Field>
            <Field label="Salle"><input className="input" name="roomName" placeholder="Ex. Salle 4" /></Field>
            <Field label="Début"><input className="input" type="time" name="startTime" required /></Field>
            <Field label="Fin"><input className="input" type="time" name="endTime" required /></Field>
            <Field label="Valide du"><input className="input" type="date" name="validFrom" defaultValue={currentYear?.start_date ?? ''} /></Field>
            <Field label="Valide jusqu'au"><input className="input" type="date" name="validTo" defaultValue={currentYear?.end_date ?? ''} /></Field>
          </div>
          <button className="button button-primary" type="submit">Enregistrer le créneau</button>
        </form>
      </section>
    </main>
  )
}
function Field({ label, children }: { label: string; children: React.ReactNode }) { return <label className="field"><span className="label">{label}</span>{children}</label> }
