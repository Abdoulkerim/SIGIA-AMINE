'use server'

import { revalidatePath } from 'next/cache'
import { redirect } from 'next/navigation'
import { z } from 'zod'
import { createClient } from '@/lib/supabase/server'

const uuid = z.string().uuid()
const date = z.string().min(1)
const num = z.coerce.number().finite()
const optionalText = z.string().trim().max(2000).optional()

function fail(path: string, message: string): never {
  redirect(`${path}?error=${encodeURIComponent(message)}`)
}

function jsonLine(productId: string, quantity: number, unitCost?: number, notes?: string) {
  return JSON.stringify([{ product_id: productId, quantity, ...(unitCost !== undefined ? { unit_cost: unitCost } : {}), ...(unitCost !== undefined ? { estimated_unit_cost: unitCost } : {}), ...(notes ? { notes } : {}) }])
}

export async function createSupplier(formData: FormData) {
  const code = z.string().trim().min(1).max(50).safeParse(formData.get('code'))
  const name = z.string().trim().min(1).max(200).safeParse(formData.get('name'))
  const contactName = z.string().trim().max(160).optional().safeParse(formData.get('contactName') || undefined)
  const phone = z.string().trim().max(60).optional().safeParse(formData.get('phone') || undefined)
  const email = z.string().trim().email().max(200).optional().safeParse(formData.get('email') || undefined)
  const address = z.string().trim().max(500).optional().safeParse(formData.get('address') || undefined)
  const taxId = z.string().trim().max(100).optional().safeParse(formData.get('taxId') || undefined)
  if (![code, name, contactName, phone, email, address, taxId].every(x => x.success)) fail('/stocks/fournisseurs', 'Fournisseur invalide.')
  const supabase = await createClient()
  const { error } = await supabase.rpc('create_supplier', { p_code: code.data, p_name: name.data, p_contact_name: contactName.data ?? null, p_phone: phone.data ?? null, p_email: email.data ?? null, p_address: address.data ?? null, p_tax_id: taxId.data ?? null })
  if (error) fail('/stocks/fournisseurs', error.message)
  revalidatePath('/stocks')
  revalidatePath('/stocks/fournisseurs')
  redirect('/stocks/fournisseurs?created=1')
}

export async function createCategory(formData: FormData) {
  const code = z.string().trim().min(1).max(50).safeParse(formData.get('code'))
  const name = z.string().trim().min(1).max(160).safeParse(formData.get('name'))
  if (!code.success || !name.success) fail('/stocks/produits', 'Catégorie invalide.')
  const supabase = await createClient()
  const { error } = await supabase.rpc('create_stock_category', { p_code: code.data, p_name: name.data })
  if (error) fail('/stocks/produits', error.message)
  revalidatePath('/stocks/produits')
  redirect('/stocks/produits?created=1')
}

export async function createLocation(formData: FormData) {
  const name = z.string().trim().min(1).max(160).safeParse(formData.get('name'))
  const type = z.string().trim().max(100).optional().safeParse(formData.get('locationType') || undefined)
  if (!name.success || !type.success) fail('/stocks/produits', 'Emplacement invalide.')
  const supabase = await createClient()
  const { error } = await supabase.rpc('create_stock_location', { p_name: name.data, p_location_type: type.data ?? null })
  if (error) fail('/stocks/produits', error.message)
  revalidatePath('/stocks/produits')
  revalidatePath('/stocks/mouvements')
  redirect('/stocks/produits?location_created=1')
}

export async function createProduct(formData: FormData) {
  const sku = z.string().trim().min(1).max(80).safeParse(formData.get('sku'))
  const name = z.string().trim().min(1).max(200).safeParse(formData.get('name'))
  const categoryId = z.string().uuid().optional().safeParse(formData.get('categoryId') || undefined)
  const unit = z.string().trim().min(1).max(40).safeParse(formData.get('unit'))
  const minimum = num.min(0).safeParse(formData.get('minimumStock') || 0)
  const maximum = z.union([num.min(0), z.literal(NaN)]).optional().safeParse(formData.get('maximumStock') || undefined)
  const cost = num.min(0).safeParse(formData.get('unitCost') || 0)
  const barcode = z.string().trim().max(100).optional().safeParse(formData.get('barcode') || undefined)
  const description = z.string().trim().max(1000).optional().safeParse(formData.get('description') || undefined)
  const reorder = num.min(0).safeParse(formData.get('reorderQuantity') || 0)
  const perishable = formData.get('isPerishable') === 'on'
  if (![sku, name, categoryId, unit, minimum, maximum, cost, barcode, description, reorder].every(x => x.success)) fail('/stocks/produits', 'Produit invalide.')
  const max = formData.get('maximumStock') ? Number(formData.get('maximumStock')) : null
  if (max !== null && Number.isNaN(max)) fail('/stocks/produits', 'Stock maximum invalide.')
  const supabase = await createClient()
  const { error } = await supabase.rpc('create_product', { p_sku: sku.data, p_name: name.data, p_category_id: categoryId.data ?? null, p_unit: unit.data, p_minimum_stock: minimum.data, p_maximum_stock: max, p_unit_cost: cost.data, p_barcode: barcode.data ?? null, p_description: description.data ?? null, p_reorder_quantity: reorder.data, p_is_perishable: perishable })
  if (error) fail('/stocks/produits', error.message)
  revalidatePath('/stocks')
  revalidatePath('/stocks/produits')
  revalidatePath('/stocks/mouvements')
  redirect('/stocks/produits?created=1')
}

export async function recordStockMovement(formData: FormData) {
  const productId = uuid.safeParse(formData.get('productId'))
  const locationId = uuid.safeParse(formData.get('locationId'))
  const movementType = z.enum(['purchase','sale','issue','return','adjustment','loss','transfer','production_in','production_out','transfer_in','adjustment_in','adjustment_out']).safeParse(formData.get('movementType'))
  const quantity = num.positive().safeParse(formData.get('quantity'))
  const unitCost = z.coerce.number().min(0).optional().safeParse(formData.get('unitCost') || undefined)
  const notes = optionalText.safeParse(formData.get('notes') || undefined)
  if (![productId, locationId, movementType, quantity, unitCost, notes].every(x => x.success)) fail('/stocks/mouvements', 'Mouvement invalide.')
  const supabase = await createClient()
  const { error } = await supabase.rpc('record_stock_movement', { p_product_id: productId.data, p_location_id: locationId.data, p_movement_type: movementType.data, p_quantity: quantity.data, p_unit_cost: unitCost.data ?? null, p_notes: notes.data ?? null })
  if (error) fail('/stocks/mouvements', error.message)
  revalidatePath('/stocks')
  revalidatePath('/stocks/mouvements')
  revalidatePath('/stocks/inventaires')
  revalidatePath('/stocks/produits')
  redirect('/stocks/mouvements?recorded=1')
}

export async function createInventory(formData: FormData) {
  const locationId = uuid.safeParse(formData.get('locationId'))
  const inventoryDate = date.safeParse(formData.get('inventoryDate'))
  const notes = optionalText.safeParse(formData.get('notes') || undefined)
  if (![locationId, inventoryDate, notes].every(x => x.success)) fail('/stocks/inventaires', 'Inventaire invalide.')
  const supabase = await createClient()
  const { data, error } = await supabase.rpc('create_stock_inventory', { p_location_id: locationId.data, p_inventory_date: inventoryDate.data, p_notes: notes.data ?? null })
  if (error) fail('/stocks/inventaires', error.message)
  revalidatePath('/stocks/inventaires')
  redirect(`/stocks/inventaires?created=${data}`)
}

export async function setInventoryCount(formData: FormData) {
  const id = uuid.safeParse(formData.get('inventoryItemId'))
  const count = num.min(0).safeParse(formData.get('countedQuantity'))
  if (!id.success || !count.success) fail('/stocks/inventaires', 'Comptage invalide.')
  const supabase = await createClient()
  const { error } = await supabase.rpc('set_stock_inventory_count', { p_inventory_item_id: id.data, p_counted_quantity: count.data })
  if (error) fail('/stocks/inventaires', error.message)
  revalidatePath('/stocks/inventaires')
  redirect('/stocks/inventaires?counted=1')
}

export async function finalizeInventory(formData: FormData) {
  const id = uuid.safeParse(formData.get('inventoryId'))
  if (!id.success) fail('/stocks/inventaires', 'Inventaire invalide.')
  const supabase = await createClient()
  const { error } = await supabase.rpc('finalize_stock_inventory', { p_inventory_id: id.data })
  if (error) fail('/stocks/inventaires', error.message)
  revalidatePath('/stocks')
  revalidatePath('/stocks/inventaires')
  revalidatePath('/stocks/mouvements')
  redirect('/stocks/inventaires?finalized=1')
}

export async function createPurchaseRequest(formData: FormData) {
  const number = z.string().trim().min(1).max(60).safeParse(formData.get('requestNumber'))
  const neededBy = z.string().optional().safeParse(formData.get('neededBy') || undefined)
  const department = z.string().trim().max(160).optional().safeParse(formData.get('department') || undefined)
  const reason = optionalText.safeParse(formData.get('reason') || undefined)
  const productId = uuid.safeParse(formData.get('productId'))
  const quantity = num.positive().safeParse(formData.get('quantity'))
  const estimated = num.min(0).safeParse(formData.get('estimatedUnitCost') || 0)
  if (!number.success || !neededBy.success || !department.success || !reason.success || !productId.success || !quantity.success || !estimated.success) fail('/stocks/demandes', 'Demande invalide.')
  const supabase = await createClient()
  const { data, error } = await supabase.rpc('create_purchase_request', { p_request_number: number.data, p_needed_by: neededBy.data || null, p_department: department.data ?? null, p_reason: reason.data ?? null, p_items: jsonLine(productId.data, quantity.data, estimated.data) })
  if (error) fail('/stocks/demandes', error.message)
  revalidatePath('/stocks/demandes')
  redirect(`/stocks/demandes?created=${data}`)
}

export async function submitPurchaseRequest(formData: FormData) {
  const id = uuid.safeParse(formData.get('requestId'))
  if (!id.success) fail('/stocks/demandes', 'Demande invalide.')
  const supabase = await createClient()
  const { error } = await supabase.rpc('submit_purchase_request', { p_request_id: id.data })
  if (error) fail('/stocks/demandes', error.message)
  revalidatePath('/stocks/demandes')
  redirect('/stocks/demandes?submitted=1')
}

export async function decidePurchaseRequest(formData: FormData) {
  const id = uuid.safeParse(formData.get('requestId'))
  const decision = z.enum(['approved','rejected','cancelled']).safeParse(formData.get('decision'))
  const note = optionalText.safeParse(formData.get('note') || undefined)
  if (![id, decision, note].every(x => x.success)) fail('/stocks/demandes', 'Décision invalide.')
  const supabase = await createClient()
  const { error } = await supabase.rpc('decide_purchase_request', { p_request_id: id.data, p_decision: decision.data, p_note: note.data ?? null })
  if (error) fail('/stocks/demandes', error.message)
  revalidatePath('/stocks/demandes')
  revalidatePath('/stocks/commandes')
  redirect('/stocks/demandes?decided=1')
}

export async function createPurchaseOrder(formData: FormData) {
  const orderNumber = z.string().trim().min(1).max(60).safeParse(formData.get('orderNumber'))
  const supplierId = uuid.safeParse(formData.get('supplierId'))
  const orderDate = date.safeParse(formData.get('orderDate'))
  const expectedDate = z.string().optional().safeParse(formData.get('expectedDate') || undefined)
  const locationId = uuid.optional().safeParse(formData.get('locationId') || undefined)
  const requestId = uuid.optional().safeParse(formData.get('requestId') || undefined)
  const productId = uuid.safeParse(formData.get('productId'))
  const quantity = num.positive().safeParse(formData.get('quantity'))
  const unitCost = num.min(0).safeParse(formData.get('unitCost'))
  if (!orderNumber.success || !supplierId.success || !orderDate.success || !expectedDate.success || !locationId.success || !requestId.success || !productId.success || !quantity.success || !unitCost.success) fail('/stocks/commandes', 'Commande invalide.')
  const supabase = await createClient()
  const { data, error } = await supabase.rpc('create_purchase_order', { p_order_number: orderNumber.data, p_supplier_id: supplierId.data, p_order_date: orderDate.data, p_expected_date: expectedDate.data || null, p_default_location_id: locationId.data ?? null, p_request_id: requestId.data ?? null, p_items: jsonLine(productId.data, quantity.data, unitCost.data) })
  if (error) fail('/stocks/commandes', error.message)
  revalidatePath('/stocks/commandes')
  redirect(`/stocks/commandes?created=${data}`)
}

export async function addPurchaseOrderItem(formData: FormData) {
  const orderId = uuid.safeParse(formData.get('orderId'))
  const productId = uuid.safeParse(formData.get('productId'))
  const quantity = num.positive().safeParse(formData.get('quantity'))
  const unitCost = num.min(0).safeParse(formData.get('unitCost'))
  if (![orderId, productId, quantity, unitCost].every(x => x.success)) fail('/stocks/commandes', 'Ligne de commande invalide.')
  const supabase = await createClient()
  const { error } = await supabase.rpc('add_purchase_order_item', { p_purchase_order_id: orderId.data, p_product_id: productId.data, p_quantity: quantity.data, p_unit_cost: unitCost.data })
  if (error) fail('/stocks/commandes', error.message)
  revalidatePath('/stocks/commandes')
  redirect('/stocks/commandes?item_added=1')
}

export async function setPurchaseOrderStatus(formData: FormData) {
  const id = uuid.safeParse(formData.get('purchaseOrderId'))
  const status = z.enum(['submitted','approved','rejected','cancelled']).safeParse(formData.get('status'))
  if (!id.success || !status.success) fail('/stocks/commandes', 'Statut commande invalide.')
  const supabase = await createClient()
  const { error } = await supabase.rpc('set_purchase_order_status', { p_purchase_order_id: id.data, p_status: status.data })
  if (error) fail('/stocks/commandes', error.message)
  revalidatePath('/stocks/commandes')
  revalidatePath('/stocks/receptions')
  redirect('/stocks/commandes?updated=1')
}

export async function receivePurchaseOrder(formData: FormData) {
  const orderId = uuid.safeParse(formData.get('purchaseOrderId'))
  const locationId = uuid.safeParse(formData.get('locationId'))
  const receiptNumber = z.string().trim().min(1).max(60).safeParse(formData.get('receiptNumber'))
  const receivedAt = z.string().min(1).safeParse(formData.get('receivedAt'))
  const purchaseItemId = uuid.safeParse(formData.get('purchaseItemId'))
  const quantity = num.positive().safeParse(formData.get('quantity'))
  const notes = optionalText.safeParse(formData.get('notes') || undefined)
  if (![orderId, locationId, receiptNumber, receivedAt, purchaseItemId, quantity, notes].every(x => x.success)) fail('/stocks/receptions', 'Réception invalide.')
  const supabase = await createClient()
  const { error } = await supabase.rpc('receive_purchase_order', { p_purchase_order_id: orderId.data, p_location_id: locationId.data, p_receipt_number: receiptNumber.data, p_received_at: receivedAt.data, p_items: JSON.stringify([{ purchase_item_id: purchaseItemId.data, quantity: quantity.data }]), p_notes: notes.data ?? null })
  if (error) fail('/stocks/receptions', error.message)
  revalidatePath('/stocks')
  revalidatePath('/stocks/receptions')
  revalidatePath('/stocks/commandes')
  revalidatePath('/stocks/mouvements')
  redirect('/stocks/receptions?received=1')
}

export async function createTransfer(formData: FormData) {
  const number = z.string().trim().min(1).max(60).safeParse(formData.get('transferNumber'))
  const source = uuid.safeParse(formData.get('sourceLocationId'))
  const target = uuid.safeParse(formData.get('targetLocationId'))
  const transferDate = date.safeParse(formData.get('transferDate'))
  const productId = uuid.safeParse(formData.get('productId'))
  const quantity = num.positive().safeParse(formData.get('quantity'))
  const notes = optionalText.safeParse(formData.get('notes') || undefined)
  if (![number, source, target, transferDate, productId, quantity, notes].every(x => x.success)) fail('/stocks/transferts', 'Transfert invalide.')
  const supabase = await createClient()
  const { data, error } = await supabase.rpc('create_stock_transfer', { p_transfer_number: number.data, p_source_location_id: source.data, p_target_location_id: target.data, p_transfer_date: transferDate.data, p_items: JSON.stringify([{ product_id: productId.data, quantity: quantity.data }]), p_notes: notes.data ?? null })
  if (error) fail('/stocks/transferts', error.message)
  revalidatePath('/stocks/transferts')
  redirect(`/stocks/transferts?created=${data}`)
}

export async function completeTransfer(formData: FormData) {
  const id = uuid.safeParse(formData.get('transferId'))
  if (!id.success) fail('/stocks/transferts', 'Transfert invalide.')
  const supabase = await createClient()
  const { error } = await supabase.rpc('complete_stock_transfer', { p_transfer_id: id.data })
  if (error) fail('/stocks/transferts', error.message)
  revalidatePath('/stocks')
  revalidatePath('/stocks/transferts')
  revalidatePath('/stocks/mouvements')
  redirect('/stocks/transferts?completed=1')
}

export async function createPurchaseInvoice(formData: FormData) {
  const supplierId = uuid.safeParse(formData.get('supplierId'))
  const orderId = uuid.optional().safeParse(formData.get('purchaseOrderId') || undefined)
  const invoiceNumber = z.string().trim().min(1).max(80).safeParse(formData.get('invoiceNumber'))
  const invoiceDate = date.safeParse(formData.get('invoiceDate'))
  const dueDate = z.string().optional().safeParse(formData.get('dueDate') || undefined)
  const amount = num.positive().safeParse(formData.get('amount'))
  const notes = optionalText.safeParse(formData.get('notes') || undefined)
  if (![supplierId, orderId, invoiceNumber, invoiceDate, dueDate, amount, notes].every(x => x.success)) fail('/stocks/factures', 'Facture fournisseur invalide.')
  const supabase = await createClient()
  const { error } = await supabase.rpc('create_purchase_invoice', { p_supplier_id: supplierId.data, p_purchase_order_id: orderId.data ?? null, p_invoice_number: invoiceNumber.data, p_invoice_date: invoiceDate.data, p_due_date: dueDate.data || null, p_amount: amount.data, p_notes: notes.data ?? null })
  if (error) fail('/stocks/factures', error.message)
  revalidatePath('/stocks/factures')
  redirect('/stocks/factures?created=1')
}

export async function payPurchaseInvoice(formData: FormData) {
  const invoiceId = uuid.safeParse(formData.get('purchaseInvoiceId'))
  const cashAccountId = uuid.safeParse(formData.get('cashAccountId'))
  const amount = num.positive().safeParse(formData.get('amount'))
  const paymentDate = z.string().min(1).safeParse(formData.get('paymentDate'))
  const reference = z.string().trim().max(120).optional().safeParse(formData.get('reference') || undefined)
  if (![invoiceId, cashAccountId, amount, paymentDate, reference].every(x => x.success)) fail('/stocks/factures', 'Paiement fournisseur invalide.')
  const supabase = await createClient()
  const { error } = await supabase.rpc('pay_purchase_invoice', { p_purchase_invoice_id: invoiceId.data, p_cash_account_id: cashAccountId.data, p_amount: amount.data, p_payment_date: paymentDate.data, p_reference: reference.data ?? null })
  if (error) fail('/stocks/factures', error.message)
  revalidatePath('/stocks/factures')
  revalidatePath('/finance')
  revalidatePath('/finance/caisse')
  redirect('/stocks/factures?paid=1')
}
