'use client'

import { ImagePlus, RotateCcw, Trash2, Upload } from 'lucide-react'
import { useEffect, useRef, useState } from 'react'

const MAX_SIZE = 2 * 1024 * 1024
const ACCEPTED_TYPES = ['image/jpeg', 'image/png', 'image/webp']

export function PhotoUpload({ initialPhotoUrl }: { initialPhotoUrl?: string | null }) {
  const inputRef = useRef<HTMLInputElement>(null)
  const [preview, setPreview] = useState(initialPhotoUrl ?? '')
  const [error, setError] = useState('')
  const [removed, setRemoved] = useState(false)

  useEffect(() => () => {
    if (preview.startsWith('blob:')) URL.revokeObjectURL(preview)
  }, [preview])

  function selectFile(file?: File) {
    setError('')
    if (!file) return
    const extension = file.name.split('.').pop()?.toLowerCase()
    if (!ACCEPTED_TYPES.includes(file.type) || !['jpg', 'jpeg', 'png', 'webp'].includes(extension ?? '')) {
      setError('Format incorrect. Choisissez une image JPG, JPEG, PNG ou WEBP.')
      if (inputRef.current) inputRef.current.value = ''
      return
    }
    if (file.size > MAX_SIZE) {
      setError('Le fichier dépasse la taille maximale de 2 Mo.')
      if (inputRef.current) inputRef.current.value = ''
      return
    }
    setPreview(URL.createObjectURL(file))
    setRemoved(false)
  }

  function removePhoto() {
    setPreview('')
    setRemoved(true)
    setError('')
    if (inputRef.current) inputRef.current.value = ''
  }

  return (
    <div className="field">
      <span className="label" id="student-photo-label">Photo de l’élève</span>
      <input ref={inputRef} id="studentPhoto" name="photoFile" type="file" accept="image/jpeg,image/png,image/webp,.jpg,.jpeg,.png,.webp" aria-labelledby="student-photo-label" aria-describedby="student-photo-help student-photo-error" onChange={(event) => selectFile(event.currentTarget.files?.[0])} style={{ position: 'absolute', width: 1, height: 1, padding: 0, margin: -1, overflow: 'hidden', clip: 'rect(0, 0, 0, 0)', whiteSpace: 'nowrap', border: 0 }} />
      <input type="hidden" name="removePhoto" value={removed ? 'true' : 'false'} />
      {preview ? (
        <div style={{ display: 'flex', alignItems: 'center', gap: 16, flexWrap: 'wrap' }}>
          <img src={preview} alt="Aperçu de la photo de l’élève" style={{ width: 112, height: 112, borderRadius: 12, objectFit: 'cover', border: '1px solid var(--border)' }} />
          <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
            <button className="button button-secondary" type="button" onClick={() => inputRef.current?.click()}><RotateCcw size={16} /> Remplacer</button>
            <button className="button button-secondary" type="button" onClick={removePhoto}><Trash2 size={16} /> Retirer</button>
          </div>
        </div>
      ) : (
        <button type="button" onClick={() => inputRef.current?.click()} aria-describedby="student-photo-help student-photo-error" style={{ width: '100%', minHeight: 132, padding: 20, border: '2px dashed var(--border)', borderRadius: 12, background: 'var(--surface, transparent)', color: 'var(--text)', cursor: 'pointer', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 8 }}>
          {removed ? <Upload size={24} aria-hidden="true" /> : <ImagePlus size={24} aria-hidden="true" />}
          <strong>{removed ? 'Ajouter une autre photo' : 'Cliquez pour importer une photo'}</strong>
          <span id="student-photo-help" className="page-subtitle">JPG, JPEG, PNG ou WEBP · 2 Mo maximum</span>
        </button>
      )}
      {error ? <p className="error" id="student-photo-error" role="alert">{error}</p> : <span id="student-photo-error" />}
    </div>
  )
}
