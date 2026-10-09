'use server'

import { revalidatePath } from 'next/cache'
import { redirect } from 'next/navigation'
import { z } from 'zod'
import { createClient } from '@/lib/supabase/server'

const uuid = z.string().uuid()
const date = z.string().min(1)
const num = z.coerce.number().finite()
const text = z.string().trim().min(1).max(300)
const optionalText = z.string().trim().max(2000).optional()

function fail(path: string, message: string): never {
  redirect(`${path}?error=${encodeURIComponent(message)}`)
}

function linesFromForm(productId: string | null, productionId: string | null, locationId: string | null, quantity: number, unit: string, unitPrice: number, notes?: string) {
  return JSON.stringify([{
    ...(productId ? { product_id: productId } : {}),
    ...(productionId ? { production_id: productionId } : {}),
    ...(locationId ? { stock_location_id: locationId } : {}),
    quantity, unit, unit_price: unitPrice,
    ...(notes ? { notes } : {}),
  }])
}

export async function createActivity(formData: FormData) {
  const code = text.safeParse(formData.get('code'))
  const name = text.safeParse(formData.get('name'))
  const type = z.enum(['agriculture','livestock','agr']).safeParse(formData.get('activityType'))
  const responsible = uuid.optional().safeParse(formData.get('responsibleEmployeeId') || undefined)
  const location = z.string().trim().max(300).optional().safeParse(formData.get('location') || undefined)
  const description = optionalText.safeParse(formData.get('description') || undefined)
  const startDate = z.string().optional().safeParse(formData.get('startDate') || undefined)
  const endDate = z.string().optional().safeParse(formData.get('endDate') || undefined)
  const budget = num.min(0).safeParse(formData.get('budgetAmount') || 0)
  if (![code,name,type,responsible,location,description,startDate,endDate,budget].every(x => x.success)) fail('/activites', 'Activité invalide.')
  const supabase = await createClient()
  const { error } = await supabase.rpc('create_economic_activity', {
    p_code: code.data, p_name: name.data, p_activity_type: type.data,
    p_responsible_employee_id: responsible.data ?? null,
    p_location: location.data ?? null, p_description: description.data ?? null,
    p_start_date: startDate.data || null, p_end_date: endDate.data || null,
    p_budget_amount: budget.data,
  })
  if (error) fail('/activites', error.message)
  revalidatePath('/activites'); revalidatePath('/activites/agriculture'); revalidatePath('/activites/elevage'); revalidatePath('/activites/agr')
  redirect('/activites?created=1')
}

export async function createSite(formData: FormData) {
  const activityId = uuid.safeParse(formData.get('activityId'))
  const code = text.safeParse(formData.get('code'))
  const name = text.safeParse(formData.get('name'))
  const siteType = z.string().trim().max(120).optional().safeParse(formData.get('siteType') || undefined)
  const location = z.string().trim().max(500).optional().safeParse(formData.get('locationDescription') || undefined)
  const area = num.min(0).optional().safeParse(formData.get('area') || undefined)
  const areaUnit = z.string().trim().max(30).optional().safeParse(formData.get('areaUnit') || undefined)
  const responsible = uuid.optional().safeParse(formData.get('responsibleEmployeeId') || undefined)
  if (![activityId,code,name,siteType,location,area,areaUnit,responsible].every(x => x.success)) fail('/activites/agriculture', 'Site invalide.')
  const supabase = await createClient()
  const { error } = await supabase.rpc('create_economic_activity_site', {
    p_activity_id: activityId.data, p_code: code.data, p_name: name.data,
    p_site_type: siteType.data ?? null, p_location_description: location.data ?? null,
    p_area: area.data ?? null, p_area_unit: areaUnit.data ?? null,
    p_responsible_employee_id: responsible.data ?? null,
  })
  if (error) fail('/activites/agriculture', error.message)
  revalidatePath('/activites/agriculture'); redirect('/activites/agriculture?site_created=1')
}

export async function createCampaign(formData: FormData) {
  const activityId = uuid.safeParse(formData.get('activityId'))
  const crop = text.safeParse(formData.get('crop'))
  const startDate = z.string().optional().safeParse(formData.get('startDate') || undefined)
  const endDate = z.string().optional().safeParse(formData.get('endDate') || undefined)
  const area = num.min(0).optional().safeParse(formData.get('area') || undefined)
  const areaUnit = z.string().trim().max(30).optional().safeParse(formData.get('areaUnit') || undefined)
  const expectedYield = num.min(0).optional().safeParse(formData.get('expectedYield') || undefined)
  const notes = optionalText.safeParse(formData.get('notes') || undefined)
  if (![activityId,crop,startDate,endDate,area,areaUnit,expectedYield,notes].every(x => x.success)) fail('/activites/agriculture', 'Campagne invalide.')
  const supabase = await createClient()
  const { error } = await supabase.rpc('create_agriculture_campaign', {
    p_activity_id: activityId.data, p_crop: crop.data,
    p_start_date: startDate.data || null, p_end_date: endDate.data || null,
    p_area: area.data ?? null, p_area_unit: areaUnit.data ?? null,
    p_expected_yield: expectedYield.data ?? null, p_notes: notes.data ?? null,
  })
  if (error) fail('/activites/agriculture', error.message)
  revalidatePath('/activites/agriculture'); redirect('/activites/agriculture?campaign_created=1')
}

export async function recordInput(formData: FormData) {
  const activityId = uuid.safeParse(formData.get('activityId'))
  const productId = uuid.safeParse(formData.get('productId'))
  const locationId = uuid.safeParse(formData.get('locationId'))
  const quantity = num.positive().safeParse(formData.get('quantity'))
  const cost = num.min(0).optional().safeParse(formData.get('unitCost') || undefined)
  const site = uuid.optional().safeParse(formData.get('siteId') || undefined)
  const campaign = uuid.optional().safeParse(formData.get('campaignId') || undefined)
  const livestock = uuid.optional().safeParse(formData.get('livestockId') || undefined)
  const inputDate = date.safeParse(formData.get('inputDate'))
  const notes = optionalText.safeParse(formData.get('notes') || undefined)
  if (![activityId,productId,locationId,quantity,cost,site,campaign,livestock,inputDate,notes].every(x => x.success)) fail('/activites/agriculture', 'Intrant invalide.')
  const supabase = await createClient()
  const { error } = await supabase.rpc('record_activity_input', {
    p_activity_id: activityId.data, p_product_id: productId.data, p_stock_location_id: locationId.data,
    p_quantity: quantity.data, p_unit_cost: cost.data ?? null, p_site_id: site.data ?? null,
    p_campaign_id: campaign.data ?? null, p_livestock_id: livestock.data ?? null,
    p_input_date: inputDate.data, p_notes: notes.data ?? null,
  })
  if (error) fail('/activites/agriculture', error.message)
  revalidatePath('/activites/agriculture'); revalidatePath('/stocks'); redirect('/activites/agriculture?input_recorded=1')
}

export async function recordProduction(formData: FormData) {
  const activityId = uuid.safeParse(formData.get('activityId'))
  const productName = text.safeParse(formData.get('productName'))
  const quantity = num.min(0).safeParse(formData.get('quantity'))
  const unit = text.safeParse(formData.get('unit'))
  const unitCost = num.min(0).safeParse(formData.get('unitCost') || 0)
  const productId = uuid.optional().safeParse(formData.get('productId') || undefined)
  const locationId = uuid.optional().safeParse(formData.get('stockLocationId') || undefined)
  const campaignId = uuid.optional().safeParse(formData.get('campaignId') || undefined)
  const livestockId = uuid.optional().safeParse(formData.get('livestockId') || undefined)
  const productionDate = date.safeParse(formData.get('productionDate'))
  const notes = optionalText.safeParse(formData.get('notes') || undefined)
  if (![activityId,productName,quantity,unit,unitCost,productId,locationId,campaignId,livestockId,productionDate,notes].every(x => x.success)) fail('/activites', 'Production invalide.')
  const supabase = await createClient()
  const { error } = await supabase.rpc('record_production', {
    p_activity_id: activityId.data, p_product_name: productName.data, p_quantity: quantity.data,
    p_unit: unit.data, p_unit_cost: unitCost.data, p_product_id: productId.data ?? null,
    p_stock_location_id: locationId.data ?? null, p_campaign_id: campaignId.data ?? null,
    p_livestock_id: livestockId.data ?? null, p_production_date: productionDate.data,
    p_notes: notes.data ?? null,
  })
  if (error) fail('/activites', error.message)
  revalidatePath('/activites'); revalidatePath('/activites/agriculture'); revalidatePath('/activites/elevage'); revalidatePath('/stocks');
  redirect('/activites?production_created=1')
}

export async function recordExpense(formData: FormData) {
  const activityId = uuid.safeParse(formData.get('activityId'))
  const category = text.safeParse(formData.get('category'))
  const amount = num.min(0).safeParse(formData.get('amount'))
  const expenseDate = date.safeParse(formData.get('expenseDate'))
  const description = optionalText.safeParse(formData.get('description') || undefined)
  const siteId = uuid.optional().safeParse(formData.get('siteId') || undefined)
  const financeId = uuid.optional().safeParse(formData.get('financeExpenseId') || undefined)
  if (![activityId,category,amount,expenseDate,description,siteId,financeId].every(x => x.success)) fail('/activites', 'Dépense invalide.')
  const supabase = await createClient()
  const { error } = await supabase.rpc('record_economic_activity_expense', {
    p_activity_id: activityId.data, p_category: category.data, p_amount: amount.data,
    p_expense_date: expenseDate.data, p_description: description.data ?? null,
    p_site_id: siteId.data ?? null, p_finance_expense_id: financeId.data ?? null,
  })
  if (error) fail('/activites', error.message)
  revalidatePath('/activites'); revalidatePath('/activites/agriculture'); revalidatePath('/activites/elevage'); revalidatePath('/activites/agr');
  redirect('/activites?expense_created=1')
}

export async function createLivestock(formData: FormData) {
  const activityId = uuid.safeParse(formData.get('activityId'))
  const animalType = text.safeParse(formData.get('animalType'))
  const tag = z.string().trim().max(120).optional().safeParse(formData.get('tagNumber') || undefined)
  const breed = z.string().trim().max(160).optional().safeParse(formData.get('breed') || undefined)
  const quantity = num.positive().safeParse(formData.get('quantity'))
  const unit = text.safeParse(formData.get('unit'))
  const sex = z.string().trim().max(30).optional().safeParse(formData.get('sex') || undefined)
  const birth = z.string().optional().safeParse(formData.get('birthDate') || undefined)
  const acquisitionDate = z.string().optional().safeParse(formData.get('acquisitionDate') || undefined)
  const acquisitionCost = num.min(0).safeParse(formData.get('acquisitionCost') || 0)
  const notes = optionalText.safeParse(formData.get('notes') || undefined)
  if (![activityId,animalType,tag,breed,quantity,unit,sex,birth,acquisitionDate,acquisitionCost,notes].every(x => x.success)) fail('/activites/elevage', 'Cheptel invalide.')
  const supabase = await createClient()
  const { error } = await supabase.rpc('create_livestock', {
    p_activity_id: activityId.data, p_animal_type: animalType.data, p_tag_number: tag.data ?? null,
    p_breed: breed.data ?? null, p_quantity: quantity.data, p_unit: unit.data, p_sex: sex.data ?? null,
    p_birth_date: birth.data || null, p_acquisition_date: acquisitionDate.data || null,
    p_acquisition_cost: acquisitionCost.data, p_notes: notes.data ?? null,
  })
  if (error) fail('/activites/elevage', error.message)
  revalidatePath('/activites/elevage'); revalidatePath('/activites'); redirect('/activites/elevage?created=1')
}

export async function recordLivestockEvent(formData: FormData) {
  const livestockId = uuid.safeParse(formData.get('livestockId'))
  const eventType = text.safeParse(formData.get('eventType'))
  const eventDate = date.safeParse(formData.get('eventDate'))
  const quantity = num.min(0).optional().safeParse(formData.get('quantity') || undefined)
  const amount = num.min(0).optional().safeParse(formData.get('amount') || undefined)
  const description = optionalText.safeParse(formData.get('description') || undefined)
  if (![livestockId,eventType,eventDate,quantity,amount,description].every(x => x.success)) fail('/activites/elevage', 'Événement invalide.')
  const supabase = await createClient()
  const { error } = await supabase.rpc('record_livestock_event', {
    p_livestock_id: livestockId.data, p_event_type: eventType.data,
    p_event_date: eventDate.data, p_quantity: quantity.data ?? null,
    p_amount: amount.data ?? null, p_description: description.data ?? null,
  })
  if (error) fail('/activites/elevage', error.message)
  revalidatePath('/activites/elevage'); redirect('/activites/elevage?event_created=1')
}

export async function recordSale(formData: FormData) {
  const saleNumber = text.safeParse(formData.get('saleNumber'))
  const activityId = uuid.optional().safeParse(formData.get('activityId') || undefined)
  const saleDate = date.safeParse(formData.get('saleDate'))
  const customer = z.string().trim().max(200).optional().safeParse(formData.get('customerName') || undefined)
  const payment = z.enum(['cash','bank_transfer','mobile_money','card','cheque','other']).optional().safeParse(formData.get('paymentMethod') || undefined)
  const description = optionalText.safeParse(formData.get('description') || undefined)
  const productId = uuid.optional().safeParse(formData.get('productId') || undefined)
  const productionId = uuid.optional().safeParse(formData.get('productionId') || undefined)
  const locationId = uuid.optional().safeParse(formData.get('stockLocationId') || undefined)
  const quantity = num.positive().safeParse(formData.get('quantity'))
  const unit = text.safeParse(formData.get('unit'))
  const price = num.min(0).safeParse(formData.get('unitPrice'))
  const cashTransactionId = uuid.optional().safeParse(formData.get('cashTransactionId') || undefined)
  const activityReference = z.string().trim().max(120).optional().safeParse(formData.get('activityReference') || undefined)
  const notes = optionalText.safeParse(formData.get('notes') || undefined)
  if (!saleNumber.success || !activityId.success || !saleDate.success || !customer.success || !payment.success || !description.success || !productId.success || !productionId.success || !locationId.success || !quantity.success || !unit.success || !price.success || !cashTransactionId.success || !activityReference.success || !notes.success) fail('/activites', 'Vente invalide.')
  const supabase = await createClient()
  const { error } = await supabase.rpc('record_activity_sale', {
    p_sale_number: saleNumber.data, p_activity_id: activityId.data ?? null, p_sale_date: saleDate.data,
    p_customer_name: customer.data ?? null, p_payment_method: payment.data ?? null, p_description: description.data ?? null,
    p_items: linesFromForm(productId.data ?? null, productionId.data ?? null, locationId.data ?? null, quantity.data, unit.data, price.data, notes.data),
    p_cash_transaction_id: cashTransactionId.data ?? null, p_activity_reference: activityReference.data ?? null,
  })
  if (error) fail('/activites', error.message)
  revalidatePath('/activites'); revalidatePath('/activites/agriculture'); revalidatePath('/activites/elevage'); revalidatePath('/activites/agr'); revalidatePath('/stocks'); revalidatePath('/finance');
  redirect('/activites?sale_created=1')
}
