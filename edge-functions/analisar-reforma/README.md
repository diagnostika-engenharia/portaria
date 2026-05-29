# Edge Function: analisar-reforma

Análise IA de reformas baseada na **NBR 16280:2020** usando OpenAI.

## Deploy passo a passo

### 1. Obter chave da API OpenAI

1. Acesse: https://platform.openai.com/api-keys
2. Clique **"Create new secret key"**
3. Nome: `diagnostika-pmp` (qualquer um)
4. Permissões: **Restricted** → marcar apenas `Model capabilities → Write`
5. **Copie a chave** (começa com `sk-proj-...`) — só aparece uma vez

### 2. Configurar secret no Supabase

1. Acesse: https://supabase.com/dashboard/project/fimmjgdwhifsrrbreche/settings/functions
2. Em **Edge Function Secrets**, clique **"Add new secret"**
3. Name: `OPENAI_API_KEY`
4. Value: cole a chave (`sk-proj-...`)
5. **Save**

(Opcional) Para usar modelo diferente do padrão `gpt-4o-mini`:
- Add secret `OPENAI_MODEL` com valor `gpt-4o` (mais caro, melhor) ou `gpt-4o-mini` (default)

### 3. Deploy da função

**Opção A — Via Dashboard (sem CLI):**

1. Acesse: https://supabase.com/dashboard/project/fimmjgdwhifsrrbreche/functions
2. Clique **"Create a new function"**
3. Name: `analisar-reforma`
4. Cole o conteúdo de `index.ts`
5. Clique **"Deploy function"**

**Opção B — Via CLI (recomendado se você for atualizar com frequência):**

```bash
# Instalar CLI (uma vez)
npm install -g supabase

# Login (uma vez)
supabase login

# Link ao projeto (uma vez, dentro da pasta do app)
supabase link --project-ref fimmjgdwhifsrrbreche

# Deploy
supabase functions deploy analisar-reforma --no-verify-jwt
```

> O `--no-verify-jwt` é importante porque a função verifica JWT manualmente
> dentro do código (via header `Authorization`).

### 4. Testar

No PMP, abra qualquer demanda categoria=reforma → clique **🤖 Analisar com IA**.

Se aparecer card de parecer com `analisado_por: "gpt-4o-mini (XXX tokens)"`, está funcionando.

Se aparecer parecer com `analisado_por: "mock-v1"`, significa que a função não foi chamada — o client caiu no fallback. Verifique:
- Função foi deployada?
- Secret `OPENAI_API_KEY` configurada?
- Console do navegador mostra erro 401/404?

## Custos esperados

| Modelo | Por análise | 100 análises/mês |
|---|---|---|
| `gpt-4o-mini` (default) | ~R$ 0,02–0,05 | ~R$ 3–5 |
| `gpt-4o` | ~R$ 0,20–0,80 | ~R$ 20–80 |

`gpt-4o-mini` é mais que suficiente para 95% dos casos — só troque se notar
qualidade insuficiente.

## Limitar uso (opcional)

Pra evitar custo descontrolado, adicione RLS ou trigger:

```sql
-- Permite no máx 5 análises/dia por usuário
CREATE OR REPLACE FUNCTION limit_parecer_ia()
RETURNS trigger AS $$
DECLARE
  hoje_count INT;
BEGIN
  IF NEW.parecer_ia IS NOT NULL AND OLD.parecer_ia IS NULL THEN
    SELECT COUNT(*) INTO hoje_count FROM demandas
    WHERE user_id = NEW.user_id
      AND parecer_ia IS NOT NULL
      AND (parecer_ia->>'analisado_em')::timestamptz > NOW() - INTERVAL '24 hours';
    IF hoje_count >= 5 THEN
      RAISE EXCEPTION 'Limite de 5 análises IA por dia atingido';
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_limit_parecer_ia
BEFORE UPDATE ON demandas
FOR EACH ROW EXECUTE FUNCTION limit_parecer_ia();
```

## Próximos passos (v2)

- [ ] Extração de texto dos PDFs anexados (hoje só usa metadados)
- [ ] Cache de pareceres similares (hash do conteúdo)
- [ ] Análise multimodal: enviar fotos pra GPT-4o Vision
- [ ] Webhook quando parecer gerado (notifica síndica)
