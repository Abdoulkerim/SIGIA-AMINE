'use client'

import { useState } from 'react'
import { Eye, EyeOff } from 'lucide-react'

export function InitialPasswordField() {
  const [visible, setVisible] = useState(false)

  return (
    <div className="managed-password-wrap">
      <input className="input" id="password" name="password" type={visible ? 'text' : 'password'} autoComplete="new-password" minLength={10} maxLength={128} required />
      <button className="managed-password-toggle" type="button" onClick={() => setVisible((value) => !value)} aria-label={visible ? 'Masquer le mot de passe' : 'Afficher le mot de passe'} aria-pressed={visible} aria-controls="password">
        {visible ? <EyeOff size={18} aria-hidden="true" /> : <Eye size={18} aria-hidden="true" />}
      </button>
    </div>
  )
}
