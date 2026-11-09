'use client'

import { useState } from 'react'

type SchoolYear = { id: string; name: string; is_current: boolean }
type AcademicPeriod = { id: string; name: string; school_year_id: string; start_date: string; end_date: string; is_closed: boolean }

export function PeriodFields({ years, periods, initialYearId }: { years: SchoolYear[]; periods: AcademicPeriod[]; initialYearId: string }) {
  const [schoolYearId, setSchoolYearId] = useState(initialYearId)
  const openPeriods = periods.filter(period => period.school_year_id === schoolYearId && !period.is_closed)

  return <>
    <label className="field"><span className="label">Année scolaire</span><select className="select" name="schoolYearId" value={schoolYearId} onChange={event => setSchoolYearId(event.target.value)} required>{years.map(year => <option key={year.id} value={year.id}>{year.name}</option>)}</select></label>
    <label className="field"><span className="label">Période</span><select className="select" name="periodId" key={schoolYearId} defaultValue="" required><option value="">Sélectionner</option>{openPeriods.map(period => <option key={period.id} value={period.id}>{period.name} ({period.start_date} → {period.end_date})</option>)}</select></label>
  </>
}
