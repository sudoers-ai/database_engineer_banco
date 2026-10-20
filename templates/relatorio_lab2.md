# Relatório de recuperação — Lab 2

> Copie para `entregas/relatorio_lab2.md` e troque cada `(preencha)` pelo
> que **você mediu**. Número diferente do roteiro é normal; número
> inventado não.

**Equipe / autor:** (preencha)

## 1. Estado de partida (seção 2.1)

| Item | Valor |
|---|---|
| Contas | (preencha) |
| Transferências | (preencha) |
| Lançamentos | (preencha) |
| Dinheiro no banco (soma dos saldos) | (preencha) |
| Auditoria (4 invariantes) | (preencha) |

## 2. Backup (seção 2.2)

| Item | Valor |
|---|---|
| Hora do backup | (preencha) |
| Duração do `pg_dump` (`real`) | (preencha) |
| Tamanho do arquivo | (preencha) |
| Transferências feitas depois do backup (seção 2.3) | (preencha) |

## 3. Incidente e recuperação (seções 2.4 a 2.7)

| Item | Valor |
|---|---|
| Hora do incidente | (preencha) |
| Duração da restauração na base isolada (`real`) | (preencha) |
| Auditoria na base isolada | (preencha) |
| Transferências sem extrato depois de devolver a tabela (a perda) | (preencha) |
| Janela de tempo perdida (primeira → última) | (preencha) |
| RTO observado (seção 2.7) | (preencha) |

## 4. Comparação com as metas didáticas

| | Meta | Observado | Cumpriu? | Por quê |
|---|---|---|---|---|
| RPO | 5 minutos | (preencha) | (preencha) | (preencha) |
| RTO | 30 minutos | (preencha) | (preencha) | (preencha) |

Com **um dump por noite**, qual seria o pior RPO? O que mudaria para
cumprir a meta? (preencha)

## 5. Controles de criptografia

| Controle | Como foi feito | Evidência | Onde fica a chave |
|---|---|---|---|
| Backup cifrado | (preencha) | (preencha) | (preencha) |
| Restauração depois de decifrar | (preencha) | (preencha) | — |
| Conexão TLS com `verify-full` | (preencha) | (preencha) | (preencha: e a chave da AC?) |
| Renda cifrada em repouso | (preencha) | (preencha) | (preencha) |

## 6. O que continua exposto

Liste pelo menos três coisas que os controles deste lab **não** protegem.

1. (preencha)
2. (preencha)
3. (preencha)
