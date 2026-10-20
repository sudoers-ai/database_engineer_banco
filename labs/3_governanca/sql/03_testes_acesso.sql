-- ==========================================================================
-- Banco Sudoers - TESTES DE AUTORIZACAO (Lab 3)
--
-- Cada teste assume a identidade de um usuario (SET ROLE), tenta um comando
-- e anota se o banco PERMITIU ou NEGOU. Nada fica gravado: todo comando que
-- passa e desfeito na hora (inclusive a transferencia).
--
-- Um controle de acesso so esta provado com os dois lados:
--   teste POSITIVO  - quem deve conseguir, consegue;
--   teste NEGATIVO  - quem nao deve, e barrado.
--
--   make sql f=labs/3_governanca/sql/03_testes_acesso.sql
-- ==========================================================================
\set ON_ERROR_STOP on
SET client_min_messages = warning;
SET search_path = banco, public;

CREATE TEMP TABLE resultado (n serial, usuario text, teste text, esperado text, obtido text);

CREATE FUNCTION pg_temp.testar(p_usuario text, p_teste text, p_sql text, p_esperado text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE v_obtido text;
BEGIN
  BEGIN
    EXECUTE format('SET LOCAL ROLE %I', p_usuario);
    EXECUTE p_sql;
    -- deu certo: desfaz o que o comando fez e anota "permitido"
    RAISE EXCEPTION USING ERRCODE = 'P0099', MESSAGE = 'desfazer';
  EXCEPTION
    WHEN SQLSTATE 'P0099'          THEN v_obtido := 'permitido';
    WHEN insufficient_privilege    THEN v_obtido := 'negado';
    WHEN OTHERS                    THEN v_obtido := 'erro: ' || SQLERRM;
  END;
  INSERT INTO resultado (usuario, teste, esperado, obtido) VALUES (p_usuario, p_teste, p_esperado, v_obtido);
END $$;

-- a saida de cada teste fica escondida; o resultado vem na tabela do fim
\o /dev/null

-- ------------------------------------------------------------ aplicacao
SELECT pg_temp.testar('usr_app', 'ler saldo de uma conta',
  'SELECT saldo FROM contas WHERE id = 1', 'permitido');
SELECT pg_temp.testar('usr_app', 'ler o extrato de uma conta',
  'SELECT * FROM lancamentos WHERE conta_id = 1 LIMIT 5', 'permitido');
SELECT pg_temp.testar('usr_app', 'transferir pela funcao',
  'SELECT transferir(gen_random_uuid(), 1, 2, 10.00)', 'permitido');
SELECT pg_temp.testar('usr_app', 'ler o nome do cliente',
  'SELECT nome FROM clientes WHERE id = 1', 'permitido');
SELECT pg_temp.testar('usr_app', 'ler o CPF do cliente',
  'SELECT cpf FROM clientes WHERE id = 1', 'negado');
SELECT pg_temp.testar('usr_app', 'mudar saldo direto (UPDATE)',
  'UPDATE contas SET saldo = saldo + 1000 WHERE id = 1', 'negado');
SELECT pg_temp.testar('usr_app', 'apagar extrato (DELETE)',
  'DELETE FROM lancamentos WHERE conta_id = 1', 'negado');

-- ---------------------------------------------------------- atendimento
SELECT pg_temp.testar('usr_atendimento', 'consultar a visao de atendimento',
  'SELECT * FROM vw_atendimento_transferencias LIMIT 5', 'permitido');
SELECT pg_temp.testar('usr_atendimento', 'ler a tabela clientes',
  'SELECT * FROM clientes LIMIT 1', 'negado');
SELECT pg_temp.testar('usr_atendimento', 'ler a tabela transferencias',
  'SELECT * FROM transferencias LIMIT 1', 'negado');
SELECT pg_temp.testar('usr_atendimento', 'transferir pela funcao',
  'SELECT transferir(gen_random_uuid(), 1, 2, 10.00)', 'negado');

-- ---------------------------------------------------------------- admin
SELECT pg_temp.testar('usr_admin', 'criar um indice (DDL)',
  'CREATE INDEX ON clientes (nome)', 'permitido');
SELECT pg_temp.testar('usr_admin', 'criar um usuario novo',
  'CREATE ROLE usr_intruso LOGIN', 'negado');

-- ------------------------------------------------------ sem nenhum perfil
-- (com o nome completo, banco.contas: sem USAGE no schema, o nome curto
--  nem e encontrado, e o erro seria "nao existe" em vez de "sem permissao")
SELECT pg_temp.testar('usr_estagiario', 'ler saldo de uma conta',
  'SELECT saldo FROM banco.contas WHERE id = 1', 'negado');
SELECT pg_temp.testar('usr_estagiario', 'consultar a visao de atendimento',
  'SELECT * FROM banco.vw_atendimento_transferencias LIMIT 1', 'negado');

\o
SELECT usuario, teste, esperado, obtido,
       CASE WHEN obtido = esperado THEN '✅' ELSE '❌' END AS ok
FROM resultado ORDER BY n;

SELECT count(*) FILTER (WHERE obtido = esperado) || ' de ' || count(*) || ' testes como esperado' AS resumo
FROM resultado;
