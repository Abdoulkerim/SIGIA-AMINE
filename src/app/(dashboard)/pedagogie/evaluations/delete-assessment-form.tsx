'use client'

import { deleteAssessment } from '../pedagogie-actions'

export function DeleteAssessmentForm({ id, title }: { id: string; title: string }) {
  return <form action={deleteAssessment} onSubmit={event => {
    if (!window.confirm(`Supprimer l’évaluation « ${title} » et toutes les notes associées ? Cette action est définitive.`)) event.preventDefault()
  }}>
    <input type="hidden" name="id" value={id} />
    <button className="button button-secondary" type="submit">Supprimer</button>
  </form>
}
