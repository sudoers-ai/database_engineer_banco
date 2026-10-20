#!/usr/bin/env bash
# ==========================================================================
# Entrypoint do no `producao`. Antes de entregar o controle ao entrypoint
# oficial da imagem (docker-entrypoint.sh), ele:
#
#  1. Prepara /backup (as copias) e /cofre (as chaves). O cofre fica com
#     permissao 0700: so o usuario postgres entra.
#
#  2. Cria o ~/.pgpass do usuario postgres, com as senhas de laboratorio.
#     Assim os comandos que conectam pela rede (psql -h producao ...) nao
#     pedem senha. Senha em arquivo protegido, nunca na linha de comando.
# ==========================================================================
set -e

mkdir -p /backup /cofre
chown postgres:postgres /backup /cofre
chmod 0750 /backup
chmod 0700 /cofre

PGPASS=/var/lib/postgresql/.pgpass
cat > "$PGPASS" <<'EOF'
*:*:*:sudoers:password
*:*:*:usr_app:app123
*:*:*:usr_atendimento:atend123
*:*:*:usr_admin:admin123
*:*:*:usr_estagiario:estag123
EOF
chown postgres:postgres "$PGPASS"
chmod 0600 "$PGPASS"
# o psql do `make psql` roda como root: mesma senha, mesmo cuidado
cp "$PGPASS" /root/.pgpass && chmod 0600 /root/.pgpass

exec docker-entrypoint.sh "$@"
