-- ==========================================================================
-- Banco Sudoers - a TRANSFERENCIA e a AUDITORIA (Lab 1)
--
--   banco.transferir(chave, origem, destino, valor [, descricao])
--       debita e credita na MESMA transacao, nao processa duas vezes a
--       mesma chave e devolve o id da transferencia.
--
--   banco.auditoria()
--       confere as invariantes financeiras. Tudo `t` = integridade ok.
--
--   make sql f=labs/1_modelagem/sql/02_transferencia.sql
-- ==========================================================================
\set ON_ERROR_STOP on
SET client_min_messages = warning;

CREATE OR REPLACE FUNCTION banco.transferir(
  p_chave      uuid,
  p_origem     bigint,
  p_destino    bigint,
  p_valor      numeric,          -- sem (15,2) de proposito: ver o passo 1
  p_descricao  text DEFAULT NULL
) RETURNS bigint
LANGUAGE plpgsql
SET search_path = banco, pg_temp
AS $$
DECLARE
  v_id      bigint;
  v_antiga  transferencias%ROWTYPE;
  v_origem  contas%ROWTYPE;
  v_destino contas%ROWTYPE;
BEGIN
  -- 1. Validar o valor. Um parametro numeric(15,2) ARREDONDARIA 10.005 para
  --    10.01 em silencio; aqui o valor chega como veio e e recusado.
  IF p_valor IS NULL OR p_valor <= 0 THEN
    RAISE EXCEPTION 'valor inválido: % (precisa ser maior que zero)', p_valor
      USING ERRCODE = 'check_violation';
  END IF;
  IF p_valor <> round(p_valor, 2) THEN
    RAISE EXCEPTION 'valor com mais de 2 casas decimais: %', p_valor
      USING ERRCODE = 'check_violation';
  END IF;
  IF p_origem = p_destino THEN
    RAISE EXCEPTION 'origem e destino são a mesma conta (%)', p_origem
      USING ERRCODE = 'check_violation';
  END IF;

  -- 2. Travar as duas contas, SEMPRE na ordem do id. Duas transferencias
  --    cruzadas (A->B e B->A) travam na mesma ordem e nao dao deadlock.
  PERFORM 1 FROM contas WHERE id IN (p_origem, p_destino) ORDER BY id FOR UPDATE;
  SELECT * INTO v_origem  FROM contas WHERE id = p_origem;
  SELECT * INTO v_destino FROM contas WHERE id = p_destino;
  IF v_origem.id IS NULL OR v_destino.id IS NULL THEN
    RAISE EXCEPTION 'conta inexistente: %', CASE WHEN v_origem.id IS NULL THEN p_origem ELSE p_destino END
      USING ERRCODE = 'foreign_key_violation';
  END IF;

  -- 3. Idempotencia: registra a solicitacao. Se a chave ja existe, a
  --    transferencia ja foi feita: devolve a mesma, sem mexer em saldo.
  INSERT INTO transferencias (chave_idempotencia, conta_origem_id, conta_destino_id, valor, descricao)
  VALUES (p_chave, p_origem, p_destino, p_valor, p_descricao)
  ON CONFLICT (chave_idempotencia) DO NOTHING
  RETURNING id INTO v_id;

  IF v_id IS NULL THEN
    SELECT * INTO v_antiga FROM transferencias WHERE chave_idempotencia = p_chave;
    IF (v_antiga.conta_origem_id, v_antiga.conta_destino_id, v_antiga.valor)
       IS DISTINCT FROM (p_origem, p_destino, p_valor) THEN
      RAISE EXCEPTION 'chave % já usada na transferência % com outros dados', p_chave, v_antiga.id
        USING ERRCODE = 'unique_violation';
    END IF;
    RAISE NOTICE 'solicitação repetida: é a transferência % (nada foi debitado de novo)', v_antiga.id;
    RETURN v_antiga.id;
  END IF;

  -- 4. Regras de negocio. Qualquer RAISE desfaz TUDO, inclusive o INSERT
  --    do passo 3: a transacao e uma coisa so.
  IF v_origem.status <> 'ativa' THEN
    RAISE EXCEPTION 'conta de origem % está %', p_origem, v_origem.status;
  END IF;
  IF v_destino.status <> 'ativa' THEN
    RAISE EXCEPTION 'conta de destino % está %', p_destino, v_destino.status;
  END IF;
  IF v_origem.saldo < p_valor THEN
    RAISE EXCEPTION 'saldo insuficiente na conta %: saldo %, valor %', p_origem, v_origem.saldo, p_valor;
  END IF;

  -- 5. Debito e credito, no saldo e no extrato.
  UPDATE contas SET saldo = saldo - p_valor WHERE id = p_origem;
  UPDATE contas SET saldo = saldo + p_valor WHERE id = p_destino;
  INSERT INTO lancamentos (conta_id, transferencia_id, tipo, valor)
  VALUES (p_origem, v_id, 'D', p_valor),
         (p_destino, v_id, 'C', p_valor);

  RETURN v_id;
END;
$$;

COMMENT ON FUNCTION banco.transferir(uuid, bigint, bigint, numeric, text) IS
  'Transferencia interna atomica e idempotente';

-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION banco.auditoria()
RETURNS TABLE (regra text, ok boolean, detalhe text)
LANGUAGE sql STABLE
SET search_path = banco, pg_temp
AS $$
  -- 1. o saldo guardado bate com o extrato
  SELECT '1. saldo = créditos - débitos',
         count(*) = 0, count(*) || ' conta(s) divergente(s)'
  FROM contas c
  LEFT JOIN (SELECT conta_id, sum(CASE tipo WHEN 'C' THEN valor ELSE -valor END) AS s
             FROM lancamentos GROUP BY conta_id) l ON l.conta_id = c.id
  WHERE c.saldo <> coalesce(l.s, 0)
UNION ALL
  -- 2. toda transferencia tem exatamente 1 debito na origem e 1 credito no destino
  SELECT '2. transferência = 1 débito + 1 crédito',
         count(*) = 0, count(*) || ' transferência(s) sem os dois lançamentos'
  FROM transferencias t
  LEFT JOIN (SELECT transferencia_id,
                    count(*) AS n,
                    min(conta_id) FILTER (WHERE tipo = 'D') AS debito,
                    min(conta_id) FILTER (WHERE tipo = 'C') AS credito,
                    min(valor) AS menor, max(valor) AS maior
             FROM lancamentos WHERE transferencia_id IS NOT NULL
             GROUP BY transferencia_id) l ON l.transferencia_id = t.id
  WHERE l.n IS DISTINCT FROM 2
     OR l.debito  IS DISTINCT FROM t.conta_origem_id
     OR l.credito IS DISTINCT FROM t.conta_destino_id
     OR l.menor <> t.valor OR l.maior <> t.valor
UNION ALL
  -- 3. transferencia interna nao cria nem some com dinheiro
  SELECT '3. soma dos saldos = soma dos aportes',
         s.saldos = a.aportes, 'saldos ' || s.saldos || ' / aportes ' || a.aportes
  FROM (SELECT coalesce(sum(saldo), 0) AS saldos FROM contas) s,
       (SELECT coalesce(sum(valor), 0) AS aportes FROM lancamentos WHERE transferencia_id IS NULL) a
UNION ALL
  SELECT '4. nenhum saldo negativo',
         count(*) = 0, count(*) || ' conta(s) negativa(s)'
  FROM contas WHERE saldo < 0
$$;

COMMENT ON FUNCTION banco.auditoria() IS 'Invariantes financeiras: tudo ok = true';

\echo
\echo 'Funções criadas: banco.transferir(...) e banco.auditoria().'
