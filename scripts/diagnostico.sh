#!/usr/bin/env bash
# ==========================================================================
# Junta, num relatorio so, tudo que o instrutor precisa para te ajudar.
# Copie a saida inteira e mande para ele. Nao mostra nenhuma chave.
# ==========================================================================
set -uo pipefail
cd "$(dirname "$0")/.." && . scripts/comum.sh
linha() { echo; echo "==================== $1 ===================="; }

linha "sistema"
uname -a
docker --version 2>&1
docker compose version 2>&1
mem_b=$(docker info --format '{{.MemTotal}}' 2>/dev/null) || mem_b=""
[[ "$mem_b" =~ ^[0-9]+$ ]] || mem_b=$(docker info --format '{{.Host.MemTotal}}' 2>/dev/null) || mem_b=0
[[ "$mem_b" =~ ^[0-9]+$ ]] || mem_b=0
echo "memoria do Docker: $(( mem_b / 1024 / 1024 )) MB"
echo "imagem: $(grep -E '^IMAGEM_POSTGRES=' .env 2>/dev/null | cut -d= -f2- || echo postgres:17)"
echo "commit do repositorio: $(git rev-parse --short HEAD 2>/dev/null || echo '?')"

linha "arquivo .env"
[ -f .env ] && grep -v '^#' .env || echo "(sem .env - usando os padroes)"

linha "container"
docker ps -a --filter "name=$CONTAINER" --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'

linha "status"
bash scripts/status.sh 2>&1 | sed $'s/\x1b\\[[0-9;]*m//g'

if no_ar; then
  linha "configuracao alterada (postgresql.auto.conf) e pg_hba"
  docker exec "$CONTAINER" bash -c 'cat "$PGDATA/postgresql.auto.conf"' 2>&1 | grep -v '^#'
  docker exec "$CONTAINER" bash -c 'grep -v "^#" "$PGDATA/pg_hba.conf" | grep .' 2>&1
  linha "arquivos de backup e do cofre (so nomes)"
  docker exec "$CONTAINER" bash -c 'ls -la /backup/dumps /cofre /cofre/ac 2>&1'
fi

linha "ultimas linhas do log"
docker logs --tail 30 "$CONTAINER" 2>&1
