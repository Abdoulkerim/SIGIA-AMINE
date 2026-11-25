'use client'

import { useMemo, useState } from 'react'

export type FilterableStudent = {
  id: string
  first_name: string
  last_name: string
  student_number?: string | null
  gender?: string | null
}
export type StudentClassOption = { id: string; name: string; code?: string | null; education_stage?: string | null }
export type StudentEnrollmentOption = { student_id: string; class_id: string | null; education_stage?: string | null }

export function StudentFilterSelect({ students, classes, enrollments, name = 'studentId', label = 'Élève', required = true, includeGender = false, id, initialStage = '', hideStageFilter = false }: {
  students: FilterableStudent[]
  classes: StudentClassOption[]
  enrollments: StudentEnrollmentOption[]
  name?: string
  label?: string
  required?: boolean
  includeGender?: boolean
  id?: string
  initialStage?: string
  hideStageFilter?: boolean
}) {
  const [stage, setStage] = useState(initialStage)
  const [classId, setClassId] = useState('')
  const [gender, setGender] = useState('')
  const selectId = id ?? name
  const stages = useMemo(() => [...new Set(enrollments.map((item) => item.education_stage).filter((item): item is string => Boolean(item)))].sort(), [enrollments])
  const visibleClasses = useMemo(() => classes.filter((item) => !stage || enrollments.some((enrollment) => enrollment.class_id === item.id && enrollment.education_stage === stage)), [classes, enrollments, stage])
  const visibleStudents = useMemo(() => students.filter((student) => {
    const enrollment = enrollments.filter((item) => item.student_id === student.id)
    return (!stage || enrollment.some((item) => item.education_stage === stage)) && (!classId || enrollment.some((item) => item.class_id === classId)) && (!gender || (gender === 'other' ? !student.gender || student.gender === 'other' : student.gender === gender))
  }), [students, enrollments, stage, classId, gender])
  return <>
    {!hideStageFilter && stages.length > 1 ? <div className="field"><label className="label" htmlFor={`${selectId}-stage`}>Cycle</label><select className="select" id={`${selectId}-stage`} value={stage} onChange={(event) => { setStage(event.target.value); setClassId('') }}><option value="">Tous les cycles</option>{stages.map((value) => <option key={value} value={value}>{value.replaceAll('_', ' ')}</option>)}</select></div> : null}
    {classes.length ? <div className="field"><label className="label" htmlFor={`${selectId}-class`}>Classe</label><select className="select" id={`${selectId}-class`} value={classId} onChange={(event) => setClassId(event.target.value)}><option value="">Toutes les classes</option>{visibleClasses.map((item) => <option key={item.id} value={item.id}>{item.name}{item.code ? ` (${item.code})` : ''}</option>)}</select></div> : null}
    {includeGender ? <div className="field"><label className="label" htmlFor={`${selectId}-gender`}>Sexe</label><select className="select" id={`${selectId}-gender`} value={gender} onChange={(event) => setGender(event.target.value)}><option value="">Tous</option><option value="male">Garçon</option><option value="female">Fille</option><option value="other">Autre / non précisé</option></select></div> : null}
    <div className="field"><label className="label" htmlFor={selectId}>{label}{required ? ' *' : ''}</label><select className="select" id={selectId} name={name} required={required}><option value="">Choisir…</option>{visibleStudents.map((student) => <option key={student.id} value={student.id}>{student.student_number ? `${student.student_number} · ` : ''}{student.last_name} {student.first_name}</option>)}</select>{!visibleStudents.length ? <small>Aucun élève ne correspond aux filtres.</small> : null}</div>
  </>
}
