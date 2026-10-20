# Checklist de controles — Banco Sudoers

> Copie para `entregas/checklist_controles.md` e preencha. Uma linha por
> controle: o **requisito** que motivou, o **controle** implementado, a
> **evidência** que prova (um comando que qualquer pessoa pode repetir) e a
> **pendência**, com quem decide.
>
> **BACEN** e **PCI DSS**: estas colunas servem para **avaliar se o
> requisito se aplica**, não para afirmar conformidade. Use "a avaliar" e
> escreva a pergunta para as áreas responsáveis. Não cite artigo, prazo ou
> obrigação que você não tenha confirmado numa fonte oficial. PCI DSS trata
> de dados de **cartão de pagamento**: este banco tem dados de cartão?

**Equipe:** (preencha)

| # | Requisito | Controle | Evidência | Pendência (e quem decide) | BACEN: aplicável? | PCI DSS: aplicável? |
|---|---|---|---|---|---|---|
| 1 | Saldo nunca negativo; valor positivo (R6, R7) | `CHECK` nas tabelas + validação na função | (preencha) | (preencha) | (preencha) | (preencha) |
| 2 | Débito e crédito atômicos (R8) | transação única na função `transferir` | (preencha) | (preencha) | (preencha) | (preencha) |
| 3 | Sem processamento duplicado (R9) | `UNIQUE` na chave de idempotência + `ON CONFLICT` | (preencha) | (preencha) | (preencha) | (preencha) |
| 4 | Integridade financeira verificável | `banco.auditoria()` (4 invariantes) | (preencha) | (preencha) | (preencha) | (preencha) |
| 5 | Recuperar dados após incidente | `pg_dump` + restauração isolada + `pg_restore -L` | (preencha) | (preencha: o RPO cumpre a meta?) | (preencha) | (preencha) |
| 6 | Backup ilegível sem a chave | `gpg` AES-256; chave em `/cofre`, separada de `/backup` | (preencha) | (preencha) | (preencha) | (preencha) |
| 7 | Dados protegidos no caminho | TLS obrigatório (`hostnossl reject`) + `verify-full` | (preencha) | (preencha) | (preencha) | (preencha) |
| 8 | Renda protegida em repouso | `pgcrypto` com chave fora do banco | (preencha) | (preencha) | (preencha) | (preencha) |
| 9 | Menor privilégio para o app | `perfil_aplicacao`: leitura + `EXECUTE` em `transferir` | (preencha) | (preencha) | (preencha) | (preencha) |
| 10 | Atendimento vê só o necessário | `vw_atendimento_transferencias` (colunas, 90 dias, máscara) | (preencha) | (preencha) | (preencha) | (preencha) |
| 11 | Sem acesso para quem não tem perfil | `REVOKE CONNECT ... FROM PUBLIC` | (preencha) | (preencha) | (preencha) | (preencha) |
| 12 | Administração sem superusuário | `perfil_admin` dono do schema, sem `CREATEROLE` | (preencha) | (preencha) | (preencha) | (preencha) |
| 13 | Inventário dos dados | `entregas/inventario.md` | (preencha) | (preencha) | (preencha) | (preencha) |
| 14 | (um controle que **falta** e vocês recomendam) | (preencha) | — | (preencha) | (preencha) | (preencha) |

## Resumo para a apresentação

* Controles com evidência: (preencha) de 13
* Pendências que dependem da instituição: (preencha)
* O maior risco que continua aberto: (preencha)
