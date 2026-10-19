const fs = require('fs')
const file = 'output/pdf/notice_utilisation_sigia_amine.pdf'
const bytes = fs.readFileSync(file)
const pdf = bytes.toString('latin1')
const pageCount = (pdf.match(/\/Type \/Page\b/g) || []).length
const xrefOffset = Number(pdf.match(/startxref\n(\d+)/)?.[1])
const extracted = [...pdf.matchAll(/<([0-9a-f]+)> Tj/g)]
  .map(match => new TextDecoder('windows-1252').decode(Buffer.from(match[1], 'hex')))
  .join('\n')
if (!pdf.startsWith('%PDF-1.4')) throw new Error('PDF header invalid')
if (!pdf.endsWith('%%EOF\n')) throw new Error('PDF trailer missing')
if (pageCount !== 9) throw new Error(`Expected 9 pages, found ${pageCount}`)
if (pdf.slice(xrefOffset, xrefOffset + 4) !== 'xref') throw new Error('xref offset invalid')
for (const phrase of ['Admissions, élèves et familles', 'Gérer les comptes et leurs accès', 'Tarifs, factures et paiements']) {
  if (!extracted.includes(phrase)) throw new Error(`Missing extracted text: ${phrase}`)
}
console.log(JSON.stringify({ file, pageCount, bytes: bytes.length, xrefValid: true, requiredTextValid: true }))
