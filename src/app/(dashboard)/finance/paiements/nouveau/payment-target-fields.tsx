'use client'

import { useMemo, useState } from 'react'

type Student = { id: string; student_number: string; first_name: string; last_name: string }
type SchoolClass = { id: string; name: string; code: string | null }
type Enrollment = { student_id: string; class_id: string }
type Invoice = { id: string; invoice_number: string; student_id: string; total: number | string; status: string; due_date: string | null }

export function PaymentTargetFields({ students, classes, enrollments, invoices }: {
  students: Student[]
  classes: SchoolClass[]
  enrollments: Enrollment[]
  invoices: Invoice[]
}) {
  const [classId, setClassId] = useState('')
  const [studentId, setStudentId] = useState('')
  const [targetId, setTargetId] = useState('')

  const studentsInClass = useMemo(() => {
    if (!classId) return students
    const enrolledIds = new Set(enrollments.filter((row) => row.class_id === classId).map((row) => row.student_id))
    return students.filter((student) => enrolledIds.has(student.id))
  }, [classId, enrollments, students])

  const studentInvoices = useMemo(() => invoices.filter((invoice) => invoice.student_id === studentId), [invoices, studentId])

  function selectStudent(id: string) {
    setStudentId(id)
    setTargetId(invoices.find((invoice) => invoice.student_id === id)?.id ?? '')
  }

  return <>
    <div className="field">
      <label className="label" htmlFor="paymentClassId">Classe (filtre)</label>
      <select className="select" id="paymentClassId" value={classId} onChange={(event) => { setClassId(event.target.value); selectStudent('') }}>
        <option value="">Toutes les classes</option>
        {classes.map((item) => <option key={item.id} value={item.id}>{item.name}{item.code ? ` (${item.code})` : ''}</option>)}
      </select>
    </div>
    <div className="field">
      <label className="label" htmlFor="studentId">Élève</label>
      <select className="select" id="studentId" name="studentId" value={studentId} onChange={(event) => selectStudent(event.target.value)} required>
        <option value="">Sélectionner</option>
        {studentsInClass.map((student) => <option key={student.id} value={student.id}>{student.student_number} • {student.first_name} {student.last_name}</option>)}
      </select>
      {classId && !studentsInClass.length ? <p className="page-subtitle">Aucun élève inscrit dans cette classe pour l’année scolaire en cours.</p> : null}
    </div>
    <div className="field">
      <label className="label" htmlFor="targetId">Facture cible</label>
      <select className="select" id="targetId" name="targetId" value={targetId} onChange={(event) => setTargetId(event.target.value)} required disabled={!studentId || !studentInvoices.length}>
        <option value="">{!studentId ? 'Sélectionnez d’abord un élève' : 'Aucune facture à payer'}</option>
        {studentInvoices.map((invoice) => <option key={invoice.id} value={invoice.id}>{invoice.invoice_number} • {Number(invoice.total).toLocaleString('fr-FR')} FCFA • {invoice.status}{invoice.due_date ? ` • échéance ${invoice.due_date}` : ''}</option>)}
      </select>
      {studentId && studentInvoices.length > 1 ? <small className="field-hint">{studentInvoices.length} factures impayées pour cet élève. La plus ancienne échéance est présélectionnée ; vous pouvez en choisir une autre.</small> : null}
      <input type="hidden" name="targetType" value="invoice" />
    </div>
  </>
}
