-- ═══════════════════════════════════════════════════════════════════════════
-- Task #33 — Polish para apresentação Ana Paula
-- 1. Tabela equipe_condo: até 3 funcionários por (condo, síndico)
-- 2. Coluna morador_cpf em demandas
-- 3. RLS pra síndica ver apenas equipe dos próprios condos
-- ═══════════════════════════════════════════════════════════════════════════

-- 1. Coluna CPF do morador na demanda
ALTER TABLE demandas ADD COLUMN IF NOT EXISTS morador_cpf TEXT;

-- 1b. CPF e e-mail do porteiro nos eventos (auditoria)
ALTER TABLE portaria_eventos ADD COLUMN IF NOT EXISTS porteiro_cpf TEXT;
ALTER TABLE portaria_eventos ADD COLUMN IF NOT EXISTS porteiro_email TEXT;

-- 2. Tabela de funcionários da síndica (zelador, conselho, ajudantes)
CREATE TABLE IF NOT EXISTS equipe_condo (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  condo_id        TEXT NOT NULL,
  sindico_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  nome_completo   TEXT NOT NULL,
  cpf             TEXT,                       -- só dígitos (validação no client)
  email           TEXT,
  telefone        TEXT,
  cargo           TEXT NOT NULL,              -- 'zelador'|'conselho'|'ajudante'|'outro'
  ativo           BOOLEAN DEFAULT true,
  criado_em       TIMESTAMPTZ DEFAULT NOW(),
  atualizado_em   TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_equipe_sindico ON equipe_condo(sindico_user_id, condo_id) WHERE ativo = true;

-- Limite de 3 funcionários ativos por (síndico, condo)
CREATE OR REPLACE FUNCTION limite_equipe_condo()
RETURNS trigger AS $$
DECLARE total INT;
BEGIN
  IF NEW.ativo = true THEN
    SELECT COUNT(*) INTO total FROM equipe_condo
    WHERE sindico_user_id = NEW.sindico_user_id
      AND condo_id = NEW.condo_id
      AND ativo = true
      AND id != COALESCE(NEW.id, gen_random_uuid());
    IF total >= 3 THEN
      RAISE EXCEPTION 'Limite de 3 funcionários ativos por condomínio atingido. Desative algum antes de adicionar outro.';
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_limite_equipe ON equipe_condo;
CREATE TRIGGER trg_limite_equipe BEFORE INSERT OR UPDATE ON equipe_condo
  FOR EACH ROW EXECUTE FUNCTION limite_equipe_condo();

-- 3. RLS — síndica vê/edita só sua equipe
ALTER TABLE equipe_condo ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "equipe_sindico_all" ON equipe_condo;
CREATE POLICY "equipe_sindico_all" ON equipe_condo
  FOR ALL TO authenticated
  USING (sindico_user_id = auth.uid())
  WITH CHECK (sindico_user_id = auth.uid());
