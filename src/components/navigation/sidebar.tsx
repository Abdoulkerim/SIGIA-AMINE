'use client'

import Link from 'next/link'
import { usePathname } from 'next/navigation'
import {
  Activity,
  Archive,
  ArrowLeftRight,
  BarChart3,
  BookOpen,
  Boxes,
  Building2,
  CalendarDays,
  ChevronDown,
  Circle,
  ClipboardCheck,
  ClipboardList,
  Contact,
  FileText,
  GraduationCap,
  House,
  KeyRound,
  LayoutDashboard,
  Megaphone,
  Package,
  Receipt,
  School,
  Settings,
  ScrollText,
  ServerCog,
  ShieldCheck,
  ShoppingCart,
  Sparkles,
  Users,
  UsersRound,
  Utensils,
  Wallet,
  Warehouse,
  type LucideIcon,
} from 'lucide-react'

type NavItem = { label: string; href: string; icon: LucideIcon }
type NavGroup = { label: string; icon: LucideIcon; items: NavItem[] }

const groups: NavGroup[] = [
  {
    label: 'Administration',
    icon: School,
    items: [
      { label: 'Vue générale', href: '/administration', icon: Building2 },
      { label: 'Élèves', href: '/administration/eleves', icon: Users },
      { label: 'Parents et tuteurs', href: '/administration/parents', icon: Contact },
      { label: 'Admissions', href: '/administration/admissions', icon: ClipboardCheck },
      { label: 'Inscriptions', href: '/administration/inscriptions', icon: ClipboardList },
      { label: 'Niveaux', href: '/administration/niveaux', icon: GraduationCap },
      { label: 'Classes', href: '/administration/classes', icon: School },
    ],
  },
  {
    label: 'Pédagogie',
    icon: BookOpen,
    items: [
      { label: 'Vue générale', href: '/pedagogie', icon: BookOpen },
      { label: 'Matières', href: '/pedagogie/matieres', icon: ClipboardList },
      { label: 'Affectations', href: '/pedagogie/affectations', icon: Users },
      { label: 'Emploi du temps', href: '/pedagogie/emploi-du-temps', icon: CalendarDays },
      { label: 'Types d’évaluations', href: '/pedagogie/types-evaluations', icon: ClipboardCheck },
      { label: 'Évaluations', href: '/pedagogie/evaluations', icon: ClipboardCheck },
      { label: 'Bulletins', href: '/pedagogie/bulletins', icon: FileText },
    ],
  },
  {
    label: 'Vie scolaire',
    icon: ShieldCheck,
    items: [
      { label: 'Vue générale', href: '/vie-scolaire', icon: Activity },
      { label: 'Présences et appels', href: '/vie-scolaire/presences', icon: CalendarDays },
      { label: 'Justificatifs', href: '/vie-scolaire/justificatifs', icon: FileText },
      { label: 'Discipline', href: '/vie-scolaire/discipline', icon: ShieldCheck },
      { label: 'Suivi éducatif', href: '/vie-scolaire/suivi-educatif', icon: Users },
      { label: 'Récompenses', href: '/vie-scolaire/recompenses', icon: ClipboardCheck },
    ],
  },
  {
    label: 'Finance',
    icon: Wallet,
    items: [
      { label: 'Vue générale', href: '/finance', icon: BarChart3 },
      { label: 'Tarifs', href: '/finance/tarifs', icon: Receipt },
      { label: 'Factures', href: '/finance/factures', icon: FileText },
      { label: 'Paiements', href: '/finance/paiements', icon: Wallet },
      { label: 'Dépenses', href: '/finance/depenses', icon: Receipt },
      { label: 'Caisse', href: '/finance/caisse', icon: Building2 },
      { label: 'Impayés', href: '/finance/impayes', icon: ClipboardList },
    ],
  },
  {
    label: 'Personnel et RH',
    icon: Contact,
    items: [
      { label: 'Vue générale', href: '/personnel', icon: Users },
      { label: 'Employés', href: '/personnel/employes', icon: Contact },
      { label: 'Enseignants', href: '/personnel/enseignants', icon: GraduationCap },
      { label: 'Contrats', href: '/personnel/contrats', icon: FileText },
      { label: 'Présences', href: '/personnel/presences', icon: CalendarDays },
      { label: 'Congés', href: '/personnel/conges', icon: ClipboardCheck },
      { label: 'Formations', href: '/personnel/formations', icon: BookOpen },
      { label: 'Paie', href: '/personnel/paie', icon: Wallet },
    ],
  },
  {
    label: 'Internat',
    icon: House,
    items: [
      { label: 'Vue générale', href: '/internat', icon: House },
      { label: 'Structures', href: '/internat/structures', icon: Building2 },
      { label: 'Affectations', href: '/internat/affectations', icon: Users },
      { label: 'Sorties et retours', href: '/internat/mouvements', icon: ArrowLeftRight },
      { label: 'Présences', href: '/internat/presences', icon: CalendarDays },
    ],
  },
  {
    label: 'Restauration',
    icon: Utensils,
    items: [
      { label: 'Vue générale', href: '/restauration', icon: Utensils },
      { label: 'Types de repas', href: '/restauration/types', icon: ClipboardList },
      { label: 'Menus', href: '/restauration/menus', icon: BookOpen },
      { label: 'Services', href: '/restauration/services', icon: CalendarDays },
      { label: 'Présences repas', href: '/restauration/presences', icon: ClipboardCheck },
      { label: 'Consommations', href: '/restauration/consommations', icon: Boxes },
    ],
  },
  {
    label: 'Stocks et achats',
    icon: Warehouse,
    items: [
      { label: 'Vue générale', href: '/stocks', icon: Warehouse },
      { label: 'Produits', href: '/stocks/produits', icon: Package },
      { label: 'Mouvements', href: '/stocks/mouvements', icon: ArrowLeftRight },
      { label: 'Inventaires', href: '/stocks/inventaires', icon: ClipboardCheck },
      { label: 'Demandes', href: '/stocks/demandes', icon: ClipboardList },
      { label: 'Commandes', href: '/stocks/commandes', icon: ShoppingCart },
      { label: 'Réceptions', href: '/stocks/receptions', icon: Boxes },
      { label: 'Fournisseurs', href: '/stocks/fournisseurs', icon: Contact },
      { label: 'Factures fournisseurs', href: '/stocks/factures', icon: Receipt },
      { label: 'Transferts', href: '/stocks/transferts', icon: ArrowLeftRight },
    ],
  },
  {
    label: 'Activités et AGR',
    icon: Activity,
    items: [
      { label: 'Vue générale', href: '/activites', icon: BarChart3 },
      { label: 'AGR', href: '/activites/agr', icon: Activity },
      { label: 'Agriculture', href: '/activites/agriculture', icon: House },
      { label: 'Élevage', href: '/activites/elevage', icon: Boxes },
    ],
  },
  {
    label: 'Tahfiz et arabe',
    icon: BookOpen,
    items: [
      { label: 'Vue générale', href: '/tahfiz-arabe', icon: BookOpen },
      { label: 'Tahfiz', href: '/tahfiz-arabe/tahfiz', icon: BookOpen },
      { label: 'Arabe', href: '/tahfiz-arabe/arabe', icon: GraduationCap },
    ],
  },
  {
    label: 'Wushu',
    icon: Activity,
    items: [
      { label: 'Vue générale', href: '/wushu', icon: Activity },
      { label: 'Groupes', href: '/wushu/groupes', icon: Users },
      { label: 'Élèves', href: '/wushu/eleves', icon: GraduationCap },
      { label: 'Entraînements', href: '/wushu/entrainements', icon: CalendarDays },
      { label: 'Présences', href: '/wushu/presences', icon: ClipboardCheck },
      { label: 'Évaluations', href: '/wushu/evaluations', icon: ClipboardList },
      { label: 'Compétitions', href: '/wushu/competitions', icon: Activity },
    ],
  },
  {
    label: 'Communication',
    icon: Megaphone,
    items: [
      { label: 'Vue générale', href: '/communication', icon: Megaphone },
      { label: 'Annonces', href: '/communication/annonces', icon: FileText },
      { label: 'Notifications', href: '/communication/notifications', icon: ClipboardCheck },
    ],
  },
  {
    label: 'Documents',
    icon: FileText,
    items: [
      { label: 'Vue générale', href: '/documents', icon: FileText },
      { label: 'Demandes', href: '/documents/demandes', icon: ClipboardList },
      { label: 'Types', href: '/documents/types', icon: ClipboardCheck },
      { label: 'Archives', href: '/documents/archives', icon: Archive },
    ],
  },
  {
    label: 'Statistiques',
    icon: BarChart3,
    items: [
      { label: 'Vue générale', href: '/statistiques', icon: BarChart3 },
      { label: 'Direction', href: '/statistiques/direction', icon: Building2 },
      { label: 'Pédagogie', href: '/statistiques/pedagogie', icon: BookOpen },
      { label: 'Finance', href: '/statistiques/finance', icon: Wallet },
      { label: 'Internat', href: '/statistiques/internat', icon: House },
      { label: 'Activités', href: '/statistiques/activites', icon: Activity },
    ],
  },
  {
    label: 'Intelligence artificielle',
    icon: Sparkles,
    items: [
      { label: 'Vue générale', href: '/ia', icon: Sparkles },
      { label: 'Alertes', href: '/ia/alertes', icon: ShieldCheck },
      { label: 'Prompts', href: '/ia/prompts', icon: ClipboardList },
    ],
  },
  {
    label: 'Administration technique',
    icon: Settings,
    items: [
      { label: 'Outils IT', href: '/administration-it', icon: Settings },
      { label: 'Utilisateurs', href: '/administration-it/utilisateurs', icon: UsersRound },
      { label: 'Accès utilisateurs', href: '/administration-it/acces', icon: ShieldCheck },
      { label: 'Rôles et permissions', href: '/administration-it/roles', icon: KeyRound },
      { label: 'Journal d’audit', href: '/administration-it/audit', icon: ScrollText },
      { label: 'Paramètres établissement', href: '/administration-it/parametres', icon: Settings },
      { label: 'État du système', href: '/administration-it/systeme', icon: ServerCog },
    ],
  },
]

function isCurrentPath(pathname: string, href: string) {
  return pathname === href || pathname.startsWith(`${href}/`)
}

export function Sidebar({ canAccessIT }: { canAccessIT: boolean }) {
  const pathname = usePathname()
  const visibleGroups = canAccessIT ? groups : groups.filter((group) => group.label !== 'Administration technique')

  return (
    <aside className="sidebar">
      <div className="sidebar-brand">
        <span className="sidebar-brand-mark" aria-hidden="true"><School size={19} /></span>
        <div>
          <div className="sidebar-title">SIGIA-AMINE</div>
          <div className="sidebar-subtitle">Gestion intégrée · Al Amine</div>
        </div>
      </div>
      <nav className="nav" aria-label="Navigation principale">
        <Link
          className="nav-home"
          href="/dashboard"
          aria-current={isCurrentPath(pathname, '/dashboard') ? 'page' : undefined}
        >
          <LayoutDashboard size={17} aria-hidden="true" />
          <span>Tableau de bord</span>
        </Link>

        <div className="nav-groups">
          {visibleGroups.map((group) => {
            const GroupIcon = group.icon
            const sectionIsActive = group.items.some((item) => isCurrentPath(pathname, item.href))

            return (
              <details className="nav-section" key={group.label} open={sectionIsActive}>
                <summary className="nav-section-trigger">
                  <GroupIcon size={17} aria-hidden="true" />
                  <span>{group.label}</span>
                  <ChevronDown className="nav-chevron" size={14} aria-hidden="true" />
                </summary>
                <div className="nav-submenu">
                  {group.items.map((item) => {
                    const ItemIcon = item.icon
                    const itemIsActive = isCurrentPath(pathname, item.href)
                    return (
                      <Link
                        className="nav-link"
                        href={item.href}
                        key={item.href}
                        aria-current={itemIsActive ? 'page' : undefined}
                      >
                        <ItemIcon size={15} aria-hidden="true" />
                        <span>{item.label}</span>
                      </Link>
                    )
                  })}
                </div>
              </details>
            )
          })}
        </div>
      </nav>
    </aside>
  )
}
