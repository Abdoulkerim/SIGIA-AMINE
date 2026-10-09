import type { Metadata } from 'next'
import './globals.css'

export const metadata: Metadata = {
  title: 'SIGIA-AMINE',
  description: 'Système Intelligent de Gestion Intégrée du Complexe Scolaire Al Amine',
}

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="fr">
      <body>{children}</body>
    </html>
  )
}
