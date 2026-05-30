-- ═══════════════════════════════════════════════════════════════════════════
-- FIX CRÍTICO #2 (Auditoria 360 — 29/05/2026)
-- Revoga policies anônimas em portaria_eventos.
--
-- Antes: anon SELECT/UPDATE em todos os eventos (vazamento LGPD de CPF de
--        prestadores + capacidade de mascarar obras não autorizadas).
-- Depois:
--   - INSERT anon: continua permitido (portaria opera sem login), mas com
--     WITH CHECK validando que condo_id é válido e tipo é o esperado.
--   - SELECT/UPDATE: apenas para usuários autenticados (engenheiros + síndicos)
--     da role 'authenticated'.
--
-- Rode no editor SQL do Supabase (project diagnostika-pmp).
-- ═══════════════════════════════════════════════════════════════════════════

-- 1. Remove as policies anônimas inseguras
DROP POLICY IF EXISTS "portaria_select_anon" ON portaria_eventos;
DROP POLICY IF EXISTS "portaria_update_anon" ON portaria_eventos;
DROP POLICY IF EXISTS "portaria_delete_anon" ON portaria_eventos;

-- 2. INSERT continua anônimo (porteiro não tem login Supabase),
--    mas a anon key precisa autenticar o app antes via PIN no servidor.
--    Se já existe a policy de insert, deixa; se não, recria.
DROP POLICY IF EXISTS "portaria_insert_anon" ON portaria_eventos;
CREATE POLICY "portaria_insert_anon"
  ON portaria_eventos
  FOR INSERT
  TO anon
  WITH CHECK (
    condo_id IS NOT NULL
    AND condo_id IN ('monte-carlo','morada-morumbi','portal-primavera','residencial-santa-clara','jardins-do-malta','menotti-del-picchia','montville-residence','condominio-teste')
    AND tipo IN ('entrada','saida','obra_clandestina')
  );

-- 3. SELECT apenas para usuários autenticados (síndicos + engenheiros)
CREATE POLICY "portaria_select_authenticated"
  ON portaria_eventos
  FOR SELECT
  TO authenticated
  USING (true);

-- 4. UPDATE apenas para authenticated (revisão de alerta, marcar como tratado)
CREATE POLICY "portaria_update_authenticated"
  ON portaria_eventos
  FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- 5. Garantir que RLS está habilitado
ALTER TABLE portaria_eventos ENABLE ROW LEVEL SECURITY;

-- ═══════════════════════════════════════════════════════════════════════════
-- VERIFICAÇÃO
-- ═══════════════════════════════════════════════════════════════════════════
-- Listar policies atuais:
--   SELECT polname, polcmd, polroles::regrole[] FROM pg_policy
--   WHERE polrelid = 'portaria_eventos'::regclass;
--
-- Testes de aceitação:
-- a) Como anon: SELECT * FROM portaria_eventos  →  deve retornar 0 linhas (ou erro)
-- b) Como anon: INSERT com condo_id='monte-carlo', tipo='entrada' → OK
-- c) Como anon: INSERT com condo_id='invalido'  →  deve falhar
-- d) Como anon: UPDATE marcando revisada_em → deve falhar
-- e) Como authenticated: SELECT/UPDATE → OK
-- ═══════════════════════════════════════════════════════════════════════════
