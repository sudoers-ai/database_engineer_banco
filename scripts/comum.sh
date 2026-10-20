#!/usr/bin/env bash
# Funcoes e cores usadas pelos outros scripts.
V="\033[92m"; A="\033[93m"; R="\033[91m"; C="\033[90m"; N="\033[1m"; F="\033[0m"
CONTAINER=dbb_producao

ok()    { echo -e "  ${V}✅${F} $*"; }
aviso() { echo -e "  ${A}⚠️ ${F} $*"; }
erro()  { echo -e "  ${R}❌${F} $*"; }

# estado do container: running, exited, ausente...
container() { docker inspect -f '{{.State.Status}}' "$CONTAINER" 2>/dev/null || echo "ausente"; }

# o PostgreSQL aceita conexoes?
no_ar() { docker exec "$CONTAINER" pg_isready -q -h 127.0.0.1 -U sudoers -d postgres >/dev/null 2>&1; }

# roda uma consulta e devolve so o valor (sem cabecalho). $2 = banco (opcional)
# Sem `docker exec -i`: com -i, o container leria o terminal e engoliria as
# linhas que o aluno colou depois do comando (ex.: make subir + make status)
sql() { docker exec "$CONTAINER" psql -X -q -At -U sudoers -d "${2:-banco_sudoers}" -c "$1" 2>/dev/null; }

# a condicao SQL devolve verdadeiro?
sql_v() { [ "$(sql "$1" "${2:-banco_sudoers}")" = "t" ]; }

# comando dentro do container, como usuario postgres
no_container() { docker exec -u postgres "$CONTAINER" bash -c "$1" 2>/dev/null; }
