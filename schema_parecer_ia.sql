-- ═══════════════════════════════════════════════════════════════════════════
-- TASK #10: Parecer IA NBR 16280
-- Coluna parecer_ia JSONB armazena o resultado da análise (mock ou LLM real).
-- ═══════════════════════════════════════════════════════════════════════════

ALTER TABLE demandas
  ADD COLUMN IF NOT EXISTS parecer_ia JSONB;

CREATE INDEX IF NOT EXISTS idx_demandas_parecer_status
  ON demandas((parecer_ia->>'status'))
  WHERE parecer_ia IS NOT NULL;
