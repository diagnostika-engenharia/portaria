-- ═══════════════════════════════════════════════════════════════════════════
-- TASK #9 + #16: Conversação bidirecional (morador ↔ engenharia)
--
-- Adiciona coluna `mensagens` JSONB em demandas como thread cronológica.
-- Cada msg: {id, autor:'morador'|'engenharia', autor_nome, texto, em, anexos:[]}
--
-- Cria RPC `responder_chamado_morador` que permite o morador (anon) postar
-- uma resposta sem violar RLS.
-- ═══════════════════════════════════════════════════════════════════════════

ALTER TABLE demandas
  ADD COLUMN IF NOT EXISTS mensagens JSONB DEFAULT '[]'::jsonb;

-- RPC: morador anon responde sua própria demanda (identifica via id)
CREATE OR REPLACE FUNCTION responder_chamado_morador(
  p_id     UUID,
  p_texto  TEXT,
  p_nome   TEXT,
  p_anexos JSONB DEFAULT '[]'::jsonb
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  nova_msg JSONB;
  d demandas%ROWTYPE;
BEGIN
  -- valida que demanda existe e não foi apagada
  SELECT * INTO d FROM demandas WHERE id = p_id AND deletada_em IS NULL;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('erro','Chamado não encontrado ou cancelado.');
  END IF;

  -- valida texto mínimo
  IF p_texto IS NULL OR length(trim(p_texto)) < 3 THEN
    RETURN jsonb_build_object('erro','Texto da resposta muito curto.');
  END IF;

  -- constrói nova mensagem
  nova_msg := jsonb_build_object(
    'id', gen_random_uuid(),
    'autor', 'morador',
    'autor_nome', coalesce(p_nome, d.morador_nome, 'Morador'),
    'texto', trim(p_texto),
    'em', now(),
    'anexos', coalesce(p_anexos, '[]'::jsonb)
  );

  -- append na thread
  UPDATE demandas
     SET mensagens = coalesce(mensagens, '[]'::jsonb) || nova_msg,
         updated_at = now()
   WHERE id = p_id;

  RETURN jsonb_build_object('ok', true, 'mensagem', nova_msg);
END;
$$;

-- Permissões para a RPC
GRANT EXECUTE ON FUNCTION responder_chamado_morador TO anon, authenticated;

-- Atualiza a RPC consultar_chamado_morador para incluir mensagens (se já existe)
-- Esta função normalmente já retorna SELECT *, então só precisa que a coluna exista.
