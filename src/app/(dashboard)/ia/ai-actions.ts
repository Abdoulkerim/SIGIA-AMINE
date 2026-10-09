
'use server'

import { createClient } from '@/lib/supabase/server'

export async function getAiWorkspace() {
  const supabase = await createClient()
  const { data: claimsData } = await supabase.auth.getClaims()
  const claims = claimsData?.claims
  if (!claims?.sub) throw new Error('Session introuvable.')

  const [{ data: conversations, error: conversationsError }, { data: alerts, error: alertsError }] = await Promise.all([
    supabase.from('ai_conversations').select('id,title,mode,status,updated_at,last_message_at,model').order('updated_at', { ascending: false }).limit(20),
    supabase.from('ai_alerts').select('id,title,description,severity,status,generated_at,recommended_action,evidence').order('generated_at', { ascending: false }).limit(20),
  ])
  if (conversationsError) throw new Error(conversationsError.message)
  if (alertsError) throw new Error(alertsError.message)
  return { conversations: conversations ?? [], alerts: alerts ?? [] }
}

export async function getAiMessages(conversationId: string) {
  const supabase = await createClient()
  const { data, error } = await supabase.from('ai_messages').select('id,role,content,created_at').eq('conversation_id', conversationId).order('created_at', { ascending: true }).limit(100)
  if (error) throw new Error(error.message)
  return data ?? []
}

export async function sendAiMessage(conversationId: string | null, message: string, mode: string = 'assistant') {
  const supabase = await createClient()
  const { data: { session } } = await supabase.auth.getSession()
  if (!session?.access_token) throw new Error('Session introuvable.')
  const baseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL
  if (!baseUrl) throw new Error('NEXT_PUBLIC_SUPABASE_URL est manquante.')

  const response = await fetch(`${baseUrl}/functions/v1/ai-assistant`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${session.access_token}`,
      apikey: process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY ?? '',
      'Content-Type': 'application/json',
    },
    cache: 'no-store',
    body: JSON.stringify({ conversation_id: conversationId, message, mode }),
  })
  const payload = await response.json().catch(() => ({}))
  if (!response.ok) throw new Error(payload.message || payload.error || 'La requête IA a échoué.')
  return payload as { conversation_id: string; message: { id: string; role: 'assistant'; content: string; created_at: string }; run_id: string }
}

export async function reviewAiAlert(id: string, status: 'acknowledged' | 'resolved' | 'dismissed', reviewNote?: string) {
  const supabase = await createClient()
  const { data: claimsData } = await supabase.auth.getClaims()
  const claims = claimsData?.claims
  if (!claims?.sub) throw new Error('Session introuvable.')
  const { error } = await supabase.from('ai_alerts').update({ status, review_note: reviewNote ?? null, reviewed_by: claims.sub, reviewed_at: new Date().toISOString() }).eq('id', id)
  if (error) throw new Error(error.message)
  return { ok: true }
}
