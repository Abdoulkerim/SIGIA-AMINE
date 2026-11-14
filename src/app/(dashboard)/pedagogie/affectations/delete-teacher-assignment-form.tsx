'use client'

import { deleteTeacherAssignment } from '../../personnel/teacher-actions'

export function DeleteTeacherAssignmentForm({ id, label }: { id: string; label: string }) {
  return <form action={deleteTeacherAssignment} onSubmit={event => {
    if (!window.confirm(`Supprimer l’affectation de ${label} ?`)) event.preventDefault()
  }}>
    <input type="hidden" name="id" value={id} />
    <button className="button button-secondary" type="submit">Supprimer</button>
  </form>
}
