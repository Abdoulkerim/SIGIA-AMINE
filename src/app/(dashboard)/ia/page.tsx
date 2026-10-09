
import { getAiWorkspace } from './ai-actions'
import AiChat from './ai-chat'

export default async function AiPage() {
  const workspace = await getAiWorkspace()
  return (
    <main className="page">
      <div className="page-header">
        <div>
          <h1 className="page-title">Intelligence artificielle</h1>
          <p className="page-subtitle">Assistant sécurisé du SIGIA-AMINE : rechercher, analyser, comparer, générer et signaler.</p>
        </div>
        <span className="badge">Étape 25</span>
      </div>
      <section className="card" style={{ marginBottom: 16 }}>
        <strong>Principe de sécurité</strong>
        <p className="page-subtitle" style={{ marginBottom: 0 }}>L’IA peut lire uniquement les données autorisées par ton profil. Les alertes sont des signaux à valider par un responsable et les données métier ne sont jamais modifiées directement par le modèle.</p>
      </section>
      <AiChat initialConversations={workspace.conversations} />
    </main>
  )
}
