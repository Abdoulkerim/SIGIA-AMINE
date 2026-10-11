'use server'

import { revalidatePath } from 'next/cache'
import { redirect } from 'next/navigation'
import { z } from 'zod'
import { createClient } from '@/lib/supabase/server'

const uuid = z.string().uuid()
const date = z.string().regex(/^\d{4}-\d{2}-\d{2}$/)
const money = z.coerce.number().positive()
const method = z.enum(['cash', 'bank_transfer', 'mobile_money', 'card', 'cheque', 'other'])

function errUrl(base: string, error: string) {
  return `${base}?error=${encodeURIComponent(error)}`
}

async function currentSchoolId() {
  const supabase = await createClient()
  const claims = await supabase.auth.getClaims()
  const userId = claims.data?.claims?.sub
  if (!userId) return { supabase, schoolId: null as string | null }
  const { data } = await supabase.from('users').select('school_id').eq('id', userId).single()
  return { supabase, schoolId: data?.school_id ?? null }
}

const feeTypeSchema = z.object({
  code: z.string().trim().min(1).max(40),
  name: z.string().trim().min(1).max(160),
  category: z.string().trim().min(1).max(80),
  description: z.string().trim().max(500).optional(),
})

export async function createFeeType(formData: FormData) {
  const parsed = feeTypeSchema.safeParse({
    code: formData.get('code'), name: formData.get('name'), category: formData.get('category'),
    description: formData.get('description') || undefined,
  })
  if (!parsed.success) redirect(errUrl('/finance/tarifs', 'Type de frais invalide.'))
  const { supabase, schoolId } = await currentSchoolId()
  if (!schoolId) redirect(errUrl('/finance/tarifs', 'École introuvable.'))
  const { error } = await supabase.rpc('create_fee_type', {
    p_school_id: schoolId, p_code: parsed.data.code, p_name: parsed.data.name,
    p_category: parsed.data.category, p_description: parsed.data.description ?? null,
  })
  if (error) redirect(errUrl('/finance/tarifs', error.message))
  revalidatePath('/finance/tarifs'); revalidatePath('/finance')
  redirect('/finance/tarifs?created=1')
}

const chargeSchema = z.object({
  studentId: uuid, feeTypeId: uuid, amount: money, dueDate: date, enrollmentId: z.string().uuid().optional(), description: z.string().trim().max(300).optional(),
})

export async function createStudentCharge(formData: FormData) {
  const parsed = chargeSchema.safeParse({
    studentId: formData.get('studentId'), feeTypeId: formData.get('feeTypeId'), amount: formData.get('amount'),
    dueDate: formData.get('dueDate'), enrollmentId: formData.get('enrollmentId') || undefined,
    description: formData.get('description') || undefined,
  })
  if (!parsed.success) redirect(errUrl('/finance/eleves', 'Frais élève invalides.'))
  const { supabase } = await currentSchoolId()
  const { error } = await supabase.rpc('create_student_charge', {
    p_student_id: parsed.data.studentId, p_fee_type_id: parsed.data.feeTypeId, p_amount_due: parsed.data.amount,
    p_due_date: parsed.data.dueDate, p_enrollment_id: parsed.data.enrollmentId ?? null, p_description: parsed.data.description ?? null,
  })
  if (error) redirect(errUrl('/finance/eleves', error.message))
  revalidatePath('/finance/eleves'); revalidatePath('/finance/impayes'); revalidatePath('/finance')
  redirect('/finance/eleves?created=1')
}

const invoiceSchema = z.object({
  studentId: z.string().uuid(), parentId: z.string().uuid().optional(), issueDate: date, dueDate: date.optional(), notes: z.string().trim().max(500).optional(),
  description: z.string().trim().min(1).max(200), quantity: z.coerce.number().positive(), unitAmount: money, discount: z.coerce.number().min(0), feeTypeId: z.string().uuid().optional(),
})

export async function createInvoice(formData: FormData) {
  const parsed = invoiceSchema.safeParse({
    studentId: formData.get('studentId'), parentId: formData.get('parentId') || undefined,
    issueDate: formData.get('issueDate'), dueDate: formData.get('dueDate') || undefined, notes: formData.get('notes') || undefined,
    description: formData.get('description'), quantity: formData.get('quantity') || 1, unitAmount: formData.get('unitAmount'),
    discount: formData.get('discount') || 0, feeTypeId: formData.get('feeTypeId') || undefined,
  })
  if (!parsed.success) redirect(errUrl('/finance/factures/nouvelle', 'Données de facture invalides.'))
  const { supabase } = await currentSchoolId()
  const { data, error } = await supabase.rpc('create_invoice', {
    p_student_id: parsed.data.studentId, p_parent_id: parsed.data.parentId ?? null,
    p_issue_date: parsed.data.issueDate, p_due_date: parsed.data.dueDate ?? null, p_notes: parsed.data.notes ?? null,
    p_items: [{ fee_type_id: parsed.data.feeTypeId ?? null, description: parsed.data.description, quantity: parsed.data.quantity, unit_amount: parsed.data.unitAmount, discount: parsed.data.discount }],
  })
  if (error) redirect(errUrl('/finance/factures/nouvelle', error.message))
  revalidatePath('/finance/factures'); revalidatePath('/finance'); revalidatePath('/administration/eleves')
  redirect(`/finance/factures?created=${data}`)
}

const paymentSchema = z.object({
  studentId: z.string().uuid(), parentId: z.string().uuid().optional(), amount: money, paymentDate: z.string().min(1),
  method, reference: z.string().trim().max(120).optional(), notes: z.string().trim().max(500).optional(),
  targetType: z.enum(['invoice', 'student_charge']), targetId: uuid, cashAccountId: z.string().uuid().optional(),
})

export async function recordPayment(formData: FormData) {
  const parsed = paymentSchema.safeParse({
    studentId: formData.get('studentId'), parentId: formData.get('parentId') || undefined, amount: formData.get('amount'),
    paymentDate: formData.get('paymentDate'), method: formData.get('method'), reference: formData.get('reference') || undefined,
    notes: formData.get('notes') || undefined, targetType: formData.get('targetType'), targetId: formData.get('targetId'),
    cashAccountId: formData.get('cashAccountId') || undefined,
  })
  if (!parsed.success) redirect(errUrl('/finance/paiements/nouveau', 'Données de paiement invalides.'))
  const allocation = parsed.data.targetType === 'invoice'
    ? { invoice_id: parsed.data.targetId, amount: parsed.data.amount }
    : { student_charge_id: parsed.data.targetId, amount: parsed.data.amount }
  const { supabase } = await currentSchoolId()
  const { data, error } = await supabase.rpc('record_payment', {
    p_student_id: parsed.data.studentId, p_parent_id: parsed.data.parentId ?? null, p_amount: parsed.data.amount,
    p_payment_date: parsed.data.paymentDate, p_method: parsed.data.method, p_reference: parsed.data.reference ?? null,
    p_notes: parsed.data.notes ?? null, p_allocations: [allocation], p_cash_account_id: parsed.data.cashAccountId ?? null,
  })
  if (error) redirect(errUrl('/finance/paiements/nouveau', error.message))
  revalidatePath('/finance'); revalidatePath('/finance/paiements'); revalidatePath('/finance/factures'); revalidatePath('/finance/impayes')
  redirect(`/finance/paiements?created=${data}`)
}

const expenseSchema = z.object({
  categoryId: z.string().uuid().optional(), supplierId: z.string().uuid().optional(), amount: z.coerce.number().nonnegative(), expenseDate: date,
  description: z.string().trim().min(3).max(500), paymentMethod: method.optional(), cashAccountId: z.string().uuid().optional(),
})

export async function createExpense(formData: FormData) {
  const parsed = expenseSchema.safeParse({
    categoryId: formData.get('categoryId') || undefined, supplierId: formData.get('supplierId') || undefined,
    amount: formData.get('amount'), expenseDate: formData.get('expenseDate'), description: formData.get('description'),
    paymentMethod: formData.get('paymentMethod') || undefined, cashAccountId: formData.get('cashAccountId') || undefined,
  })
  if (!parsed.success) redirect(errUrl('/finance/depenses/nouvelle', 'Données de dépense invalides.'))
  const { supabase } = await currentSchoolId()
  const { error } = await supabase.rpc('create_expense', {
    p_category_id: parsed.data.categoryId ?? null, p_supplier_id: parsed.data.supplierId ?? null, p_amount: parsed.data.amount,
    p_expense_date: parsed.data.expenseDate, p_description: parsed.data.description, p_payment_method: parsed.data.paymentMethod ?? null,
    p_cash_account_id: parsed.data.cashAccountId ?? null,
  })
  if (error) redirect(errUrl('/finance/depenses/nouvelle', error.message))
  revalidatePath('/finance/depenses'); revalidatePath('/finance')
  redirect('/finance/depenses?created=1')
}

export async function approveExpense(formData: FormData) {
  const id = uuid.safeParse(formData.get('id'))
  if (!id.success) redirect(errUrl('/finance/depenses', 'Dépense invalide.'))
  const cashAccountId = z.string().uuid().optional().safeParse(formData.get('cashAccountId') || undefined)
  const { supabase } = await currentSchoolId()
  const { error } = await supabase.rpc('approve_expense', { p_expense_id: id.data, p_cash_account_id: cashAccountId.success ? cashAccountId.data ?? null : null })
  if (error) redirect(errUrl('/finance/depenses', error.message))
  revalidatePath('/finance/depenses'); revalidatePath('/finance/caisse'); revalidatePath('/finance')
  redirect('/finance/depenses?approved=1')
}

const cashSchema = z.object({ code: z.string().trim().min(1).max(30), name: z.string().trim().min(1).max(120), accountType: z.enum(['cash','bank','mobile_money','other']), openingBalance: z.coerce.number().nonnegative() })
export async function createCashAccount(formData: FormData) {
  const parsed = cashSchema.safeParse({ code: formData.get('code'), name: formData.get('name'), accountType: formData.get('accountType'), openingBalance: formData.get('openingBalance') })
  if (!parsed.success) redirect(errUrl('/finance/caisse', 'Compte de caisse invalide.'))
  const { supabase, schoolId } = await currentSchoolId()
  if (!schoolId) redirect(errUrl('/finance/caisse', 'École introuvable.'))
  const { error } = await supabase.rpc('create_cash_account', { p_school_id: schoolId, p_code: parsed.data.code, p_name: parsed.data.name, p_account_type: parsed.data.accountType, p_opening_balance: parsed.data.openingBalance })
  if (error) redirect(errUrl('/finance/caisse', error.message))
  revalidatePath('/finance/caisse'); revalidatePath('/finance/paiements/nouveau'); revalidatePath('/finance')
  redirect('/finance/caisse?created=1')
}

const closingSchema = z.object({ cashAccountId: uuid, closingDate: date, actualBalance: z.coerce.number().nonnegative(), notes: z.string().trim().max(500).optional() })
export async function closeCashAccount(formData: FormData) {
  const parsed = closingSchema.safeParse({ cashAccountId: formData.get('cashAccountId'), closingDate: formData.get('closingDate'), actualBalance: formData.get('actualBalance'), notes: formData.get('notes') || undefined })
  if (!parsed.success) redirect(errUrl('/finance/caisse', 'Clôture invalide.'))
  const { supabase } = await currentSchoolId()
  const { error } = await supabase.rpc('close_cash_account', { p_cash_account_id: parsed.data.cashAccountId, p_closing_date: parsed.data.closingDate, p_actual_balance: parsed.data.actualBalance, p_notes: parsed.data.notes ?? null })
  if (error) redirect(errUrl('/finance/caisse', error.message))
  revalidatePath('/finance/caisse'); revalidatePath('/finance')
  redirect('/finance/caisse?closed=1')
}

const reminderSchema = z.object({ studentId: uuid, parentId: z.string().uuid().optional(), amountDue: z.coerce.number().nonnegative(), reminderDate: date, channel: z.string().trim().max(30).optional(), message: z.string().trim().max(1000).optional() })
export async function createCollectionReminder(formData: FormData) {
  const parsed = reminderSchema.safeParse({ studentId: formData.get('studentId'), parentId: formData.get('parentId') || undefined, amountDue: formData.get('amountDue'), reminderDate: formData.get('reminderDate'), channel: formData.get('channel') || undefined, message: formData.get('message') || undefined })
  if (!parsed.success) redirect(errUrl('/finance/impayes', 'Relance invalide.'))
  const { supabase } = await currentSchoolId()
  const { error } = await supabase.rpc('create_collection_reminder', { p_student_id: parsed.data.studentId, p_parent_id: parsed.data.parentId ?? null, p_amount_due: parsed.data.amountDue, p_reminder_date: parsed.data.reminderDate, p_channel: parsed.data.channel ?? null, p_message: parsed.data.message ?? null })
  if (error) redirect(errUrl('/finance/impayes', error.message))
  revalidatePath('/finance/impayes'); revalidatePath('/finance')
  redirect('/finance/impayes?reminded=1')
}
