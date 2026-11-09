import { SpecializedReportCards } from '@/components/pedagogy/specialized-report-cards'

export default async function ArabicReportCardsPage({ searchParams }: { searchParams: Promise<{ error?: string; generated?: string; published?: string }> }) {
  return <SpecializedReportCards module="arabic" title="Arabe" backHref="/tahfiz-arabe/arabe" searchParams={searchParams}/>
}
