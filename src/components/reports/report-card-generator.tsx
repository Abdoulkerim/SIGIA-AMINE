'use client'

import { useMemo, useState } from 'react'
import { generateReportCards } from '@/app/(dashboard)/pedagogie/pedagogie-actions'

type Option = { id: string; name: string; school_year_id?: string; is_closed?: boolean; is_current?: boolean }
type Enrollment = {
  student_id: string
  class_id: string
  school_year_id: string
  students: { first_name: string | null; last_name: string | null } | null
}

export function ReportCardGenerator({ years, periods, classes, enrollments }: {
  years: Option[]
  periods: Option[]
  classes: Option[]
  enrollments: Enrollment[]
}) {
  const initialYear = years.find((year) => year.is_current)?.id ?? years[0]?.id ?? ''
  const [yearId, setYearId] = useState(initialYear)
  const [classId, setClassId] = useState('')
  const [periodId, setPeriodId] = useState('')
  const [selected, setSelected] = useState<string[]>([])

  const availableClasses = classes.filter((item) => item.school_year_id === yearId)
  const availablePeriods = periods.filter((item) => item.school_year_id === yearId)
  const students = useMemo(() => {
    const unique = new Map<string, Enrollment>()
    enrollments.filter((row) => row.school_year_id === yearId && row.class_id === classId).forEach((row) => {
      if (!unique.has(row.student_id)) unique.set(row.student_id, row)
    })
    return [...unique.values()].sort((a, b) => `${a.students?.last_name ?? ''} ${a.students?.first_name ?? ''}`.localeCompare(`${b.students?.last_name ?? ''} ${b.students?.first_name ?? ''}`))
  }, [enrollments, yearId, classId])

  function changeYear(value: string) {
    setYearId(value); setClassId(''); setPeriodId(''); setSelected([])
  }
  function changeClass(value: string) { setClassId(value); setSelected([]) }
  const allSelected = students.length > 0 && students.every((row) => selected.includes(row.student_id))

  return <section className="card" style={{ marginBottom: 20 }}>
    <h2 style={{ marginTop: 0 }}>Générer les bulletins</h2>
    <form action={generateReportCards}>
      <div className="grid grid-2">
        <label className="field"><span className="label">Année scolaire</span><select className="select" name="schoolYearId" required value={yearId} onChange={(e) => changeYear(e.target.value)}><option value="">Sélectionner</option>{years.map((y) => <option key={y.id} value={y.id}>{y.name}</option>)}</select></label>
        <label className="field"><span className="label">Période</span><select className="select" name="periodId" required value={periodId} onChange={(e) => setPeriodId(e.target.value)}><option value="">Sélectionner</option>{availablePeriods.map((p) => <option key={p.id} value={p.id}>{p.name}{p.is_closed ? ' — clôturée' : ''}</option>)}</select></label>
        <label className="field"><span className="label">Classe</span><select className="select" name="classId" value={classId} onChange={(e) => changeClass(e.target.value)} required><option value="">Sélectionner une classe</option>{availableClasses.map((item) => <option key={item.id} value={item.id}>{item.name}</option>)}</select></label>
      </div>
      <div className="field" style={{ margin: '12px 0 16px' }}>
        <span className="label">Élèves de la classe ({students.length})</span>
        <div style={{ maxHeight: 280, overflowY: 'auto', border: '1px solid var(--border, #d8e0eb)', borderRadius: 10, padding: 12 }}>
          {!classId ? <p className="empty">Choisissez une classe pour afficher ses élèves.</p> : students.length ? <>
            <label style={{ display: 'flex', gap: 8, padding: '6px 0', fontWeight: 700 }}><input type="checkbox" checked={allSelected} onChange={() => setSelected(allSelected ? [] : students.map((row) => row.student_id))} />Tout sélectionner</label>
            {students.map((row) => <label key={row.student_id} style={{ display: 'flex', gap: 8, padding: '6px 0' }}><input type="checkbox" name="studentIds" value={row.student_id} checked={selected.includes(row.student_id)} onChange={(e) => setSelected(e.target.checked ? [...selected, row.student_id] : selected.filter((id) => id !== row.student_id))} />{`${row.students?.last_name ?? ''} ${row.students?.first_name ?? ''}`.trim()}</label>)}
          </> : <p className="empty">Aucun élève inscrit dans cette classe pour cette année.</p>}
        </div>
      </div>
      <button className="button button-primary" type="submit" disabled={!classId || !periodId || selected.length === 0}>Générer les bulletins sélectionnés ({selected.length})</button>
    </form>
  </section>
}
