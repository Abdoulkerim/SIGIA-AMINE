export type ManagedCard = { number: string; name: string; detail: string; status: string }

export function CardManager({ cards, title }: { cards: ManagedCard[]; title: string; fileName?: string; cardTitle?: string }) {
  return (
    <>
      <section className="card">
        <h2>{title}</h2>
        <p className="page-subtitle">Consultation seule · {cards.length} fiche(s)</p>
      </section>
      <section className="grid grid-3 card-preview-grid" aria-label={`Liste des cartes : ${title}`}>
        {cards.map((card) => (
          <article className="id-card-preview" key={card.number}>
            <div className="id-card-brand"><span>AA</span><div><strong>COMPLEXE SCOLAIRE AL AMINE</strong><small>{title.toLocaleUpperCase('fr')}</small></div></div>
            <div className="id-card-body">
              <small>Nom complet</small>
              <strong>{card.name}</strong>
              <div><span><small>Matricule</small><b>{card.number}</b></span><span><small>Classe / fonction</small><b>{card.detail}</b></span></div>
            </div>
            <footer>{card.status}</footer>
          </article>
        ))}
      </section>
      {!cards.length ? <p className="empty">Aucune carte à consulter.</p> : null}
    </>
  )
}
