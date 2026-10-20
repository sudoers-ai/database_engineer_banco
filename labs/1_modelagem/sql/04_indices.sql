-- ==========================================================================
-- Banco Sudoers - indices para os padroes de acesso (Lab 1)
--
-- O PostgreSQL cria indice sozinho para PRIMARY KEY e UNIQUE, mas NAO para
-- chave estrangeira. Estes indices atendem as consultas do enunciado:
--
--   * extrato de UMA conta num PERIODO  -> (conta_id, criado_em)
--     a coluna de igualdade vem primeiro; a de intervalo, depois
--   * lancamentos de uma transferencia (auditoria, conciliacao)
--   * transferencias enviadas e recebidas por conta
--
--   make sql f=labs/1_modelagem/sql/04_indices.sql
-- ==========================================================================
\set ON_ERROR_STOP on
SET client_min_messages = warning;
SET search_path = banco, public;
\timing on

CREATE INDEX IF NOT EXISTS idx_lancamentos_conta_data   ON lancamentos (conta_id, criado_em);
CREATE INDEX IF NOT EXISTS idx_lancamentos_transferencia ON lancamentos (transferencia_id);
CREATE INDEX IF NOT EXISTS idx_transferencias_origem    ON transferencias (conta_origem_id, solicitada_em);
CREATE INDEX IF NOT EXISTS idx_transferencias_destino   ON transferencias (conta_destino_id, solicitada_em);
CREATE INDEX IF NOT EXISTS idx_contas_cliente           ON contas (cliente_id);

ANALYZE lancamentos, transferencias, contas;
\timing off

SELECT indexrelname AS indice, pg_size_pretty(pg_relation_size(indexrelid)) AS tamanho
FROM pg_stat_user_indexes
WHERE schemaname = 'banco' AND indexrelname LIKE 'idx_%'
ORDER BY indexrelname;
