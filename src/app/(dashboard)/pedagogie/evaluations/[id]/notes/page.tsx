
import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'
import { getCurrentUserContext } from '@/lib/auth/current-user'
import { saveAssessmentGradesFromForm } from '../../../pedagogie-actions'
import { ReportActions } from '@/components/reports/report-actions'

type AssessmentGrade = {
  score?: number | string | null
  observation?: string | null
}

type AssessmentGradeSheetStudent = {
  student_id: string
  grade?: AssessmentGrade | null
  students?: {
    student_number?: string | null
    first_name?: string | null
    last_name?: string | null
  } | null
}

export default async function AssessmentGradesPage({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>
  searchParams: Promise<{
    error?: string
    created?: string
    saved?: string
  }>
}) {
  const { id } = await params
  const query = await searchParams
  const context = await getCurrentUserContext()

  if (!context?.profile.school_id) return null

  const supabase = await createClient()

  const {
    data: sheetData,
    error: sheetError,
  } = await supabase.rpc('get_assessment_grade_sheet', {
    p_assessment_id: id,
  })

  const sheet = sheetData as any
  const assessment = sheet?.assessment

  const students: AssessmentGradeSheetStudent[] =
    Array.isArray(sheet?.students)
      ? (sheet.students as AssessmentGradeSheetStudent[])
      : []

  if (sheetError || !assessment) {
    return (
      <main className="page">
        <p className="error">
          Évaluation introuvable ou accès non autorisé.
        </p>
      </main>
    )
  }

  const gradeMap = new Map<string, AssessmentGrade>()

  for (const row of students) {
    if (row.grade) {
      gradeMap.set(row.student_id, row.grade)
    }
  }

  return (
    <main className="page">
      <div className="page-header">
        <div>
          <h1 className="page-title">Saisie des notes</h1>
          <p className="page-subtitle">
            {assessment.title} · {assessment.subjects?.name ?? 'Matière'} ·{' '}
            {assessment.classes?.name ?? 'Classe'} · barème{' '}
            {assessment.max_score}
          </p>
        </div>
        <Link
          className="button button-secondary"
          href="/pedagogie/evaluations"
        >
          Retour
        </Link>
      </div>

      {query.created ? (
        <p className="success">
          Évaluation créée. Saisissez maintenant les notes.
        </p>
      ) : null}

      {query.saved ? (
        <p className="success">Notes enregistrées.</p>
      ) : null}

      {query.error ? <p className="error">{query.error}</p> : null}

      {assessment.is_published ? (
        <p className="error">
          Cette évaluation est publiée : les notes sont verrouillées.
        </p>
      ) : null}

      {assessment.academic_periods?.is_closed ? (
        <p className="error">
          La période est clôturée : aucune modification n'est autorisée.
        </p>
      ) : null}

      <ReportActions
        title={`Notes — ${assessment.title} — ${assessment.classes?.name ?? 'Classe'}`}
        fileName="liste-notes"
        headers={[
          'Matricule',
          'Élève',
          'Classe',
          'Matière',
          'Évaluation',
          `Note / ${assessment.max_score}`,
          'Observation',
        ]}
        rows={students.map((row) => {
          const student = row.students
          const grade = gradeMap.get(row.student_id)

          return [
            student?.student_number,
            `${student?.last_name ?? ''} ${student?.first_name ?? ''}`.trim(),
            assessment.classes?.name,
            assessment.subjects?.name,
            assessment.title,
            grade?.score,
            grade?.observation,
          ]
        })}
      />

      <section className="card">
        <form action={saveAssessmentGradesFromForm}>
          <input type="hidden" name="assessmentId" value={id} />

          <div className="table-wrap assessment-grade-list">
            <table>
              <thead>
                <tr>
                  <th>N°</th>
                  <th>Élève</th>
                  <th>Note / {assessment.max_score}</th>
                  <th>Observation</th>
                </tr>
              </thead>

              <tbody>
                {students.map((row) => {
                  const student = row.students
                  const grade = gradeMap.get(row.student_id)

                  return (
                    <tr key={row.student_id}>
                      <td data-label="Matricule">
                        {student?.student_number ?? '—'}
                      </td>

                      <td
                        data-label="Élève"
                        className="assessment-grade-student"
                      >
                        {student?.last_name} {student?.first_name}
                      </td>

                      <td data-label={`Note / ${assessment.max_score}`}>
                        <input
                          aria-label={`Note de ${student?.last_name ?? ''} ${student?.first_name ?? ''}`}
                          className="input"
                          type="number"
                          step="0.01"
                          min="0"
                          max={assessment.max_score}
                          name={`score_${row.student_id}`}
                          defaultValue={grade?.score ?? ''}
                          disabled={
                            assessment.is_published ||
                            assessment.academic_periods?.is_closed
                          }
                        />
                      </td>

                      <td data-label="Observation">
                        <input
                          aria-label={`Observation pour ${student?.last_name ?? ''} ${student?.first_name ?? ''}`}
                          className="input"
                          name={`observation_${row.student_id}`}
                          defaultValue={grade?.observation ?? ''}
                          disabled={
                            assessment.is_published ||
                            assessment.academic_periods?.is_closed
                          }
                        />
                      </td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>

          {!students.length ? (
            <p className="empty">
              Aucun élève inscrit dans cette classe pour cette année.
            </p>
          ) : (
            <div
              style={{
                marginTop: 16,
                display: 'flex',
                gap: 10,
                flexWrap: 'wrap',
              }}
            >
              <button
                className="button button-primary"
                type="submit"
                disabled={
                  assessment.is_published ||
                  assessment.academic_periods?.is_closed
                }
              >
                Enregistrer les notes
              </button>

              <Link
                className="button button-secondary"
                href="/pedagogie/evaluations"
              >
                Retour aux évaluations
              </Link>
            </div>
          )}
        </form>
      </section>
    </main>
  )
}
