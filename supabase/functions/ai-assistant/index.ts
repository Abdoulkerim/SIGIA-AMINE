import { createSupabaseContext } from "@supabase/server"

const OPENAI_URL = "https://api.openai.com/v1/responses"
const MAX_TOOL_ROUNDS = 4
const DEFAULT_MODEL = "gpt-5.6-luna"

type ToolCall = {
  type: "function_call"
  id?: string
  call_id: string
  name: string
  arguments?: string
}

type ResponseLike = {
  output?: Array<Record<string, unknown>>
  output_text?: string
  usage?: { input_tokens?: number; output_tokens?: number }
}

const toolDefinitions = [
  {
    type: "function",
    name: "get_direction_dashboard",
    description: "Lire le tableau de bord directionnel lorsque l'utilisateur est autorisé à le consulter.",
    parameters: { type: "object", properties: {}, additionalProperties: false },
  },
  {
    type: "function",
    name: "get_pedagogy_dashboard",
    description: "Lire le tableau de bord pédagogique lorsque l'utilisateur est autorisé à le consulter.",
    parameters: { type: "object", properties: {}, additionalProperties: false },
  },
  {
    type: "function",
    name: "get_finance_dashboard",
    description: "Lire le tableau de bord financier lorsque l'utilisateur est autorisé à le consulter.",
    parameters: { type: "object", properties: {}, additionalProperties: false },
  },
  {
    type: "function",
    name: "get_boarding_dashboard",
    description: "Lire le tableau de bord internat lorsque l'utilisateur est autorisé à le consulter.",
    parameters: { type: "object", properties: {}, additionalProperties: false },
  },
  {
    type: "function",
    name: "get_activities_dashboard",
    description: "Lire le tableau de bord agriculture/élevage/AGR lorsque l'utilisateur est autorisé à le consulter.",
    parameters: { type: "object", properties: {}, additionalProperties: false },
  },
  {
    type: "function",
    name: "search_students",
    description: "Rechercher des élèves accessibles à l'utilisateur, par nom ou numéro.",
    parameters: {
      type: "object",
      properties: {
        query: { type: "string" },
        limit: { type: "integer", minimum: 1, maximum: 20 },
      },
      required: ["query"],
      additionalProperties: false,
    },
  },
  {
    type: "function",
    name: "get_student_summary",
    description: "Lire le résumé sécurisé d'un élève accessible à l'utilisateur.",
    parameters: {
      type: "object",
      properties: { student_id: { type: "string" } },
      required: ["student_id"],
      additionalProperties: false,
    },
  },
  {
    type: "function",
    name: "create_ai_alert",
    description: "Créer un signal IA en statut open avec des éléments factuels. Cette action n'écrit jamais dans les données métier.",
    parameters: {
      type: "object",
      properties: {
        title: { type: "string" },
        description: { type: "string" },
        severity: { type: "integer", minimum: 1, maximum: 5 },
        alert_type: { type: "string" },
        related_table: { type: "string" },
        related_id: { type: "string" },
        evidence: { type: "object" },
        recommended_action: { type: "string" },
      },
      required: ["title", "description", "severity", "alert_type", "evidence"],
      additionalProperties: false,
    },
  },
]

function buildSystemPrompt(mode: string) {
  const base = `Tu es l'assistant IA du SIGIA-AMINE du Complexe Scolaire Al Amine.\n\nRègles obligatoires:\n- Répondre en français clair et professionnel.\n- Utiliser uniquement les données retournées par les outils et les informations générales explicitement fournies par l'utilisateur.\n- Ne jamais inventer un chiffre, un élève, une note, un paiement, une règle officielle ou un résultat.\n- Si une donnée n'est pas disponible ou si l'accès est refusé, le dire clairement.\n- Les analyses et alertes sont des aides à la décision. Elles ne remplacent jamais la validation humaine.\n- Ne jamais modifier une donnée métier : élèves, notes, paiements, caisse, stock, personnel, présences, internat, etc.\n- Pour une question nécessitant des chiffres du SIGIA-AMINE, appeler un outil de lecture plutôt que deviner.\n- Pour une alerte, rester factuel : signal observé, données de preuve, action de vérification proposée.`
  const modes: Record<string, string> = {
    assistant: "Mode général : répondre et guider l'utilisateur dans l'utilisation du SIGIA-AMINE.",
    analyze: "Mode analyse : produire des constats factuels, puis une interprétation prudente et des points à vérifier.",
    compare: "Mode comparaison : comparer uniquement des indicateurs observés et expliciter la période et le périmètre.",
    report: "Mode rapport : produire un texte structuré réutilisable dans un rapport administratif.",
    alerts: "Mode alertes : repérer uniquement des signaux mesurables et créer, si demandé, des alertes en attente de validation.",
  }
  return `${base}\n- ${modes[mode] ?? modes.assistant}`
}

async function openAi(body: Record<string, unknown>, apiKey: string): Promise<ResponseLike> {
  const response = await fetch(OPENAI_URL, {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${apiKey}` },
    body: JSON.stringify(body),
  })
  const text = await response.text()
  let parsed: ResponseLike & { error?: { message?: string } }
  try {
    parsed = JSON.parse(text)
  } catch {
    throw new Error(`OPENAI_INVALID_JSON:${response.status}`)
  }
  if (!response.ok) throw new Error(`OPENAI_${response.status}:${parsed.error?.message ?? "Erreur fournisseur IA"}`)
  return parsed
}

function toolCallsFromResponse(response: ResponseLike): ToolCall[] {
  return (response.output ?? []).filter((x) => x.type === "function_call") as unknown as ToolCall[]
}

function textFromResponse(response: ResponseLike): string {
  if (typeof response.output_text === "string" && response.output_text.trim()) return response.output_text.trim()
  for (const item of response.output ?? []) {
    if (item.type === "message") {
      const content = Array.isArray(item.content) ? item.content : []
      const parts = content
        .filter((c) => c && typeof c === "object" && (c as Record<string, unknown>).type === "output_text")
        .map((c) => String((c as Record<string, unknown>).text ?? ""))
        .filter(Boolean)
      if (parts.length) return parts.join("\n").trim()
    }
  }
  return ""
}

function safeArgs(raw?: string) {
  if (!raw) return {}
  try { return JSON.parse(raw) } catch { return {} }
}

async function callTool(supabase: ReturnType<typeof createSupabaseContext> extends Promise<infer T> ? T extends { data: infer C } ? C extends { supabase: infer S } ? S : never : never : never, schoolId: string, name: string, args: Record<string, unknown>) {
  switch (name) {
    case "get_direction_dashboard":
      return await supabase.rpc("get_dashboard_direction", { p_school_id: schoolId })
    case "get_pedagogy_dashboard":
      return await supabase.rpc("get_dashboard_pedagogy", { p_school_id: schoolId })
    case "get_finance_dashboard":
      return await supabase.rpc("get_finance_dashboard", { p_school_id: schoolId })
    case "get_boarding_dashboard":
      return await supabase.rpc("get_dashboard_boarding", { p_school_id: schoolId })
    case "get_activities_dashboard":
      return await supabase.rpc("get_dashboard_activities", { p_school_id: schoolId })
    case "search_students":
      return await supabase.rpc("ai_tool_search_students", { p_query: String(args.query ?? ""), p_limit: Number(args.limit ?? 8) })
    case "get_student_summary":
      return await supabase.rpc("ai_tool_student_summary", { p_student_id: String(args.student_id ?? "") })
    default:
      return { data: null, error: new Error(`OUTCOME_TOOL_DENIED:${name}`) }
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type" } })

  const { data: ctx, error: authError } = await createSupabaseContext(req, { auth: "user" })
  if (authError || !ctx?.userClaims?.sub) return Response.json({ error: "UNAUTHORIZED" }, { status: 401 })

  const userId = String(ctx.userClaims.sub)
  const supabase = ctx.supabase
  const { data: profile, error: profileError } = await supabase.from("users").select("id,school_id,first_name,last_name").eq("id", userId).single()
  if (profileError || !profile?.school_id) return Response.json({ error: "USER_PROFILE_NOT_FOUND" }, { status: 403 })

  const body = await req.json().catch(() => ({})) as { conversation_id?: string; message?: string; mode?: string }
  const userMessage = String(body.message ?? "").trim()
  if (!userMessage) return Response.json({ error: "MESSAGE_REQUIRED" }, { status: 400 })

  let conversationId = body.conversation_id
  if (conversationId) {
    const { data: conversation, error } = await supabase.from("ai_conversations").select("id,user_id,school_id,title,mode,status").eq("id",conversationId).single()
    if (error || !conversation || (conversation.user_id !== userId && conversation.school_id !== profile.school_id)) return Response.json({ error: "CONVERSATION_FORBIDDEN" }, { status: 403 })
  } else {
    const title = userMessage.slice(0, 80)
    const { data: created, error } = await supabase.from("ai_conversations").insert({ school_id: profile.school_id, user_id: userId, title, mode: body.mode ?? "assistant" }).select("id").single()
    if (error || !created) return Response.json({ error: error?.message ?? "CONVERSATION_CREATE_FAILED" }, { status: 400 })
    conversationId = created.id
  }

  const { error: insertUserError } = await supabase.from("ai_messages").insert({ conversation_id: conversationId, role: "user", content: userMessage, metadata: { source: "web" } })
  if (insertUserError) return Response.json({ error: insertUserError.message }, { status: 400 })

  const model = Deno.env.get("AI_MODEL") || DEFAULT_MODEL
  const apiKey = Deno.env.get("OPENAI_API_KEY")
  if (!apiKey) return Response.json({ error: "AI_NOT_CONFIGURED", message: "OPENAI_API_KEY n'est pas configurée dans Supabase Edge Functions." }, { status: 503 })

  const started = Date.now()
  const { data: run, error: runError } = await supabase.from("ai_runs").insert({ school_id: profile.school_id, user_id: userId, conversation_id: conversationId, mode: body.mode ?? "assistant", provider: "openai", model, status: "running" }).select("id").single()
  if (runError || !run) return Response.json({ error: runError?.message ?? "RUN_CREATE_FAILED" }, { status: 400 })

  try {
    const { data: messages, error: messagesError } = await supabase.from("ai_messages").select("role,content,metadata,created_at").eq("conversation_id",conversationId).order("created_at",{ ascending: false }).limit(24)
    if (messagesError) throw new Error(`MESSAGE_HISTORY:${messagesError.message}`)

    const ordered = (messages ?? []).reverse().map((m) => ({ role: m.role === "assistant" || m.role === "user" ? m.role : "user", content: m.content }))
    let input: Array<Record<string, unknown>> = [{ role: "system", content: buildSystemPrompt(body.mode ?? "assistant") }, ...ordered]
    let finalText = ""
    let totalIn = 0
    let totalOut = 0

    for (let round = 0; round < MAX_TOOL_ROUNDS; round += 1) {
      const response = await openAi({ model, input, tools: toolDefinitions, tool_choice: "auto", store: false }, apiKey)
      totalIn += response.usage?.input_tokens ?? 0
      totalOut += response.usage?.output_tokens ?? 0
      const calls = toolCallsFromResponse(response)
      if (!calls.length) {
        finalText = textFromResponse(response)
        break
      }

      const toolOutputs: Array<Record<string, unknown>> = []
      for (const call of calls) {
        const toolStarted = Date.now()
        const args = safeArgs(call.arguments)
        let result: unknown = null
        let status = "completed"
        let toolError: string | null = null
        try {
          if (call.name === "create_ai_alert") {
            const { data: alert, error } = await supabase.from("ai_alerts").insert({
              school_id: profile.school_id,
              alert_type: String(args.alert_type ?? "ai_signal"),
              severity: Math.min(Math.max(Number(args.severity ?? 1),1),5),
              title: String(args.title ?? "Signal IA"),
              description: String(args.description ?? ""),
              related_table: args.related_table ? String(args.related_table) : null,
              related_id: args.related_id ? String(args.related_id) : null,
              evidence: args.evidence ?? {},
              recommended_action: args.recommended_action ? String(args.recommended_action) : null,
              source_run_id: run.id,
              status: "open",
            }).select("id,title,status").single()
            if (error) throw error
            result = alert
          } else {
            const toolResult = await callTool(supabase, profile.school_id, call.name, args)
            if (toolResult.error) throw toolResult.error
            result = toolResult.data
          }
        } catch (error) {
          status = "failed"
          toolError = error instanceof Error ? error.message : String(error)
          result = { error: toolError }
        }

        await supabase.from("ai_tool_calls").insert({ run_id: run.id, school_id: profile.school_id, tool_name: call.name, arguments: args, result: result ?? {}, status, error_message: toolError, duration_ms: Date.now() - toolStarted })
        toolOutputs.push({ type: "function_call_output", call_id: call.call_id, output: JSON.stringify(result ?? {}) })
      }

      const outputItems = response.output ?? []
      input = [...input, ...outputItems, ...toolOutputs]
    }

    if (!finalText) finalText = "Je n'ai pas pu terminer l'analyse dans la limite d'outils prévue. Reformule la demande ou demande une analyse plus ciblée."

    const { data: assistantMessage, error: assistantError } = await supabase.from("ai_messages").insert({ conversation_id: conversationId, role: "assistant", content: finalText, metadata: { model, mode: body.mode ?? "assistant", run_id: run.id } }).select("id,content,created_at").single()
    if (assistantError) throw assistantError

    await supabase.from("ai_runs").update({ status: "completed", input_tokens: totalIn, output_tokens: totalOut, latency_ms: Date.now() - started, finished_at: new Date().toISOString() }).eq("id", run.id)
    return Response.json({ conversation_id: conversationId, message: assistantMessage, run_id: run.id })
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error)
    await supabase.from("ai_runs").update({ status: "failed", error_message: message, error_code: message.split(":")[0], latency_ms: Date.now() - started, finished_at: new Date().toISOString() }).eq("id", run.id)
    return Response.json({ error: "AI_RUN_FAILED", message }, { status: 500 })
  }
})
