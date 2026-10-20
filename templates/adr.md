# ADR 001 — Banco de dados e modelagem do serviço de transferências

> Copie para `entregas/adr.md` e troque cada `(preencha)`. Seja curto: um
> ADR bom cabe em uma ou duas páginas. Use números do lab sempre que puder.

| | |
|---|---|
| **Equipe / autor** | (preencha) |
| **Data** | (preencha) |
| **Situação** | proposta / aceita / substituída |

## 1. Contexto

O que precisava ser decidido e por quê. Cite os requisitos (R1 a R10) e os
padrões de acesso (P1 a P4) que mais pesaram.

(preencha)

## 2. Por que um banco relacional (PostgreSQL)

Compare, **em conceito**, com pelo menos duas alternativas não relacionais
(ex.: banco de documentos, chave-valor). Não é preciso ter usado: pense no
que cada uma faria bem ou mal **neste** caso.

| Critério | PostgreSQL (relacional) | Alternativa 1: (preencha) | Alternativa 2: (preencha) |
|---|---|---|---|
| Débito e crédito atômicos entre duas contas (R8) | (preencha) | (preencha) | (preencha) |
| Regras garantidas pelo banco: saldo ≥ 0, FK (R4, R7) | (preencha) | (preencha) | (preencha) |
| Não processar duas vezes (R9) | (preencha) | (preencha) | (preencha) |
| Extrato por conta e período (P1) | (preencha) | (preencha) | (preencha) |
| Escala horizontal e esquema flexível | (preencha) | (preencha) | (preencha) |

**Decisão:** (preencha)

## 3. Decisões de modelagem

| Decisão | Alternativa descartada | Justificativa |
|---|---|---|
| Dinheiro em `numeric(15,2)` | `float`, `money`, inteiro em centavos | (preencha) |
| Saldo guardado em `contas` **e** extrato em `lancamentos` | só o extrato, com o saldo calculado | (preencha) |
| Chave de idempotência `uuid UNIQUE`, gerada por quem pede | (preencha) | (preencha) |
| Transferência só pela função `transferir()` | `UPDATE`s feitos pelo app | (preencha) |
| Índice `(conta_id, criado_em)` em `lancamentos` | (preencha) | antes: (preencha) ms; depois: (preencha) ms |
| (uma decisão do **seu** modelo que difere da referência) | (preencha) | (preencha) |

## 4. Consequências

O que fica melhor, o que fica pior e o que precisa de cuidado daqui para a
frente (ex.: o saldo guardado precisa da auditoria; cada índice custa
escrita).

(preencha)

## 5. Evidências

* `make conferir l=1`: (preencha: todos ✅?)
* `SELECT * FROM auditoria()`: (preencha)
* `EXPLAIN ANALYZE` do extrato, antes e depois do índice: (preencha)

## 6. Revisão depois dos Labs 2 e 3

Acrescente as decisões novas: estratégia de backup e metas de RPO e RTO,
onde ficam as chaves, o que foi cifrado, o modelo de perfis de acesso.

(preencha)
