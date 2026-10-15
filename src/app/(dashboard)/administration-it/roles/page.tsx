import { createClient } from '@/lib/supabase/server'

export default async function ITRolesPage() {
  const supabase = await createClient()
  const { data: roles, error } = await supabase
    .from('roles')
    .select('id,code,name,description,role_permissions(permission_id,permissions(code,name,module))')
    .order('name')

  return (
    <main className="page">
      <div className="page-header"><div><h1 className="page-title">Rôles et permissions</h1><p className="page-subtitle">Référentiel de contrôle d’accès configuré pour SIGIA-AMINE.</p></div><span className="badge">{roles?.length ?? 0} rôle(s)</span></div>
      {error ? <p className="error">Impossible de charger les rôles : {error.message}</p> : null}
      <section className="table-wrap">
        <table>
          <thead><tr><th>Rôle</th><th>Code</th><th>Description</th><th>Permissions accordées</th></tr></thead>
          <tbody>
            {(roles ?? []).map((role: any) => {
              const permissions = (role.role_permissions ?? []).map((item: any) => item.permissions).filter(Boolean)
              return (
                <tr key={role.id}>
                  <td><strong>{role.name}</strong></td>
                  <td><code>{role.code}</code></td>
                  <td>{role.description ?? '—'}</td>
                  <td><div className="it-permission-list">{permissions.length ? permissions.map((permission: any) => <span className="it-permission-chip" key={permission.code} title={permission.module}>{permission.name}</span>) : <span>Aucune permission explicite</span>}</div></td>
                </tr>
              )
            })}
          </tbody>
        </table>
        {!roles?.length ? <p className="empty">Aucun rôle configuré.</p> : null}
      </section>
      <p className="page-subtitle" style={{ marginTop: 12 }}>Les permissions effectives sont contrôlées par la base de données et ses règles d’accès.</p>
    </main>
  )
}
