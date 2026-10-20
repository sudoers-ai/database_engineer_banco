#!/usr/bin/env bash
# ==========================================================================
# Espera o PostgreSQL aceitar conexoes. Evita o erro classico de rodar um
# comando com o banco ainda subindo.
# ==========================================================================
set -uo pipefail
cd "$(dirname "$0")/.." && . scripts/comum.sh
LIMITE=180
inicio=$(date +%s)
avisou=0
while true; do
  estado=$(container)
  if [ "$estado" = "ausente" ]; then
    erro "o container $CONTAINER não existe. Rode: make subir"; exit 1
  fi
  if [ "$estado" != "running" ]; then
    echo
    erro "o container $CONTAINER parou (estado: $estado). O PostgreSQL não conseguiu subir."
    echo "     Últimas linhas do log:"
    docker logs --tail 15 "$CONTAINER" 2>&1 | sed 's/^/       /'
    echo "     Consulte docs/faq.md"
    exit 1
  fi
  if no_ar && sql_v "SELECT true"; then
    [ "$avisou" = 1 ] && echo -e "\r  ${V}✅${F} producao pronto                         "
    break
  fi
  agora=$(date +%s)
  if [ $((agora - inicio)) -ge "$LIMITE" ]; then
    echo
    erro "o banco não ficou pronto em ${LIMITE}s. Veja o motivo com: make logs"
    exit 1
  fi
  avisou=1
  echo -ne "\r  ${A}⏳${F} esperando o banco ... ${C}$((agora - inicio))s${F}   "
  sleep 1
done
