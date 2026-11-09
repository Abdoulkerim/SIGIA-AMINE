import { SpecializedReportCards } from '@/components/pedagogy/specialized-report-cards'

export default async function TahfizReportCardsPage({ searchParams }: { searchParams: Promise<{ error?: string; generated?: string; published?: string }> }) {
  return <SpecializedReportCards module="tahfiz" title="Tahfiz" backHref="/tahfiz-arabe/tahfiz" searchParams={searchParams}/>
}
