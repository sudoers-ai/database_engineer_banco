#!/usr/bin/env bash
# Abre o psql, com uma mensagem clara se o banco nao estiver no ar.
set -uo pipefail
cd "$(dirname "$0")/.." && . scripts/comum.sh
d="${1:-banco_sudoers}"
estado=$(container)
if [ "$estado" != "running" ]; then
  erro "o banco está desligado (estado: $estado). Ligue com: make subir"; exit 1
fi
if ! no_ar; then
  erro "o PostgreSQL ainda não aceita conexões. Veja: make logs"; exit 1
fi
if ! sql_v "SELECT true" "$d"; then
  erro "o banco '$d' não existe (ainda)."; exit 1
fi
exec docker exec -it "$CONTAINER" psql -P pager=off -U sudoers -d "$d"
