#!/usr/bin/env bash
# ==========================================================================
# Mostra o banco e, para cada lab, o que ja foi feito. E o "onde eu parei?"
# do comeco de cada aula. O detalhe de cada lab: make conferir l=N
# ==========================================================================
set -uo pipefail
cd "$(dirname "$0")/.." && . scripts/comum.sh
marca() { if [ "$1" = t ]; then echo -ne "${V}✅${F}"; else echo -ne "${C}⬜${F}"; fi; }

echo
estado=$(container)
if [ "$estado" = "ausente" ]; then
  echo -e "  producao   ${C}não criado${F} (make subir)"; echo; exit 0
elif [ "$estado" != "running" ]; then
  echo -e "  producao   ${R}desligado${F} (make subir)"; echo; exit 0
elif ! no_ar; then
  echo -e "  producao   ${A}iniciando...${F} (espere ou veja make logs)"; echo; exit 0
fi
versao=$(sql "SHOW server_version" | cut -d' ' -f1)
tam=$(sql "SELECT pg_size_pretty(pg_database_size('banco_sudoers'))")
echo -e "  ${N}producao${F}   ${V}no ar${F}   PostgreSQL $versao   banco_sudoers: $tam   porta ${PORTA_PRODUCAO:-$(grep -s PORTA_PRODUCAO .env | cut -d= -f2)}"
echo

tem_modelo=$(sql "SELECT count(*) = 4 FROM pg_tables WHERE schemaname = 'banco' AND tablename IN ('clientes','contas','transferencias','lancamentos')")
v() { [ "$tem_modelo" = t ] && sql "$1" || echo f; }
existe() { docker exec "$CONTAINER" test -e "$1" 2>/dev/null && echo t || echo f; }

echo -e "  ${N}Lab 1${F}  $(marca "$tem_modelo") modelo   $(marca "$(v "SELECT to_regprocedure('banco.transferir(uuid,bigint,bigint,numeric,text)') IS NOT NULL")") transferência   $(marca "$(v "SELECT count(*) >= 800000 FROM banco.lancamentos")") carga   $(marca "$(v "SELECT count(*) > 0 FROM pg_indexes WHERE schemaname = 'banco' AND indexname LIKE 'idx_lancamentos%'")") índices"
echo -e "  ${N}Lab 2${F}  $(marca "$(existe /backup/dumps/globais.sql)") dump   $(marca "$(sql "SELECT true" banco_restaurado || echo f)") cópia isolada   $(marca "$(existe /backup/dumps/banco_sudoers.dump.gpg)") backup cifrado   $(marca "$(sql "SELECT current_setting('ssl') = 'on'")") TLS   $(marca "$(v "SELECT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'banco' AND column_name = 'renda_cifrada')")") renda cifrada"
echo -e "  ${N}Lab 3${F}  $(marca "$(sql "SELECT count(*) >= 3 FROM pg_roles WHERE rolname LIKE 'perfil\_%'")") perfis   $(marca "$(v "SELECT to_regclass('banco.vw_atendimento_transferencias') IS NOT NULL")") visão do atendimento   $(marca "$([ -f entregas/inventario.md ] && echo t)") inventário   $(marca "$([ -f entregas/checklist_controles.md ] && echo t)") checklist"
echo
echo -e "  ${C}Detalhe de cada lab: make conferir l=1 (ou 2, 3)${F}"
echo
