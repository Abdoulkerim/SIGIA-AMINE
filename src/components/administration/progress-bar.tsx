export function ProgressBar({ value }: { value: number | null | undefined }) {
  const progress = Math.min(100, Math.max(0, Number.isFinite(Number(value)) ? Number(value) : 0))
  const rounded = Math.round(progress * 100) / 100

  return (
    <div style={{ display: 'grid', gridTemplateColumns: 'minmax(90px, 1fr) auto', alignItems: 'center', gap: 8, minWidth: 130 }}>
      <div
        role="progressbar"
        aria-label="Progression de l’élève"
        aria-valuemin={0}
        aria-valuemax={100}
        aria-valuenow={rounded}
        style={{ height: 10, overflow: 'hidden', borderRadius: 999, background: '#e5eaf0' }}
      >
        <div style={{ width: `${rounded}%`, height: '100%', borderRadius: 999, background: '#16805d', transition: 'width 250ms ease' }} />
      </div>
      <strong style={{ whiteSpace: 'nowrap' }}>{rounded}%</strong>
    </div>
  )
}
