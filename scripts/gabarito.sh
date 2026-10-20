#!/usr/bin/env bash
# ==========================================================================
# ATALHO para quem faltou a uma aula: deixa o banco como ele estaria no FIM
# do lab indicado, rodando os mesmos arquivos e comandos dos roteiros (sem o
# incidente do Lab 2). Depois, siga o proximo lab normalmente.
#
#   scripts/gabarito.sh 1   modelo, transferencia, carga e indices
#   scripts/gabarito.sh 2   + backup cifrado, copia isolada, TLS e renda cifrada
#   scripts/gabarito.sh 3   + perfis, visao do atendimento
#
# Cada passo so roda se ainda nao foi feito: pode rodar de novo.
# ==========================================================================
set -euo pipefail
cd "$(dirname "$0")/.." && . scripts/comum.sh
l="${1:-}"
case "$l" in 1|2|3) ;; *) echo "uso: make gabarito l=1   (1, 2 ou 3)"; exit 1 ;; esac
no_ar || { erro "o banco não está no ar. Rode: make subir"; exit 1; }

passo() { echo -e "\n${N}▶ $*${F}"; }
rodar_sql() { docker exec "$CONTAINER" psql -X -q -v ON_ERROR_STOP=1 -U sudoers -d banco_sudoers -f "/repo/$1" >/dev/null; }
pg() { docker exec -u postgres "$CONTAINER" bash -eo pipefail -c "$1"; }

lab1_feito() {
  [ "$(sql "SELECT count(*) FROM pg_tables WHERE schemaname = 'banco'")" -ge 4 ] 2>/dev/null &&
  [ "$(sql "SELECT count(*) >= 800000 FROM banco.lancamentos")" = t ] &&
  [ "$(sql "SELECT count(*) FROM pg_indexes WHERE indexname = 'idx_lancamentos_conta_data'")" = 1 ]
}

# ------------------------------------------------------------------- lab 1
if lab1_feito; then
  ok "Lab 1 já está feito: o modelo, a carga e os índices existem"
else
  passo "Lab 1: recriando o modelo do zero (o schema banco é apagado e recriado)"
  for f in 01_schema 02_transferencia 03_carga 04_indices; do
    echo "  make sql f=labs/1_modelagem/sql/$f.sql"
    rodar_sql "labs/1_modelagem/sql/$f.sql"
  done
  ok "Lab 1 pronto"
fi
[ "$l" = 1 ] && { echo; echo "  Siga em labs/2_backup_criptografia/README.md"; echo; exit 0; }

# ------------------------------------------------------------------- lab 2
passo "Lab 2: backups (/backup) e chave do backup (/cofre)"
pg '
mkdir -p /backup/dumps
[ -f /cofre/chave_backup ] || { openssl rand -base64 32 > /cofre/chave_backup; chmod 600 /cofre/chave_backup; }
pg_dumpall -U sudoers --globals-only -f /backup/dumps/globais.sql
pg_dump -U sudoers -d banco_sudoers -Fc \
  | gpg --batch --yes -q --symmetric --cipher-algo AES256 --compress-algo none \
        --passphrase-file /cofre/chave_backup -o /backup/dumps/banco_sudoers.dump.gpg
rm -f /backup/dumps/banco_sudoers.dump'
ok "backup cifrado em /backup/dumps/banco_sudoers.dump.gpg"

passo "Lab 2: restaurando o backup cifrado na cópia isolada banco_restaurado"
pg '
dropdb -U sudoers --if-exists banco_restaurado
createdb -U sudoers banco_restaurado
gpg --batch -q --decrypt --passphrase-file /cofre/chave_backup /backup/dumps/banco_sudoers.dump.gpg \
  | pg_restore -U sudoers -d banco_restaurado'
ok "cópia isolada restaurada"

if [ "$(sql "SHOW ssl")" != on ]; then
  passo "Lab 2: AC de treinamento, certificado do servidor e TLS obrigatório"
  pg '
mkdir -p /cofre/ac && cd /cofre/ac
[ -f ac.key ] || openssl req -quiet -x509 -newkey rsa:2048 -nodes -days 90 \
  -subj "/CN=AC de Treinamento - Banco Sudoers" -keyout ac.key -out ac.crt 2>/dev/null
mkdir -p "$PGDATA/tls" && cd "$PGDATA/tls"
openssl req -quiet -newkey rsa:2048 -nodes -subj "/CN=producao" -keyout servidor.key -out servidor.csr 2>/dev/null
printf "subjectAltName=DNS:producao,DNS:localhost\n" > san.txt
openssl x509 -req -in servidor.csr -CA /cofre/ac/ac.crt -CAkey /cofre/ac/ac.key -CAcreateserial \
  -days 90 -extfile san.txt -out servidor.crt 2>/dev/null
chmod 600 servidor.key
grep -q "^hostnossl" "$PGDATA/pg_hba.conf" || {
  sed -i "1i hostssl   all all all scram-sha-256" "$PGDATA/pg_hba.conf"
  sed -i "1i hostnossl all all all reject" "$PGDATA/pg_hba.conf"
  sed -i "1i # Lab 2: conexoes pela rede so com TLS" "$PGDATA/pg_hba.conf"
}'
  sql "ALTER SYSTEM SET ssl = on" >/dev/null
  sql "ALTER SYSTEM SET ssl_cert_file = 'tls/servidor.crt'" >/dev/null
  sql "ALTER SYSTEM SET ssl_key_file = 'tls/servidor.key'" >/dev/null
  sql "SELECT pg_reload_conf()" >/dev/null
  sleep 1
fi
ok "TLS ligado e obrigatório pela rede"

if sql_v "SELECT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'banco' AND table_name = 'clientes' AND column_name = 'renda_mensal')"; then
  passo "Lab 2: cifrando a renda dos clientes com a chave dos campos (/cofre)"
  pg '[ -f /cofre/chave_campos ] || { openssl rand -base64 32 > /cofre/chave_campos; chmod 600 /cofre/chave_campos; }'
  docker exec -i "$CONTAINER" psql -X -q -v ON_ERROR_STOP=1 -U sudoers -d banco_sudoers >/dev/null <<'EOF'
\set chave `cat /cofre/chave_campos`
CREATE EXTENSION IF NOT EXISTS pgcrypto;
ALTER TABLE banco.clientes ADD COLUMN renda_cifrada bytea;
UPDATE banco.clientes SET renda_cifrada = pgp_sym_encrypt(renda_mensal::text, :'chave', 'cipher-algo=aes256')
WHERE renda_mensal IS NOT NULL;
ALTER TABLE banco.clientes DROP COLUMN renda_mensal;
VACUUM FULL banco.clientes;
EOF
fi
ok "renda guardada cifrada"
ok "Lab 2 pronto"
[ "$l" = 2 ] && { echo; echo "  Siga em labs/3_governanca/README.md"; echo; exit 0; }

# ------------------------------------------------------------------- lab 3
passo "Lab 3: perfis de acesso e visão do atendimento"
for f in 01_perfis 02_visao_atendimento; do
  echo "  make sql f=labs/3_governanca/sql/$f.sql"
  rodar_sql "labs/3_governanca/sql/$f.sql"
done
ok "Lab 3 pronto (os entregáveis em entregas/ continuam com você)"
echo
