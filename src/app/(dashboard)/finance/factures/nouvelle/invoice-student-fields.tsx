'use client'

import { useMemo, useState } from 'react'

type Student = {
  id: string
  student_number: string
  first_name: string
  last_name: string
}

type SchoolClass = {
  id: string
  name: string
  code: string | null
}

type Enrollment = {
  student_id: string
  class_id: string
}

export function InvoiceStudentFields({
  students,
  classes,
  enrollments,
}: {
  students: Student[]
  classes: SchoolClass[]
  enrollments: Enrollment[]
}) {
  const [classId, setClassId] = useState('')
  const [studentId, setStudentId] = useState('')

  const studentsInClass = useMemo(() => {
    if (!classId) return students

    const enrolledIds = new Set(
      enrollments
        .filter((row) => row.class_id === classId)
        .map((row) => row.student_id),
    )

    return students.filter((student) => enrolledIds.has(student.id))
  }, [classId, enrollments, students])

  return (
    <>
      <div className="field">
        <label className="label" htmlFor="invoiceClassId">
          Classe (filtre)
        </label>

        <select
          className="select"
          id="invoiceClassId"
          value={classId}
          onChange={(event) => {
            setClassId(event.target.value)
            setStudentId('')
          }}
        >
          <option value="">Toutes les classes</option>
          {classes.map((item) => (
            <option key={item.id} value={item.id}>
              {item.name}{item.code ? ` (${item.code})` : ''}
            </option>
          ))}
        </select>
      </div>

      <div className="field">
        <label className="label" htmlFor="studentId">
          {'\u00C9l\u00E8ve'}
        </label>

        <select
          className="select"
          id="studentId"
          name="studentId"
          value={studentId}
          onChange={(event) => setStudentId(event.target.value)}
          required
        >
          <option value="" disabled>
            {'S\u00E9lectionner un \u00E9l\u00E8ve'}
          </option>

          {studentsInClass.map((student) => (
            <option key={student.id} value={student.id}>
              {student.student_number} {'\u2022'} {student.first_name} {student.last_name}
            </option>
          ))}
        </select>

        {classId && !studentsInClass.length ? (
          <p className="page-subtitle">
            {'Aucun \u00E9l\u00E8ve inscrit dans cette classe pour l\u2019ann\u00E9e scolaire en cours.'}
          </p>
        ) : null}
      </div>
    </>
  )
}