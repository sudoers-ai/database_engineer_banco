# ==========================================================================
# Banco Sudoers - Database Engineering (Bloco B5) - atalhos
#
#   make ajuda      lista tudo
#
# Nada aqui e obrigatorio: todo `make` corresponde a um comando `docker`
# que esta escrito em docs/comandos.md. O Makefile so poupa digitacao.
# ==========================================================================
.DEFAULT_GOAL := ajuda
SHELL := /bin/bash
DC    := docker compose
d     ?= banco_sudoers
t     ?= 30
r     ?= 20

# Cria o .env na primeira vez (so para voce poder trocar uma porta ocupada).
$(shell [ -f .env ] || cp .env.example .env 2>/dev/null)

.PHONY: ajuda verificar preflight subir status derruba limpar logs consertar \
        diagnostico psql bash sql carga conferir gabarito

ajuda:  ## mostra esta ajuda
	@echo ""
	@echo "  Banco Sudoers - Database Engineering (Bloco B5)"
	@echo "  ---------------------------------------------------------------"
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
	  | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[1m%-14s\033[0m %s\n", $$1, $$2}'
	@echo ""

# ---------------------------------------------------------------- ambiente
verificar:   ## confere Docker, porta e memoria ANTES de subir
	@bash scripts/verificar.sh

preflight:   ## ANTES DA 1a AULA: verifica, baixa a imagem, sobe e testa as ferramentas
	@bash scripts/verificar.sh
	$(DC) up -d
	@bash scripts/esperar.sh
	@bash scripts/preflight.sh

subir:       ## sobe o banco e espera ele ficar pronto (retoma de onde parou)
	$(DC) up -d
	@bash scripts/esperar.sh
	@echo ""
	@echo "  Tudo no ar. Veja onde voce parou com: make status"
	@echo ""

status:      ## mostra o banco e o que ja foi feito em cada lab
	@bash scripts/status.sh

derruba:     ## para o container (MANTEM dados, backups e chaves)
	$(DC) down

limpar:      ## APAGA tudo deste repositorio (banco, backups e chaves) e recomeca
	@bash scripts/limpar.sh

logs:        ## segue o log do PostgreSQL
	$(DC) logs -f --tail 50 producao

consertar:   ## recria o container (NAO apaga os dados)
	$(DC) up -d --force-recreate
	@bash scripts/esperar.sh

diagnostico: ## junta tudo que o instrutor precisa para te ajudar
	@bash scripts/diagnostico.sh

# ------------------------------------------------------------------- banco
psql:        ## abre o psql (make psql d=banco_restaurado para a copia) - saia com \q
	@bash scripts/psql.sh $(d)

bash:        ## abre um terminal DENTRO do servidor, como usuario postgres (saia com exit)
	@docker exec -it -u postgres dbb_producao bash

sql:         ## roda um arquivo .sql do repositorio (make sql f=labs/1_modelagem/sql/01_schema.sql)
	@test -n "$(f)" || (echo "uso: make sql f=caminho/do/arquivo.sql" && exit 1)
	@test -f "$(f)" || (echo "arquivo nao encontrado: $(f)" && exit 1)
	@docker exec dbb_producao psql -X -v ON_ERROR_STOP=1 -P pager=off -U sudoers -d $(d) -f /repo/$(f)

carga:       ## simula transferencias pelo app (make carga t=30 r=20: 30 s, 20 por segundo)
	@echo "Simulando transferencias por $(t)s, $(r) por segundo..."
	@set -o pipefail; docker exec dbb_producao pgbench -n -U sudoers -d banco_sudoers -T $(t) -c 2 -R $(r) -P 5 \
	  -f /repo/carga/transferencias.sql 2>&1 | grep -E "^progress|^number of transactions actually|^tps|^pgbench: error|ERROR"

# ------------------------------------------------------------- conferencia
conferir:    ## confere o que ja foi feito num lab (make conferir l=1)
	@test -n "$(l)" || (echo "uso: make conferir l=1   (o numero do lab: 1, 2 ou 3)" && exit 1)
	@bash scripts/conferir.sh $(l)

gabarito:    ## ATALHO para quem faltou: deixa o banco como no FIM do lab (make gabarito l=1)
	@test -n "$(l)" || (echo "uso: make gabarito l=1   (o lab que voce perdeu: 1 ou 2)" && exit 1)
	@bash scripts/gabarito.sh $(l)
