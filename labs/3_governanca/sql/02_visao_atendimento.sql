-- ==========================================================================
-- Banco Sudoers - VISAO COM DADOS MINIMOS para a central de atendimento
-- (Lab 3)
--
-- Cenario: o cliente liga dizendo "fiz uma transferencia e o dinheiro nao
-- chegou". O atendente precisa CONFIRMAR a transferencia; nao precisa do
-- CPF inteiro, do e-mail, do telefone, da data de nascimento nem da renda.
--
-- Minimizacao aplicada:
--   * colunas: so o necessario para identificar a transferencia;
--   * linhas: so os ultimos 90 dias (hipotese didatica; o prazo real e
--     decisao da instituicao);
--   * mascara: CPF no formato ***.456.789-** e nome com sobrenome abreviado.
--
-- LIMITES (estao no README do lab): a mascara nao anonimiza (o dado continua
-- pessoal), quem tem acesso a tabela ve tudo, e o superusuario ignora GRANTs.
--
--   make sql f=labs/3_governanca/sql/02_visao_atendimento.sql
-- ==========================================================================
\set ON_ERROR_STOP on
SET client_min_messages = warning;

CREATE OR REPLACE VIEW banco.vw_atendimento_transferencias
WITH (security_barrier) AS
SELECT t.id                                   AS transferencia,
       t.solicitada_em,
       t.valor,
       co.agencia || '/' || co.numero         AS conta_origem,
       split_part(clo.nome, ' ', 1) || ' ' || left(split_part(clo.nome, ' ', 2), 1) || '.' AS titular_origem,
       '***.' || substr(clo.cpf, 4, 3) || '.' || substr(clo.cpf, 7, 3) || '-**'          AS cpf_origem,
       cd.agencia || '/' || cd.numero         AS conta_destino,
       split_part(cld.nome, ' ', 1) || ' ' || left(split_part(cld.nome, ' ', 2), 1) || '.' AS titular_destino
FROM banco.transferencias t
JOIN banco.contas   co  ON co.id  = t.conta_origem_id
JOIN banco.clientes clo ON clo.id = co.cliente_id
JOIN banco.contas   cd  ON cd.id  = t.conta_destino_id
JOIN banco.clientes cld ON cld.id = cd.cliente_id
WHERE t.solicitada_em >= now() - interval '90 days';

COMMENT ON VIEW banco.vw_atendimento_transferencias IS
  'Atendimento: confirma transferencias dos ultimos 90 dias com dados mascarados';

-- a visao roda com os direitos do DONO: e por isso que o atendente consegue
-- ler a visao sem ter acesso as tabelas
ALTER VIEW banco.vw_atendimento_transferencias OWNER TO perfil_admin;
GRANT SELECT ON banco.vw_atendimento_transferencias TO perfil_atendimento;

\echo
\echo 'Visao criada: banco.vw_atendimento_transferencias'
