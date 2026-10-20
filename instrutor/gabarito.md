# 🔑 Gabarito do instrutor

> ⬅️ [Material do instrutor](./README.md)

> ⚠️ Se o repositório for público, este arquivo deve ficar num repositório
> privado. O gabarito **não substitui** o exercício: os comandos e o SQL já
> estão prontos nos roteiros, e o que se avalia é o raciocínio.

---

## Lab 1

### Seção 1.2 — perguntas da comparação

1. **Saldo guardado e lançamentos.** O P2 (saldo) fica instantâneo: é uma linha só, sem somar o extrato. O risco é o saldo divergir do extrato, se alguém mudar um sem o outro. Por isso: (a) o dinheiro só se move pela função, que muda os dois na mesma transação; (b) a `auditoria()` confere a invariante 1; (c) no Lab 3, o app perde o `UPDATE` direto.
2. **`numeric(15,2)`.** É exato em base 10. O `float` é binário e não representa 0,1 exatamente (`0.1 + 0.2 = 0.30000000000000004`). O `money` depende da configuração de moeda (`lc_monetary`) e tem arredondamentos próprios. Inteiro em centavos também é uma escolha válida e comum; o `numeric` é mais legível. Atenção: o `numeric(15,2)` **arredonda** o que chega com mais casas, por isso a função valida antes.
3. **`uuid` gerado por quem pede.** A chave precisa existir **antes** de o banco responder, para o app reenviar a mesma em caso de falha de rede. Um id do banco (sequência) só existe depois do `INSERT`. O UUID é gerado no app, sem consultar ninguém, e não se repete.
4. **`transferencia_id` nulo.** São os aportes: dinheiro que entrou de fora (simplificação). O `CHECK (transferencia_id IS NOT NULL OR tipo = 'C')` garante que só crédito pode não ter transferência.
5. **Diferenças comuns nos modelos dos alunos:**
   * sem tabela de lançamentos (extrato calculado das transferências): funciona para o P1, mas o aporte não tem onde ficar, e o extrato precisa de `UNION` de enviadas e recebidas;
   * sem saldo guardado: correto e mais simples, mas o P2 vira soma de todo o histórico;
   * `status` como tabela de domínio: válido;
   * sem chave de idempotência: **falta grave** (R9);
   * dinheiro em `float` ou `decimal` sem escala: **falta grave** (R6).

### Seção 1.8 — pontos para explorar

* `UPDATE 0` não é erro: o banco não sabe que você esperava uma linha. A função resolve isso travando e lendo as duas contas antes, e acusando "conta inexistente".
* Erro dentro de transação condena a transação inteira (`current transaction is aborted`) até o `ROLLBACK`.
* Uma função PL/pgSQL roda dentro da transação de quem chamou: o `RAISE` desfaz tudo, inclusive o `INSERT` do passo 3.
* Duas janelas: a janela B espera no `FOR UPDATE` do passo 2. Quando A confirma, B faz o `INSERT ... ON CONFLICT DO NOTHING`, encontra a chave já confirmada e devolve a transferência existente.

### Seção 1.9

* Sem índice em `conta_id`, o extrato lê as ~812 mil linhas (`Seq Scan`, `Rows Removed by Filter`). Com `(conta_id, criado_em)`, lê só as da conta no período (`Index Cond` com as duas colunas).
* Índice com a data primeiro serviria para "todas as transferências do dia", não para o extrato de uma conta.
* Custo: ~64 MB de índices e mais escrita em cada transferência.

### ADR de referência (resumo)

* **Contexto:** transferências internas com atomicidade (R8), sem duplicidade (R9), saldo não negativo (R7) e extrato rápido (P1).
* **Decisão:** PostgreSQL. Transações ACID entre várias linhas e tabelas, restrições declarativas (`CHECK`, FK, `UNIQUE`) garantidas pelo banco, `FOR UPDATE` para concorrência e índices compostos para o padrão de acesso.
* **Alternativas (em conceito):**
  * *banco de documentos*: um documento por conta com o extrato embutido facilita ler a conta, mas a transferência mexe em **dois** documentos. Exige transação entre documentos (onde existe, tem mais restrições) e as regras de integridade ficam na aplicação. O extrato embutido cresce sem limite;
  * *chave-valor*: ótimo para ler o saldo por chave e para a idempotência (`SET se não existir`), mas não tem consulta por período nem integridade entre chaves;
  * *esquema flexível e escala horizontal* são as vantagens deles. Para este caso, consistência vale mais que flexibilidade.
* **Consequências:** o saldo guardado precisa de auditoria e de escrita só pela função; índices custam escrita; escalar escrita além de um servidor exigiria particionamento ou fragmentação (fora do escopo).
* **Revisão (Labs 2 e 3):** dump lógico com restauração isolada (RPO = intervalo entre dumps; não cumpre 5 min sem PITR); backup cifrado com chave no cofre; TLS `verify-full`; renda com `pgcrypto`; perfis por função com `SECURITY DEFINER` e visão minimizada.

---

## Lab 2

### Números de referência (execução real, máquina do autor)

| Item | Valor |
|---|---|
| `pg_dump -Fc` | ~2,3 s, 29 MB |
| `pg_restore -j 2` na base isolada | ~1,5 s |
| Carga de 20 s a 20/s | ~400 transferências |
| Perda observada depois do `pg_restore -L` | ~400 transferências sem extrato (a janela da carga) |
| Cifrar o dump (`pg_dump \| gpg`) | ~3,5 s |
| Decifrar e restaurar | ~4 s |
| RTO observado (com leitura do roteiro) | 5 a 10 min |

### Discussão (seção 2.12)

1. **RPO.** Se o incidente acontece logo depois da carga, a perda é a janela desde o backup (alguns minutos): pode cumprir ou não a meta de 5 min, dependendo de quanto tempo passou. Com um dump por noite, o pior caso é **24 horas**. Para cumprir 5 min: backup físico com arquivamento contínuo de WAL (PITR), ou réplica.
2. **RTO em 1 TB.** O `pg_restore` recria cada tabela e **cada índice**: horas. Para cumprir 30 min: backup físico (restaura arquivos, sem recriar índices), réplica pronta para assumir, runbook automatizado e testado, restauração ensaiada periodicamente.
3. **Chaves.** Backup: num cofre de segredos ou KMS, com acesso de quem restaura (e cópia da chave em outro local). Campos: na aplicação, via KMS; o banco nunca vê a chave em claro idealmente. AC: na área de PKI, de preferência em HSM; o servidor de banco só recebe o certificado assinado.

### Pontos que costumam confundir

* "O `-Fc` é compactado, então está protegido": **não**. O `pg_restore` abriu sem senha.
* "Com TLS, não precisa de senha": **não**. O `hostssl` ainda usa `scram-sha-256`.
* "O `require` é seguro": cifra, mas aceita qualquer certificado, inclusive o de um impostor.
* "A renda está cifrada, então o backup está seguro": o backup da 2.8 é anterior e tem a renda (dentro do arquivo cifrado pelo `gpg`); o WAL antigo também.

---

## Lab 3

### Seção 3.1 — os pedidos

| Pedido | Precisa de | Resposta |
|---|---|---|
| App | ler saldo e extrato; transferir | `perfil_aplicacao`: `SELECT` + `EXECUTE transferir`; sem escrita direta; sem CPF |
| Atendimento | confirmar uma transferência | `perfil_atendimento`: só a visão minimizada |
| Time de dados | DDL | `perfil_admin`: dono do schema, sem superusuário, sem `CREATEROLE` |
| Parceiro de marketing | — | **não é decisão técnica**: finalidade, base legal, contrato, sigilo bancário. Registrar como pendência para Jurídico/Privacidade/Compliance. Se aprovado, o caminho seria um conjunto mínimo, preferencialmente agregado ou anonimizado, nunca acesso ao banco |
| Estagiário | estudar | sem acesso à produção; uma cópia com dados sintéticos ou anonimizados |

### Inventário de referência (`clientes`)

Todas as classificações, responsáveis e prazos são **hipóteses didáticas**.

| Campo | Origem | Finalidade | Classificação | Dado pessoal? | Responsável | Quem acessa | Compartilhamento | Retenção | Descarte | Proteção atual |
|---|---|---|---|---|---|---|---|---|---|---|
| `id` | gerado pelo banco | identificador interno | Interna | sim, combinado (identificador da pessoa) | Produto Contas | todos os perfis com acesso a `clientes`; app (coluna) | nenhum | enquanto houver relacionamento + prazo a definir | com o registro | — |
| `nome` | informado na abertura | identificar o titular; exibir no app | Confidencial | sim | Produto Contas | app (coluna), admin; atendimento abreviado | nenhum | a definir com Jurídico/Compliance | anonimizar ou apagar, inclusive backups (definir) | privilégio por coluna; abreviado na visão |
| `cpf` | informado na abertura | identificar o titular perante terceiros | Restrita | sim, identifica sozinho | Produto Contas | admin; atendimento mascarado | a validar (ex.: órgãos reguladores) | a definir | a definir | mascarado na visão; app sem acesso; **em claro na tabela** (pendência) |
| `email` | informado | contato | Confidencial | sim | Produto Contas / Atendimento | admin | nenhum | a definir | a definir | app e atendimento sem acesso |
| `telefone` | informado | contato; segurança (ex.: confirmação) | Confidencial | sim | Produto Contas / Atendimento | admin | nenhum | a definir | a definir | idem |
| `data_nascimento` | informado | validar idade/maioridade (hipótese) | Confidencial | sim, combinado | Produto Contas | admin | nenhum | a definir | a definir | fora da visão |
| `renda_cifrada` | informado | análise de crédito (hipótese) | Restrita | sim | Crédito / Risco | admin (cifrado; precisa da chave) | nenhum | a definir | descartar a chave também é descarte (*crypto-shredding*) — a validar | `pgcrypto`, chave fora do banco |
| `criado_em` | sistema | auditoria do cadastro | Interna | sim, combinado | Produto Contas | admin | nenhum | junto com o registro | junto com o registro | — |

### Checklist — exemplos de evidência e pendência

| # | Evidência | Pendência |
|---|---|---|
| 1 | `make conferir l=1`; seção 1.7 (erros de `CHECK`) | — |
| 3 | `make conferir l=1` (repete a chave e confere o saldo) | idempotência só vale se o app reenviar a **mesma** chave: requisito para o time do app |
| 5 | relatório do Lab 2 (RPO, RTO) | RPO de 5 min não é cumprido com dump: avaliar PITR/réplica (Infra + Negócio) |
| 6 | "ladrão do volume" (seção 2.8); `make conferir l=2` | custódia e cópia da chave; rotação (Segurança) |
| 7 | teste com `sslmode=disable` recusado; `pg_stat_ssl` | certificado de AC corporativa e renovação (PKI) |
| 8 | `pgp_sym_decrypt` com chave errada falha | chave via KMS na aplicação; backups antigos com renda (Segurança) |
| 9–12 | tabela dos 15 testes (seção 3.5); `make conferir l=3` | revisão periódica de acessos; registro de acesso (Segurança/Auditoria) |
| 13 | `entregas/inventario.md` | validar classificação e retenção (Jurídico/Privacidade) |

**BACEN:** a resposta esperada é "a avaliar com Compliance/Riscos": instituições
autorizadas pelo Banco Central têm normas sobre segurança cibernética,
continuidade e contratação de serviços. O aluno **não** deve citar números
de resoluções nem prazos sem confirmar na fonte oficial.

**PCI DSS:** aplica-se a quem armazena, processa ou transmite dados de
**cartão de pagamento**. Este banco não tem dado de cartão: "não aplicável
ao escopo atual; reavaliar se o serviço passar a lidar com cartões". Esta é
a resposta que mostra entendimento.

---

## Perguntas individuais

1. **`float` e `numeric`.** `float` é binário e aproximado (0,1 + 0,2 ≠ 0,3). `numeric(15,2)` é exato, mas arredonda 10,005 para 10,01 em silêncio; por isso a função recebe `numeric` sem escala e recusa mais de 2 casas.
2. **Duas vezes.** O `UNIQUE` em `chave_idempotencia` e o `INSERT ... ON CONFLICT DO NOTHING`. Ao mesmo tempo: a segunda espera a trava das contas (`FOR UPDATE`); quando a primeira confirma, o `INSERT` da segunda encontra a chave e devolve a transferência existente.
3. **Ordem do id.** Evita deadlock entre A→B e B→A: as duas tentam travar primeiro a mesma conta (a de menor id), e uma espera a outra.
4. **Ordem do índice.** Igualdade primeiro, intervalo depois: os lançamentos de uma conta ficam juntos e ordenados por data, e o banco lê só o trecho do período. Com a data primeiro, leria o período de todas as contas.
5. **Base isolada.** Validar que o backup presta (auditoria, contagens) sem destruir o que a produção tem a mais (as transferências depois do backup). Restaurar por cima voltaria tudo ao passado.
6. **`pg_restore -t`.** Traz tabela e dados, sem chave primária, índices e chaves estrangeiras: a tabela "funciona", mas aceita lixo e fica lenta. Ninguém percebe na hora.
7. **RPO zero?** Não. O backup perdeu as transferências posteriores; a recuperação veio do **modelo** (a tabela `transferencias` sobreviveu). Se ela tivesse sido apagada, a perda seria real.
8. **Chave do backup.** Em `/cofre`, separada de `/backup`. Quem obtém o storage de backup (funcionário, fornecedor, bucket exposto) não obtém a chave. A chave também precisa de cópia segura.
9. **`require` × `verify-full`.** Os dois cifram. O `require` não confere quem está do outro lado (um impostor no meio passa). O `verify-full` confere a AC e o nome do servidor.
10. **"Banco criptografado"?** Não. Só a renda. Nome, CPF, e-mail, saldos e extrato continuam em claro no disco; a chave passa pelo SQL; backups e WAL antigos guardam a renda; quem tem acesso e chave vê tudo.
11. **App sem `UPDATE`.** Ele muda saldos só pela função `transferir`, que é `SECURITY DEFINER` (roda como o dono) e aplica todas as regras. Um bug ou invasão do app não consegue "inventar" saldo direto.
12. **Visão sem acesso às tabelas.** A visão roda com os direitos do dono (`perfil_admin`); o atendente só precisa de `SELECT` na visão.
13. **Máscara anonimiza?** Não. Com nome abreviado, conta e parte do CPF, a pessoa continua identificável: é dado pessoal, com as mesmas obrigações. É minimização.
14. **Perfis.** Os privilégios ficam num lugar só; mudar alguém de função é trocar o perfil (`GRANT/REVOKE perfil`), e a auditoria de acessos fica legível.
15. **PCI DSS.** Só se o banco armazenar, processar ou transmitir dados de cartão. Este não tem: "não aplicável ao escopo atual", e quem confirma é a área de Compliance/Segurança.
