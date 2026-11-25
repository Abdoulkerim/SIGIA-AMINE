'use client'

import { usePathname } from 'next/navigation'
import { setArabicActiveStage } from '@/app/(dashboard)/tahfiz-arabe/tahfiz-arabe-actions'

export function ArabicStageSwitch({
  stages,
  selectedStage,
}: {
  stages: { value: string; label: string }[]
  selectedStage: string
}) {
  const pathname = usePathname()

  if (stages.length < 2) return null

  return (
    <form action={setArabicActiveStage} className="arabic-stage-switch">
      <input type="hidden" name="returnTo" value={pathname} />
      <label>
        <span>Cycle Arabe</span>
        <select
          className="select"
          name="stage"
          defaultValue={selectedStage}
          onChange={(event) => event.currentTarget.form?.requestSubmit()}
          aria-label="Changer le cycle Arabe"
        >
          {stages.map((stage) => (
            <option key={stage.value} value={stage.value}>{stage.label}</option>
          ))}
        </select>
      </label>
    </form>
  )
}
