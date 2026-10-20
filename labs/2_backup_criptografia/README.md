# 2️⃣ Lab 2 — Backup, recuperação e criptografia

> ⬅️ Anterior: [Lab 1 — Modelagem](../1_modelagem/README.md) · [README principal](../../README.md) · Lab 2 de 3 · ⏱️ 180 min

> **A pergunta do banco:** "Apagaram o extrato. Quanto perdemos, em quanto
> tempo voltamos, e o backup está protegido?"

Você faz o backup do Banco Sudoers, assiste a um incidente, recupera os
dados numa cópia isolada antes de tocar na produção e **mede** a perda e o
tempo. Depois protege o que ficou exposto: o arquivo de backup, a conexão
com o banco e um dado sensível guardado no disco.

**Objetivos**

* fazer backup lógico com `pg_dump` e restaurar com `pg_restore`, inteiro e em parte;
* medir RPO e RTO de verdade e comparar com metas;
* validar uma restauração com registros, relacionamentos e invariantes financeiras;
* cifrar o backup, guardar a chave longe dele e provar que ele volta;
* exigir TLS nas conexões e validar a identidade do servidor;
* proteger um campo em repouso e entender o que isso **não** protege.

**Pré-requisitos:** o Lab 1 concluído (`make conferir l=1`). Faltou? Rode
`make gabarito l=1`.

| Seção | Atividade | Tempo |
|---|---|---|
| [2.1](#21-metas-de-recuperação-e-conferência) | Metas de recuperação e conferência dos dados | 15 min |
| [2.2](#22-o-backup-lógico) e [2.3](#23-a-vida-segue) | Backup lógico | 30 min |
| [2.4](#24-o-incidente) a [2.7](#27-conciliação-e-o-rto) | Incidente e restauração isolada | 35 min |
| [2.8](#28-cifrando-o-backup) e [2.9](#29-restaurando-o-backup-cifrado) | Criptografia do backup e recuperação | 30 min |
| [2.10](#210-conexão-com-tls) | Conexão TLS | 35 min |
| [2.11](#211-proteção-em-repouso) | Proteção em repouso e gestão das chaves | 20 min |
| [2.12](#212-revisão-e-evidências) | Revisão e evidências | 15 min |

---

## 2.1 Metas de recuperação e conferência

⏱️ 15 min

Toda estratégia de backup responde a duas perguntas:

| Pergunta | Nome técnico | Meta didática deste lab |
|---|---|---|
| "Se der problema, **quanto dado** podemos perder?" | **RPO** (*Recovery Point Objective*) | no máximo **5 minutos** de transferências |
| "Se der problema, **quanto tempo** podemos ficar fora?" | **RTO** (*Recovery Time Objective*) | no máximo **30 minutos** |

> As metas acima são **hipóteses didáticas**. Num banco de verdade, elas
> vêm da análise de impacto no negócio e das exigências que se aplicam à
> instituição, e são aprovadas pelas áreas responsáveis.

Copie o template do relatório, que você vai preenchendo ao longo do lab:

🖥️ **No seu terminal:**

<!-- rodar: shell -->
```bash
make subir
cp -n templates/relatorio_lab2.md entregas/relatorio_lab2.md
make conferir l=1
```

```
...
✅ Lab 1 conferido.
```

Antes de qualquer backup, conheça o estado de partida. Guarde estes números
no relatório:

🐘 **No psql** (`make psql`):

<!-- rodar: producao -->
```sql
SELECT (SELECT count(*) FROM contas)         AS contas,
       (SELECT count(*) FROM transferencias) AS transferencias,
       (SELECT count(*) FROM lancamentos)    AS lancamentos,
       (SELECT sum(saldo) FROM contas)       AS dinheiro_no_banco;
SELECT * FROM auditoria();
```

```
 contas | transferencias | lancamentos | dinheiro_no_banco
--------+----------------+-------------+-------------------
  12000 |         400002 |      812004 |      722365914.27
(1 row)

                  regra                  | ok |                  detalhe
-----------------------------------------+----+--------------------------------------------
 1. saldo = créditos - débitos           | t  | 0 conta(s) divergente(s)
...
```

---

## 2.2 O backup lógico

⏱️ dentro dos 30 min das seções 2.2 e 2.3

**Backup lógico** guarda o banco como **comandos**: "crie esta tabela,
insira estas linhas, crie este índice". A ferramenta é o `pg_dump`. Ele
roda no servidor.

🖥️ **No seu terminal:**

```bash
make bash
```

📦 **No terminal do servidor** (o prompt muda para `postgres@producao`):

<!-- rodar: bash-producao -->
```bash
mkdir -p /backup/dumps && cd /backup/dumps
date '+backup iniciado às %H:%M:%S'
time pg_dump -U sudoers -d banco_sudoers -Fc -f banco_sudoers.dump
pg_dumpall -U sudoers --globals-only -f globais.sql
ls -lh
```

```
backup iniciado às 14:02:10

real	0m2.218s
...
total 29M
-rw-r--r-- 1 postgres postgres 29M Oct 20 14:02 banco_sudoers.dump
-rw-r--r-- 1 postgres postgres 669 Oct 20 14:02 globais.sql
```

**Anote no relatório a hora do backup e o tempo (`real`).**

* `-Fc` é o formato *custom*: compactado e com um **sumário** que permite restaurar só uma parte;
* `pg_dumpall --globals-only` guarda os **usuários**, que pertencem ao servidor e não ao banco: o `pg_dump` não os leva;
* o `pg_dump` **não trava** o banco. Ele lê uma "foto" consistente do instante em que começou. Quem transfere durante o dump transfere normalmente; a transferência só não entra no backup.

O sumário mostra cada objeto que pode ser restaurado separadamente:

<!-- rodar: bash-producao -->
```bash
cd /backup/dumps
pg_restore -l banco_sudoers.dump | grep -E "TABLE|FUNCTION|INDEX" | grep -v "^;"
```

```
229; 1255 16466 FUNCTION banco auditoria() sudoers
...
228; 1255 16464 FUNCTION banco transferir(uuid, bigint, bigint, numeric, text) sudoers
...
221; 1259 16387 TABLE banco clientes sudoers
...
3487; 0 16445 TABLE DATA banco lancamentos sudoers
...
3326; 1259 16492 INDEX banco idx_lancamentos_conta_data sudoers
...
```

> `/backup` é o "storage de backup". Aqui é um volume do Docker, mas em
> produção seria outro equipamento (ou um bucket na nuvem), em **outro**
> lugar. Backup no mesmo disco do banco não é backup.

---

## 2.3 A vida segue

O backup terminou, e os clientes continuam transferindo. Simule 20 segundos
do app.

🖥️ **No seu terminal** (o da sua máquina, fora do servidor):

<!-- rodar: shell -->
```bash
make carga t=20
```

```
Simulando transferencias por 20s, 20 por segundo...
progress: 5.0 s, 21.2 tps, lat 2.423 ms stddev 0.971, 0 failed, lag 0.083 ms
progress: 10.0 s, 20.8 tps, lat 2.280 ms stddev 1.513, 0 failed, lag 0.087 ms
progress: 15.0 s, 20.0 tps, lat 2.340 ms stddev 1.863, 0 failed, lag 0.091 ms
number of transactions actually processed: 403
tps = 20.161491 (without initial connection time)
```

Cerca de **400 transferências** que **não estão** no backup. Anote o número.

---

## 2.4 O incidente

⏱️ dentro dos 35 min das seções 2.4 a 2.7

Um script de "limpeza do ambiente de testes" roda, por engano, na
produção.

📦 **No terminal do servidor:**

<!-- rodar: bash-producao -->
```bash
psql -U sudoers -d banco_sudoers -c "DROP TABLE banco.lancamentos"
date +%s > /tmp/incidente_inicio
date '+incidente às %H:%M:%S'
```

```
DROP TABLE
incidente às 14:04:31
```

O extrato de **todas** as contas sumiu. O relógio do RTO começou a correr:
a hora está guardada em `/tmp/incidente_inicio`.

🐘 **No psql:**

<!-- rodar: producao falha-esperada -->
```sql
SELECT * FROM auditoria();
```

```
ERROR:  relation "lancamentos" does not exist
```

Nem a auditoria roda. Os saldos continuam em `contas`, mas ninguém consegue
provar que estão certos.

---

## 2.5 Restauração isolada

A primeira reação seria restaurar o backup **por cima** da produção. Não
faça isso: você voltaria **todas** as tabelas ao momento do backup e
apagaria as 400 transferências de depois dele. Antes de tocar na produção,
restaure numa **base isolada** e confira se o backup presta.

📦 **No terminal do servidor:**

<!-- rodar: bash-producao -->
```bash
cd /backup/dumps
createdb -U sudoers banco_restaurado
time pg_restore -U sudoers -d banco_restaurado -j 2 banco_sudoers.dump
```

```
real	0m1.350s
...
```

🐘 **No psql**, troque para a cópia (o prompt muda para `banco_restaurado=#`):

<!-- rodar: producao falha-esperada -->
```sql
\c banco_restaurado
SELECT * FROM auditoria();
```

```
You are now connected to database "banco_restaurado" as user "sudoers".
ERROR:  function auditoria() does not exist
```

A função existe, mas no schema `banco`, e a cópia não sabe disso: o
`ALTER DATABASE ... SET search_path` do Lab 1 é uma configuração do
**banco**, e o `pg_dump` não a leva (assim como não leva os usuários). Use o
nome completo:

<!-- rodar: producao -->
```sql
\c banco_restaurado
SELECT * FROM banco.auditoria();
SELECT (SELECT count(*) FROM banco.transferencias) AS transferencias,
       (SELECT count(*) FROM banco.lancamentos)    AS lancamentos,
       (SELECT max(solicitada_em) FROM banco.transferencias) AS ultima_transferencia;
```

```
                  regra                  | ok |                  detalhe
-----------------------------------------+----+--------------------------------------------
 1. saldo = créditos - débitos           | t  | 0 conta(s) divergente(s)
 2. transferência = 1 débito + 1 crédito | t  | 0 transferência(s) sem os dois lançamentos
 3. soma dos saldos = soma dos aportes   | t  | saldos 722365914.27 / aportes 722365914.27
 4. nenhum saldo negativo                | t  | 0 conta(s) negativa(s)
(4 rows)

 transferencias | lancamentos |     ultima_transferencia
----------------+-------------+-------------------------------
         400002 |      812004 | 2026-10-20 14:02:02.17373-03
(1 row)
```

O backup é **íntegro**: as quatro invariantes fecham, com os números da
seção 2.1. A última transferência é de antes do backup. Agora dá para
usá-lo com segurança.

---

## 2.6 Devolvendo só o que sumiu

Da produção sumiu **uma tabela**. Restaure só ela, com tudo o que pertence a
ela: os dados, a chave primária, os índices e as chaves estrangeiras.

📦 **No terminal do servidor:**

<!-- rodar: bash-producao -->
```bash
cd /backup/dumps
pg_restore -l banco_sudoers.dump | grep lancamentos | tee /tmp/so_lancamentos.txt
```

```
227; 1259 16445 TABLE banco lancamentos sudoers
3499; 0 0 COMMENT banco TABLE lancamentos sudoers
226; 1259 16444 SEQUENCE banco lancamentos_id_seq sudoers
3487; 0 16445 TABLE DATA banco lancamentos sudoers
3503; 0 0 SEQUENCE SET banco lancamentos_id_seq sudoers
3329; 2606 16453 CONSTRAINT banco lancamentos lancamentos_pkey sudoers
3326; 1259 16492 INDEX banco idx_lancamentos_conta_data sudoers
3327; 1259 16493 INDEX banco idx_lancamentos_transferencia sudoers
3333; 2606 16454 FK CONSTRAINT banco lancamentos lancamentos_conta_id_fkey sudoers
3334; 2606 16459 FK CONSTRAINT banco lancamentos lancamentos_transferencia_id_fkey sudoers
```

<!-- rodar: bash-producao -->
```bash
pg_restore -U sudoers -d banco_sudoers -L /tmp/so_lancamentos.txt --verbose /backup/dumps/banco_sudoers.dump
```

```
pg_restore: connecting to database for restore
pg_restore: creating TABLE "banco.lancamentos"
...
pg_restore: processing data for table "banco.lancamentos"
...
pg_restore: creating FK CONSTRAINT "banco.lancamentos lancamentos_transferencia_id_fkey"
```

> **Por que não `pg_restore -t lancamentos`?** O `-t` traz só a tabela e os
> dados: sem chave primária, sem índice, sem chave estrangeira. A tabela
> "volta", mas aceita lançamento de conta inexistente e o extrato fica
> lento. É um erro silencioso.

🐘 **No psql**, de volta à produção:

<!-- rodar: producao -->
```sql
\c banco_sudoers
SELECT * FROM auditoria();
```

```
                  regra                  | ok |                   detalhe
-----------------------------------------+----+----------------------------------------------
 1. saldo = créditos - débitos           | f  | 769 conta(s) divergente(s)
 2. transferência = 1 débito + 1 crédito | f  | 397 transferência(s) sem os dois lançamentos
 3. soma dos saldos = soma dos aportes   | t  | saldos 722365914.27 / aportes 722365914.27
 4. nenhum saldo negativo                | t  | 0 conta(s) negativa(s)
(4 rows)
```

A auditoria agora **mede a perda**. As transferências da seção 2.3
aconteceram depois do backup: elas existem em `transferencias` e mexeram nos
saldos, mas os lançamentos delas não estavam no dump.

<!-- rodar: producao -->
```sql
SELECT count(*) AS sem_extrato,
       min(solicitada_em)::time(0) AS primeira,
       max(solicitada_em)::time(0) AS ultima
FROM transferencias t
WHERE NOT EXISTS (SELECT 1 FROM lancamentos l WHERE l.transferencia_id = t.id);
```

```
 sem_extrato | primeira | ultima
-------------+----------+----------
         397 | 14:02:13 | 14:02:32
(1 row)
```

**Essa é a perda observada (o RPO real):** tudo o que aconteceu entre o
backup e o incidente. Anote no relatório. O número bate com a carga da
seção 2.3 (pode faltar uma ou outra: a carga pula as contas bloqueadas).

---

## 2.7 Conciliação e o RTO

Desta vez dá para recuperar a perda: a tabela `transferencias` **não** foi
apagada, e cada linha dela diz origem, destino, valor e hora. Os
lançamentos perdidos podem ser **reconstruídos** a partir dela.

🐘 **No psql:**

<!-- rodar: producao -->
```sql
BEGIN;
INSERT INTO lancamentos (conta_id, transferencia_id, tipo, valor, criado_em)
SELECT v.conta_id, t.id, v.tipo, t.valor, t.solicitada_em
FROM transferencias t
CROSS JOIN LATERAL (VALUES (t.conta_origem_id, 'D'), (t.conta_destino_id, 'C')) AS v(conta_id, tipo)
WHERE NOT EXISTS (SELECT 1 FROM lancamentos l WHERE l.transferencia_id = t.id);
SELECT * FROM auditoria();
COMMIT;
```

```
BEGIN
INSERT 0 794
                  regra                  | ok |                  detalhe
-----------------------------------------+----+--------------------------------------------
 1. saldo = créditos - débitos           | t  | 0 conta(s) divergente(s)
 2. transferência = 1 débito + 1 crédito | t  | 0 transferência(s) sem os dois lançamentos
 3. soma dos saldos = soma dos aportes   | t  | saldos 722365914.27 / aportes 722365914.27
 4. nenhum saldo negativo                | t  | 0 conta(s) negativa(s)
(4 rows)

COMMIT
```

Repare na ordem: a auditoria rodou **dentro** da transação, antes do
`COMMIT`. Se algum `f` aparecesse, um `ROLLBACK` desfaria a conciliação.

> **Atenção:** esta recuperação foi possível porque o **modelo** guarda a
> transferência separada do lançamento, não porque o backup foi bom. Se o
> incidente tivesse apagado `transferencias`, as 400 transferências estariam
> perdidas de verdade. Num banco real, a conciliação passa por aprovação
> e por outras fontes (os registros do app, por exemplo).

Pare o relógio.

📦 **No terminal do servidor:**

<!-- rodar: bash-producao -->
```bash
echo "RTO observado: $(( $(date +%s) - $(cat /tmp/incidente_inicio) )) segundos"
```

```
RTO observado: 412 segundos
```

Anote no relatório. Esse é o tempo entre o incidente e a produção íntegra
de novo, com você lendo o roteiro. Ele inclui decidir o que fazer, e não
só os comandos.

**📍 Checkpoint 2.7:** produção íntegra e cópia isolada conferida. Se a aula
acabar aqui, `make derruba` guarda tudo.

---

## 2.8 Cifrando o backup

⏱️ dentro dos 30 min das seções 2.8 e 2.9

O dump de agora há pouco está em `/backup` **em claro**. Quem tiver acesso
ao storage de backup lê o banco inteiro: nomes, CPFs, rendas, saldos. Isso
vale para um funcionário curioso, para o fornecedor do storage ou para um
bucket mal configurado. Veja:

📦 **No terminal do servidor:**

<!-- rodar: bash-producao -->
```bash
pg_restore -f - --data-only -t clientes /backup/dumps/banco_sudoers.dump | grep -A2 "^COPY"
```

```
COPY banco.clientes (id, nome, cpf, email, telefone, data_nascimento, renda_mensal, criado_em) FROM stdin;
1	Vinicius Lima Nascimento	10000003710	cliente1@exemplo.com	(00) 90643-0942	1961-10-03	9142.87	2025-09-06 15:10:12.507231-03
2	Vinicius Carvalho Moreira	10000007460	cliente2@exemplo.com	(00) 98383-8274	1957-03-11	3921.32	2025-09-12 15:22:10.914422-03
```

> **Compactação não é criptografia.** O formato `-Fc` é compactado, e o
> `pg_restore` abriu sem pedir nada. Qualquer um com o arquivo faz o mesmo.

A chave do backup vai para o **cofre** (`/cofre`), um volume **diferente**
do storage de backup (`/backup`):

<!-- rodar: bash-producao -->
```bash
openssl rand -base64 32 > /cofre/chave_backup
chmod 600 /cofre/chave_backup
ls -l /cofre
```

```
total 4
-rw------- 1 postgres postgres 45 Oct 20 14:10 chave_backup
```

Agora o backup sai do `pg_dump` direto para o `gpg`, que cifra com AES-256.
O arquivo em claro nem chega a ser gravado:

<!-- rodar: bash-producao -->
```bash
cd /backup/dumps
time (pg_dump -U sudoers -d banco_sudoers -Fc \
  | gpg --batch --yes --symmetric --cipher-algo AES256 --compress-algo none \
        --passphrase-file /cofre/chave_backup -o banco_sudoers.dump.gpg)
rm banco_sudoers.dump
ls -lh
```

```
real	0m3.278s
...
total 29M
-rw-r--r-- 1 postgres postgres 29M Oct 20 14:11 banco_sudoers.dump.gpg
-rw-r--r-- 1 postgres postgres 669 Oct 20 14:02 globais.sql
```

* `--compress-algo none`: o `-Fc` já compactou. **Compacte antes de cifrar**: dado cifrado parece aleatório e não compacta mais;
* `rm banco_sudoers.dump`: a cópia em claro de antes sai do storage. Uma cópia esquecida anula a proteção de todas as outras.

### O ladrão do storage de backup

Simule alguém que conseguiu **só** o volume de backup, sem o cofre. Ele
monta o volume num container qualquer e tenta ler.

🖥️ **No seu terminal** (o da sua máquina):

<!-- rodar: shell falha-esperada -->
```bash
docker run --rm -v database_engineer_banco_backup:/backup postgres:17 \
  bash -c "ls /backup/dumps; head -c 64 /backup/dumps/banco_sudoers.dump.gpg | od -c | head -2; pg_restore -l /backup/dumps/banco_sudoers.dump.gpg"
```

```
banco_sudoers.dump.gpg
globais.sql
0000000 214  \r 004  \t 003  \b ...
...
pg_restore: error: input file does not appear to be a valid archive
```

Ele tem o arquivo, mas não tem a chave: o arquivo é ruído. É por isso que
cópia e chave moram em lugares diferentes.

> Neste lab, o cofre está montado no mesmo servidor por praticidade. Em
> produção, a chave fica num cofre de segredos ou num serviço de chaves
> (KMS, HSM), com outras pessoas responsáveis. E a **própria chave** precisa
> de cópia segura: perder a chave é perder todos os backups cifrados com
> ela.

### A criptografia também denuncia adulteração

📦 **No terminal do servidor:**

<!-- rodar: bash-producao -->
```bash
cp /backup/dumps/banco_sudoers.dump.gpg /tmp/adulterado.gpg
printf 'XXXX' | dd of=/tmp/adulterado.gpg bs=1 seek=1000000 conv=notrunc status=none
gpg --batch --decrypt --passphrase-file /cofre/chave_backup /tmp/adulterado.gpg > /dev/null || echo "recusado"
echo "senha-errada" > /tmp/errada
gpg --batch --decrypt --passphrase-file /tmp/errada /backup/dumps/banco_sudoers.dump.gpg > /dev/null || echo "recusado"
rm /tmp/adulterado.gpg /tmp/errada
```

```
gpg: AES256.CFB encrypted data
gpg: encrypted with 1 passphrase
gpg: WARNING: encrypted message has been manipulated!
recusado
gpg: AES256.CFB encrypted data
gpg: encrypted with 1 passphrase
gpg: decryption failed: Bad session key
recusado
```

Quatro bytes trocados num arquivo de 29 MB, e o `gpg` percebeu. Com a chave
errada, nada sai.

---

## 2.9 Restaurando o backup cifrado

Backup que nunca foi restaurado é só uma esperança. Recrie a cópia isolada
a partir do arquivo cifrado:

📦 **No terminal do servidor:**

<!-- rodar: bash-producao -->
```bash
dropdb -U sudoers banco_restaurado
createdb -U sudoers banco_restaurado
time (gpg --batch --decrypt --passphrase-file /cofre/chave_backup /backup/dumps/banco_sudoers.dump.gpg \
  | pg_restore -U sudoers -d banco_restaurado)
psql -U sudoers -d banco_restaurado -c "SELECT * FROM banco.auditoria()"
```

```
gpg: AES256.CFB encrypted data
gpg: encrypted with 1 passphrase

real	0m2.078s
...
                  regra                  | ok |                  detalhe
-----------------------------------------+----+--------------------------------------------
 1. saldo = créditos - débitos           | t  | 0 conta(s) divergente(s)
 2. transferência = 1 débito + 1 crédito | t  | 0 transferência(s) sem os dois lançamentos
 3. soma dos saldos = soma dos aportes   | t  | saldos 722365914.27 / aportes 722365914.27
 4. nenhum saldo negativo                | t  | 0 conta(s) negativa(s)
(4 rows)
```

O backup cifrado volta íntegro. O dado decifrado passou direto para o
`pg_restore`, sem ficar gravado em claro no disco.

> **Por que restaurar numa base isolada também aqui?** Com o `|`, o
> `pg_restore` vai gravando enquanto o `gpg` decifra. Se o arquivo estiver
> adulterado, o `gpg` só reclama **no fim**, e a base já recebeu parte dos
> dados. Numa base isolada, isso não estraga nada: é só apagar e recomeçar.

---

## 2.10 Conexão com TLS

⏱️ 35 min

O backup está protegido. E o caminho entre o app e o banco? Hoje, quem
conecta pela rede conversa **em claro**: senha e dados passam legíveis por
qualquer equipamento no caminho. Confira: conecte pela rede (`host=producao`)
e pergunte se a conexão está cifrada.

📦 **No terminal do servidor:**

<!-- rodar: bash-producao -->
```bash
psql "host=producao dbname=banco_sudoers user=sudoers sslmode=disable" \
  -c "SELECT ssl FROM pg_stat_ssl WHERE pid = pg_backend_pid()"
```

```
 ssl
-----
 f
(1 row)
```

`f`: sem criptografia. O TLS precisa de duas coisas:

* um **certificado** para o servidor, assinado por uma **autoridade certificadora (AC)** em que o cliente confia;
* a regra, no servidor, de **recusar** quem chegar sem TLS.

### A autoridade certificadora de treinamento

Num banco de verdade, a AC é da área de segurança da empresa. Aqui você
cria uma de treinamento. A chave dela (`ac.key`) é o segredo mais valioso
deste lab: quem a tem emite certificados em que todos confiam. Ela vai para
o cofre.

<!-- rodar: bash-producao -->
```bash
mkdir -p /cofre/ac && cd /cofre/ac
openssl req -quiet -x509 -newkey rsa:2048 -nodes -days 90 \
  -subj "/CN=AC de Treinamento - Banco Sudoers" -keyout ac.key -out ac.crt
ls -l /cofre/ac
```

```
-----
total 8
-rw-r--r-- 1 postgres postgres 1180 Oct 20 14:15 ac.crt
-rw------- 1 postgres postgres 1704 Oct 20 14:15 ac.key
```

`ac.crt` é **público**: todo cliente recebe uma cópia para conferir o
servidor. `ac.key` nunca sai do cofre.

### O certificado do servidor

O servidor gera a **sua** chave (que nunca sai dele) e um pedido de
certificado (CSR). A AC assina o pedido. O certificado vale para os nomes
pelos quais os clientes chamam o servidor (`producao` e `localhost`).

<!-- rodar: bash-producao -->
```bash
mkdir -p "$PGDATA/tls" && cd "$PGDATA/tls"
openssl req -quiet -newkey rsa:2048 -nodes -subj "/CN=producao" -keyout servidor.key -out servidor.csr
printf "subjectAltName=DNS:producao,DNS:localhost\n" > san.txt
openssl x509 -req -in servidor.csr -CA /cofre/ac/ac.crt -CAkey /cofre/ac/ac.key -CAcreateserial \
  -days 90 -extfile san.txt -out servidor.crt
chmod 600 servidor.key
openssl x509 -in servidor.crt -noout -subject -issuer -ext subjectAltName -enddate
```

```
-----
Certificate request self-signature ok
subject=CN=producao
subject=CN=producao
issuer=CN=AC de Treinamento - Banco Sudoers
X509v3 Subject Alternative Name:
    DNS:producao, DNS:localhost
notAfter=Jan 18 17:15:32 2027 GMT
```

> O `chmod 600` não é detalhe: o PostgreSQL **recusa** usar uma chave que
> outros usuários do sistema consigam ler.

### Ligando o TLS e fechando a porta sem TLS

🐘 **No psql** (`\c banco_sudoers` se ainda estiver na cópia):

<!-- rodar: producao -->
```sql
ALTER SYSTEM SET ssl = on;
ALTER SYSTEM SET ssl_cert_file = 'tls/servidor.crt';
ALTER SYSTEM SET ssl_key_file = 'tls/servidor.key';
SELECT pg_reload_conf();
SELECT pg_sleep(1);
SHOW ssl;
```

```
...
 ssl
-----
 on
(1 row)
```

O TLS está **disponível**, mas ainda é opcional. Quem decide quem entra e
como é o `pg_hba.conf`, lido de cima para baixo, onde a primeira regra que
casa vence. Coloque duas regras no topo:

📦 **No terminal do servidor:**

<!-- rodar: bash-producao -->
```bash
sed -i "1i hostssl   all all all scram-sha-256" "$PGDATA/pg_hba.conf"
sed -i "1i hostnossl all all all reject" "$PGDATA/pg_hba.conf"
sed -i "1i # Lab 2: conexoes pela rede so com TLS" "$PGDATA/pg_hba.conf"
head -3 "$PGDATA/pg_hba.conf"
psql -U sudoers -d banco_sudoers -c "SELECT pg_reload_conf()"
```

```
# Lab 2: conexoes pela rede so com TLS
hostnossl all all all reject
hostssl   all all all scram-sha-256
 pg_reload_conf
----------------
 t
(1 row)
```

* `hostnossl ... reject`: conexão pela rede **sem** TLS é recusada;
* `hostssl ... scram-sha-256`: conexão **com** TLS ainda precisa de senha. TLS protege o caminho, não substitui a autenticação.

### Testes: o negativo e os positivos

O mesmo comando do começo da seção, sem TLS, agora **deve falhar**:

<!-- rodar: bash-producao falha-esperada -->
```bash
psql "host=producao dbname=banco_sudoers user=sudoers sslmode=disable" -c "SELECT 1"
```

```
psql: error: connection to server at "producao" (172.22.0.2), port 5432 failed: FATAL:  pg_hba.conf rejects connection for host "172.22.0.2", user "sudoers", database "banco_sudoers", no encryption
```

Com TLS **e** verificação completa da identidade do servidor
(`verify-full`):

<!-- rodar: bash-producao -->
```bash
psql "host=producao dbname=banco_sudoers user=sudoers sslmode=verify-full sslrootcert=/cofre/ac/ac.crt" \
  -c "SELECT ssl, version, cipher FROM pg_stat_ssl WHERE pid = pg_backend_pid()" -c "\conninfo"
```

```
 ssl | version |         cipher
-----+---------+------------------------
 t   | TLSv1.3 | TLS_AES_256_GCM_SHA384
(1 row)

You are connected to database "banco_sudoers" as user "sudoers" on host "producao" (address "172.22.0.2") at port "5432".
SSL connection (protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384, compression: off, ALPN: postgresql)
```

O `verify-full` confere duas coisas: que o certificado foi assinado pela AC
(`sslrootcert`) **e** que ele vale para o nome que você digitou. Teste o
segundo ponto chamando o **mesmo** servidor por outro nome, o IP:

<!-- rodar: bash-producao falha-esperada -->
```bash
psql "host=127.0.0.1 dbname=banco_sudoers user=sudoers sslmode=verify-full sslrootcert=/cofre/ac/ac.crt" -c "SELECT 1"
```

```
psql: error: connection to server at "127.0.0.1", port 5432 failed: server certificate for "producao" (and 2 other names) does not match host name "127.0.0.1"
```

Recusado: o certificado não vale para "127.0.0.1". É essa checagem que
impede um impostor no meio do caminho de se passar pelo servidor.

| `sslmode` do cliente | Cifra? | Confere a AC? | Confere o nome? | Protege contra impostor? |
|---|---|---|---|---|
| `disable` | não | — | — | não (e agora é recusado) |
| `require` | sim | não | não | **não**: cifra a conversa com quem quer que responda |
| `verify-ca` | sim | sim | não | em parte |
| `verify-full` | sim | sim | sim | **sim**. Use este |

> O seu cliente gráfico (DBeaver, pgAdmin) na porta 5470 também passa a
> precisar de TLS. Nas opções de SSL dele, aponte o "CA certificate" para
> uma cópia do `ac.crt`.

---

## 2.11 Proteção em repouso

⏱️ 20 min

E o dado **parado no disco**? O volume do Docker é só uma pasta da sua
máquina. Ele **não** cifra nada. Procure o CPF de um cliente direto no
arquivo da tabela:

📦 **No terminal do servidor:**

<!-- rodar: bash-producao -->
```bash
cd "$PGDATA"
ARQUIVO=$(psql -U sudoers -d banco_sudoers -Atc "SELECT pg_relation_filepath('banco.clientes')")
CPF=$(psql -U sudoers -d banco_sudoers -Atc "SELECT cpf FROM banco.clientes WHERE id = 1")
echo "arquivo: $ARQUIVO   CPF procurado: $CPF"
grep -a -o "$CPF" "$ARQUIVO" | head -1
```

```
arquivo: base/16384/16479   CPF procurado: 10000003710
10000003710
```

Quem copiar o disco (ou o volume) lê o CPF sem senha nenhuma: o banco nem
precisa estar ligado.

### Cifrando um campo: a renda

A renda do cliente é dado financeiro sensível para o negócio, e o app só a
usa em análises de crédito, não no dia a dia. Ela será guardada
**cifrada**, com a extensão `pgcrypto` e uma chave **que não fica no
banco**: ela fica no cofre e só passa pelo SQL na hora de usar.

📦 **No terminal do servidor:**

<!-- rodar: bash-producao -->
```bash
openssl rand -base64 32 > /cofre/chave_campos
chmod 600 /cofre/chave_campos
```

🐘 **No psql**, o `\set` lê a chave do cofre para uma variável do psql (o
arquivo não vai para o banco):

<!-- rodar: producao -->
```sql
\set chave `cat /cofre/chave_campos`
CREATE EXTENSION IF NOT EXISTS pgcrypto;
ALTER TABLE clientes ADD COLUMN renda_cifrada bytea;
UPDATE clientes SET renda_cifrada = pgp_sym_encrypt(renda_mensal::text, :'chave', 'cipher-algo=aes256')
WHERE renda_mensal IS NOT NULL;
ALTER TABLE clientes DROP COLUMN renda_mensal;
VACUUM FULL clientes;
SELECT id, nome, left(renda_cifrada::text, 34) || '...' AS renda_cifrada FROM clientes WHERE id <= 3 ORDER BY id;
```

```
CREATE EXTENSION
ALTER TABLE
UPDATE 10000
ALTER TABLE
VACUUM
 id |           nome            |             renda_cifrada
----+---------------------------+---------------------------------------
  1 | Vinicius Lima Nascimento  | \xc30d0409030281e939ae5ce84e9871d2...
  2 | Vinicius Carvalho Moreira | \xc30d04090302df40b12a480b6b2278d2...
  3 | Carla Barbosa Gomes       | \xc30d0409030286fac025d381dd5b61d2...
(3 rows)
```

O `VACUUM FULL` reescreve o arquivo da tabela. Sem ele, as versões antigas
das linhas, **com a renda em claro**, continuariam no disco até serem
reaproveitadas.

Quem tem a chave lê. Quem não tem, não:

<!-- rodar: producao -->
```sql
\set chave `cat /cofre/chave_campos`
SELECT id, nome, pgp_sym_decrypt(renda_cifrada, :'chave')::numeric(12,2) AS renda_mensal
FROM clientes WHERE id <= 3 ORDER BY id;
```

```
 id |           nome            | renda_mensal
----+---------------------------+--------------
  1 | Vinicius Lima Nascimento  |      9142.87
  2 | Vinicius Carvalho Moreira |      3921.32
  3 | Carla Barbosa Gomes       |     35956.81
(3 rows)
```

<!-- rodar: producao falha-esperada -->
```sql
SELECT pgp_sym_decrypt(renda_cifrada, 'chutei-uma-chave') FROM clientes WHERE id = 1;
```

```
ERROR:  Wrong key or corrupt data
```

### Os limites (leia com atenção)

Cifrar um campo **não** é cifrar o banco:

* **o resto continua em claro** no disco: nome, CPF, e-mail, saldos e o extrato (o `grep` de agora há pouco ainda acha o CPF);
* **a chave passa pelo SQL**: ela aparece no texto do comando e pode cair em log (`log_statement`), no `pg_stat_activity` ou no histórico do psql. Em produção, quem cifra e decifra costuma ser a **aplicação**, com a chave vinda de um KMS, e o banco só guarda o resultado;
* **o passado não some**: o backup cifrado da seção 2.8 foi feito **antes** e guarda a renda em claro lá dentro, assim como o WAL antigo. Proteção nova não corrige cópia velha: ela precisa ser refeita ou expirada;
* **campo cifrado não se pesquisa**: não dá para filtrar, ordenar ou indexar pela renda sem decifrar cada linha;
* **quem tem a chave e acesso ao banco vê tudo**: a proteção é contra quem leva o disco ou o backup, não contra um usuário autorizado.

### A alternativa de infraestrutura: cifrar o volume

A proteção do **disco inteiro** é feita fora do banco, pela infraestrutura.
Ela não exige mudar nenhuma tabela, mas também não protege contra quem
acessa o banco ligado:

| Onde | Como | O que protege |
|---|---|---|
| Notebook Windows | BitLocker | disco perdido ou roubado, com a máquina desligada |
| Notebook Mac | FileVault | idem |
| Servidor Linux | LUKS (dm-crypt) no volume do PostgreSQL | disco descartado ou roubado |
| Nuvem | disco ou bucket cifrado com chave do KMS do provedor | mídia física do provedor; acesso à chave fica auditado |
| Dentro do banco | *TDE* (cifra os arquivos de dados inteiros) | arquivos copiados do servidor. O PostgreSQL da comunidade **não** tem TDE; algumas distribuições e extensões de terceiros oferecem |

Nada disso é exigido neste lab: são mudanças de administrador na máquina.
Discuta na apresentação qual combinação você recomendaria para o Banco
Sudoers.

> **Não confunda:** volume do Docker não é criptografia; compactação
> (`-Fc`, `gzip`) não é criptografia; e **hash de senha** (o `SCRAM-SHA-256`
> do `pg_hba.conf`) protege a senha guardada, não os dados.

---

## 2.12 Revisão e evidências

⏱️ 15 min

Complete o `entregas/relatorio_lab2.md`: os tempos, a perda observada, a
comparação com as metas da seção 2.1 e onde está cada chave. Depois confira:

🖥️ **No seu terminal:**

<!-- rodar: shell -->
```bash
make conferir l=2
```

```
Conferindo o Lab 2 - Backup, recuperação e criptografia

  ✅ usuários e senhas: /backup/dumps/globais.sql
  ✅ backup cifrado: /backup/dumps/banco_sudoers.dump.gpg
  ✅ a chave do cofre abre o backup cifrado
  ✅ chave no cofre (/cofre), longe das cópias (/backup)
  ✅ cópia isolada banco_restaurado: as 4 invariantes financeiras fecham
  ✅ produção (depois do incidente): as 4 invariantes financeiras fecham
  ✅ TLS ligado no servidor (ssl = on)
  ✅ conexão pela rede sem TLS é recusada (pg_hba.conf)
  ✅ conexão com verify-full: certificado e nome do servidor validados
  ✅ renda guardada cifrada (renda_cifrada) e a chave do cofre abre
  ✅ entregável: entregas/relatorio_lab2.md

✅ Lab 2 conferido.
```

Saia do psql (`\q`) e do terminal do servidor (`exit`). Ao fim da aula:
`make derruba`.

### Para a discussão

1. A perda observada cumpriu a meta de RPO de 5 minutos? Com um dump por noite, qual seria o RPO? (A resposta leva ao **PITR**, a recuperação até um instante qualquer com arquivamento de WAL. Fica como estudo complementar.)
2. O RTO medido inclui ler o roteiro e decidir. O que você automatizaria para cumprir os 30 minutos num banco de 1 TB?
3. Onde ficaria cada chave (backup, campos, AC) num banco de verdade? Quem teria acesso a cada uma?

---

## 📦 Entregáveis e avaliação

| Entregável | Onde | O que se avalia |
|---|---|---|
| Relatório de recuperação | `entregas/relatorio_lab2.md` | tempos e perda medidos, comparação honesta com as metas, local de cada chave |
| Recuperação comprovada | `make conferir l=2` | cópia isolada e produção com as 4 invariantes fechando |
| Controles de criptografia | `make conferir l=2` | backup cifrado e restaurável, TLS com `verify-full`, renda cifrada |

## 🆘 Erros comuns

| O que apareceu | O que é | O que fazer |
|---|---|---|
| `database "banco_restaurado" already exists` | Você já tinha restaurado antes | `dropdb -U sudoers banco_restaurado` e repita |
| `function auditoria() does not exist` na cópia | O `search_path` não vem no dump (seção 2.5) | Use `banco.auditoria()` |
| `relation "lancamentos" already exists` no `pg_restore -L` | A tabela já foi devolvida | Siga para a seção 2.7 |
| `gpg: decryption failed: Bad session key` | Chave errada, ou o arquivo foi cifrado com outra chave | Confira `/cofre/chave_backup`; se você a recriou, cifre de novo (seção 2.8) |
| `ssl` continua `off` depois do reload | Arquivo de certificado ou chave com problema | `make logs` mostra o motivo (ex.: permissão da chave: `chmod 600`) |
| `FATAL: pg_hba.conf rejects connection ... no encryption` | É o esperado sem TLS (seção 2.10) | Conecte com `sslmode=verify-full` |
| `does not match host name` | Você conectou por um nome que não está no certificado | Use `host=producao` (ou `localhost`) |
| `cat: /cofre/chave_campos: No such file` no `\set` | Faltou criar a chave (início da seção 2.11) | Rode o bloco do `openssl rand` no terminal do servidor |
| O DBeaver parou de conectar | A porta agora exige TLS | Ative SSL no DBeaver com o `ac.crt` como CA |

Mais em [docs/faq.md](../../docs/faq.md).

---

# ➡️ Continue em [Lab 3 — Governança, acessos e consolidação](../3_governanca/README.md)
