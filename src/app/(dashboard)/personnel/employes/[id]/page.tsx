import Link from 'next/link'
import { notFound } from 'next/navigation'
import { createClient } from '@/lib/supabase/server'
import { getCurrentUserContext } from '@/lib/auth/current-user'
import { updateEmployee } from '../../personnel-actions'

export default async function EmployeeDetailPage({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>
  searchParams: Promise<{ error?: string; updated?: string }>
}) {
  const context = await getCurrentUserContext()
  if (!context?.profile.school_id) return null
  const [{ id }, query, supabase] = await Promise.all([params, searchParams, createClient()])
  const [{ data, error }, { data: roleAssignments }] = await Promise.all([
    supabase.rpc('get_employee_dossier', { p_employee_id: id }),
    supabase.from('user_roles')
      .select('school_id,roles(role_permissions(permissions(code)))')
      .eq('user_id', context.profile.id)
      .eq('is_active', true),
  ])
  if (error || !data) notFound()

  const dossier = data as Record<string, any>
  const employee = dossier.employee ?? {}
  const contracts = dossier.contracts ?? []
  const leaves = dossier.leaves ?? []
  const skills = dossier.skills ?? []
  const trainings = dossier.trainings ?? []
  const hasHrManage = (roleAssignments ?? []).some((assignment: any) => {
    if (assignment.school_id !== null && assignment.school_id !== context.profile.school_id) return false
    return (assignment.roles?.role_permissions ?? []).some((item: any) => item.permissions?.code === 'hr.manage')
  })
  const canEdit = hasHrManage || context.roles.some(({ code }) => code === 'super_admin')

  return (
    <main className="page">
      <div className="page-header">
        <div>
          <h1 className="page-title">{employee.last_name} {employee.first_name}</h1>
          <p className="page-subtitle">{employee.employee_number} • {employee.job_title ?? 'Fonction non renseignée'} • {employee.department ?? 'Service non renseigné'}</p>
        </div>
        <div className="actions">
          <Link className="button button-secondary" href="/personnel/employes">Retour</Link>
          <Link className="button button-secondary" href={`/personnel/contrats?employee=${id}`}>Contrats</Link>
          {canEdit ? <a className="button button-primary" href="#modifier-employe">Modifier les informations</a> : null}
        </div>
      </div>

      {query.updated ? <p className="success">Informations de l’employé mises à jour.</p> : null}
      {query.error ? <p className="error">{query.error}</p> : null}

      {canEdit ? (
        <section className="card" id="modifier-employe" style={{ marginBottom: 16 }}>
          <h2>Modifier les informations de l’employé</h2>
          <form action={updateEmployee} className="grid grid-2">
            <input type="hidden" name="employeeId" value={id} />
            <div className="field"><label className="label" htmlFor="employeeNumber">N° employé *</label><input className="input" id="employeeNumber" name="employeeNumber" defaultValue={employee.employee_number ?? ''} required maxLength={50} /></div>
            <div className="field"><label className="label" htmlFor="jobTitle">Fonction</label><input className="input" id="jobTitle" name="jobTitle" defaultValue={employee.job_title ?? ''} maxLength={160} /></div>
            <div className="field"><label className="label" htmlFor="firstName">Prénom *</label><input className="input" id="firstName" name="firstName" defaultValue={employee.first_name ?? ''} required maxLength={120} /></div>
            <div className="field"><label className="label" htmlFor="lastName">Nom *</label><input className="input" id="lastName" name="lastName" defaultValue={employee.last_name ?? ''} required maxLength={120} /></div>
            <div className="field"><label className="label" htmlFor="department">Service</label><input className="input" id="department" name="department" defaultValue={employee.department ?? ''} maxLength={160} /></div>
            <div className="field"><label className="label" htmlFor="qualification">Qualification</label><input className="input" id="qualification" name="qualification" defaultValue={employee.qualification ?? ''} maxLength={255} /></div>
            <div className="field"><label className="label" htmlFor="gender">Genre</label><select className="select" id="gender" name="gender" defaultValue={employee.gender ?? ''}><option value="">Non renseigné</option><option value="male">Masculin</option><option value="female">Féminin</option><option value="other">Autre</option></select></div>
            <div className="field"><label className="label" htmlFor="hireDate">Date d’embauche</label><input className="input" id="hireDate" name="hireDate" type="date" defaultValue={employee.hire_date ?? ''} /></div>
            <div className="field"><label className="label" htmlFor="dateOfBirth">Date de naissance</label><input className="input" id="dateOfBirth" name="dateOfBirth" type="date" defaultValue={employee.date_of_birth ?? ''} /></div>
            <div className="field"><label className="label" htmlFor="placeOfBirth">Lieu de naissance</label><input className="input" id="placeOfBirth" name="placeOfBirth" defaultValue={employee.place_of_birth ?? ''} maxLength={120} /></div>
            <div className="field"><label className="label" htmlFor="phone">Téléphone</label><input className="input" id="phone" name="phone" defaultValue={employee.phone ?? ''} maxLength={50} /></div>
            <div className="field"><label className="label" htmlFor="email">E-mail</label><input className="input" id="email" name="email" type="email" defaultValue={employee.email ?? ''} maxLength={255} /></div>
            <div className="field" style={{ gridColumn: '1 / -1' }}><label className="label" htmlFor="address">Adresse</label><input className="input" id="address" name="address" defaultValue={employee.address ?? ''} maxLength={500} /></div>
            <button className="button button-primary" type="submit">Enregistrer les modifications</button>
          </form>
        </section>
      ) : null}

      <section className="grid grid-4">
        <article className="card"><h3>Statut</h3><p className="metric" style={{ fontSize: 24 }}>{employee.status}</p></article>
        <article className="card"><h3>Téléphone</h3><p>{employee.phone ?? '—'}</p></article>
        <article className="card"><h3>Email</h3><p>{employee.email ?? '—'}</p></article>
        <article className="card"><h3>Embauche</h3><p>{employee.hire_date ?? '—'}</p></article>
      </section>
      <section className="grid grid-2" style={{ marginTop: 16 }}>
        <article className="card"><h2>Contrats</h2><div className="table-wrap"><table><thead><tr><th>Type</th><th>Période</th><th>Salaire</th><th>Statut</th></tr></thead><tbody>{contracts.map((c: any) => <tr key={c.id}><td>{c.contract_type}</td><td>{c.start_date} → {c.end_date ?? '∞'}</td><td>{c.salary ?? '—'}</td><td>{c.status}</td></tr>)}</tbody></table></div>{!contracts.length ? <p className="empty">Aucun contrat.</p> : null}</article>
        <article className="card"><h2>Congés</h2><div className="table-wrap"><table><thead><tr><th>Type</th><th>Période</th><th>Statut</th></tr></thead><tbody>{leaves.slice(0, 10).map((l: any) => <tr key={l.id}><td>{l.leave_type}</td><td>{l.start_date} → {l.end_date}</td><td>{l.status}</td></tr>)}</tbody></table></div>{!leaves.length ? <p className="empty">Aucune demande.</p> : null}</article>
        <article className="card"><h2>Compétences</h2>{skills.map((s: any) => <p key={s.id}><strong>{s.skill_name}</strong> — {s.level ?? 'niveau non renseigné'}</p>)}{!skills.length ? <p className="empty">Aucune compétence enregistrée.</p> : null}</article>
        <article className="card"><h2>Formations</h2>{trainings.map((t: any) => <p key={t.id}><strong>{t.title}</strong>{t.provider ? ` — ${t.provider}` : ''} <span className="badge">{t.status}</span></p>)}{!trainings.length ? <p className="empty">Aucune formation enregistrée.</p> : null}</article>
      </section>
    </main>
  )
}
