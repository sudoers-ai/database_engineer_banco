# ✅ Checklist do aluno

> ⬅️ [README principal](../README.md)

Marque cada item **somente depois de ver a evidência**. O `make status`
mostra o resumo, e o `make conferir l=N` mostra o detalhe.

### 0) Antes da primeira aula

* [ ] Segui o guia do meu sistema: [Windows](./windows.md), [Mac](./mac.md) ou [Linux](./linux.md)
* [ ] **Windows:** estou no terminal do Ubuntu (WSL), e não no PowerShell
* [ ] `make verificar` terminou com **Tudo certo**
* [ ] `make preflight` terminou com **Pronto para o Lab 1**
* [ ] Abri o https://dbdiagram.io/d no navegador

### 1) Modelagem e implementação

* [ ] Li os requisitos R1 a R10 e os padrões de acesso P1 a P4
* [ ] Desenhei o meu modelo no dbdiagram.io e salvei em `entregas/meu_modelo.dbml`
* [ ] Comparei com o modelo de referência e respondi às 5 perguntas
* [ ] Exportei o meu SQL e vi o que o export não gera (`CHECK`, função)
* [ ] Rodei `01_schema.sql`, `02_transferencia.sql` e `03_carga.sql`
* [ ] A auditoria mostrou 4 `t`
* [ ] Vi as restrições recusarem saldo negativo, origem = destino e conta inexistente
* [ ] Vi o `UPDATE 0` e o `ROLLBACK` salvarem 100 reais
* [ ] Vi a solicitação repetida devolver a mesma transferência
* [ ] Vi a janela B esperar a janela A
* [ ] Medi o extrato com `EXPLAIN ANALYZE` antes e depois do `04_indices.sql`
* [ ] Preenchi o ADR (`entregas/adr.md`)
* [ ] `make conferir l=1` ✅

### 2) Backup, recuperação e criptografia

* [ ] Anotei as metas de RPO e RTO e o estado de partida
* [ ] Fiz o `pg_dump` e o `pg_dumpall --globals-only` e anotei a hora
* [ ] Rodei a carga depois do backup
* [ ] Restaurei na base isolada `banco_restaurado` e a auditoria fechou
* [ ] Devolvi só a tabela `lancamentos` com `pg_restore -L`
* [ ] Medi a perda (transferências sem extrato) e o RTO
* [ ] Cifrei o backup com `gpg`, apaguei a cópia em claro e vi o "ladrão" falhar
* [ ] Restaurei o backup cifrado e a auditoria fechou
* [ ] Liguei o TLS, vi a conexão sem TLS ser recusada e o `verify-full` funcionar
* [ ] Vi o `verify-full` recusar o nome errado
* [ ] Achei o CPF em claro no arquivo da tabela
* [ ] Cifrei a renda com `pgcrypto` e entendi os limites
* [ ] Preenchi o relatório (`entregas/relatorio_lab2.md`)
* [ ] `make conferir l=2` ✅

### 3) Governança, acessos e consolidação

* [ ] Discuti os quatro pedidos de acesso e o do estagiário
* [ ] Preenchi o inventário (`entregas/inventario.md`), pelo menos todos os campos de `clientes`
* [ ] Criei os perfis e entrei como `usr_app`, `usr_atendimento` e `usr_estagiario`
* [ ] Criei a visão do atendimento e entendi os limites dela
* [ ] Os testes de acesso deram 15 de 15
* [ ] Preenchi o checklist de controles (`entregas/checklist_controles.md`)
* [ ] Revisei o ADR com as decisões dos Labs 2 e 3
* [ ] `make conferir l=3` ✅
* [ ] Apresentei com a minha equipe

### Ao fim de cada aula

* [ ] `make derruba` (para o container e **mantém** o seu progresso)
