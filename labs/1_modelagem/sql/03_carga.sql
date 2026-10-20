-- ==========================================================================
-- Banco Sudoers - carga SINTETICA (Lab 1)
--
-- Nenhum dado aqui e real:
--   * nomes sorteados de uma lista;
--   * CPF com DIGITO VERIFICADOR ERRADO de proposito: nunca coincide com o
--     CPF de uma pessoa de verdade;
--   * e-mail no dominio exemplo.com (reservado para exemplos) e telefone
--     com DDD 00, que nao existe.
--
-- Volume: 10 mil clientes, 12 mil contas, 400 mil transferencias de 12 meses
-- (800 mil lancamentos). Leva de 10 a 40 segundos. Sempre gera os mesmos
-- dados (setseed), com as datas contadas a partir de hoje.
--
-- Recomeca do zero: apaga os dados das 4 tabelas antes de carregar.
--
--   make sql f=labs/1_modelagem/sql/03_carga.sql
-- ==========================================================================
\set ON_ERROR_STOP on
SET client_min_messages = warning;
SET search_path = banco, public;
\timing on

TRUNCATE lancamentos, transferencias, contas, clientes RESTART IDENTITY;
SELECT setseed(0.42);

-- CPF sintetico: 9 digitos unicos + 1o digito verificador ERRADO + 0
CREATE FUNCTION pg_temp.cpf_sintetico(n bigint) RETURNS char(11) LANGUAGE sql IMMUTABLE AS $$
  WITH b AS (SELECT lpad((100000000 + n * 37)::text, 9, '0') AS base),
       s AS (SELECT base, (SELECT sum(substr(base, i, 1)::int * (11 - i)) FROM generate_series(1, 9) i) % 11 AS r FROM b)
  SELECT base || (((CASE WHEN r < 2 THEN 0 ELSE 11 - r END) + 1) % 10)::text || '0' FROM s
$$;

-- ----------------------------------------------------------------- clientes
INSERT INTO clientes (nome, cpf, email, telefone, data_nascimento, renda_mensal, criado_em)
SELECT nomes[1 + floor(random() * array_length(nomes, 1))::int] || ' ' ||
       sobrenomes[1 + floor(random() * array_length(sobrenomes, 1))::int] || ' ' ||
       sobrenomes[1 + floor(random() * array_length(sobrenomes, 1))::int],
       pg_temp.cpf_sintetico(g),
       'cliente' || g || '@exemplo.com',
       '(00) 9' || lpad(floor(random() * 10000)::text, 4, '0') || '-' || lpad(floor(random() * 10000)::text, 4, '0'),
       date '1950-01-01' + floor(random() * 365 * 55)::int,
       round((1500 + random() * random() * 40000)::numeric, 2),
       now() - interval '420 days' + random() * interval '20 days'
FROM generate_series(1, 10000) g,
     (SELECT ARRAY['Ana','Bruno','Carla','Diego','Eduarda','Felipe','Gabriela','Heitor','Isabela',
                   'Joao','Karina','Lucas','Mariana','Nicolas','Olivia','Pedro','Rafaela','Samuel',
                   'Tatiane','Vinicius','Yasmin','Arthur','Beatriz','Caio','Helena','Miguel'] AS nomes,
             ARRAY['Silva','Santos','Oliveira','Souza','Rodrigues','Ferreira','Alves','Pereira',
                   'Lima','Gomes','Costa','Ribeiro','Martins','Carvalho','Almeida','Lopes',
                   'Soares','Fernandes','Vieira','Barbosa','Rocha','Dias','Nascimento','Moreira'] AS sobrenomes) l;

-- ------------------------------------------------------------------- contas
-- uma conta por cliente, mais 2 mil segundas contas; ~1% bloqueadas
INSERT INTO contas (cliente_id, agencia, numero, status, aberta_em)
SELECT cliente_id,
       (ARRAY['0001','0002','0003','0104'])[1 + (g % 4)],
       lpad((100000 + g * 7)::text, 6, '0'),
       CASE WHEN g % 97 = 0 THEN 'bloqueada' ELSE 'ativa' END,
       now() - interval '400 days' + random() * interval '30 days'
FROM (SELECT g, CASE WHEN g <= 10000 THEN g ELSE 1 + floor(random() * 10000)::bigint END AS cliente_id
      FROM generate_series(1, 12000) g) x;

-- ------------------------------------------------------------------ aportes
-- o dinheiro que entrou de fora: um credito sem transferencia por conta
INSERT INTO lancamentos (conta_id, tipo, valor, criado_em)
SELECT id, 'C', round((20000 + random() * 80000)::numeric, 2), aberta_em
FROM contas ORDER BY aberta_em;

-- ----------------------------------------------------------- transferencias
INSERT INTO transferencias (chave_idempotencia, conta_origem_id, conta_destino_id, valor, descricao, solicitada_em)
SELECT chave, origem, destino, valor, descricao, quando
FROM (SELECT md5('carga-' || g)::uuid AS chave,
             o AS origem,
             1 + (o + floor(random() * 11999)::int) % 12000 AS destino,  -- nunca igual a origem
             round((1 + random() * 999)::numeric, 2) AS valor,
             (ARRAY['aluguel','mercado','divisao de conta','presente','reembolso',NULL])[1 + floor(random() * 6)::int] AS descricao,
             now() - interval '365 days' + random() * interval '364 days' AS quando
      FROM (SELECT g, 1 + floor(random() * 12000)::int AS o FROM generate_series(1, 400000) g) s) t
ORDER BY quando;

-- ------------------------------------------------------- lancamentos (extrato)
INSERT INTO lancamentos (conta_id, transferencia_id, tipo, valor, criado_em)
SELECT conta_id, transferencia_id, tipo, valor, criado_em
FROM (SELECT conta_origem_id AS conta_id, id AS transferencia_id, 'D' AS tipo, valor, solicitada_em AS criado_em FROM transferencias
      UNION ALL
      SELECT conta_destino_id, id, 'C', valor, solicitada_em FROM transferencias) x
ORDER BY criado_em, transferencia_id, tipo DESC;

-- -------------------------------------------------------------------- saldo
-- o CHECK (saldo >= 0) reclama aqui se alguma conta ficasse negativa
UPDATE contas c SET saldo = l.s
FROM (SELECT conta_id, sum(CASE tipo WHEN 'C' THEN valor ELSE -valor END) AS s
      FROM lancamentos GROUP BY conta_id) l
WHERE l.conta_id = c.id;

ANALYZE clientes, contas, transferencias, lancamentos;
\timing off

SELECT (SELECT count(*) FROM clientes)       AS clientes,
       (SELECT count(*) FROM contas)         AS contas,
       (SELECT count(*) FROM transferencias) AS transferencias,
       (SELECT count(*) FROM lancamentos)    AS lancamentos;
