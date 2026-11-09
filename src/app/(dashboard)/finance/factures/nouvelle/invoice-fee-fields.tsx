'use client'

import { useState } from 'react'

type FeeType = { id: string; code: string; name: string; default_amount: number | null }

export function InvoiceFeeFields({ fees }: { fees: FeeType[] }) {
  const [feeTypeId, setFeeTypeId] = useState('')
  const [amount, setAmount] = useState('')

  function selectFeeType(id: string) {
    setFeeTypeId(id)
    const fee = fees.find(item => item.id === id)
    setAmount(fee?.default_amount == null ? '' : String(fee.default_amount))
  }

  return <>
    <div className="field"><label className="label" htmlFor="feeTypeId">Type de frais (facultatif)</label><select className="select" id="feeTypeId" name="feeTypeId" value={feeTypeId} onChange={event => selectFeeType(event.target.value)}><option value="">Autre frais</option>{fees.map(fee => <option key={fee.id} value={fee.id}>{fee.code} • {fee.name}</option>)}</select></div>
    <div className="field"><label className="label" htmlFor="unitAmount">Montant</label><input className="input" id="unitAmount" type="number" step="0.01" min="0.01" name="unitAmount" value={amount} onChange={event => setAmount(event.target.value)} required /></div>
  </>
}
