import Link from 'next/link'
import { FunctionsHttpError } from '@supabase/supabase-js'
import { createClient } from '@/lib/supabase/server'
import { createInvoice } from '../../finance-actions'
import { InvoiceFeeFields } from './invoice-fee-fields'
import { InvoiceStudentFields } from './invoice-student-fields'

export default async function NewInvoicePage({ searchParams }: { searchParams: Promise<{ error?: string }> }) {
  const query = await searchParams
  const supabase = await createClient()
  const [{ data: studentResult, error: studentLoadError }, { data: parents }, { data: fees }] = await Promise.all([
    supabase.functions.invoke('managed-user-directory', { body: { action: 'invoice-students' } }),
    supabase.from('parents').select('id,first_name,last_name,phone').order('last_name').limit(500),
    supabase.from('fee_types').select('id,code,name,default_amount').eq('is_active', true).order('name'),
  ])
  let studentErrorMessage: string | null = null
  if (studentLoadError instanceof FunctionsHttpError) {
    try {
      const result = await studentLoadError.context.json()
      studentErrorMessage = typeof result?.error === 'string' ? result.error : null
    } catch { /* Réponse non JSON. */ }
  }
  const students = studentResult?.students ?? []
  const classes = studentResult?.classes ?? []
  const enrollments = studentResult?.enrollments ?? []
  const today = new Date().toISOString().slice(0, 10)

  return (
    <main className="page">
      <div className="page-header">
        <div><h1 className="page-title">Nouvelle facture</h1><p className="page-subtitle">Cette facture commence avec une ligne de frais.</p></div>
        <Link className="button button-secondary" href="/finance/factures">Retour</Link>
      </div>
      {query.error ? <p className="error">{query.error}</p> : null}
      {studentLoadError ? <p className="error">{studentErrorMessage ?? 'Impossible de charger les élèves. Vérifiez la permission financière et la fonction de gestion des comptes.'}</p> : null}
      {!studentLoadError && !students.length ? <p className="error">Aucun élève disponible pour cette école. Vérifiez que des élèves sont enregistrés et que votre compte a la permission « Gérer finance ».</p> : null}

      <section className="card" style={{ marginBottom: 16 }}>
        <h2 style={{ marginTop: 0 }}>Comment utiliser ce formulaire</h2>
        <ol>
          <li>Sélectionnez l’élève à facturer. La liste contient les élèves de votre école.</li>
          <li>Choisissez éventuellement le parent payeur et le type de frais; son prix remplira automatiquement le montant.</li>
          <li>Vérifiez la date d’émission et ajoutez une date d’échéance si nécessaire.</li>
          <li>Vérifiez le montant prérempli (modifiable), la remise éventuelle, puis la désignation de la ligne.</li>
          <li>Ajoutez une note si utile, puis cliquez sur « Créer la facture ».</li>
        </ol>
      </section>

      <form className="card" action={createInvoice}>
        <div className="grid grid-2">
          <InvoiceStudentFields students={students} classes={classes ?? []} enrollments={enrollments ?? []} />
          <div className="field"><label className="label" htmlFor="parentId">Parent payeur (facultatif)</label><select className="select" id="parentId" name="parentId" defaultValue=""><option value="">Aucun parent sélectionné</option>{parents?.map((parent: any) => <option key={parent.id} value={parent.id}>{parent.last_name} {parent.first_name}{parent.phone ? ` • ${parent.phone}` : ''}</option>)}</select></div>
          <InvoiceFeeFields fees={(fees ?? []).map((fee: any) => ({ ...fee, default_amount: fee.default_amount == null ? null : Number(fee.default_amount) }))} />
          <div className="field"><label className="label" htmlFor="issueDate">Date d’émission</label><input className="input" id="issueDate" type="date" name="issueDate" defaultValue={today} required /></div>
          <div className="field"><label className="label" htmlFor="dueDate">Date d’échéance (facultative)</label><input className="input" id="dueDate" type="date" name="dueDate" /></div>
          <div className="field"><label className="label" htmlFor="discount">Remise (FCFA)</label><input className="input" id="discount" type="number" step="0.01" min="0" name="discount" defaultValue="0" /></div>
        </div>
        <div className="field"><label className="label" htmlFor="description">Désignation</label><input className="input" id="description" name="description" placeholder="Scolarité — période 1" required /></div>
        <div className="field"><label className="label" htmlFor="notes">Note (facultative)</label><textarea className="input" id="notes" name="notes" rows={3} /></div>
        <button className="button button-primary" type="submit" disabled={!students.length}>Créer la facture</button>
      </form>
    </main>
  )
}
