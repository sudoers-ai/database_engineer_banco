# 3️⃣ Lab 3 — Governança, acessos e consolidação

> ⬅️ Anterior: [Lab 2 — Backup e criptografia](../2_backup_criptografia/README.md) · [README principal](../../README.md) · Lab 3 de 3 · ⏱️ 180 min

> **A pergunta do banco:** "Quem pode ver o CPF do cliente? E como você
> prova?"

O banco está modelado, recuperável e cifrado onde importa. Falta decidir
**quem acessa o quê**, deixar isso documentado e **provar** que o banco
obedece. No fim, as equipes apresentam o trabalho dos três labs.

**Objetivos**

* inventariar os dados: de onde vêm, para que servem, quem responde por eles;
* criar perfis distintos para aplicação, atendimento e administração com `GRANT` e `REVOKE`;
* provar cada permissão com testes **positivos** e **negativos**;
* expor só o necessário com uma visão de dados mínimos;
* registrar requisito, controle, evidência e pendência num checklist;
* defender as decisões numa apresentação.

**Pré-requisitos:** os Labs 1 e 2 concluídos (`make conferir l=2`). Faltou?
`make gabarito l=2`.

| Seção | Atividade | Tempo |
|---|---|---|
| [3.1](#31-o-cenário) | Cenário de acesso e compartilhamento | 15 min |
| [3.2](#32-inventário-dos-dados) | Inventário dos dados | 40 min |
| [3.3](#33-perfis-de-acesso) | Perfis de acesso | 30 min |
| [3.4](#34-a-visão-com-dados-mínimos) e [3.5](#35-provando-os-acessos) | Visão com dados mínimos e testes | 25 min |
| [3.6](#36-documentação-e-checklist) | Documentação e checklist | 25 min |
| [3.7](#37-apresentações) | Apresentações em equipe e perguntas individuais | 45 min |

---

## 3.1 O cenário

⏱️ 15 min

🖥️ **No seu terminal:**

<!-- rodar: shell -->
```bash
make subir
make status
```

```
...
  Lab 1  ✅ modelo   ✅ transferência   ✅ carga   ✅ índices
  Lab 2  ✅ dump   ✅ cópia isolada   ✅ backup cifrado   ✅ TLS   ✅ renda cifrada
  Lab 3  ⬜ perfis   ⬜ visão do atendimento   ⬜ inventário   ⬜ checklist
...
```

Hoje, **todo mundo** entra no banco com o usuário `sudoers`, um
superusuário: o app, a central de atendimento, os analistas. Chegaram
quatro pedidos:

| Quem | O pedido |
|---|---|
| **Time do app** | "O app precisa mostrar saldo e extrato e fazer transferências." |
| **Central de atendimento** | "Quando o cliente liga reclamando de uma transferência, precisamos confirmar que ela aconteceu." |
| **Time de dados** | "Precisamos administrar o schema: criar índices, ajustar tabelas." |
| **Um parceiro de marketing** | "Queremos o extrato completo dos clientes, com CPF e e-mail, para uma campanha." |

E um estagiário que chegou ontem pediu "acesso ao banco, para estudar".

Discuta com a sua equipe antes de seguir: o que cada um **precisa** (não o
que pediu)? Algum pedido deve ser recusado ou reduzido? Quem decide?

> O pedido do parceiro de marketing **não** é uma decisão técnica. Ele
> envolve finalidade, base legal, contrato e sigilo, e quem decide é a
> instituição (Jurídico, Privacidade, Compliance). O papel de quem cuida
> dos dados é mostrar o que existe, o risco e os controles possíveis, e
> registrar a pendência.

---

## 3.2 Inventário dos dados

⏱️ 40 min · em equipe

Não dá para proteger o que você não sabe que tem. O primeiro passo de
governança é o **inventário**: cada campo, de onde vem, para que serve, quão
sensível é e quem responde por ele.

O banco já sabe listar o que existe:

🐘 **No psql** (`make psql`):

<!-- rodar: producao -->
```sql
SELECT table_name AS tabela, column_name AS campo, data_type AS tipo
FROM information_schema.columns
WHERE table_schema = 'banco' AND table_name IN ('clientes','contas','transferencias','lancamentos')
ORDER BY table_name, ordinal_position;
```

```
     tabela     |       campo        |           tipo
----------------+--------------------+--------------------------
 clientes       | id                 | bigint
 clientes       | nome               | text
 clientes       | cpf                | character
 clientes       | email              | text
 clientes       | telefone           | text
 clientes       | data_nascimento    | date
 clientes       | criado_em          | timestamp with time zone
 clientes       | renda_cifrada      | bytea
 contas         | id                 | bigint
...
(28 rows)
```

São 28 campos. Copie o template do inventário:

🖥️ **No seu terminal:**

<!-- rodar: shell -->
```bash
cp -n templates/inventario.md entregas/inventario.md
```

Preencha `entregas/inventario.md`. O template explica cada coluna e traz
três linhas de exemplo. Algumas orientações:

* **Classificação**: use a escala do template (Pública, Interna, Confidencial, Restrita). A escala é uma **hipótese didática**: cada instituição tem a sua;
* **Dado pessoal**: um dado é pessoal quando identifica ou pode identificar uma pessoa, inclusive combinado com outros. Pela LGPD, a categoria "dado pessoal sensível" é uma lista fechada (origem racial, saúde, religião...). Dado financeiro não está nessa lista, mas tem outras proteções, como o **sigilo bancário**. Não invente enquadramento: na dúvida, escreva "a validar com Jurídico/Privacidade";
* **Retenção e descarte**: **não** invente prazos. Escreva "definir com Jurídico/Compliance" e, se quiser, a hipótese que você levaria para a reunião, marcada como hipótese;
* **Responsável**: uma área ou um papel (ex.: "Produto Contas"), nunca "TI".

> Preencha pelo menos **todos os campos de `clientes`** e um campo de cada
> outra tabela. O instrutor tem um inventário de referência para a
> discussão.

---

## 3.3 Perfis de acesso

⏱️ 30 min

O modelo de acesso deste lab separa **perfis** de **pessoas**:

```
  perfil_aplicacao   ◄── usr_app           (o sistema do app)
  perfil_atendimento ◄── usr_atendimento   (a central)
  perfil_admin       ◄── usr_admin         (o time de dados)
  (nenhum perfil)    ◄── usr_estagiario
```

* **perfil** = uma role **sem login**, que recebe os `GRANT`s;
* **usuário** = uma role **com login**, que é membro de um perfil e herda os direitos dele;
* trocar alguém de função é trocar o perfil, não refazer `GRANT`s um a um.

Leia [`sql/01_perfis.sql`](./sql/01_perfis.sql). As decisões principais:

| Decisão | Por quê |
|---|---|
| `REVOKE CONNECT ... FROM PUBLIC` | `PUBLIC` é "qualquer role". Por padrão, **qualquer** usuário criado conecta em qualquer banco |
| `REVOKE EXECUTE ON ALL FUNCTIONS ... FROM PUBLIC` | por padrão, qualquer role **executa** qualquer função nova, inclusive `transferir` |
| `perfil_admin` vira dono do schema | o dono faz DDL (cria índice, altera tabela), sem precisar ser superusuário |
| app sem `INSERT`/`UPDATE`/`DELETE` | o dinheiro só se move pela função, que aplica todas as regras do Lab 1 |
| `transferir` com `SECURITY DEFINER` | a função roda com os direitos do **dono**: o app executa, mas não toca nas tabelas |
| `GRANT SELECT (id, nome) ON clientes` | privilégio por **coluna**: o app mostra o nome, mas não lê CPF, e-mail nem renda |

🖥️ **No seu terminal:**

<!-- rodar: shell -->
```bash
make sql f=labs/3_governanca/sql/01_perfis.sql
```

```
SET
DO
REVOKE
GRANT
...
ALTER FUNCTION
GRANT

Perfis criados.
```

🐘 **No psql:**

<!-- rodar: producao -->
```sql
\du
\dp contas
```

```
                                List of roles
     Role name      |                         Attributes
--------------------+------------------------------------------------------------
 perfil_admin       | Cannot login
 perfil_aplicacao   | Cannot login
 perfil_atendimento | Cannot login
 sudoers            | Superuser, Create role, Create DB, Replication, Bypass RLS
 usr_admin          |
 usr_app            |
 usr_atendimento    |
 usr_estagiario     |

                                      Access privileges
 Schema |  Name  | Type  |         Access privileges          | Column privileges | Policies
--------+--------+-------+------------------------------------+-------------------+----------
 banco  | contas | table | perfil_admin=arwdDxtm/perfil_admin+|                   |
        |        |       | perfil_aplicacao=r/perfil_admin    |                   |
(1 row)
```

Lendo o `\dp`: `perfil_admin=arwdDxtm` é o dono, com tudo (`a` insert, `r`
select, `w` update, `d` delete...). `perfil_aplicacao=r` só lê.

### Entrando como cada usuário, pela rede e com TLS

Até aqui você usou o `sudoers`. Agora entre como os usuários de verdade, do
jeito que o app entraria: pela rede, com o TLS do Lab 2. As senhas de
laboratório estão no `~/.pgpass` do servidor, por isso não são pedidas.

📦 **No terminal do servidor** (`make bash`):

<!-- rodar: bash-producao -->
```bash
C="host=producao dbname=banco_sudoers sslmode=verify-full sslrootcert=/cofre/ac/ac.crt"
psql "$C user=usr_app" -c "SELECT current_user, transferir(gen_random_uuid(), 5, 6, 25.00) AS transferencia"
```

```
 current_user | transferencia
--------------+---------------
 usr_app      |        400412
(1 row)
```

O app transfere. E se ele tentar mexer no saldo direto?

<!-- rodar: bash-producao falha-esperada -->
```bash
C="host=producao dbname=banco_sudoers sslmode=verify-full sslrootcert=/cofre/ac/ac.crt"
psql "$C user=usr_app" -c "UPDATE banco.contas SET saldo = saldo + 1000000 WHERE id = 5"
```

```
ERROR:  permission denied for table contas
```

E o estagiário, sem perfil:

<!-- rodar: bash-producao falha-esperada -->
```bash
C="host=producao dbname=banco_sudoers sslmode=verify-full sslrootcert=/cofre/ac/ac.crt"
psql "$C user=usr_estagiario" -c "SELECT 1"
```

```
psql: error: connection to server at "producao" (172.22.0.2), port 5432 failed: FATAL:  permission denied for database "banco_sudoers"
DETAIL:  User does not have CONNECT privilege.
```

Ele tem login e senha, mas não entra: o `REVOKE CONNECT ... FROM PUBLIC` em
ação.

---

## 3.4 A visão com dados mínimos

⏱️ dentro dos 25 min das seções 3.4 e 3.5

O atendimento precisa **confirmar** uma transferência. Não precisa do CPF
inteiro, do e-mail, do telefone, da data de nascimento nem da renda. Leia
[`sql/02_visao_atendimento.sql`](./sql/02_visao_atendimento.sql): a visão
aplica três tipos de minimização.

* **colunas**: só o que identifica a transferência;
* **linhas**: só os últimos 90 dias (prazo hipotético, a validar);
* **máscara**: CPF como `***.456.789-**` e sobrenome abreviado.

🖥️ **No seu terminal:**

<!-- rodar: shell -->
```bash
make sql f=labs/3_governanca/sql/02_visao_atendimento.sql
```

```
SET
CREATE VIEW
COMMENT
ALTER VIEW
GRANT

Visao criada: banco.vw_atendimento_transferencias
```

📦 **No terminal do servidor**, como atendente:

<!-- rodar: bash-producao -->
```bash
C="host=producao dbname=banco_sudoers sslmode=verify-full sslrootcert=/cofre/ac/ac.crt"
psql "$C user=usr_atendimento" -c "SELECT * FROM vw_atendimento_transferencias WHERE conta_origem = '0002/100035' ORDER BY solicitada_em DESC LIMIT 3"
```

```
 transferencia |         solicitada_em         | valor  | conta_origem | titular_origem |   cpf_origem   | conta_destino | titular_destino
---------------+-------------------------------+--------+--------------+----------------+----------------+---------------+-----------------
        400412 | 2026-10-20 14:40:12.763383-03 |  25.00 | 0002/100035  | Beatriz N.     | ***.000.185-** | 0003/100042   | Ana O.
        391401 | 2026-10-11 05:45:41.039214-03 | 324.81 | 0002/100035  | Beatriz N.     | ***.000.185-** | 0002/107847   | Nicolas S.
        387641 | 2026-10-07 19:21:50.839811-03 | 286.04 | 0002/100035  | Beatriz N.     | ***.000.185-** | 0104/120937   | Heitor O.
(3 rows)
```

A transferência do app de agora há pouco (conta 5, agência/número
`0002/100035`) aparece, com os dados mascarados. E as tabelas?

<!-- rodar: bash-producao falha-esperada -->
```bash
C="host=producao dbname=banco_sudoers sslmode=verify-full sslrootcert=/cofre/ac/ac.crt"
psql "$C user=usr_atendimento" -c "SELECT cpf, email FROM banco.clientes LIMIT 1"
```

```
ERROR:  permission denied for table clientes
```

**Por que a visão funciona sem acesso às tabelas?** Uma visão roda com os
direitos do **dono** dela (`perfil_admin`), e não de quem consulta. O
atendente recebeu `SELECT` só na visão. A opção `security_barrier` impede
que um filtro "esperto" na consulta do atendente veja linhas antes do
filtro da visão.

### Os limites da visão (leia com atenção)

* **Máscara não é anonimização.** `***.000.185-**` com o nome abreviado e a conta ainda identificam a pessoa. Continua sendo dado pessoal, com as mesmas obrigações. É **minimização**: menos dado exposto, menos risco;
* **A tabela continua lá.** Quem tem acesso à tabela (o `perfil_admin`, o `sudoers`) vê tudo. A visão protege um caminho, não o dado;
* **Superusuário ignora `GRANT`.** O `sudoers` lê tudo, sempre. Uso dele deve ser raro, nominal e registrado;
* **Combinação de consultas.** Com consultas repetidas e filtros, um atendente mal-intencionado pode juntar informação. Por isso existem limite de linhas, registro de acesso e revisão periódica, que estão fora deste lab;
* **Nenhum destes controles, sozinho, prova conformidade com a LGPD** ou com qualquer outra norma. Eles são evidências de controles técnicos. Conformidade envolve finalidade, base legal, processos e pessoas.

---

## 3.5 Provando os acessos

Um controle de acesso só está provado com os dois lados: **quem deve
conseguir consegue** (teste positivo) e **quem não deve é barrado** (teste
negativo). O arquivo [`sql/03_testes_acesso.sql`](./sql/03_testes_acesso.sql)
assume a identidade de cada usuário (`SET ROLE`), tenta um comando e anota
o resultado. Tudo o que passa é desfeito na hora: nenhuma transferência
fica gravada.

🖥️ **No seu terminal:**

<!-- rodar: shell -->
```bash
make sql f=labs/3_governanca/sql/03_testes_acesso.sql
```

```
...
     usuario     |              teste               | esperado  |  obtido   | ok
-----------------+----------------------------------+-----------+-----------+----
 usr_app         | ler saldo de uma conta           | permitido | permitido | ✅
 usr_app         | ler o extrato de uma conta       | permitido | permitido | ✅
 usr_app         | transferir pela funcao           | permitido | permitido | ✅
 usr_app         | ler o nome do cliente            | permitido | permitido | ✅
 usr_app         | ler o CPF do cliente             | negado    | negado    | ✅
 usr_app         | mudar saldo direto (UPDATE)      | negado    | negado    | ✅
 usr_app         | apagar extrato (DELETE)          | negado    | negado    | ✅
 usr_atendimento | consultar a visao de atendimento | permitido | permitido | ✅
 usr_atendimento | ler a tabela clientes            | negado    | negado    | ✅
 usr_atendimento | ler a tabela transferencias      | negado    | negado    | ✅
 usr_atendimento | transferir pela funcao           | negado    | negado    | ✅
 usr_admin       | criar um indice (DDL)            | permitido | permitido | ✅
 usr_admin       | criar um usuario novo            | negado    | negado    | ✅
 usr_estagiario  | ler saldo de uma conta           | negado    | negado    | ✅
 usr_estagiario  | consultar a visao de atendimento | negado    | negado    | ✅
(15 rows)

           resumo
-----------------------------
 15 de 15 testes como esperado
(1 row)
```

Essa tabela é uma **evidência**: cole-a no checklist da seção 3.6. Se um
dia alguém der um `GRANT` a mais, rodar o teste de novo mostra um ❌.

> **Experimente:** dê ao estagiário o perfil do atendimento
> (`GRANT perfil_atendimento TO usr_estagiario;` no psql), rode os testes
> de novo e veja os dois ❌. Depois desfaça com `REVOKE perfil_atendimento
> FROM usr_estagiario;` e confira que voltou a 15 de 15.

**📍 Checkpoint 3.5:** perfis, visão e testes no lugar. Confira com
`make conferir l=3` (os lembretes de entregáveis são normais por enquanto).

---

## 3.6 Documentação e checklist

⏱️ 25 min · em equipe

O checklist liga cada **requisito** a um **controle** e a uma **evidência**,
e deixa claras as **pendências**. Copie o template:

🖥️ **No seu terminal:**

<!-- rodar: shell -->
```bash
cp -n templates/checklist_controles.md entregas/checklist_controles.md
```

Preencha `entregas/checklist_controles.md`. Ele já traz as linhas dos
controles que você fez nos três labs. Para cada uma:

* **Evidência**: o comando ou o resultado que prova (o `make conferir`, a tabela de testes, o `EXPLAIN`, o relatório do Lab 2);
* **Pendência**: o que falta, quem decide e por quê;
* **BACEN** e **PCI DSS**: as colunas existem para **avaliar a aplicabilidade**, não para afirmar conformidade. Marque "a avaliar" e escreva a pergunta que você levaria às áreas responsáveis. Não cite artigo, prazo ou obrigação que você não tenha confirmado numa fonte oficial.

> **Exemplo de pendência bem escrita:** "O CPF continua em claro na tabela
> `clientes`. Avaliar cifragem ou tokenização. Decisão: Segurança da
> Informação + Produto. Impacto: a busca por CPF precisaria de um índice
> sobre um hash."

Por fim, **revise o seu ADR** (`entregas/adr.md`): acrescente as decisões
dos Labs 2 e 3 (estratégia de backup, onde ficam as chaves, modelo de
perfis).

<!-- rodar: shell -->
```bash
make conferir l=3
```

```
Conferindo o Lab 3 - Governança, acessos e consolidação

  ✅ 3 perfis sem login e 4 usuários com login (nenhum superusuário)
  ✅ usuário sem perfil não conecta no banco
  ✅ app transfere pela função (SECURITY DEFINER)
  ✅ app não altera saldo nem extrato direto
  ✅ app lê o nome do cliente, mas não o CPF
  ✅ atendimento não transfere e não lê as tabelas
  ✅ admin altera o schema, mas não cria usuários nem é superusuário
  ✅ atendimento consulta a visão
  ✅ a visão não expõe e-mail, telefone, nascimento nem renda
  ✅ entregável: entregas/inventario.md
  ✅ entregável: entregas/checklist_controles.md
  ✅ entregável: entregas/adr.md

✅ Lab 3 conferido.
```

---

## 3.7 Apresentações

⏱️ 45 min · cada equipe tem **6 minutos** de apresentação e **3** de perguntas

Roteiro sugerido, com um slide (ou uma tela) por item:

1. **O modelo** (1 min): o diagrama e as duas decisões de que vocês mais se orgulham.
2. **A transferência** (1 min): como o banco garante R7, R8 e R9. Mostrem a auditoria.
3. **A recuperação** (1,5 min): RPO e RTO medidos contra as metas; o que vocês mudariam para cumprir as metas num banco de 1 TB.
4. **A criptografia** (1 min): o que está protegido (backup, conexão, renda), onde ficam as chaves e o que **não** está protegido.
5. **A governança** (1 min): os perfis, a visão e a tabela de testes. Um campo do inventário que gerou discussão.
6. **As pendências** (0,5 min): o que depende de decisão da instituição.

Depois das apresentações, o instrutor faz **perguntas individuais**: sobre
qualquer lab, para qualquer pessoa da equipe. Prepare-se para explicar com
as suas palavras, por exemplo:

* por que dinheiro não vai em `float`;
* o que impede uma transferência de rodar duas vezes;
* por que restaurar numa base isolada antes da produção;
* a diferença entre `require` e `verify-full`;
* o que a cifragem da renda **não** protege;
* por que a máscara do CPF não é anonimização.

Ao fim da aula: `make derruba`. Para recomeçar a trilha do zero um dia,
`make limpar`, que lista o que vai apagar e pede confirmação.

---

## 📦 Entregáveis e avaliação

| Entregável | Onde | O que se avalia |
|---|---|---|
| Inventário | `entregas/inventario.md` | campos de `clientes` completos; classificação justificada; hipóteses marcadas; nada inventado sobre prazos e obrigações |
| Checklist de controles | `entregas/checklist_controles.md` | cada controle com evidência verificável; pendências com responsável |
| ADR revisado | `entregas/adr.md` | decisões dos três labs |
| Banco governado | `make conferir l=3` | todos os itens ✅ |
| Apresentação | em aula | clareza, números, limites reconhecidos |
| Perguntas individuais | em aula | entendimento próprio, não decorado |

## 🆘 Erros comuns

| O que apareceu | O que é | O que fazer |
|---|---|---|
| `role "usr_app" does not exist` | Faltou o `01_perfis.sql` | `make sql f=labs/3_governanca/sql/01_perfis.sql` |
| `permission denied for database` com o `usr_app` | Os `GRANT`s não foram aplicados | Rode o `01_perfis.sql` de novo (ele pode ser repetido) |
| `password authentication failed` | Você conectou sem o `.pgpass` (fora do servidor) | Rode os testes de login dentro do `make bash` |
| `FATAL: pg_hba.conf rejects connection ... no encryption` | Faltou `sslmode=verify-full` (o TLS é obrigatório desde o Lab 2) | Use a variável `C` do roteiro |
| `root certificate file "/cofre/ac/ac.crt" does not exist` | O TLS do Lab 2 não foi feito | `make gabarito l=2` |
| Teste com `erro: ...` na coluna `obtido` | O comando falhou por outro motivo (ex.: tabela inexistente) | Leia a mensagem; confira `make conferir l=1` |
| `relation "vw_atendimento_transferencias" does not exist` | Faltou o `02_visao_atendimento.sql` | Rode a seção 3.4 |

Mais em [docs/faq.md](../../docs/faq.md).

---

# 🏁 Fim da trilha. Volte ao [README principal](../../README.md) e marque o [checklist](../../docs/checklist.md).
