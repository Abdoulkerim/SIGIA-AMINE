'use client'

type Card = { number: string; name: string; detail: string; status: string }
function esc(value: string) { return value.replace(/[&<>"']/g, (ch) => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[ch] ?? ch)) }

export function PrintCards({ cards, title }: { cards: Card[]; title: string }) {
  function print() {
    const win = window.open('', '_blank', 'width=1000,height=750')
    if (!win) { window.alert('Autorisez les fenêtres contextuelles pour imprimer les cartes.'); return }
    const content = cards.map((card) => `<article class="card"><header><span class="mark">AA</span><span><b>COMPLEXE SCOLAIRE AL AMINE</b><small>${esc(title)}</small></span></header><div class="body"><div><small>Nom complet</small><strong>${esc(card.name)}</strong></div><div class="row"><div><small>Matricule</small><strong>${esc(card.number)}</strong></div><div><small>Fonction / statut</small><strong>${esc(card.detail)} · ${esc(card.status)}</strong></div></div></div><footer>Carte scolaire · SIGIA-AMINE</footer></article>`).join('')
    win.document.write(`<!doctype html><html lang="fr"><head><meta charset="utf-8"><title>${esc(title)}</title><style>*{box-sizing:border-box}body{font:13px Arial,sans-serif;padding:20px;color:#102a43}.sheet{display:grid;grid-template-columns:1fr 1fr;gap:14px}.card{height:190px;border:1px solid #cbd5e1;border-radius:12px;overflow:hidden;background:linear-gradient(135deg,#fff 65%,#eff6ff)}header{height:56px;display:flex;align-items:center;gap:10px;padding:10px 14px;background:#12335b;color:white}.mark{display:grid;place-items:center;width:34px;height:34px;border-radius:8px;background:#f5c842;color:#12335b;font-weight:bold}header b,header small,.body small,.body strong{display:block}header small{margin-top:4px;color:#dbeafe;font-size:10px}.body{padding:14px}.body small{color:#64748b;font-size:9px;text-transform:uppercase;letter-spacing:.06em}.body strong{margin-top:4px;font-size:14px}.row{display:grid;grid-template-columns:1fr 1.5fr;gap:12px;margin-top:14px}footer{padding:7px 14px;border-top:1px solid #e2e8f0;color:#64748b;font-size:9px}@media print{body{padding:0}.sheet{gap:8px}.card{break-inside:avoid}}</style></head><body><h1>${esc(title)} · ${cards.length} carte(s)</h1><div class="sheet">${content}</div><script>window.addEventListener('load',()=>{window.focus();window.print()})<\/script></body></html>`)
    win.document.close()
  }
  return <button className="button button-primary" type="button" onClick={print} disabled={!cards.length}>Imprimer les cartes</button>
}
