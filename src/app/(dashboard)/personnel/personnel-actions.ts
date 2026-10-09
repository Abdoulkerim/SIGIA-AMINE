'use server'

import { revalidatePath } from 'next/cache'
import { redirect } from 'next/navigation'
import { z } from 'zod'
import { createClient } from '@/lib/supabase/server'

const uuid = z.string().uuid()
const date = z.string().min(1)
const nonNegative = z.coerce.number().min(0)
const optionalText = z.string().trim().max(2000).optional()

function fail(path: string, message: string): never {
  redirect(`${path}?error=${encodeURIComponent(message)}`)
}

async function client() {
  return createClient()
}

export async function createEmployee(formData: FormData) {
  const employeeNumber = z.string().trim().min(1).max(50).safeParse(formData.get('employeeNumber'))
  const firstName = z.string().trim().min(1).max(120).safeParse(formData.get('firstName'))
  const lastName = z.string().trim().min(1).max(120).safeParse(formData.get('lastName'))
  const jobTitle = z.string().trim().max(160).optional().safeParse(formData.get('jobTitle') || undefined)
  const department = z.string().trim().max(160).optional().safeParse(formData.get('department') || undefined)
  const qualification = z.string().trim().max(255).optional().safeParse(formData.get('qualification') || undefined)
  const hireDate = z.string().optional().safeParse(formData.get('hireDate') || undefined)
  const gender = z.enum(['male', 'female', 'other']).optional().safeParse(formData.get('gender') || undefined)
  const dob = z.string().optional().safeParse(formData.get('dateOfBirth') || undefined)
  const place = z.string().trim().max(120).optional().safeParse(formData.get('placeOfBirth') || undefined)
  const phone = z.string().trim().max(50).optional().safeParse(formData.get('phone') || undefined)
  const email = z.string().trim().email().max(255).optional().safeParse(formData.get('email') || undefined)
  const address = z.string().trim().max(500).optional().safeParse(formData.get('address') || undefined)
  if (![employeeNumber, firstName, lastName, jobTitle, department, qualification, hireDate, gender, dob, place, phone, email, address].every((x) => x.success)) fail('/personnel/employes/nouveau', 'Données employé invalides.')
  const supabase = await client()
  const { data, error } = await supabase.rpc('create_employee', {
    p_employee_number: employeeNumber.data,
    p_first_name: firstName.data,
    p_last_name: lastName.data,
    p_job_title: jobTitle.data ?? null,
    p_department: department.data ?? null,
    p_qualification: qualification.data ?? null,
    p_hire_date: hireDate.data || null,
    p_gender: gender.data ?? null,
    p_date_of_birth: dob.data || null,
    p_place_of_birth: place.data ?? null,
    p_phone: phone.data ?? null,
    p_email: email.data ?? null,
    p_address: address.data ?? null,
  })
  if (error) fail('/personnel/employes/nouveau', error.message)
  revalidatePath('/personnel')
  revalidatePath('/personnel/employes')
  redirect(`/personnel/employes/${data}?created=1`)
}

export async function setEmployeeStatus(formData: FormData) {
  const employeeId = uuid.safeParse(formData.get('employeeId'))
  const status = z.enum(['active', 'inactive', 'suspended', 'terminated', 'archived']).safeParse(formData.get('status'))
  if (!employeeId.success || !status.success) fail('/personnel/employes', 'Paramètres invalides.')
  const supabase = await client()
  const { error } = await supabase.rpc('set_employee_status', { p_employee_id: employeeId.data, p_status: status.data })
  if (error) fail('/personnel/employes', error.message)
  revalidatePath('/personnel')
  revalidatePath('/personnel/employes')
  revalidatePath(`/personnel/employes/${employeeId.data}`)
  redirect('/personnel/employes?updated=1')
}

export async function createContract(formData: FormData) {
  const employeeId = uuid.safeParse(formData.get('employeeId'))
  const type = z.string().trim().min(1).max(100).safeParse(formData.get('contractType'))
  const start = date.safeParse(formData.get('startDate'))
  const end = z.string().optional().safeParse(formData.get('endDate') || undefined)
  const salary = nonNegative.optional().safeParse(formData.get('salary') || undefined)
  const status = z.enum(['draft', 'active', 'suspended', 'terminated', 'expired', 'archived']).safeParse(formData.get('status') || 'active')
  if (![employeeId, type, start, end, salary, status].every((x) => x.success)) fail('/personnel/contrats', 'Contrat invalide.')
  const supabase = await client()
  const { error } = await supabase.rpc('create_employee_contract', {
    p_employee_id: employeeId.data,
    p_contract_type: type.data,
    p_start_date: start.data,
    p_end_date: end.data || null,
    p_salary: salary.data ?? null,
    p_document_id: null,
    p_status: status.data,
  })
  if (error) fail('/personnel/contrats', error.message)
  revalidatePath('/personnel/contrats')
  revalidatePath(`/personnel/employes/${employeeId.data}`)
  redirect('/personnel/contrats?created=1')
}

export async function recordEmployeeAttendance(formData: FormData) {
  const employeeId = uuid.safeParse(formData.get('employeeId'))
  const attendanceDate = date.safeParse(formData.get('attendanceDate'))
  const status = z.enum(['present', 'absent', 'late', 'excused']).safeParse(formData.get('status'))
  const checkIn = z.string().optional().safeParse(formData.get('checkIn') || undefined)
  const checkOut = z.string().optional().safeParse(formData.get('checkOut') || undefined)
  const notes = optionalText.safeParse(formData.get('notes') || undefined)
  if (![employeeId, attendanceDate, status, checkIn, checkOut, notes].every((x) => x.success)) fail('/personnel/presences', 'Présence invalide.')
  const supabase = await client()
  const { error } = await supabase.rpc('record_employee_attendance', {
    p_employee_id: employeeId.data,
    p_attendance_date: attendanceDate.data,
    p_status: status.data,
    p_check_in: checkIn.data || null,
    p_check_out: checkOut.data || null,
    p_notes: notes.data ?? null,
  })
  if (error) fail('/personnel/presences', error.message)
  revalidatePath('/personnel/presences')
  revalidatePath(`/personnel/employes/${employeeId.data}`)
  redirect('/personnel/presences?recorded=1')
}

export async function requestEmployeeLeave(formData: FormData) {
  const employeeId = uuid.safeParse(formData.get('employeeId'))
  const leaveType = z.string().trim().min(1).max(100).safeParse(formData.get('leaveType'))
  const startDate = date.safeParse(formData.get('startDate'))
  const endDate = date.safeParse(formData.get('endDate'))
  const reason = optionalText.safeParse(formData.get('reason') || undefined)
  if (![employeeId, leaveType, startDate, endDate, reason].every((x) => x.success)) fail('/personnel/conges', 'Demande de congé invalide.')
  const supabase = await client()
  const { error } = await supabase.rpc('request_employee_leave', {
    p_employee_id: employeeId.data,
    p_leave_type: leaveType.data,
    p_start_date: startDate.data,
    p_end_date: endDate.data,
    p_reason: reason.data ?? null,
  })
  if (error) fail('/personnel/conges', error.message)
  revalidatePath('/personnel/conges')
  revalidatePath(`/personnel/employes/${employeeId.data}`)
  redirect('/personnel/conges?submitted=1')
}

export async function decideEmployeeLeave(formData: FormData) {
  const leaveId = uuid.safeParse(formData.get('leaveId'))
  const decision = z.enum(['approved', 'rejected', 'cancelled']).safeParse(formData.get('decision'))
  const reason = optionalText.safeParse(formData.get('reason') || undefined)
  if (![leaveId, decision, reason].every((x) => x.success)) fail('/personnel/conges', 'Décision de congé invalide.')
  const supabase = await client()
  const { error } = await supabase.rpc('decide_employee_leave', {
    p_leave_id: leaveId.data,
    p_decision: decision.data,
    p_reason: reason.data ?? null,
  })
  if (error) fail('/personnel/conges', error.message)
  revalidatePath('/personnel/conges')
  redirect('/personnel/conges?decided=1')
}

export async function addSkill(formData: FormData) {
  const employeeId = uuid.safeParse(formData.get('employeeId'))
  const skillName = z.string().trim().min(1).max(160).safeParse(formData.get('skillName'))
  const level = z.string().trim().max(80).optional().safeParse(formData.get('level') || undefined)
  const acquiredAt = z.string().optional().safeParse(formData.get('acquiredAt') || undefined)
  const notes = optionalText.safeParse(formData.get('notes') || undefined)
  if (![employeeId, skillName, level, acquiredAt, notes].every((x) => x.success)) fail('/personnel/formations', 'Compétence invalide.')
  const supabase = await client()
  const { error } = await supabase.rpc('add_employee_skill', {
    p_employee_id: employeeId.data,
    p_skill_name: skillName.data,
    p_level: level.data ?? null,
    p_acquired_at: acquiredAt.data || null,
    p_notes: notes.data ?? null,
  })
  if (error) fail('/personnel/formations', error.message)
  revalidatePath('/personnel/formations')
  revalidatePath(`/personnel/employes/${employeeId.data}`)
  redirect('/personnel/formations?added=1')
}

export async function addTraining(formData: FormData) {
  const employeeId = uuid.safeParse(formData.get('employeeId'))
  const title = z.string().trim().min(1).max(200).safeParse(formData.get('title'))
  const provider = z.string().trim().max(200).optional().safeParse(formData.get('provider') || undefined)
  const startDate = z.string().optional().safeParse(formData.get('startDate') || undefined)
  const endDate = z.string().optional().safeParse(formData.get('endDate') || undefined)
  const certificateReference = z.string().trim().max(120).optional().safeParse(formData.get('certificateReference') || undefined)
  const status = z.string().trim().min(1).max(50).safeParse(formData.get('status') || 'completed')
  const notes = optionalText.safeParse(formData.get('notes') || undefined)
  if (![employeeId, title, provider, startDate, endDate, certificateReference, status, notes].every((x) => x.success)) fail('/personnel/formations', 'Formation invalide.')
  const supabase = await client()
  const { error } = await supabase.rpc('add_employee_training', {
    p_employee_id: employeeId.data,
    p_title: title.data,
    p_provider: provider.data ?? null,
    p_start_date: startDate.data || null,
    p_end_date: endDate.data || null,
    p_certificate_reference: certificateReference.data ?? null,
    p_status: status.data,
    p_notes: notes.data ?? null,
  })
  if (error) fail('/personnel/formations', error.message)
  revalidatePath('/personnel/formations')
  revalidatePath(`/personnel/employes/${employeeId.data}`)
  redirect('/personnel/formations?added=1')
}

export async function createPayrollPeriod(formData: FormData) {
  const label = z.string().trim().min(1).max(100).safeParse(formData.get('periodLabel'))
  const startDate = date.safeParse(formData.get('startDate'))
  const endDate = date.safeParse(formData.get('endDate'))
  if (![label, startDate, endDate].every((x) => x.success)) fail('/personnel/paie', 'Période de paie invalide.')
  const supabase = await client()
  const { error } = await supabase.rpc('create_payroll_period', {
    p_period_label: label.data,
    p_start_date: startDate.data,
    p_end_date: endDate.data,
  })
  if (error) fail('/personnel/paie', error.message)
  revalidatePath('/personnel/paie')
  revalidatePath('/personnel')
  redirect('/personnel/paie?created=1')
}

export async function openPayroll(formData: FormData) {
  const id = uuid.safeParse(formData.get('payrollPeriodId'))
  if (!id.success) fail('/personnel/paie', 'Période invalide.')
  const supabase = await client()
  const { error } = await supabase.rpc('open_payroll_period', { p_payroll_period_id: id.data })
  if (error) fail('/personnel/paie', error.message)
  revalidatePath('/personnel/paie')
  redirect('/personnel/paie?updated=1')
}

export async function generatePayroll(formData: FormData) {
  const id = uuid.safeParse(formData.get('payrollPeriodId'))
  if (!id.success) fail('/personnel/paie', 'Période invalide.')
  const supabase = await client()
  const { error } = await supabase.rpc('generate_payroll', { p_payroll_period_id: id.data })
  if (error) fail('/personnel/paie', error.message)
  revalidatePath('/personnel/paie')
  redirect('/personnel/paie?generated=1')
}

export async function updatePayrollItem(formData: FormData) {
  const id = uuid.safeParse(formData.get('payrollItemId'))
  const base = nonNegative.safeParse(formData.get('baseSalary'))
  const allowances = nonNegative.safeParse(formData.get('allowances'))
  const deductions = nonNegative.safeParse(formData.get('deductions'))
  const notes = optionalText.safeParse(formData.get('notes') || undefined)
  if (![id, base, allowances, deductions, notes].every((x) => x.success)) fail('/personnel/paie', 'Ligne de paie invalide.')
  const supabase = await client()
  const { error } = await supabase.rpc('update_payroll_item', {
    p_payroll_item_id: id.data,
    p_base_salary: base.data,
    p_allowances: allowances.data,
    p_deductions: deductions.data,
    p_notes: notes.data ?? null,
  })
  if (error) fail('/personnel/paie', error.message)
  revalidatePath('/personnel/paie')
  redirect('/personnel/paie?updated=1')
}

export async function approvePayroll(formData: FormData) {
  const id = uuid.safeParse(formData.get('payrollPeriodId'))
  if (!id.success) fail('/personnel/paie', 'Période invalide.')
  const supabase = await client()
  const { error } = await supabase.rpc('approve_payroll', { p_payroll_period_id: id.data })
  if (error) fail('/personnel/paie', error.message)
  revalidatePath('/personnel/paie')
  revalidatePath('/personnel')
  redirect('/personnel/paie?approved=1')
}

export async function markPayrollItemPaid(formData: FormData) {
  const id = uuid.safeParse(formData.get('payrollItemId'))
  if (!id.success) fail('/personnel/paie', 'Ligne de paie invalide.')
  const supabase = await client()
  const { error } = await supabase.rpc('mark_payroll_item_paid', { p_payroll_item_id: id.data })
  if (error) fail('/personnel/paie', error.message)
  revalidatePath('/personnel/paie')
  revalidatePath('/personnel')
  redirect('/personnel/paie?paid=1')
}

export async function closePayroll(formData: FormData) {
  const id = uuid.safeParse(formData.get('payrollPeriodId'))
  if (!id.success) fail('/personnel/paie', 'Période invalide.')
  const supabase = await client()
  const { error } = await supabase.rpc('close_payroll', { p_payroll_period_id: id.data })
  if (error) fail('/personnel/paie', error.message)
  revalidatePath('/personnel/paie')
  revalidatePath('/personnel')
  redirect('/personnel/paie?closed=1')
}
