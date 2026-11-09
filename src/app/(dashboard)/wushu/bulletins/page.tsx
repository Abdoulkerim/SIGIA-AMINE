import { SpecializedReportCards } from '@/components/pedagogy/specialized-report-cards'

export default async function WushuReportCardsPage({ searchParams }: { searchParams: Promise<{ error?: string; generated?: string; published?: string }> }) {
  return <SpecializedReportCards module="wushu" title="Wushu" backHref="/wushu/evaluations" searchParams={searchParams}/>
}
