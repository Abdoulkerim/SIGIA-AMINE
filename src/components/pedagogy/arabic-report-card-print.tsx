'use client'

export function ArabicReportCardPrint() {
  return <button className="button button-primary no-print" type="button" onClick={() => window.print()}>Imprimer le bulletin</button>
}
