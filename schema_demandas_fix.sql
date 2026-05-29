-- ═══════════════════════════════════════════════════════════════════════════
-- CORREÇÃO DE SCHEMA — tabela demandas
-- Adiciona colunas faltantes que o PMP/Portaria/Reformas usam.
-- Rodar no SQL Editor do Supabase.
-- Idempotente (IF NOT EXISTS) — pode rodar quantas vezes quiser.
-- ═══════════════════════════════════════════════════════════════════════════

-- Localização física da demanda (qual unidade do condomínio)
ALTER TABLE demandas ADD COLUMN IF NOT EXISTS bloco TEXT;
ALTER TABLE demandas ADD COLUMN IF NOT EXISTS apto  TEXT;

-- Marca quando a demanda foi gerada a partir de obra clandestina detectada pela portaria
ALTER TABLE demandas ADD COLUMN IF NOT EXISTS clandestina BOOLEAN DEFAULT false;
ALTER TABLE demandas ADD COLUMN IF NOT EXISTS porteiro_origem TEXT;
ALTER TABLE demandas ADD COLUMN IF NOT EXISTS portaria_evento_id UUID;

-- Campos de reforma (NBR 16280) — emissão de ART, responsável técnico, validação
ALTER TABLE demandas ADD COLUMN IF NOT EXISTS art_numero TEXT;
ALTER TABLE demandas ADD COLUMN IF NOT EXISTS art_emitida_em TIMESTAMPTZ;
ALTER TABLE demandas ADD COLUMN IF NOT EXISTS responsavel_tecnico JSONB;
ALTER TABLE demandas ADD COLUMN IF NOT EXISTS irregular BOOLEAN DEFAULT false;
ALTER TABLE demandas ADD COLUMN IF NOT EXISTS observacoes_engenharia TEXT;

-- Índices para performance dos filtros
CREATE INDEX IF NOT EXISTS idx_demandas_condo_categoria ON demandas(condo_id, categoria);
CREATE INDEX IF NOT EXISTS idx_demandas_clandestina    ON demandas(condo_id, clandestina) WHERE clandestina = true;
CREATE INDEX IF NOT EXISTS idx_demandas_bloco_apto     ON demandas(condo_id, bloco, apto);
