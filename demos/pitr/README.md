# 🎬 Demonstração — WAL, backup físico e PITR

> ⬅️ [README principal](../../README.md) · Roteiro de apoio da **Aula 03** (ciclo de vida, backup e recuperação) · ⏱️ ~30 min

> **A pergunta do banco:** "O dump da noite passada não cumpre a meta de
> perder no máximo 5 minutos. Como voltar o banco ao segundo **anterior** ao
> incidente?"

Esta demonstração é conduzida pelo **instrutor**, com a tela compartilhada,
na aula teórica de ciclo de vida e backup. O aluno pode repeti-la depois, por
conta própria: ela não faz parte de nenhum `make conferir` e **não mexe** no
banco dos labs.

**Pré-requisito:** o Lab 1 concluído (`make conferir l=1`). Faltou? Rode
`make gabarito l=1`. Precisa de ~1 GB livre de disco.

| Seção | O que acontece | Tempo |
|---|---|---|
| [D.1](#d1-os-conceitos) | WAL, backup físico, arquivamento e PITR | 5 min |
| [D.2](#d2-uma-produção-de-demonstração-com-arquivamento) | Uma cópia da produção, com arquivamento de WAL ligado | 5 min |
| [D.3](#d3-o-backup-físico) | O backup físico com `pg_basebackup` | 3 min |
| [D.4](#d4-a-vida-segue-e-o-incidente) | Transferências depois do backup, o "ponto bom" e o incidente | 5 min |
| [D.5](#d5-a-recuperação-até-um-instante) | A recuperação até o instante anterior ao incidente | 7 min |
| [D.6](#d6-discussão-e-limpeza) | Discussão: RPO, réplica não é backup; limpeza | 5 min |

---

## D.1 Os conceitos

| Conceito | O que é |
|---|---|
| **WAL** (*write-ahead log*) | o diário do PostgreSQL: toda mudança é escrita nele **antes** de ir para as tabelas. É o que garante a durabilidade depois de uma queda |
| **Backup físico** | cópia dos **arquivos** do banco (`pg_basebackup`), e não dos comandos, como o `pg_dump`. Volta o servidor inteiro, mais rápido em bancos grandes |
| **Arquivamento de WAL** | cada pedaço de WAL completo (um *segmento*, 16 MB) é copiado para fora do servidor pelo `archive_command` |
| **PITR** (*point-in-time recovery*) | restaurar o backup físico e **reaplicar** o WAL arquivado até um instante escolhido (`recovery_target_time`) |

Com só o `pg_dump` (Lab 2), o RPO é o tempo desde o último dump. Com backup
físico **e** WAL arquivado, o RPO cai para o que ainda não foi arquivado:
minutos, ou segundos.

> **Por que uma "produção de demonstração"?** Ligar o arquivamento exige
> reiniciar o servidor, e o incidente desta demonstração apagaria o extrato
> do banco dos labs. Por isso tudo acontece numa **cópia** da produção, com
> outra porta, dentro do mesmo container. O banco dos labs não é tocado.

---

## D.2 Uma produção de demonstração, com arquivamento

🖥️ **No seu terminal:**

```bash
make subir
make bash
```

📦 **No terminal do servidor** (o prompt muda para `postgres@producao`).
Primeiro, a cópia da produção (é um backup físico também) e a pasta que faz
o papel do *storage* de WAL:

<!-- rodar: bash-producao -->
```bash
D=/var/lib/postgresql/pitr_demo
rm -rf "$D" && mkdir -p "$D/wal_arquivado"
pg_basebackup -U sudoers -D "$D/prod" -X stream -c fast
du -sh "$D/prod"
```

```
253M	/var/lib/postgresql/pitr_demo/prod
```

Agora as configurações da cópia: outra porta, só conexões locais e o
**arquivamento ligado**. O `archive_command` copia cada segmento de WAL para
`wal_arquivado` e se recusa a sobrescrever um que já esteja lá.

<!-- rodar: bash-producao -->
```bash
D=/var/lib/postgresql/pitr_demo
cat >> "$D/prod/postgresql.auto.conf" <<EOF
port = 5433
listen_addresses = ''
unix_socket_directories = '/tmp'
archive_mode = on
archive_command = 'test ! -f $D/wal_arquivado/%f && cp %p $D/wal_arquivado/%f'
archive_timeout = 60
EOF
pg_ctl -D "$D/prod" -l "$D/prod.log" start -w
psql -h /tmp -p 5433 -U sudoers -d banco_sudoers -c "SHOW archive_mode" -c "SELECT * FROM auditoria()"
```

```
waiting for server to start.... done
server started
 archive_mode
--------------
 on
(1 row)

                  regra                  | ok |                  detalhe
-----------------------------------------+----+--------------------------------------------
 1. saldo = créditos - débitos           | t  | 0 conta(s) divergente(s)
...
```

`archive_timeout = 60`: mesmo com pouco movimento, um segmento é arquivado
pelo menos a cada 60 segundos. **É esse número que define o RPO.**

---

## D.3 O backup físico

O backup da noite. Sai em formato `tar` compactado (`-Ft -z`), com o WAL
necessário para ele ser consistente sozinho (`-X fetch`):

<!-- rodar: bash-producao -->
```bash
D=/var/lib/postgresql/pitr_demo
date '+backup físico às %H:%M:%S'
time pg_basebackup -h /tmp -p 5433 -U sudoers -D "$D/base" -Ft -z -X fetch -c fast
ls -lh "$D/base"
```

```
backup físico às 15:37:47
...
-rw------- 1 postgres postgres 183K Oct 20 15:37 backup_manifest
-rw------- 1 postgres postgres  68M Oct 20 15:37 base.tar.gz
```

Compare com o dump do Lab 2: aqui vão os **arquivos** do servidor (tabelas,
índices, configuração), e não comandos SQL.

---

## D.4 A vida segue, e o incidente

Os clientes continuam transferindo **depois** do backup. Cinquenta
transferências de R$ 1,00:

<!-- rodar: bash-producao -->
```bash
P="psql -h /tmp -p 5433 -U sudoers -d banco_sudoers -At"
$P -c "SELECT count(transferir(gen_random_uuid(), origem, destino, 1.00))
       FROM (SELECT o.id AS origem, d.id AS destino
             FROM contas o JOIN contas d ON d.id = o.id + 1
             WHERE o.status = 'ativa' AND d.status = 'ativa' AND o.saldo >= 1
             ORDER BY o.id LIMIT 50) AS pares"
$P -c "SELECT count(*) || ' transferências no banco de demonstração' FROM transferencias"
```

```
50
400141 transferências no banco de demonstração
```

Anote o número (o seu será outro: depende do que você já fez nos labs). Agora marque o **ponto bom**, o último instante em que o
banco estava certo:

<!-- rodar: bash-producao -->
```bash
D=/var/lib/postgresql/pitr_demo
sleep 2
psql -h /tmp -p 5433 -U sudoers -d banco_sudoers -Atc "SELECT now()" | tee "$D/ponto_bom"
sleep 2
```

```
2026-10-20 15:37:58.453418-03
```

E o mesmo script de limpeza do Lab 2 roda, por engano, na produção de
demonstração:

<!-- rodar: bash-producao -->
```bash
D=/var/lib/postgresql/pitr_demo
P="psql -h /tmp -p 5433 -U sudoers -d banco_sudoers -At"
$P -c "DROP TABLE banco.lancamentos"
$P -c "SELECT pg_switch_wal()" > /dev/null
sleep 3
ls "$D/wal_arquivado"
```

```
DROP TABLE
000000010000000000000018
...
00000001000000000000001F.00000028.backup
000000010000000000000020
```

O `pg_switch_wal()` fecha o segmento atual na hora, para ele ser arquivado
sem esperar os 60 segundos. Num incidente real, o WAL do momento do
`DROP` chega ao arquivo em até `archive_timeout`.

> Um `pg_dump` restaurado agora devolveria o extrato, mas **perderia as 50
> transferências** feitas depois do backup. É o RPO do Lab 2.

---

## D.5 A recuperação até um instante

Restaure o backup físico numa pasta nova e diga ao PostgreSQL **de onde**
buscar o WAL (`restore_command`) e **até quando** reaplicar
(`recovery_target_time`). O arquivo `recovery.signal` é o que liga o modo de
recuperação. O servidor recuperado sobe em outra porta, a 5434: a produção de
demonstração fica como está, para comparar.

<!-- rodar: bash-producao -->
```bash
D=/var/lib/postgresql/pitr_demo
mkdir -p "$D/recuperado" && chmod 700 "$D/recuperado"
tar xzf "$D/base/base.tar.gz" -C "$D/recuperado"
cat >> "$D/recuperado/postgresql.auto.conf" <<EOF
port = 5434
archive_mode = off
restore_command = 'cp $D/wal_arquivado/%f %p'
recovery_target_time = '$(cat "$D/ponto_bom")'
recovery_target_action = 'promote'
EOF
touch "$D/recuperado/recovery.signal"
time pg_ctl -D "$D/recuperado" -l "$D/recuperado.log" start -w -t 120
grep -E "starting point-in-time recovery|recovery stopping" "$D/recuperado.log" | cut -c1-140
```

```
waiting for server to start.... done
server started
... LOG:  starting point-in-time recovery to 2026-10-20 15:37:58.453418-03
... LOG:  recovery stopping before commit of transaction 906, time 2026-10-20 15:38:00.481977-03

real	0m0.615s
```

O log conta a história: começou a recuperação até o ponto bom e **parou
antes** da transação do `DROP TABLE`. Confira o banco recuperado:

<!-- rodar: bash-producao -->
```bash
psql -h /tmp -p 5434 -U sudoers -d banco_sudoers \
  -c "SELECT count(*) || ' transferências no banco recuperado' AS transferencias FROM transferencias" \
  -c "SELECT * FROM auditoria()"
```

```
             transferencias
-----------------------------------------
 400141 transferências no banco recuperado
(1 row)

                  regra                  | ok |                  detalhe
-----------------------------------------+----+--------------------------------------------
 1. saldo = créditos - débitos           | t  | 0 conta(s) divergente(s)
 2. transferência = 1 débito + 1 crédito | t  | 0 transferência(s) sem os dois lançamentos
 3. soma dos saldos = soma dos aportes   | t  | saldos 722365914.27 / aportes 722365914.27
 4. nenhum saldo negativo                | t  | 0 conta(s) negativa(s)
(4 rows)
```

O mesmo número de transferências da seção D.4, **incluindo as 50 feitas
depois do backup**, e o extrato de volta, com as quatro invariantes
fechando. A perda foi zero, porque o ponto bom estava num segmento já
arquivado.

---

## D.6 Discussão e limpeza

Perguntas para a turma:

1. Qual o RPO desta configuração? (O que não foi arquivado: até `archive_timeout`, aqui 60 s. E se o servidor e o `wal_arquivado` estiverem no mesmo disco e ele queimar?)
2. **Réplica não é backup.** Se a produção tivesse uma réplica em tempo real, o `DROP TABLE` chegaria nela em milissegundos. Para que serve a réplica, então? (Disponibilidade e RTO, não recuperação de erro lógico.)
3. Por quanto tempo guardar o WAL arquivado? Ele só serve junto com um backup físico anterior a ele. Quem define a retenção? (Ligação com o ciclo de vida do dado.)
4. O RTO aqui foi o tempo do `pg_ctl start`. Num banco de 1 TB, o que domina esse tempo? (Restaurar a base e reaplicar o WAL; por isso backups físicos frequentes.)
5. Em produção, ninguém escreve `archive_command` com `cp`: usa-se uma ferramenta (pgBackRest, Barman) ou o PITR gerenciado do provedor de nuvem, com o arquivo **cifrado** e **em outro lugar**. O que os Labs 2 e 3 ensinaram que vale aqui também?

Limpeza (no terminal do servidor). Os dois servidores de demonstração
param, e a pasta é apagada; o banco dos labs continua como estava:

<!-- rodar: bash-producao -->
```bash
D=/var/lib/postgresql/pitr_demo
pg_ctl -D "$D/recuperado" stop -m fast
pg_ctl -D "$D/prod" stop -m fast
rm -rf "$D"
psql -U sudoers -d banco_sudoers -Atc "SELECT 'banco dos labs intacto: ' || ok FROM auditoria() WHERE regra LIKE '2%'"
```

```
waiting for server to shut down.... done
server stopped
waiting for server to shut down.... done
server stopped
banco dos labs intacto: true
```

> Esqueceu a limpeza? `make consertar` recria o container e os servidores
> de demonstração somem junto (a pasta não fica em volume nenhum). O banco
> dos labs, que está no volume, não é afetado.
