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
      { label: 'Créer un compte', href: '/administration-it/utilisateurs/nouveau', icon: UsersRound },
      { label: 'Cartes scolaires', href: '/administration-it/cartes', icon: Contact },
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

const routePermissions: Array<{ prefix: string; anyOf: string[] }> = [
  { prefix: '/administration/eleves', anyOf: ['students.view', 'students.manage'] },
  { prefix: '/administration/parents', anyOf: ['parents.view', 'parents.manage'] },
  { prefix: '/administration/admissions', anyOf: ['enrollments.manage', 'enrollments.view', 'admissions.manage', 'admissions.view'] },
  { prefix: '/administration/inscriptions', anyOf: ['enrollments.manage', 'enrollments.view', 'admissions.manage', 'admissions.view'] },
  { prefix: '/administration/niveaux', anyOf: ['classes.manage', 'classes.view', 'levels.manage', 'levels.view'] },
  { prefix: '/administration/classes', anyOf: ['classes.manage', 'classes.view'] },
  { prefix: '/administration', anyOf: ['students.view', 'students.manage', 'parents.view', 'parents.manage', 'enrollments.manage', 'enrollments.view', 'admissions.manage', 'admissions.view', 'classes.manage', 'classes.view'] },
  { prefix: '/pedagogie/matieres', anyOf: ['subjects.manage', 'subjects.view'] },
  { prefix: '/pedagogie/affectations', anyOf: ['teachers.manage', 'teachers.view'] },
  { prefix: '/pedagogie/emploi-du-temps', anyOf: ['timetable.manage', 'timetable.view'] },
  { prefix: '/pedagogie/types-evaluations', anyOf: ['assessments.manage', 'assessments.view'] },
  { prefix: '/pedagogie/evaluations', anyOf: ['assessments.manage', 'assessments.view', 'grades.enter', 'grades.view', 'grades.publish'] },
  { prefix: '/pedagogie/bulletins', anyOf: ['report_cards.generate', 'report_cards.view', 'report_cards.publish', 'grades.view', 'grades.publish'] },
  { prefix: '/pedagogie', anyOf: ['subjects.manage', 'subjects.view', 'teachers.manage', 'teachers.view', 'timetable.manage', 'timetable.view', 'assessments.manage', 'assessments.view', 'grades.enter', 'grades.view', 'grades.publish', 'report_cards.generate', 'report_cards.view'] },
  { prefix: '/vie-scolaire/presences', anyOf: ['attendance.manage', 'attendance.view'] },
  { prefix: '/vie-scolaire/justificatifs', anyOf: ['attendance.manage', 'attendance.view', 'absence_justifications.review', 'absence_justifications.view'] },
  { prefix: '/vie-scolaire/discipline', anyOf: ['discipline.manage', 'discipline.view'] },
  { prefix: '/vie-scolaire/suivi-educatif', anyOf: ['discipline.manage', 'discipline.view', 'followups.manage', 'followups.view'] },
  { prefix: '/vie-scolaire/recompenses', anyOf: ['discipline.manage', 'rewards.manage', 'rewards.view'] },
  { prefix: '/vie-scolaire', anyOf: ['attendance.manage', 'attendance.view', 'absence_justifications.view', 'discipline.manage', 'discipline.view', 'followups.view', 'rewards.view'] },
  { prefix: '/finance/tarifs', anyOf: ['finance.manage'] },
  { prefix: '/finance/factures', anyOf: ['finance.view', 'finance.manage'] },
  { prefix: '/finance/paiements', anyOf: ['finance.view', 'finance.manage'] },
  { prefix: '/finance/depenses', anyOf: ['expenses.manage'] },
  { prefix: '/finance/caisse', anyOf: ['cash.manage'] },
  { prefix: '/finance/impayes', anyOf: ['finance.view', 'finance.manage'] },
  { prefix: '/finance', anyOf: ['finance.view', 'finance.manage', 'expenses.manage', 'cash.manage'] },
  { prefix: '/personnel/enseignants', anyOf: ['teachers.manage', 'teachers.view'] },
  { prefix: '/personnel/conges', anyOf: ['hr.manage', 'hr.view'] },
  { prefix: '/personnel/formations', anyOf: ['hr.manage', 'hr.view'] },
  { prefix: '/personnel/paie', anyOf: ['payroll.manage', 'payroll.view'] },
  { prefix: '/personnel', anyOf: ['hr.manage', 'hr.view', 'teachers.manage', 'teachers.view'] },
  { prefix: '/internat', anyOf: ['boarding.manage', 'boarding.view'] },
  { prefix: '/restauration', anyOf: ['catering.manage', 'catering.view'] },
  { prefix: '/stocks/demandes', anyOf: ['purchases.manage'] },
  { prefix: '/stocks/commandes', anyOf: ['purchases.manage'] },
  { prefix: '/stocks/receptions', anyOf: ['purchases.manage', 'purchases.view', 'stock.manage', 'stock.view'] },
  { prefix: '/stocks/fournisseurs', anyOf: ['purchases.manage', 'purchases.view'] },
  { prefix: '/stocks/factures', anyOf: ['purchases.manage', 'purchases.view'] },
  { prefix: '/stocks', anyOf: ['stock.manage', 'stock.view', 'inventory.manage', 'purchases.manage', 'purchases.view'] },
  { prefix: '/activites/agriculture', anyOf: ['agriculture.manage', 'agriculture.view'] },
  { prefix: '/activites/elevage', anyOf: ['livestock.manage', 'livestock.view'] },
  { prefix: '/activites', anyOf: ['agriculture.manage', 'agriculture.view', 'livestock.manage', 'livestock.view'] },
  { prefix: '/tahfiz-arabe/tahfiz', anyOf: ['tahfiz.manage', 'tahfiz.view'] },
  { prefix: '/tahfiz-arabe/arabe', anyOf: ['arabic.manage', 'arabic.view'] },
  { prefix: '/tahfiz-arabe', anyOf: ['tahfiz.manage', 'tahfiz.view', 'arabic.manage', 'arabic.view'] },
  { prefix: '/wushu', anyOf: ['wushu.manage', 'wushu.view', 'wushu.publish'] },
  { prefix: '/communication/notifications', anyOf: [] },
  { prefix: '/communication', anyOf: ['communication.manage'] },
  { prefix: '/documents', anyOf: ['documents.view', 'documents.manage'] },
  { prefix: '/statistiques/direction', anyOf: ['dashboard.direction', 'reports.view'] },
  { prefix: '/statistiques/pedagogie', anyOf: ['dashboard.pedagogy', 'reports.view'] },
  { prefix: '/statistiques/finance', anyOf: ['dashboard.finance', 'finance.reports', 'reports.view'] },
  { prefix: '/statistiques/internat', anyOf: ['dashboard.boarding', 'boarding.view', 'reports.view'] },
  { prefix: '/statistiques/activites', anyOf: ['dashboard.activities', 'agriculture.view', 'livestock.view', 'reports.view'] },
  { prefix: '/statistiques', anyOf: ['reports.view', 'dashboard.direction', 'dashboard.pedagogy', 'dashboard.finance', 'dashboard.boarding', 'dashboard.activities'] },
  { prefix: '/ia/alertes', anyOf: ['ai.alerts.review', 'ai.manage', 'ai.use'] },
  { prefix: '/ia/prompts', anyOf: ['ai.manage'] },
  { prefix: '/ia', anyOf: ['ai.use', 'ai.manage'] },
  { prefix: '/administration-it/audit', anyOf: ['audit.view'] },
  { prefix: '/administration-it/parametres', anyOf: ['settings.manage'] },
  { prefix: '/administration-it/roles', anyOf: ['users.roles.manage'] },
  { prefix: '/administration-it/acces', anyOf: ['users.roles.manage'] },
  { prefix: '/administration-it/cartes', anyOf: ['students.view', 'hr.manage'] },
  { prefix: '/administration-it/systeme', anyOf: ['settings.manage', 'audit.view'] },
  { prefix: '/administration-it', anyOf: ['users.manage', 'users.roles.manage', 'audit.view', 'settings.manage'] },
]

function itemIsAllowed(href: string, permissionCodes: Set<string>, canAccessIT: boolean) {
  if (href.startsWith('/administration-it/utilisateurs')) return canAccessIT
  if (href.startsWith('/administration-it') && !canAccessIT) return false
  const rule = routePermissions.find(({ prefix }) => href === prefix || href.startsWith(`${prefix}/`))
  if (!rule) return false
  if (href === '/communication/notifications') return true
  return rule.anyOf.some((code) => permissionCodes.has(code))
}

export function Sidebar({ canAccessIT, permissionCodes }: { canAccessIT: boolean; permissionCodes: string[] }) {
  const pathname = usePathname()
  const permissionSet = new Set(permissionCodes)
  const visibleGroups = groups.map((group) => ({
    ...group,
    items: group.items.map((item) => ({
      ...item,
      allowed: itemIsAllowed(item.href, permissionSet, canAccessIT),
    })),
  }))

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
            const sectionIsActive = group.items.some((item) => item.allowed && isCurrentPath(pathname, item.href))

            const sectionAllowed = group.items.some((item) => item.allowed)

            return (
              <details className={`nav-section${sectionAllowed ? '' : ' nav-section-disabled'}`} key={group.label} open={sectionIsActive}>
                <summary className="nav-section-trigger" aria-disabled={!sectionAllowed}>
                  <GroupIcon size={17} aria-hidden="true" />
                  <span>{group.label}</span>
                  <ChevronDown className="nav-chevron" size={14} aria-hidden="true" />
                </summary>
                <div className="nav-submenu">
                  {group.items.map((item) => {
                    const ItemIcon = item.icon
                    const itemIsActive = isCurrentPath(pathname, item.href)
                    return item.allowed ? (
                      <Link className="nav-link" href={item.href} key={item.href} aria-current={itemIsActive ? 'page' : undefined}>
                        <ItemIcon size={15} aria-hidden="true" /><span>{item.label}</span>
                      </Link>
                    ) : (
                      <span className="nav-link nav-link-disabled" key={item.href} aria-disabled="true" title="Vous n’avez pas accès à cette page">
                        <ItemIcon size={15} aria-hidden="true" /><span>{item.label}</span>
                      </span>
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
