'use client'

import { useState } from 'react'
import { Eye, EyeOff } from 'lucide-react'

export function PasswordField() {
  const [visible, setVisible] = useState(false)
  return (
    <div className="login-password-wrap">
      <input className="input" id="password" name="password" type={visible ? 'text' : 'password'} autoComplete="current-password" placeholder="Votre mot de passe" required />
      <button className="login-password-toggle" type="button" onClick={() => setVisible((value) => !value)} aria-label={visible ? 'Masquer le mot de passe' : 'Afficher le mot de passe'} aria-pressed={visible} aria-controls="password">
        {visible ? <EyeOff size={18} aria-hidden="true" /> : <Eye size={18} aria-hidden="true" />}
      </button>
    </div>
  )
}
