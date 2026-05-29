// ═══════════════════════════════════════════════════════════════════════════
// Edge Function: analisar-reforma
//
// Recebe demanda_id, busca dados, chama OpenAI com prompt NBR 16280, persiste
// o parecer estruturado em demandas.parecer_ia e retorna pro cliente.
//
// Variáveis de ambiente necessárias (Supabase Dashboard → Edge Functions → Secrets):
// - OPENAI_API_KEY (string)  ← obrigatória
// - OPENAI_MODEL (string)    ← opcional, default 'gpt-4o-mini'
//
// SUPABASE_URL e SUPABASE_ANON_KEY são injetadas automaticamente pelo Supabase.
// ═══════════════════════════════════════════════════════════════════════════

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS'
}

const SYSTEM_PROMPT = `Você é um engenheiro civil sênior, especialista na NBR 16280:2020 (Reformas em Edificações).
Sua tarefa: analisar uma solicitação de reforma de morador e emitir parecer técnico estruturado.

Princípios:
- Seja rigoroso com requisitos legais (NBR 16280, NBR 5410, NBR 5626, NBR 13523, Lei 6.496/77 ART)
- Identifique riscos por tipo de serviço (estrutural, gás, elétrica, hidráulica)
- Recomende complementação de documentação quando faltar
- Sugira contratação de RT quando o morador não tiver
- Use linguagem técnica mas acessível ao(à) síndico(a)

IMPORTANTE: responda APENAS com um objeto JSON válido, sem markdown nem texto adicional.`

interface ParecerResult {
  conformidade_geral: number
  status: 'aprovado' | 'aprovado_com_ressalvas' | 'complementar' | 'reprovado'
  status_label: string
  checklist_nbr_16280: { item: string; ok: boolean; observacao: string }[]
  alertas_criticos: string[]
  recomendacoes: string[]
}

function calcStatusCor(conformidade: number): string {
  if (conformidade >= 100) return '#1B8A4A'
  if (conformidade >= 80) return '#65A30D'
  if (conformidade >= 50) return '#D4A24C'
  return '#C00000'
}

serve(async (req) => {
  // CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: CORS_HEADERS })
  }

  try {
    const { demanda_id } = await req.json()
    if (!demanda_id) throw new Error('demanda_id obrigatório')

    const authHeader = req.headers.get('Authorization')
    if (!authHeader) throw new Error('Não autenticado')

    // Cliente autenticado como o usuário
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseAnon = Deno.env.get('SUPABASE_ANON_KEY')!
    const supabase = createClient(supabaseUrl, supabaseAnon, {
      global: { headers: { Authorization: authHeader } }
    })

    // Busca demanda
    const { data: demanda, error: errSel } = await supabase
      .from('demandas')
      .select('*')
      .eq('id', demanda_id)
      .single()
    if (errSel || !demanda) throw new Error('Demanda não encontrada ou sem permissão')
    if (demanda.categoria !== 'reforma') throw new Error('Esta demanda não é categoria reforma')

    // Monta prompt do usuário
    const det = demanda.detalhes || {}
    const fotos = demanda.fotos || []
    const docsCount = fotos.filter((f: any) => f && (f.tipo === 'documento' || /pdf/i.test(f.tipo || ''))).length
    const fotosCount = fotos.length - docsCount
    const tipos = det.tipos_servico?.join(', ') || 'não declarados pelo morador'

    const userPrompt = `Dados da solicitação:

Título: ${demanda.titulo}
Categoria: ${demanda.categoria}
Subtipo: ${det.subtipo_morador || 'reforma'}
Urgência: ${demanda.urgencia}
Local: Bloco ${demanda.bloco || '?'} · Apto ${demanda.apto || '?'}

Descrição do morador:
"${demanda.descricao || '(em branco)'}"

Tipos de serviço declarados: ${tipos}
${det.art_tipos_obra ? `Tipo(s) de obra (ART): ${det.art_tipos_obra.join(', ')}` : ''}
${det.art_prazo ? `Prazo desejado: ${det.art_prazo}` : ''}

Responsável Técnico:
${det.tem_rt
  ? `Sim — Nome: ${det.rt_nome || '(não informado)'}, Registro CREA/CAU: ${det.rt_registro || '(não informado)'}`
  : 'NÃO — morador não possui RT (oportunidade da Diagnóstika oferecer contratação)'}

Anexos: ${docsCount} documento(s) PDF, ${fotosCount} foto(s)
${docsCount > 0 ? `Lista de documentos: ${fotos.filter((f: any) => f && f.tipo === 'documento').map((f: any) => f.nome).join(', ')}` : ''}

Histórico:
- Já houve resposta da engenharia: ${demanda.resposta ? 'SIM' : 'não'}
- Mensagens trocadas: ${(demanda.mensagens || []).length}

────────
Emita o parecer técnico nesta estrutura JSON (apenas o objeto, sem markdown):

{
  "conformidade_geral": <inteiro 0-100>,
  "status": "aprovado" | "aprovado_com_ressalvas" | "complementar" | "reprovado",
  "status_label": "<frase com emoji curta>",
  "checklist_nbr_16280": [
    {"item": "<requisito da norma>", "ok": <true|false>, "observacao": "<o que foi encontrado ou está faltando>"}
  ],
  "alertas_criticos": ["<alerta técnico se houver, prefixe com ⚠ ou 🚨>"],
  "recomendacoes": ["<próximo passo concreto para a engenharia>"]
}`

    // Chama OpenAI
    const openaiKey = Deno.env.get('OPENAI_API_KEY')
    if (!openaiKey) throw new Error('OPENAI_API_KEY não configurada no Supabase')
    const model = Deno.env.get('OPENAI_MODEL') || 'gpt-4o-mini'

    const resp = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${openaiKey}`
      },
      body: JSON.stringify({
        model,
        messages: [
          { role: 'system', content: SYSTEM_PROMPT },
          { role: 'user', content: userPrompt }
        ],
        response_format: { type: 'json_object' },
        temperature: 0.2,
        max_tokens: 1500
      })
    })

    if (!resp.ok) {
      const errText = await resp.text()
      throw new Error(`OpenAI ${resp.status}: ${errText.substring(0, 200)}`)
    }

    const data = await resp.json()
    const content = data.choices?.[0]?.message?.content
    if (!content) throw new Error('Resposta vazia da OpenAI')

    let parecer: ParecerResult
    try {
      parecer = JSON.parse(content)
    } catch {
      throw new Error('OpenAI retornou JSON inválido: ' + content.substring(0, 200))
    }

    // Sanitiza e adiciona metadados
    const result: any = {
      ...parecer,
      analisado_em: new Date().toISOString(),
      analisado_por: `${model} (${data.usage?.total_tokens || '?'} tokens)`,
      versao_norma: 'NBR 16280:2020',
      status_cor: calcStatusCor(parecer.conformidade_geral || 0),
      documentos_analisados: fotos.filter((f: any) => f && f.tipo === 'documento').map((f: any) => ({
        nome: f.nome || 'documento',
        tipo: f.tipo
      })),
      fotos_analisadas: fotosCount,
      _meta: {
        model,
        tokens_prompt: data.usage?.prompt_tokens,
        tokens_completion: data.usage?.completion_tokens,
        tokens_total: data.usage?.total_tokens
      }
    }

    // Persiste
    const { error: errUpd } = await supabase
      .from('demandas')
      .update({
        parecer_ia: result,
        updated_at: new Date().toISOString()
      })
      .eq('id', demanda_id)
    if (errUpd) throw new Error('Falha ao gravar: ' + errUpd.message)

    return new Response(JSON.stringify(result), {
      status: 200,
      headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' }
    })

  } catch (e) {
    const msg = (e as Error).message || String(e)
    console.error('Erro analisar-reforma:', msg)
    return new Response(JSON.stringify({ error: msg }), {
      status: 400,
      headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' }
    })
  }
})
