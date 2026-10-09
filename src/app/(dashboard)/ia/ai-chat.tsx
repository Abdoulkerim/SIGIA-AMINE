
'use client'

import { useEffect, useState, useTransition } from 'react'
import { getAiMessages, sendAiMessage } from './ai-actions'

type Conversation = { id: string; title: string | null; mode: string; status: string; updated_at: string; model: string | null }
type Message = { id: string; role: string; content: string; created_at: string }

const quickPrompts = [
  ['Pilotage', 'Donne-moi une synthèse factuelle de la situation actuelle de l’établissement.'],
  ['Pédagogie', 'Analyse les résultats et l’assiduité disponibles et signale les points à vérifier.'],
  ['Finance', 'Analyse la situation financière actuelle et identifie les écarts à examiner.'],
  ['Élève', 'Je veux retrouver le résumé d’un élève à partir de son nom.'],
]

export default function AiChat({ initialConversations }: { initialConversations: Conversation[] }) {
  const [conversations, setConversations] = useState(initialConversations)
  const [activeId, setActiveId] = useState<string | null>(initialConversations[0]?.id ?? null)
  const [messages, setMessages] = useState<Message[]>([])
  const [text, setText] = useState('')
  const [mode, setMode] = useState('assistant')
  const [pending, startTransition] = useTransition()
  const [error, setError] = useState('')

  useEffect(() => {
    if (!activeId) { setMessages([]); return }
    startTransition(async () => {
      try { setMessages(await getAiMessages(activeId)) }
      catch (e) { setError(e instanceof Error ? e.message : 'Erreur de lecture.') }
    })
  }, [activeId])

  function ask(prompt: string) {
    setText(prompt)
    setTimeout(() => document.getElementById('ai-message-input')?.focus(), 0)
  }

  async function submit() {
    const message = text.trim()
    if (!message || pending) return
    setError('')
    setText('')
    startTransition(async () => {
      try {
        const result = await sendAiMessage(activeId, message, mode)
        if (!activeId) setActiveId(result.conversation_id)
        setMessages((current) => [...current, { id: `user-${Date.now()}`, role: 'user', content: message, created_at: new Date().toISOString() }, result.message])
        if (!activeId) setConversations((current) => [{ id: result.conversation_id, title: message.slice(0,80), mode, status: 'active', updated_at: new Date().toISOString(), model: null }, ...current])
      } catch (e) {
        setError(e instanceof Error ? e.message : 'Erreur IA.')
      }
    })
  }

  return (
    <section className="grid grid-2" style={{ alignItems: 'start' }}>
      <div className="card">
        <div className="page-header" style={{ marginBottom: 12 }}>
          <div>
            <h2 style={{ margin: 0 }}>Assistant</h2>
            <p className="page-subtitle">Lecture des données autorisées, analyse et rédaction. Aucune modification métier directe.</p>
          </div>
          <select className="select" value={mode} onChange={(e) => setMode(e.target.value)}>
            <option value="assistant">Assistant</option>
            <option value="analyze">Analyse</option>
            <option value="compare">Comparaison</option>
            <option value="report">Rapport</option>
            <option value="alerts">Alertes</option>
          </select>
        </div>

        <div className="grid grid-2" style={{ marginBottom: 16 }}>
          {quickPrompts.map(([label, prompt]) => <button key={label} type="button" className="button button-secondary" onClick={() => ask(prompt)}>{label}</button>)}
        </div>

        <div style={{ minHeight: 430, maxHeight: 560, overflowY: 'auto', display: 'grid', gap: 10, padding: 4 }}>
          {!messages.length && <div className="empty">Pose une question sur les données auxquelles ton profil a accès.</div>}
          {messages.map((m) => (
            <div key={m.id} className="card" style={{ margin: 0, background: m.role === 'user' ? 'var(--card)' : 'var(--background)' }}>
              <div className="stat-label">{m.role === 'user' ? 'VOUS' : 'SIGIA-AMINE IA'}</div>
              <div style={{ whiteSpace: 'pre-wrap', lineHeight: 1.55 }}>{m.content}</div>
            </div>
          ))}
        </div>

        {error && <div className="error" style={{ marginTop: 12 }}>{error}</div>}

        <div className="field" style={{ marginTop: 16 }}>
          <label className="label" htmlFor="ai-message-input">Votre demande</label>
          <textarea id="ai-message-input" className="input" rows={4} value={text} onChange={(e) => setText(e.target.value)} onKeyDown={(e) => { if ((e.ctrlKey || e.metaKey) && e.key === 'Enter') submit() }} placeholder="Ex. Analyse les absences des 30 derniers jours et indique les points à vérifier." />
        </div>
        <div style={{ display: 'flex', justifyContent: 'flex-end', marginTop: 10 }}>
          <button type="button" className="button button-primary" onClick={submit} disabled={pending}>{pending ? 'Analyse en cours…' : 'Envoyer'}</button>
        </div>
      </div>

      <div className="card">
        <div className="page-header">
          <div>
            <h2 style={{ margin: 0 }}>Conversations</h2>
            <p className="page-subtitle">Historique personnel des échanges.</p>
          </div>
        </div>
        {!conversations.length && <div className="empty">Aucune conversation.</div>}
        <div style={{ display: 'grid', gap: 8 }}>
          {conversations.map((c) => <button key={c.id} type="button" onClick={() => setActiveId(c.id)} className="card" style={{ textAlign: 'left', cursor: 'pointer', margin: 0 }}>
            <div className="stat-label">{c.mode}</div>
            <strong>{c.title || 'Nouvelle conversation'}</strong>
            <div className="page-subtitle">{new Date(c.updated_at).toLocaleString('fr-FR')}</div>
          </button>)}
        </div>
      </div>
    </section>
  )
}
