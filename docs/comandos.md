# ⌨️ Comandos

> ⬅️ [README principal](../README.md)

Todo `make` é só um atalho. Esta é a lista, com o comando `docker` que ele
roda por baixo: útil para entender o que acontece e para quando o `make`
não estiver disponível.

## Ambiente

| Atalho | O que faz | Equivalente |
|---|---|---|
| `make ajuda` | lista os comandos | — |
| `make verificar` | confere Docker, Compose, porta e memória | `scripts/verificar.sh` |
| `make preflight` | verificar + subir + testar as ferramentas dos labs | `scripts/verificar.sh`, `docker compose up -d`, `scripts/preflight.sh` |
| `make subir` | sobe o banco e espera ficar pronto | `docker compose up -d` |
| `make status` | o banco e o progresso em cada lab | `scripts/status.sh` |
| `make derruba` | para o container, **mantendo** tudo | `docker compose down` |
| `make limpar` | **apaga** banco, backups e chaves (lista antes e pede `APAGAR`) | `docker compose down -v` |
| `make logs` | segue o log do PostgreSQL | `docker compose logs -f --tail 50 producao` |
| `make consertar` | recria o container sem apagar dados | `docker compose up -d --force-recreate` |
| `make diagnostico` | relatório para o instrutor (sem chaves) | `scripts/diagnostico.sh` |

## Banco

| Atalho | Equivalente |
|---|---|
| `make psql` | `docker exec -it dbb_producao psql -P pager=off -U sudoers -d banco_sudoers` |
| `make psql d=banco_restaurado` | o mesmo, no banco `banco_restaurado` |
| `make bash` | `docker exec -it -u postgres dbb_producao bash` |
| `make sql f=labs/1_modelagem/sql/01_schema.sql` | `docker exec dbb_producao psql -X -v ON_ERROR_STOP=1 -U sudoers -d banco_sudoers -f /repo/labs/1_modelagem/sql/01_schema.sql` |
| `make carga t=30 r=20` | `docker exec dbb_producao pgbench -n -U sudoers -d banco_sudoers -T 30 -c 2 -R 20 -f /repo/carga/transferencias.sql` |

O repositório aparece **dentro** do container em `/repo` (somente leitura):
é por isso que o `make sql` e o `\i /repo/...` enxergam os arquivos.

O `-P pager=off` desliga o paginador do psql: sem ele, um resultado longo
no meio de um bloco colado abriria o `less`, que engoliria os comandos
seguintes.

## Conferência e recuperação

| Atalho | O que faz |
|---|---|
| `make conferir l=1` | confere o Lab 1 (ou `l=2`, `l=3`) olhando o estado do banco e dos arquivos; não altera nada |
| `make gabarito l=1` | para quem faltou: deixa o banco como no fim do Lab 1 (ou `l=2`, `l=3`), rodando os mesmos arquivos dos roteiros |

## Onde fica cada coisa

| Caminho (dentro do container) | O que é | Volume |
|---|---|---|
| `/var/lib/postgresql/data` | os arquivos do banco (o `$PGDATA`) | `database_engineer_banco_pg_producao` |
| `/var/lib/postgresql/data/tls` | certificado e chave do servidor (Lab 2) | idem |
| `/backup/dumps` | os backups | `database_engineer_banco_backup` |
| `/cofre` | as chaves: `chave_backup`, `chave_campos`, `ac/` | `database_engineer_banco_cofre` |
| `/repo` | este repositório | a pasta da sua máquina |
