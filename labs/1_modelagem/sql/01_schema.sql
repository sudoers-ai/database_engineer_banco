-- ==========================================================================
-- Banco Sudoers - modelo de REFERENCIA (Lab 1)
--
-- Este e o modelo final. Rode-o depois de fazer a sua modelagem no
-- dbdiagram.io, seja qual for o desenho a que voce chegou: os labs
-- seguintes contam com exatamente estas tabelas.
--
-- ATENCAO: o arquivo recomeca do zero. Rodar de novo APAGA o schema
-- `banco` (tabelas e dados) e recria tudo vazio.
--
--   make sql f=labs/1_modelagem/sql/01_schema.sql
-- ==========================================================================
\set ON_ERROR_STOP on
SET client_min_messages = warning;

DROP SCHEMA IF EXISTS banco CASCADE;
CREATE SCHEMA banco;
-- quem conectar neste banco enxerga as tabelas sem escrever "banco."
ALTER DATABASE banco_sudoers SET search_path = banco, public;
SET search_path = banco, public;

-- --------------------------------------------------------------- clientes
CREATE TABLE clientes (
  id               bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  nome             text          NOT NULL,
  cpf              char(11)      NOT NULL UNIQUE CHECK (cpf ~ '^[0-9]{11}$'),
  email            text          NOT NULL,
  telefone         text,
  data_nascimento  date          NOT NULL,
  renda_mensal     numeric(12,2) CHECK (renda_mensal >= 0),
  criado_em        timestamptz   NOT NULL DEFAULT now()
);

-- ----------------------------------------------------------------- contas
CREATE TABLE contas (
  id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  cliente_id  bigint        NOT NULL REFERENCES clientes (id),
  agencia     char(4)       NOT NULL CHECK (agencia ~ '^[0-9]{4}$'),
  numero      char(6)       NOT NULL CHECK (numero  ~ '^[0-9]{6}$'),
  -- saldo "materializado": atualizado junto com os lancamentos, na mesma
  -- transacao. Sem cheque especial: nunca fica negativo.
  saldo       numeric(15,2) NOT NULL DEFAULT 0 CHECK (saldo >= 0),
  status      text          NOT NULL DEFAULT 'ativa'
                            CHECK (status IN ('ativa', 'bloqueada', 'encerrada')),
  aberta_em   timestamptz   NOT NULL DEFAULT now(),
  UNIQUE (agencia, numero)
);

-- --------------------------------------------------------- transferencias
-- Uma linha por SOLICITACAO atendida. A chave de idempotencia vem de quem
-- pede (o app gera um UUID por clique em "transferir"); repetir a mesma
-- chave nunca transfere duas vezes.
CREATE TABLE transferencias (
  id                  bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  chave_idempotencia  uuid          NOT NULL UNIQUE,
  conta_origem_id     bigint        NOT NULL REFERENCES contas (id),
  conta_destino_id    bigint        NOT NULL REFERENCES contas (id),
  valor               numeric(15,2) NOT NULL CHECK (valor > 0),
  descricao           text,
  solicitada_em       timestamptz   NOT NULL DEFAULT now(),
  CHECK (conta_origem_id <> conta_destino_id)
);

-- ------------------------------------------------------------ lancamentos
-- O extrato. Toda transferencia gera DOIS lancamentos: um debito (D) na
-- origem e um credito (C) no destino. Lancamento sem transferencia e um
-- aporte (dinheiro que entrou de fora do banco): so pode ser credito.
CREATE TABLE lancamentos (
  id                bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  conta_id          bigint        NOT NULL REFERENCES contas (id),
  transferencia_id  bigint        REFERENCES transferencias (id),
  tipo              char(1)       NOT NULL CHECK (tipo IN ('C', 'D')),
  valor             numeric(15,2) NOT NULL CHECK (valor > 0),
  criado_em         timestamptz   NOT NULL DEFAULT now(),
  CHECK (transferencia_id IS NOT NULL OR tipo = 'C')
);

COMMENT ON TABLE clientes       IS 'Pessoas titulares de conta (dados sinteticos)';
COMMENT ON TABLE contas         IS 'Contas correntes; saldo sempre igual a creditos - debitos';
COMMENT ON TABLE transferencias IS 'Solicitacoes de transferencia interna atendidas';
COMMENT ON TABLE lancamentos    IS 'Extrato: um debito e um credito por transferencia; aportes sem transferencia';

\echo
\echo 'Modelo criado: clientes, contas, transferencias, lancamentos (schema banco).'
