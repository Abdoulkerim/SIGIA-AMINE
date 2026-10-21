'use client'

import { useState } from 'react'

type ReportActionsProps = {
  title: string
  fileName: string
  headers: string[]
  rows: (string | number | null | undefined)[][]
}

function escapeHtml(value: string) {
  return value.replace(/[&<>"']/g, (character) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[character] ?? character)
}

function printable(value: string | number | null | undefined) {
  return value === null || value === undefined || value === '' ? '—' : String(value)
}

export function ReportActions({ title, fileName, headers, rows }: ReportActionsProps) {
  const [consulting, setConsulting] = useState(false)

  function exportCsv() {
    const lines = [headers, ...rows].map((line) => line.map((cell) => `"${printable(cell).replace(/"/g, '""')}"`).join(';'))
    const blob = new Blob([`\uFEFF${lines.join('\r\n')}`], { type: 'text/csv;charset=utf-8' })
    const url = URL.createObjectURL(blob)
    const link = document.createElement('a')
    link.href = url
    link.download = `${fileName}.csv`
    link.click()
    URL.revokeObjectURL(url)
  }

  function printReport() {
    const printWindow = window.open('', '_blank', 'width=1000,height=750')
    if (!printWindow) {
      window.alert('Autorisez les fenêtres contextuelles pour imprimer ce document.')
      return
    }
    const tableHead = headers.map((header) => `<th>${escapeHtml(header)}</th>`).join('')
    const tableRows = rows.map((row) => `<tr>${headers.map((_, index) => `<td>${escapeHtml(printable(row[index]))}</td>`).join('')}</tr>`).join('')
    printWindow.document.write(`<!doctype html><html lang="fr"><head><meta charset="utf-8"><title>${escapeHtml(title)}</title><style>body{font:14px Arial,sans-serif;color:#111;padding:24px}h1{font-size:22px}p{color:#555}table{width:100%;border-collapse:collapse;margin-top:20px}th,td{border:1px solid #bbb;padding:8px;text-align:left}th{background:#eee}tr{break-inside:avoid}@media print{body{padding:0}}</style></head><body><h1>${escapeHtml(title)}</h1><p>${rows.length} ligne(s) · généré le ${new Date().toLocaleDateString('fr-FR')}</p><table><thead><tr>${tableHead}</tr></thead><tbody>${tableRows}</tbody></table><script>window.addEventListener('load',()=>{window.focus();window.print()})<\/script></body></html>`)
    printWindow.document.close()
  }

  return (
    <div className="report-actions">
      <div className="actions" aria-label={`Actions pour ${title}`}>
        <button className="button button-secondary" type="button" onClick={() => setConsulting((value) => !value)}>{consulting ? 'Masquer l’aperçu' : 'Consulter'}</button>
        <button className="button button-secondary" type="button" onClick={exportCsv}>Excel / CSV</button>
        <button className="button button-secondary" type="button" onClick={printReport}>Imprimer / PDF</button>
      </div>
      {consulting ? (
        <section className="card" style={{ marginTop: 12 }} aria-label={`Aperçu de ${title}`}>
          <h2 style={{ marginTop: 0 }}>{title}</h2>
          <p className="page-subtitle">{rows.length} ligne(s) · aperçu du document</p>
          <div className="table-wrap"><table><thead><tr>{headers.map((header) => <th key={header}>{header}</th>)}</tr></thead><tbody>
            {rows.map((row, rowIndex) => <tr key={rowIndex}>{headers.map((header, index) => <td key={`${rowIndex}-${header}`}>{printable(row[index])}</td>)}</tr>)}
          </tbody></table></div>
          {!rows.length ? <p className="empty">Aucune donnée à afficher.</p> : null}
        </section>
      ) : null}
    </div>
  )
}
