#!/usr/bin/env bash
# ==========================================================================
# Confere o terreno ANTES de subir o banco: Docker, Compose v2, porta e
# memoria. A maior parte dos problemas de aula e porta ocupada - e e bem
# mais facil corrigir antes do que depois.
# ==========================================================================
set -uo pipefail
cd "$(dirname "$0")/.." && . scripts/comum.sh
[ -f .env ] && set -a && . ./.env && set +a
erros=0
erro_() { erro "$@"; erros=$((erros + 1)); }

echo
echo -e "${N}Conferindo o ambiente${F}"
echo

if ! command -v docker >/dev/null 2>&1; then
  erro_ "Docker não encontrado. Siga o guia do seu perfil: docs/windows.md ou docs/linux.md (Podman: docs/ambiente_corporativo.md)."
  echo; exit 1
fi
if ! docker info >/dev/null 2>&1; then
  erro_ "O Docker está instalado, mas não responde. Ele está aberto? (no Linux: sudo systemctl start docker)"
  echo "       Se a mensagem for 'permission denied', veja docs/faq.md"
  echo; exit 1
fi
ok "Docker respondendo ($(docker --version | awk '{print $3}' | tr -d ','))"

if docker compose version >/dev/null 2>&1; then
  ok "Docker Compose v2 ($(docker compose version --short 2>/dev/null))"
else
  erro_ "Falta o Docker Compose v2. O comando é 'docker compose' (com espaço), não 'docker-compose'."
  echo "       Linux: sudo apt install docker-compose-plugin"
fi

porta_ocupada() {
  local p="$1"
  if command -v ss >/dev/null 2>&1; then
    ss -ltn 2>/dev/null | awk '{print $4}' | grep -qE "[:.]${p}\$"
  elif command -v lsof >/dev/null 2>&1; then
    lsof -iTCP:"$p" -sTCP:LISTEN >/dev/null 2>&1
  else
    (exec 3<>"/dev/tcp/127.0.0.1/$p") >/dev/null 2>&1
  fi
}

porta="${PORTA_PRODUCAO:-5470}"
if docker ps --format '{{.Names}}' 2>/dev/null | grep -qx "$CONTAINER"; then
  ok "porta $porta em uso pelo próprio $CONTAINER — o banco já está no ar"
elif porta_ocupada "$porta"; then
  erro_ "porta $porta está ocupada por outro programa."
  echo "       Abra o arquivo .env e troque PORTA_PRODUCAO=$porta por outra, ex.: PORTA_PRODUCAO=$((porta + 100))"
else
  ok "porta $porta livre"
fi

# Docker responde em .MemTotal; o Podman (com podman-docker) em .Host.MemTotal
mem_b=$(docker info --format '{{.MemTotal}}' 2>/dev/null) || mem_b=""
[[ "$mem_b" =~ ^[0-9]+$ ]] || mem_b=$(docker info --format '{{.Host.MemTotal}}' 2>/dev/null) || mem_b=0
[[ "$mem_b" =~ ^[0-9]+$ ]] || mem_b=0
mem_gb=$(( mem_b / 1024 / 1024 / 1024 ))
if [ "$mem_gb" -ge 1 ]; then
  ok "memória disponível para o Docker: ${mem_gb} GB"
else
  aviso "memória para o Docker abaixo de 1 GB (ou não foi possível medir). No Docker Desktop: Settings > Resources."
fi

echo
if [ "$erros" -gt 0 ]; then
  echo -e "${R}${erros} problema(s) acima.${F} Corrija e rode ${N}make verificar${F} de novo."
  echo "Dúvidas: docs/faq.md"
  echo; exit 1
fi
echo -e "${V}Tudo certo.${F}"
echo
