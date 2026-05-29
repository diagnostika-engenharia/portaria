-- ═══════════════════════════════════════════════════════════════════════════
-- FIX descoberto via teste E2E:
-- A policy de UPDATE/SELECT em portaria_eventos só permitia 'anon'.
-- Engenheiro autenticado (PMP) ao "Abrir chamado de clandestina" tentava
-- atualizar revisada_em e falhava silenciosamente (HTTP 200, 0 rows affected).
-- ═══════════════════════════════════════════════════════════════════════════

-- Permitir SELECT pra authenticated também (PMP, Síndico)
DROP POLICY IF EXISTS "portaria_select_auth" ON portaria_eventos;
CREATE POLICY "portaria_select_auth" ON portaria_eventos
  FOR SELECT TO authenticated
  USING (true);

-- Permitir UPDATE pra authenticated (marcar revisada_em, revisada_por)
DROP POLICY IF EXISTS "portaria_update_auth" ON portaria_eventos;
CREATE POLICY "portaria_update_auth" ON portaria_eventos
  FOR UPDATE TO authenticated
  USING (true)
  WITH CHECK (true);

-- Permitir INSERT pra authenticated (PMP poderia gravar saída de prestador no futuro)
DROP POLICY IF EXISTS "portaria_insert_auth" ON portaria_eventos;
CREATE POLICY "portaria_insert_auth" ON portaria_eventos
  FOR INSERT TO authenticated
  WITH CHECK (true);
