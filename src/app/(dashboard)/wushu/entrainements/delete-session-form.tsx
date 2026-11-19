'use client'

import type { FormEvent } from 'react'

export function DeleteWushuSessionForm({ action, sessionId }: { action: (formData: FormData) => void | Promise<void>; sessionId: string }) {
  function confirmDeletion(event: FormEvent<HTMLFormElement>) {
    if (!window.confirm('Supprimer définitivement cette séance Wushu ? Les présences associées seront également supprimées.')) {
      event.preventDefault()
    }
  }

  return <form action={action} onSubmit={confirmDeletion}>
    <input type="hidden" name="sessionId" value={sessionId} />
    <button className="button" type="submit">Supprimer</button>
  </form>
}
