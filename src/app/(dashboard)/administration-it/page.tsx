import Link from 'next/link'
import { Activity, KeyRound, ScrollText, Settings2, ShieldCheck, UsersRound } from 'lucide-react'
import { createClient } from '@/lib/supabase/server'
import { getCurrentUserContext } from '@/lib/auth/current-user'

const tools = [
  { title: 'Utilisateurs', description: 'Consulter les comptes et leurs rôles actifs.', href: '/administration-it/utilisateurs', icon: UsersRound, color: '#2563eb' },
  { title: 'Créer un compte', description: 'Créer un identifiant, choisir son cycle et son rôle.', href: '/administration-it/utilisateurs/nouveau', icon: UsersRound, color: '#0891b2' },
  { title: 'Cartes scolaires', description: 'Générer, exporter et imprimer les cartes des élèves et employés.', href: '/administration-it/cartes', icon: KeyRound, color: '#0f766e' },
  { title: 'Accès utilisateurs', description: 'Attribuer les privilèges, gérer les connexions et voir les pages accessibles.', href: '/administration-it/acces', icon: ShieldCheck, color: '#b45309' },
  { title: 'Rôles et permissions', description: 'Vérifier les rôles et leurs autorisations.', href: '/administration-it/roles', icon: KeyRound, color: '#7c3aed' },
  { title: 'Journal d’audit', description: 'Suivre les opérations enregistrées par le système.', href: '/administration-it/audit', icon: ScrollText, color: '#c2410c' },
  { title: 'Paramètres établissement', description: 'Consulter les informations et réglages de l’école.', href: '/administration-it/parametres', icon: Settings2, color: '#0f766e' },
  { title: 'État du système', description: 'Vérifier la configuration des services applicatifs.', href: '/administration-it/systeme', icon: Activity, color: '#15803d' },
]

export default async function ITAdministrationPage() {
  const context = await getCurrentUserContext()
  const canManageAccounts = context?.roles.some(({ code }) => code === 'it_admin') ?? false
  const schoolId = context?.profile.school_id
  const supabase = await createClient()
  let usersQuery = supabase.from('users').select('id', { count: 'exact', head: true })
  let auditQuery = supabase.from('audit_logs').select('id', { count: 'exact', head: true })
  if (schoolId) {
    usersQuery = usersQuery.eq('school_id', schoolId)
    auditQuery = auditQuery.eq('school_id', schoolId)
  }
  const [users, roles, audit] = await Promise.all([
    usersQuery,
    supabase.from('roles').select('id', { count: 'exact', head: true }),
    auditQuery,
  ])
  const visibleTools = tools.filter(({ href }) =>
    canManageAccounts || !['/administration-it/utilisateurs', '/administration-it/utilisateurs/nouveau', '/administration-it/acces'].includes(href),
  )

  return (
    <main className="page">
      <div className="page-header">
        <div>
          <h1 className="page-title">Administration technique</h1>
          <p className="page-subtitle">Comptes, contrôle d’accès, sécurité et suivi technique de SIGIA-AMINE.</p>
        </div>
        <span className="badge">Accès informatique</span>
      </div>

      <section className="grid grid-3" style={{ marginBottom: 22 }}>
        <article className="card"><div className="stat-label">Comptes de l’établissement</div><div className="stat-value">{users.count ?? '—'}</div></article>
        <article className="card"><div className="stat-label">Rôles configurés</div><div className="stat-value">{roles.count ?? '—'}</div></article>
        <article className="card"><div className="stat-label">Événements d’audit</div><div className="stat-value">{audit.count ?? '—'}</div></article>
      </section>

      <section aria-labelledby="it-tools-heading">
        <div className="page-header">
          <div>
            <h2 className="page-title" id="it-tools-heading" style={{ fontSize: 21 }}>Outils IT</h2>
            <p className="page-subtitle">Sélectionnez un outil pour consulter les informations techniques.</p>
          </div>
        </div>
        <div className="grid grid-2">
          {visibleTools.map(({ title, description, href, icon: Icon, color }) => (
            <Link className="card it-tool-card" href={href} key={href}>
              <span className="it-tool-icon" style={{ color, background: `${color}14` }}><Icon size={22} aria-hidden="true" /></span>
              <span className="it-tool-copy"><strong>{title}</strong><span>{description}</span></span>
              <span className="it-tool-arrow" aria-hidden="true">→</span>
            </Link>
          ))}
        </div>
      </section>
    </main>
  )
}
