#!/usr/bin/env bash
# ==========================================================================
# Apaga TUDO deste repositorio e so deste repositorio: o container e os tres
# volumes do projeto `database_engineer_banco`. Lista antes o que vai apagar
# e pede confirmacao. Nao toca em nenhum outro container ou volume.
#
#   make limpar            pergunta antes
#   make limpar SIM=1      sem perguntar (para scripts)
# ==========================================================================
set -uo pipefail
cd "$(dirname "$0")/.." && . scripts/comum.sh
PROJETO=database_engineer_banco

volumes=$(docker volume ls -q --filter "label=com.docker.compose.project=$PROJETO" 2>/dev/null)
existe_container=$(docker ps -a -q --filter "name=^${CONTAINER}$" 2>/dev/null)

echo
if [ -z "$volumes" ] && [ -z "$existe_container" ]; then
  echo "  Nada para apagar: o ambiente deste repositório não existe."
  echo; exit 0
fi
echo -e "${N}Vai ser APAGADO (sem volta):${F}"
[ -n "$existe_container" ] && echo "  container  $CONTAINER"
for v in $volumes; do
  case "$v" in
    *_pg_producao) o="o banco banco_sudoers e a cópia banco_restaurado" ;;
    *_backup)      o="os dumps (/backup)" ;;
    *_cofre)       o="as CHAVES: do backup, dos campos e da AC do TLS (/cofre)" ;;
    *)             o="" ;;
  esac
  printf "  volume     %-40s %s\n" "$v" "$o"
done
echo
echo "  Sem as chaves, os backups cifrados que você copiou para fora NÃO abrem mais."
echo

if [ "${SIM:-}" != "1" ]; then
  read -r -p "  Para confirmar, digite APAGAR: " resposta
  if [ "$resposta" != "APAGAR" ]; then
    echo "  Nada foi apagado."; echo; exit 0
  fi
fi
docker compose down -v
echo
ok "ambiente apagado. Para recomeçar: make subir"
echo
