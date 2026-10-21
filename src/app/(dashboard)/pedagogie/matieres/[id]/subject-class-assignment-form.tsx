'use client'

import { useState } from 'react'
import Link from 'next/link'
import { assignSubjectToClass } from '../../subjects-actions'

type SchoolYear = { id: string; name: string; is_current: boolean }
type SchoolClass = { id: string; name: string; code: string; school_year_id: string }

export default function SubjectClassAssignmentForm({ subjectId, weeklyHours, years, classes }: { subjectId: string; weeklyHours: number | null; years: SchoolYear[]; classes: SchoolClass[] }) {
  const initialYearId = years.find((year) => year.is_current)?.id ?? years[0]?.id ?? ''
  const [schoolYearId, setSchoolYearId] = useState(initialYearId)
  const availableClasses = classes.filter((item) => item.school_year_id === schoolYearId)
  const [classId, setClassId] = useState(availableClasses[0]?.id ?? '')

  function changeYear(nextYearId: string) {
    setSchoolYearId(nextYearId)
    setClassId(classes.find((item) => item.school_year_id === nextYearId)?.id ?? '')
  }

  return (
    <form action={assignSubjectToClass} className="grid grid-3">
      <input type="hidden" name="subjectId" value={subjectId} />
      <div className="field">
        <label className="label" htmlFor="schoolYearId">Année *</label>
        <select className="select" id="schoolYearId" name="schoolYearId" value={schoolYearId} onChange={(event) => changeYear(event.target.value)} required>
          {years.map((year) => <option key={year.id} value={year.id}>{year.name}{year.is_current ? ' — actuelle' : ''}</option>)}
        </select>
      </div>
      <div className="field">
        <label className="label" htmlFor="classId">Classe *</label>
        <select className="select" id="classId" name="classId" value={classId} onChange={(event) => setClassId(event.target.value)} required disabled={!availableClasses.length}>
          {availableClasses.map((item) => <option key={item.id} value={item.id}>{item.code} — {item.name}</option>)}
        </select>
        {!availableClasses.length ? <p className="field-hint">Aucune classe active pour cette année. <Link href="/administration/classes/nouveau">Créer une classe</Link></p> : null}
      </div>
      <div className="field">
        <label className="label" htmlFor="coefficientOverride">Coefficient de cette matière dans la classe *</label>
        <input className="input" id="coefficientOverride" name="coefficientOverride" type="number" min="0.01" step="0.01" placeholder="Ex. 3" required />
      </div>
      <div className="field">
        <label className="label" htmlFor="weeklyHoursOverride">H/semaine spécifique</label>
        <input className="input" id="weeklyHoursOverride" name="weeklyHoursOverride" type="number" min="0.01" step="0.25" placeholder={`Par défaut : ${weeklyHours ?? 'non défini'}`} />
      </div>
      <div className="field">
        <label className="label" htmlFor="isRequired">Obligatoire ?</label>
        <select className="select" id="isRequired" name="isRequired" defaultValue="true"><option value="true">Oui</option><option value="false">Non</option></select>
      </div>
      <div className="actions" style={{ alignSelf: 'end' }}>
        <button className="button button-primary" type="submit" disabled={!availableClasses.length}>Enregistrer le rattachement</button>
      </div>
    </form>
  )
}
