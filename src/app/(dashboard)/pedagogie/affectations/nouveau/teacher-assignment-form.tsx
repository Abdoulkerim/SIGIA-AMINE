'use client'

import Link from 'next/link'
import { useMemo, useState } from 'react'

type Year = { id: string; name: string; is_current: boolean }
type Teacher = { id: string; employee_number: string; first_name: string; last_name: string }
type SchoolClass = { id: string; name: string; code: string; school_year_id: string }
type Subject = { id: string; name: string; code: string }
type EligibleAssignment = { school_year_id: string; class_id: string; subject_id: string }

export default function TeacherAssignmentForm({
  years, teachers, teachersError, classes, subjects, eligibleAssignments, selectedTeacherId, action, initialAssignment,
}: {
  years: Year[]
  teachers: Teacher[]
  teachersError: boolean
  classes: SchoolClass[]
  subjects: Subject[]
  eligibleAssignments: EligibleAssignment[]
  selectedTeacherId: string
  action: (formData: FormData) => void | Promise<void>
  initialAssignment?: { id: string; schoolYearId: string; teacherId: string; classId: string; subjectId: string; weeklyHours: number | null; isPrimary: boolean }
}) {
  const currentEligibleYears = new Set(eligibleAssignments.map((assignment) => assignment.school_year_id))
  const availableYears = years.filter((year) => currentEligibleYears.has(year.id))
  const initialYearId = availableYears.find((year) => year.is_current)?.id ?? availableYears[0]?.id ?? ''
  const [yearId, setYearId] = useState(initialAssignment?.schoolYearId ?? initialYearId)
  const availableClasses = useMemo(() => classes.filter((item) =>
    item.school_year_id === yearId && eligibleAssignments.some((assignment) => assignment.school_year_id === yearId && assignment.class_id === item.id),
  ), [classes, eligibleAssignments, yearId])
  const [classId, setClassId] = useState(initialAssignment?.classId ?? availableClasses[0]?.id ?? '')
  const availableSubjects = subjects.filter((subject) => eligibleAssignments.some((assignment) =>
    assignment.school_year_id === yearId && assignment.class_id === classId && assignment.subject_id === subject.id,
  ))
  const [subjectId, setSubjectId] = useState(initialAssignment?.subjectId ?? availableSubjects[0]?.id ?? '')

  function changeYear(nextYearId: string) {
    setYearId(nextYearId)
    const nextClass = classes.find((item) => item.school_year_id === nextYearId && eligibleAssignments.some((assignment) => assignment.school_year_id === nextYearId && assignment.class_id === item.id))
    setClassId(nextClass?.id ?? '')
    const nextSubjectId = subjects.find((subject) => eligibleAssignments.some((assignment) => assignment.school_year_id === nextYearId && assignment.class_id === (nextClass?.id ?? '') && assignment.subject_id === subject.id))?.id ?? ''
    setSubjectId(nextSubjectId)
  }

  function changeClass(nextClassId: string) {
    setClassId(nextClassId)
    setSubjectId(subjects.find((subject) => eligibleAssignments.some((assignment) => assignment.school_year_id === yearId && assignment.class_id === nextClassId && assignment.subject_id === subject.id))?.id ?? '')
  }

  if (!availableYears.length) return (
    <div>
      <p className="field-hint">Aucune matière n’est encore rattachée à une classe active. Rattachez d’abord les matières aux classes pour pouvoir créer une affectation enseignant.</p>
      <Link className="button button-secondary" href="/pedagogie/matieres">Configurer les matières</Link>
    </div>
  )

  return (
    <form action={action} className="grid grid-2">
      {initialAssignment ? <input type="hidden" name="assignmentId" value={initialAssignment.id} /> : null}
      <div className="field">
        <label className="label" htmlFor="schoolYearId">Année scolaire *</label>
        <select className="select" id="schoolYearId" name="schoolYearId" value={yearId} onChange={(event) => changeYear(event.target.value)} required>
          {availableYears.map((year) => <option key={year.id} value={year.id}>{year.name}{year.is_current ? ' — actuelle' : ''}</option>)}
        </select>
      </div>
      <div className="field">
        <label className="label" htmlFor="teacherId">Enseignant *</label>
        <select className="select" id="teacherId" name="teacherId" defaultValue={selectedTeacherId} required>
          <option value="" disabled>Choisir...</option>
          {teachers.map((teacher) => <option key={teacher.id} value={teacher.id}>{teacher.last_name} {teacher.first_name} — {teacher.employee_number}</option>)}
        </select>
        {teachersError ? <p className="error">Impossible de charger les enseignants. Vérifiez les droits d’accès et réessayez.</p> : null}
        {!teachersError && !teachers.length ? <p className="field-hint">Aucun employé actif avec un profil enseignant n’est disponible.</p> : null}
      </div>
      <div className="field">
        <label className="label" htmlFor="classId">Classe *</label>
        <select className="select" id="classId" name="classId" value={classId} onChange={(event) => changeClass(event.target.value)} required>
          {availableClasses.map((item) => <option key={item.id} value={item.id}>{item.name} — {item.code}</option>)}
        </select>
      </div>
      <div className="field">
        <label className="label" htmlFor="subjectId">Matière *</label>
        <select className="select" id="subjectId" name="subjectId" value={availableSubjects.some((subject) => subject.id === subjectId) ? subjectId : availableSubjects[0]?.id ?? ''} onChange={(event) => setSubjectId(event.target.value)} required>
          {!availableSubjects.length ? <option value="" disabled>Aucune matière rattachée à cette classe</option> : null}
          {availableSubjects.map((subject) => <option key={subject.id} value={subject.id}>{subject.name} — {subject.code}</option>)}
        </select>
        {!availableSubjects.length ? <p className="field-hint">Rattachez une matière active à cette classe pour l’année sélectionnée.</p> : null}
      </div>
      <div className="field">
        <label className="label" htmlFor="weeklyHours">Volume hebdomadaire</label>
        <input className="input" id="weeklyHours" name="weeklyHours" type="number" min="0.25" step="0.25" defaultValue={initialAssignment?.weeklyHours ?? ''} />
      </div>
      <div className="field">
        <label className="label" htmlFor="isPrimary">Enseignant principal ?</label>
        <select className="select" id="isPrimary" name="isPrimary" defaultValue={initialAssignment?.isPrimary ? 'true' : 'false'}><option value="false">Non</option><option value="true">Oui</option></select>
      </div>
      <div><button className="button button-primary" type="submit" disabled={!teachers.length || !availableClasses.length || !availableSubjects.length}>{initialAssignment ? 'Enregistrer les modifications' : 'Enregistrer l’affectation'}</button></div>
    </form>
  )
}
