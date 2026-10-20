-- ==========================================================================
-- Banco Sudoers - PERFIS DE ACESSO (Lab 3)
--
-- Modelo: os privilegios vao para PERFIS (roles sem login); as PESSOAS e
-- os sistemas entram com USUARIOS (roles com login) que sao membros de um
-- perfil. Trocar alguem de funcao = trocar o perfil, nao refazer GRANTs.
--
--   perfil_admin        dono do schema: cria e altera tabelas (DDL)
--   perfil_aplicacao    o app: le contas e extrato e TRANSFERE so pela funcao
--   perfil_atendimento  a central: so a visao com dados minimos (arquivo 02)
--
--   usr_admin -> perfil_admin    usr_app -> perfil_aplicacao
--   usr_atendimento -> perfil_atendimento
--   usr_estagiario -> nenhum perfil (o teste do "sem acesso")
--
-- Pode rodar de novo: so cria o que falta e reaplica os GRANTs.
-- As senhas sao de laboratorio (estao no ~/.pgpass do container).
--
--   make sql f=labs/3_governanca/sql/01_perfis.sql
-- ==========================================================================
\set ON_ERROR_STOP on
SET client_min_messages = warning;

-- ------------------------------------------------------- roles (cluster)
DO $$
DECLARE r record;
BEGIN
  FOR r IN SELECT * FROM (VALUES
      ('perfil_admin', NULL, NULL), ('perfil_aplicacao', NULL, NULL), ('perfil_atendimento', NULL, NULL),
      ('usr_admin', 'admin123', 'perfil_admin'),
      ('usr_app', 'app123', 'perfil_aplicacao'),
      ('usr_atendimento', 'atend123', 'perfil_atendimento'),
      ('usr_estagiario', 'estag123', NULL)) AS v(nome, senha, perfil)
  LOOP
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = r.nome) THEN
      IF r.senha IS NULL THEN
        EXECUTE format('CREATE ROLE %I NOLOGIN', r.nome);
      ELSE
        EXECUTE format('CREATE ROLE %I LOGIN PASSWORD %L', r.nome, r.senha);
      END IF;
    END IF;
    IF r.perfil IS NOT NULL THEN
      EXECUTE format('GRANT %I TO %I', r.perfil, r.nome);
    END IF;
  END LOOP;
END $$;

-- --------------------------------------------- fechar a porta para PUBLIC
-- PUBLIC = "qualquer role". Por padrao ela pode CONECTAR em qualquer banco
-- e EXECUTAR qualquer funcao nova. Aqui, so entra quem tem perfil.
REVOKE CONNECT ON DATABASE banco_sudoers FROM PUBLIC;
GRANT  CONNECT ON DATABASE banco_sudoers TO perfil_admin, perfil_aplicacao, perfil_atendimento;
REVOKE ALL ON SCHEMA banco FROM PUBLIC;
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA banco FROM PUBLIC;
GRANT  USAGE ON SCHEMA banco TO perfil_aplicacao, perfil_atendimento;

-- ----------------------------------------------------------- perfil_admin
-- dono do schema e de tudo dentro dele (tabelas, sequencias, funcoes)
ALTER SCHEMA banco OWNER TO perfil_admin;
DO $$
DECLARE o record;
BEGIN
  FOR o IN SELECT c.oid::regclass AS nome, c.relkind FROM pg_class c
           WHERE c.relnamespace = 'banco'::regnamespace AND c.relkind IN ('r', 'v') LOOP
    EXECUTE format('ALTER %s %s OWNER TO perfil_admin',
                   CASE o.relkind WHEN 'v' THEN 'VIEW' ELSE 'TABLE' END, o.nome);
  END LOOP;
  FOR o IN SELECT p.oid::regprocedure AS nome FROM pg_proc p
           WHERE p.pronamespace = 'banco'::regnamespace LOOP
    EXECUTE format('ALTER FUNCTION %s OWNER TO perfil_admin', o.nome);
  END LOOP;
END $$;

-- ------------------------------------------------------- perfil_aplicacao
-- Le contas, transferencias e extrato. NAO tem INSERT/UPDATE/DELETE: o
-- dinheiro so se move pela funcao transferir(), que roda com os direitos
-- do dono (SECURITY DEFINER) e aplica todas as regras.
GRANT SELECT ON banco.contas, banco.transferencias, banco.lancamentos TO perfil_aplicacao;
GRANT SELECT (id, nome) ON banco.clientes TO perfil_aplicacao;   -- so as colunas que o app mostra
ALTER FUNCTION banco.transferir(uuid, bigint, bigint, numeric, text) SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION banco.transferir(uuid, bigint, bigint, numeric, text) TO perfil_aplicacao;

\echo
\echo 'Perfis criados.'
