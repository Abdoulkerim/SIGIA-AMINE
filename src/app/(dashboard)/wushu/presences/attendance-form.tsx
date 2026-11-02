'use client'

import { useState } from 'react'
import { recordWushuAttendance } from '../wushu-actions'

type AttendanceSession = {
  id: string
  group_id: string
  session_date: string
  session_type: string
  group_name: string
}

type AttendanceStudent = {
  id: string
  group_id: string
  first_name: string
  last_name: string
  student_number: string | null
}

export function WushuAttendanceForm({ sessions, students }: {
  sessions: AttendanceSession[]
  students: AttendanceStudent[]
}) {
  const [sessionId, setSessionId] = useState('')
  const selectedSession = sessions.find((session) => session.id === sessionId)
  const eligibleStudents = selectedSession
    ? students.filter((student) => student.group_id === selectedSession.group_id)
    : []

  return (
    <form action={recordWushuAttendance} className="grid grid-3">
      <div className="field">
        <label className="label" htmlFor="wushu-attendance-session">Séance *</label>
        <select
          className="select"
          id="wushu-attendance-session"
          name="sessionId"
          required
          value={sessionId}
          onChange={(event) => setSessionId(event.target.value)}
        >
          <option value="">Choisir…</option>
          {sessions.map((session) => (
            <option key={session.id} value={session.id}>
              {session.session_date} · {session.group_name} · {session.session_type}
            </option>
          ))}
        </select>
      </div>
      <div className="field">
        <label className="label" htmlFor="wushu-attendance-student">Élève *</label>
        <select className="select" id="wushu-attendance-student" name="studentId" required disabled={!selectedSession}>
          <option value="">{selectedSession ? 'Choisir…' : 'Choisir d’abord une séance'}</option>
          {eligibleStudents.map((student) => (
            <option key={student.id} value={student.id}>
              {student.last_name} {student.first_name}{student.student_number ? ` · ${student.student_number}` : ''}
            </option>
          ))}
        </select>
        {selectedSession && eligibleStudents.length === 0 ? <small>Aucun élève actif affecté à ce groupe Wushu.</small> : null}
      </div>
      <div className="field">
        <label className="label" htmlFor="wushu-attendance-status">Statut *</label>
        <select className="select" id="wushu-attendance-status" name="status" defaultValue="present">
          <option value="present">Présent</option>
          <option value="absent">Absent</option>
          <option value="late">Retard</option>
          <option value="excused">Excusé</option>
        </select>
      </div>
      <div><button className="button button-primary" type="submit" disabled={!sessions.length || !eligibleStudents.length}>Enregistrer</button></div>
    </form>
  )
}
