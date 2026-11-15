import { FunctionsHttpError } from '@supabase/supabase-js'

export type FinanceStudent = {
  id: string
  student_number: string
  first_name: string
  last_name: string
  status: string
}

export type FinanceDirectory = {
  students: FinanceStudent[]
  classes: Array<{ id: string; name: string; code: string | null }>
  enrollments: Array<{ student_id: string; class_id: string | null; education_stage: string | null }>
  parents: Array<{ id: string; first_name: string; last_name: string; phone: string | null }>
}

export async function loadFinanceDirectory(supabase: any) {
  const { data, error } = await supabase.functions.invoke('managed-user-directory', {
    body: { action: 'finance-directory' },
  })

  if (!error) return { data: (data ?? null) as FinanceDirectory | null, error: null as string | null }

  let message = 'Impossible de charger les élèves, classes et parents pour Finance.'
  if (error instanceof FunctionsHttpError) {
    try {
      const response = await error.context.json()
      if (typeof response?.error === 'string') message = response.error
    } catch {
      // Garder le message explicite si la fonction ne renvoie pas de JSON.
    }
  }

  return { data: null, error: message }
}
