-- Carga do `make carga`: cada execucao e UMA transferencia entre duas contas
-- sorteadas, com uma chave de idempotencia nova (como um app faria).
-- So chama a funcao quando as duas contas estao ativas e a origem tem saldo,
-- para a carga nao parar no primeiro erro de regra de negocio.
\set origem random(1, 12000)
\set salto random(1, 11999)
\set centavos random(100, 50000)
SELECT banco.transferir(gen_random_uuid(), o.id, d.id, :centavos / 100.0, 'carga')
FROM banco.contas o, banco.contas d
WHERE o.id = :origem
  AND d.id = 1 + (:origem + :salto - 1) % 12000   -- nunca igual a origem
  AND o.status = 'ativa' AND d.status = 'ativa'
  AND o.saldo >= :centavos / 100.0;
