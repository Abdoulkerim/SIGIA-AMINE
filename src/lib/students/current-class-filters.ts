export async function getCurrentClassFilters(supabase: any, schoolId: string) {
  const { data: years } = await supabase.from('school_years').select('id,is_current,start_date').eq('school_id', schoolId).order('start_date', { ascending: false })
  const yearId = years?.find((year: any) => year.is_current)?.id ?? years?.[0]?.id
  if (!yearId) return { classes: [], enrollments: [] }
  const [{ data: classes }, { data: enrollments }] = await Promise.all([
    supabase.from('classes').select('id,name,code').eq('school_id', schoolId).eq('school_year_id', yearId).order('name'),
    supabase.from('enrollments').select('student_id,class_id,education_stage').eq('school_id', schoolId).eq('school_year_id', yearId).eq('status', 'enrolled'),
  ])
  return { classes: classes ?? [], enrollments: enrollments ?? [] }
}
