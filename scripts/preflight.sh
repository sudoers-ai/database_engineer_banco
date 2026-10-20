#!/usr/bin/env bash
# ==========================================================================
# Preflight: confere, ANTES da primeira aula, que tudo o que os tres labs
# usam esta disponivel dentro do container. Nao altera nenhum dado.
# ==========================================================================
set -uo pipefail
cd "$(dirname "$0")/.." && . scripts/comum.sh
erros=0
confere() {  # confere "rotulo" "comando"
  local saida
  if saida=$(docker exec -u postgres "$CONTAINER" bash -c "$2" 2>&1); then
    ok "$1 ${C}$(echo "$saida" | head -1)${F}"
  else
    erro "$1: $(echo "$saida" | tail -1)"; erros=$((erros + 1))
  fi
}

echo
echo -e "${N}Preflight: as ferramentas dos três labs${F}"
echo
confere "PostgreSQL no ar"                 "psql -U sudoers -d banco_sudoers -Atc 'SHOW server_version'"
confere "pg_dump e pg_restore (Lab 2)"     "pg_dump --version && pg_restore --version >/dev/null"
confere "pgbench, para a carga (Lab 2)"    "pgbench --version"
confere "gpg, cifra o backup (Lab 2)"      "gpg --version | head -1"
confere "openssl, certificados TLS (Lab 2)" "openssl version"
confere "pgcrypto disponível (Lab 2)"      "psql -U sudoers -d banco_sudoers -Atc \"SELECT 'versão ' || default_version FROM pg_available_extensions WHERE name = 'pgcrypto'\" | grep ."
confere "pasta /backup gravável (cópias)"  "touch /backup/.teste && rm /backup/.teste && echo ok"
confere "pasta /cofre gravável (chaves)"   "touch /cofre/.teste && rm /cofre/.teste && stat -c 'permissão %a' /cofre"
confere "arquivos do repositório visíveis" "test -f /repo/labs/1_modelagem/sql/01_schema.sql && echo /repo"
echo
if [ "$erros" -gt 0 ]; then
  echo -e "${R}${erros} problema(s).${F} Rode make diagnostico e mande a saída ao instrutor."
  echo; exit 1
fi
echo -e "${V}Pronto para o Lab 1.${F} Até a aula, pode desligar com ${N}make derruba${F}."
echo
