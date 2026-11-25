import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'
import { getCurrentUserContext } from '@/lib/auth/current-user'
import { deleteEmployee, setEmployeeStatus } from '../personnel-actions'

export default async function EmployeesPage({ searchParams }: { searchParams: Promise<{ error?: string; updated?: string; deleted?: string }> }) {
  const context = await getCurrentUserContext()
  if (!context?.profile.school_id) return null

  const [params, supabase] = await Promise.all([searchParams, createClient()])
  const [{ data: rows }, { data: roleAssignments }] = await Promise.all([
    supabase.from('employees')
      .select('id,employee_number,first_name,last_name,job_title,department,phone,status,hire_date,teacher_profiles(speciality)')
      .eq('school_id', context.profile.school_id)
      .order('last_name', { ascending: true })
      .order('first_name', { ascending: true }),
    supabase.from('user_roles')
      .select('school_id,roles(role_permissions(permissions(code)))')
      .eq('user_id', context.profile.id)
      .eq('is_active', true),
  ])

  const canEdit = context.roles.some(({ code }) => code === 'super_admin')
    || (roleAssignments ?? []).some((assignment: any) => {
      if (assignment.school_id !== null && assignment.school_id !== context.profile.school_id) return false
      return (assignment.roles?.role_permissions ?? []).some((item: any) => item.permissions?.code === 'hr.manage')
    })

  return <main className="page">
    <div className="page-header">
      <div><h1 className="page-title">Dossiers employés</h1><p className="page-subtitle">Personnel administratif, pédagogique et services.</p></div>
      <Link className="button button-primary" href="/personnel/employes/nouveau">+ Nouvel employé</Link>
    </div>
    {params.error ? <p className="error">{params.error}</p> : null}
    {params.updated ? <p className="success">Dossier employé mis à jour.</p> : null}
    {params.deleted ? <p className="success">Employé supprimé définitivement.</p> : null}
    <section className="card">
      <div className="table-wrap">
        <table>
          <thead><tr><th>N°</th><th>Nom</th><th>Fonctions</th><th>Service</th><th>Embauche</th><th>Statut</th><th>Actions</th></tr></thead>
          <tbody>
            {(rows ?? []).map((employee: any) => {
              const teacherProfile = Array.isArray(employee.teacher_profiles)
                ? employee.teacher_profiles[0]
                : employee.teacher_profiles
              return <tr key={employee.id}>
              <td>{employee.employee_number}</td>
              <td>{employee.last_name?.toLocaleUpperCase('fr-FR')} {employee.first_name}</td>
              <td>{employee.job_title ?? '—'}{teacherProfile?.speciality ? <div className="page-subtitle">Enseignant · {teacherProfile.speciality}</div> : null}</td>
              <td>{employee.department ?? '—'}</td>
              <td>{employee.hire_date ?? '—'}</td>
              <td><span className="badge">{employee.status}</span></td>
              <td className="actions">
                <Link className="button button-secondary" href={`/personnel/employes/${employee.id}`}>Dossier</Link>
                {canEdit ? <Link className="button button-primary" href={`/personnel/employes/${employee.id}#modifier-employe`}>Modifier</Link> : null}
                {canEdit ? <form action={setEmployeeStatus}>
                  <input type="hidden" name="employeeId" value={employee.id} />
                  <input type="hidden" name="status" value={employee.status === 'active' ? 'inactive' : 'active'} />
                  <button className="button button-secondary" type="submit">{employee.status === 'active' ? 'Désactiver' : 'Activer'}</button>
                </form> : null}
                {canEdit ? <details className="user-delete">
                  <summary>Supprimer</summary>
                  <form action={deleteEmployee} className="delete-action">
                    <input type="hidden" name="employeeId" value={employee.id} />
                    <label className="label" htmlFor={`delete-employee-${employee.id}`}>Confirmez en saisissant SUPPRIMER</label>
                    <input className="input" id={`delete-employee-${employee.id}`} name="confirmation" pattern="SUPPRIMER" required />
                    <button className="button button-danger" type="submit">Supprimer définitivement</button>
                  </form>
                </details> : null}
              </td>
              </tr>
            })}
            {!rows?.length ? <tr><td colSpan={7}><div className="empty">Aucun employé.</div></td></tr> : null}
          </tbody>
        </table>
      </div>
    </section>
  </main>
}
