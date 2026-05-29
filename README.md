# Portaria Diagnóstika

App PWA para porteiros registrarem entrada de prestadores em obras de reforma nos condomínios atendidos pela Diagnóstika Engenharia.

## Funcionalidades

- Login por condomínio + PIN do síndico + nome do porteiro
- Grid de unidades com status visual (sem reforma / c/ART / aguardando ART / sem RT / não autorizada)
- Modal de registro: tipo de serviço, prestador, CPF, telefone, observação
- Botão para sinalizar obra não autorizada
- Sincronização em tempo real com Supabase (tabela `portaria_eventos`)
- Funciona offline com fallback em localStorage

## Stack

- HTML/CSS/JS vanilla (sem framework)
- Supabase (Postgres + Realtime + Auth anon)
- PWA mobile-first

## Deploy

GitHub Pages: https://diagnostika-engenharia.github.io/portaria/

## Banco

Rodar `schema.sql` no SQL Editor do Supabase antes do primeiro uso para criar a tabela `portaria_eventos` com RLS e Realtime habilitados.

## Integração

Os eventos gravados aparecem em tempo real:
- **Painel Técnico (PMP)** → aba "Portaria" (mostra feed + permite "Abrir chamado")
- **Portal do Síndico** → aba de demandas/reformas
- **Painel da Diagnóstika** → notificações de obras não autorizadas
