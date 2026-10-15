import { redirect } from 'next/navigation'
import { getCurrentUserContext } from '@/lib/auth/current-user'

export default async function ITAdministrationLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  const context = await getCurrentUserContext()
  const canAccess = context?.roles.some(({ code }) => ['it_admin', 'super_admin', 'founder'].includes(code ?? ''))

  if (!canAccess) redirect('/dashboard')

  return children
}
