'use client'

import { createClient } from '@/lib/supabase/client'

export function LogoutButton() {
  async function logout() {
    const supabase = createClient()
    await supabase.auth.signOut()
    window.location.href = '/login'
  }

  return (
    <button className="button button-secondary" type="button" onClick={logout}>
      Déconnexion
    </button>
  )
}
