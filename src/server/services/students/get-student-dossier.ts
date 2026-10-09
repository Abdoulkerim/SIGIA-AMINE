import { createClient } from '@/lib/supabase/server'
import type { StudentDossier } from '@/types/student-dossier'

export async function getStudentDossier(studentId: string): Promise<StudentDossier | null> {
  const supabase = await createClient()

  const { data, error } = await supabase.rpc('get_student_dossier', {
    p_student_id: studentId,
  })

  if (error) {
    throw new Error(error.message)
  }

  return (data as StudentDossier | null) ?? null
}
