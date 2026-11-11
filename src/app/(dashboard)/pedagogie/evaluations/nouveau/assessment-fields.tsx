'use client'

import { useMemo, useState } from 'react'

type SchoolYear = { id: string; name: string; is_current: boolean }
type AcademicPeriod = { id: string; name: string; school_year_id: string; is_closed: boolean }
type SchoolClass = { id: string; name: string; code: string; school_year_id: string }
type Subject = { id: string; name: string; code: string }
type Teacher = { id: string; first_name: string; last_name: string; employee_number: string }
type Assignment = { school_year_id: string; class_id: string; subject_id: string; teacher_id: string }

export function AssessmentFields({
  years,
  periods,
  classes,
  subjects,
  teachers,
  assignments,
  initialYearId,
  teacherProfile,
}: {
  years: SchoolYear[]
  periods: AcademicPeriod[]
  classes: SchoolClass[]
  subjects: Subject[]
  teachers: Teacher[]
  assignments: Assignment[]
  initialYearId: string
  teacherProfile: Teacher | null
}) {
  const [schoolYearId, setSchoolYearId] = useState(initialYearId)
  const [classId, setClassId] = useState('')
  const [subjectId, setSubjectId] = useState('')
  const [teacherId, setTeacherId] = useState(teacherProfile?.id ?? '')

  const yearAssignments = useMemo(
    () => assignments.filter(assignment => assignment.school_year_id === schoolYearId),
    [assignments, schoolYearId],
  )
  const availableClasses = useMemo(() => {
    const allowedIds = new Set(yearAssignments.map(assignment => assignment.class_id))
    return classes.filter(item => item.school_year_id === schoolYearId && (!teacherProfile || allowedIds.has(item.id)))
  }, [classes, teacherProfile, yearAssignments, schoolYearId])
  const availableSubjects = useMemo(() => {
    if (!teacherProfile) return subjects
    const allowedIds = new Set(yearAssignments
      .filter(assignment => assignment.class_id === classId)
      .map(assignment => assignment.subject_id))
    return subjects.filter(item => allowedIds.has(item.id))
  }, [classId, subjects, teacherProfile, yearAssignments])
  const openPeriods = periods.filter(period => period.school_year_id === schoolYearId && !period.is_closed)
  const availableTeachers = teacherProfile ? [teacherProfile] : teachers

  return <>
    <label className="field">
      <span className="label">Année scolaire</span>
      <select
        className="select"
        name="schoolYearId"
        value={schoolYearId}
        onChange={event => {
          setSchoolYearId(event.target.value)
          setClassId('')
          setSubjectId('')
          if (!teacherProfile) setTeacherId('')
        }}
        required
      >
        {years.map(year => <option key={year.id} value={year.id}>{year.name}</option>)}
      </select>
    </label>
    <label className="field">
      <span className="label">Période</span>
      <select className="select" name="periodId" key={schoolYearId} defaultValue="" required>
        <option value="">Sélectionner</option>
        {openPeriods.map(period => <option key={period.id} value={period.id}>{period.name}</option>)}
      </select>
    </label>
    <label className="field">
      <span className="label">Classe</span>
      <select
        className="select"
        name="classId"
        value={classId}
        onChange={event => {
          setClassId(event.target.value)
          setSubjectId('')
        }}
        required
      >
        <option value="">Sélectionner</option>
        {availableClasses.map(item => <option key={item.id} value={item.id}>{item.name} ({item.code})</option>)}
      </select>
      {teacherProfile && !availableClasses.length ? <span className="field-hint">Aucune classe ne vous est affectée pour cette année.</span> : null}
    </label>
    <label className="field">
      <span className="label">Matière</span>
      <select
        className="select"
        name="subjectId"
        value={subjectId}
        onChange={event => setSubjectId(event.target.value)}
        required
        disabled={Boolean(teacherProfile && !classId)}
      >
        <option value="">Sélectionner</option>
        {availableSubjects.map(item => <option key={item.id} value={item.id}>{item.name} ({item.code})</option>)}
      </select>
      {teacherProfile && classId && !availableSubjects.length ? <span className="field-hint">Aucune matière ne vous est affectée pour cette classe.</span> : null}
    </label>
    <label className="field">
      <span className="label">Enseignant</span>
      <select className="select" name="teacherId" value={teacherId} onChange={event => setTeacherId(event.target.value)} required>
        <option value="">Sélectionner</option>
        {availableTeachers.map(item => <option key={item.id} value={item.id}>{item.last_name} {item.first_name} ({item.employee_number})</option>)}
      </select>
    </label>
  </>
}
