
import { createClient } from '@/lib/supabase/server'

export default async function AiPromptsPage() {
  const supabase = await createClient()
  const { data: prompts, error } = await supabase.from('ai_prompt_templates').select('id,code,name,description,capabilities,is_active,updated_at').eq('is_active', true).order('name')
  if (error) throw new Error(error.message)
  return (
    <main className="page">
      <div className="page-header">
        <div>
          <h1 className="page-title">Prompts gouvernés</h1>
          <p className="page-subtitle">Référentiel des comportements IA autorisés par le SIGIA-AMINE.</p>
        </div>
      </div>
      <div className="grid grid-2">
        {(prompts ?? []).map((p) => <article className="card" key={p.id}>
          <div className="stat-label">{p.code}</div>
          <h2 style={{ margin: '6px 0' }}>{p.name}</h2>
          <p className="page-subtitle">{p.description}</p>
          <div className="badge">{(p.capabilities as string[] | null)?.join(' • ')}</div>
        </article>)}
      </div>
    </main>
  )
}
