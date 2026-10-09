export default function Page() {
  return (
    <main className="page">
      <div className="page-header">
        <div>
          <h1 className="page-title">Administration IT</h1>
          <p className="page-subtitle">Module préparé dans l’architecture SIGIA-AMINE.</p>
        </div>
        <span className="badge">À construire</span>
      </div>
      <section className="card empty">
        <h2 style={{ marginTop: 0, color: 'var(--text)' }}>Socle prêt</h2>
        <p>Les migrations, l’authentification, le RBAC, le RLS et le layout global sont en place. Ce module sera développé selon l’ordre fonctionnel validé.</p>
      </section>
    </main>
  )
}
