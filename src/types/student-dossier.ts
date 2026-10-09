export type StudentDossier = {
  student: {
    id: string
    school_id: string
    student_number: string
    first_name: string
    last_name: string
    gender: string | null
    date_of_birth: string | null
    place_of_birth: string | null
    nationality: string | null
    address: string | null
    phone: string | null
    email: string | null
    photo_url: string | null
    residence_type: string
    status: string
    emergency_contact: Record<string, unknown>
    medical_notes: string | null
    created_at: string
    updated_at: string
  }
  current_enrollment: {
    id?: string
    registration_number?: string
    school_year_id?: string
    school_year_name?: string
    class_id?: string
    class_name?: string
    class_code?: string
    level_id?: string
    level_name?: string
    level_code?: string
    residence_type?: string
    enrollment_date?: string
    status?: string
    is_reenrollment?: boolean
    registration_fee?: number
    notes?: string | null
  }
  parents: Array<{
    id: string
    first_name: string
    last_name: string
    gender: string | null
    profession: string | null
    phone: string | null
    email: string | null
    address: string | null
    relationship: string
    is_primary: boolean
    has_financial_responsibility: boolean
    receives_notifications: boolean
  }>
  enrollments: Array<{
    id: string
    registration_number: string
    school_year_id: string
    school_year_name: string
    class_id: string | null
    class_name: string | null
    class_code: string | null
    level_id: string | null
    level_name: string | null
    residence_type: string
    enrollment_date: string
    status: string
    is_reenrollment: boolean
    registration_fee: number
  }>
  enrollment_history: Array<{
    id: string
    old_class_name: string | null
    new_class_name: string | null
    old_residence_type: string | null
    new_residence_type: string | null
    reason: string | null
    changed_at: string
  }>
  admissions: Array<{
    id: string
    application_number: string
    applicant_name: string
    status: string
    desired_level_label: string | null
    desired_level_name: string | null
    desired_year_name: string | null
    desired_residence_type: string | null
    submitted_at: string | null
    reviewed_at: string | null
    notes: string | null
  }>
  teachers: Array<{
    teacher_id: string
    teacher_employee_number: string
    teacher_first_name: string
    teacher_last_name: string
    teacher_speciality: string | null
    subject_id: string
    subject_code: string
    subject_name: string
    class_id: string
    class_code: string
    class_name: string
    school_year_id: string
    school_year_name: string
    weekly_hours: number | null
    is_primary: boolean
  }>
  authorized_pickup_persons: Array<{
    id: string
    full_name: string
    relationship: string | null
    phone: string | null
    identity_document: string | null
    is_active: boolean
  }>
  documents: Array<{
    id: string
    document_type_id: string | null
    reference: string | null
    title: string
    status: string
    file_path: string | null
    issue_date: string | null
    created_at: string
  }>
  modules: Record<string, string>
}
