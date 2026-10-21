'use client'

import { useMemo, useState } from 'react'
import { PrintCards } from './print-cards'

export type ManagedCard = { number: string; name: string; detail: string; status: string }
function csvCell(value: string) { return `"${value.replace(/"/g,'""')}"` }

export function CardManager({ cards, title, fileName, cardTitle }: { cards: ManagedCard[]; title: string; fileName: string; cardTitle: string }) {
  const [selected, setSelected] = useState<string[] | null>(null)
  const visible = useMemo(() => selected === null ? cards : cards.filter((card) => selected.includes(card.number)), [cards, selected])
  async function importList(file?: File) {
    if (!file) return
    const text = (await file.text()).replace(/^\uFEFF/, '')
    const values = text.split(/\r?\n/).flatMap((line) => line.split(/[;,\t]/)).map((item) => item.trim().replace(/^"|"$/g,'').replace(/""/g,'"')).filter(Boolean)
    const allNumbers = new Set(cards.map((card) => card.number))
    const hasHeader = values[0]?.toLocaleLowerCase('fr').includes('matricule')
    const known = [...new Set(values.slice(hasHeader ? 1 : 0).filter((value) => allNumbers.has(value))) ]
    setSelected(known)
    if (!known.length) window.alert('Aucun matricule reconnu. Utilisez un fichier CSV avec une colonne Matricule.')
  }
  function exportCsv() {
    const csv = [['Matricule','Nom complet','Classe / fonction','Statut'], ...visible.map((card) => [card.number,card.name,card.detail,card.status])].map((row) => row.map(csvCell).join(';')).join('\r\n')
    const url=URL.createObjectURL(new Blob([`\uFEFF${csv}`],{type:'text/csv;charset=utf-8'})); const link=document.createElement('a'); link.href=url; link.download=`${fileName}.csv`; link.click(); URL.revokeObjectURL(url)
  }
  return <>
    <section className="card card-import-panel"><div><h2>Importer une sélection</h2><p className="page-subtitle">Chargez un CSV de matricules pour isoler les cartes à imprimer. Les dossiers restent inchangés.</p></div><div className="actions"><label className="button button-secondary" htmlFor={`import-${fileName}`}>Importer un CSV</label><input id={`import-${fileName}`} className="visually-hidden" type="file" accept=".csv,text/csv" onChange={(event)=>{void importList(event.target.files?.[0]);event.currentTarget.value=''}}/><button className="button button-secondary" type="button" onClick={()=>setSelected(null)}>Tout afficher</button><button className="button button-secondary" type="button" onClick={exportCsv} disabled={!visible.length}>Exporter CSV</button><PrintCards cards={visible} title={cardTitle}/></div><p className="page-subtitle">Affichées : {visible.length} / {cards.length}{selected !== null ? ' · sélection importée' : ''}</p></section>
    <section className="grid grid-3 card-preview-grid">{visible.map((card)=><article className="id-card-preview" key={card.number}><div className="id-card-brand"><span>AA</span><div><strong>COMPLEXE SCOLAIRE AL AMINE</strong><small>{title.toLocaleUpperCase('fr')}</small></div></div><div className="id-card-body"><small>Nom complet</small><strong>{card.name}</strong><div><span><small>Matricule</small><b>{card.number}</b></span><span><small>Classe / fonction</small><b>{card.detail}</b></span></div></div><footer>{card.status}</footer></article>)}</section>
    {!visible.length?<p className="empty">Aucune carte dans cette sélection.</p>:null}
  </>
}
