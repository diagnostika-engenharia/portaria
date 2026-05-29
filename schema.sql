-- ═══════════════════════════════════════════════════════════════════════════
-- TABELA portaria_eventos
-- Registra eventos da portaria: entrada de prestador, obra clandestina, etc.
-- Rodar no SQL Editor do Supabase.
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS portaria_eventos (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  condo_id        TEXT NOT NULL,
  porteiro        TEXT NOT NULL,
  torre           TEXT,
  apto            TEXT,
  tipo_evento     TEXT NOT NULL,         -- 'entrada_prestador' | 'obra_clandestina' | 'saida_prestador' | 'visitante'
  tipo_servico    TEXT,                  -- 'Pedreiro' | 'Encanador' etc.
  prestador_nome  TEXT,
  prestador_cpf   TEXT,
  prestador_tel   TEXT,
  observacao      TEXT,
  foto_url        TEXT,
  hora            TIMESTAMPTZ DEFAULT NOW(),
  revisada_em     TIMESTAMPTZ,           -- preenchido quando PMP abre chamado a partir do evento
  revisada_por    TEXT,                  -- nome do engenheiro Diagnóstika que revisou
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_portaria_condo_hora ON portaria_eventos(condo_id, hora DESC);
CREATE INDEX IF NOT EXISTS idx_portaria_clandestina ON portaria_eventos(condo_id, tipo_evento) WHERE tipo_evento='obra_clandestina';

-- RLS: permitir INSERT da portaria (anon) e SELECT da equipe Diagnóstika
ALTER TABLE portaria_eventos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "portaria_insert_anon" ON portaria_eventos;
CREATE POLICY "portaria_insert_anon" ON portaria_eventos
  FOR INSERT TO anon
  WITH CHECK (true);

DROP POLICY IF EXISTS "portaria_select_authenticated" ON portaria_eventos;
CREATE POLICY "portaria_select_authenticated" ON portaria_eventos
  FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS "portaria_select_anon" ON portaria_eventos;
CREATE POLICY "portaria_select_anon" ON portaria_eventos
  FOR SELECT TO anon
  USING (true);

DROP POLICY IF EXISTS "portaria_update_anon" ON portaria_eventos;
CREATE POLICY "portaria_update_anon" ON portaria_eventos
  FOR UPDATE TO anon
  USING (true)
  WITH CHECK (true);

-- Realtime: habilitar para a tabela
ALTER PUBLICATION supabase_realtime ADD TABLE portaria_eventos;
