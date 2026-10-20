#!/usr/bin/env bash
# ==========================================================================
# Confere se um lab foi feito, olhando o ESTADO do banco e dos arquivos (e
# nao o que voce digitou). Nao altera nada: os testes que transferem
# dinheiro rodam numa transacao que e desfeita no fim.
#
#   scripts/conferir.sh 1
# ==========================================================================
set -uo pipefail
cd "$(dirname "$0")/.." && . scripts/comum.sh

l="${1:-}"
falhas=0
avisos=0
passou() { ok "$*"; }
falhou() { erro "$*"; falhas=$((falhas + 1)); }
lembrete() { aviso "$*"; avisos=$((avisos + 1)); }
existe() { docker exec "$CONTAINER" test -e "$1" 2>/dev/null; }
entrega() {  # entrega arquivo "descricao"
  if [ ! -f "entregas/$1" ]; then
    lembrete "entregável: falta entregas/$1 ($2). Copie de templates/ e preencha"
  elif grep -v "^>" "entregas/$1" | grep -q "(preencha)"; then
    lembrete "entregável: entregas/$1 ainda tem campos (preencha)"
  else
    passou "entregável: entregas/$1"
  fi
}

titulo() { echo; echo -e "${N}Conferindo o Lab $l - $1${F}"; echo; }

if ! no_ar; then
  echo; erro "o banco não está no ar. Rode: make subir"; echo; exit 1
fi

# o modelo do lab 1 existe? (os labs 2 e 3 dependem dele)
modelo_ok() {
  [ "$(sql "SELECT count(*) FROM pg_tables WHERE schemaname = 'banco'
            AND tablename IN ('clientes','contas','transferencias','lancamentos')")" = 4 ]
}

auditoria_ok() {  # auditoria_ok banco rotulo
  local r
  r=$(sql "SELECT string_agg(regra, '; ') FILTER (WHERE NOT ok) || '' , count(*) FILTER (WHERE NOT ok) FROM banco.auditoria()" "$1")
  if [ -z "$r" ]; then
    falhou "$2: banco.auditoria() não roda (falta tabela ou função?)"
  elif [ "${r##*|}" = 0 ]; then
    passou "$2: as 4 invariantes financeiras fecham"
  else
    falhou "$2: invariantes quebradas: ${r%|*}"
  fi
}

case "$l" in
# --------------------------------------------------------------------------
1)
  titulo "Modelagem e implementação"
  if modelo_ok; then passou "modelo criado: clientes, contas, transferencias, lancamentos"
  else falhou "faltam tabelas no schema banco (seção 1.4: 01_schema.sql)"; fi

  if sql_v "SELECT to_regprocedure('banco.transferir(uuid,bigint,bigint,numeric,text)') IS NOT NULL
            AND to_regprocedure('banco.auditoria()') IS NOT NULL"; then
    passou "funções transferir() e auditoria() criadas"
  else
    falhou "faltam as funções (seção 1.5: 02_transferencia.sql)"
  fi

  n=$(sql "SELECT count(*) FROM banco.lancamentos")
  if [ "${n:-0}" -ge 800000 ] 2>/dev/null; then passou "carga sintética: $n lançamentos"
  else falhou "carga não encontrada: ${n:-0} lançamentos (seção 1.6: 03_carga.sql)"; fi

  if sql_v "SELECT EXISTS (SELECT 1 FROM pg_index i JOIN pg_attribute a
              ON a.attrelid = i.indrelid AND a.attnum = i.indkey[0]
            WHERE i.indrelid = 'banco.lancamentos'::regclass AND a.attname = 'conta_id')"; then
    passou "índice para o extrato (lancamentos começando por conta_id)"
  else
    falhou "falta um índice em lancamentos que comece por conta_id (seção 1.9: 04_indices.sql)"
  fi

  modelo_ok && auditoria_ok banco_sudoers "produção"

  if modelo_ok; then
    r=$(docker exec -i "$CONTAINER" psql -X -q -U sudoers -d banco_sudoers 2>&1 <<'EOF' | grep -o 'RESULTADO:[a-z]*' | head -1
DO $$
DECLARE a bigint; b bigint; s0 numeric; s1 numeric; id1 bigint; id2 bigint; k uuid := gen_random_uuid();
BEGIN
  SET LOCAL client_min_messages = warning;
  SELECT id INTO a FROM banco.contas WHERE status = 'ativa' AND saldo > 100 ORDER BY id LIMIT 1;
  SELECT id INTO b FROM banco.contas WHERE status = 'ativa' AND id <> a ORDER BY id LIMIT 1;
  SELECT saldo INTO s0 FROM banco.contas WHERE id = a;
  id1 := banco.transferir(k, a, b, 10.00);
  id2 := banco.transferir(k, a, b, 10.00);
  SELECT saldo INTO s1 FROM banco.contas WHERE id = a;
  IF id1 <> id2 OR s1 <> s0 - 10 THEN RAISE EXCEPTION 'RESULTADO:idempotencia'; END IF;
  BEGIN
    PERFORM banco.transferir(gen_random_uuid(), a, b, s1 + 1);
    RAISE EXCEPTION 'RESULTADO:saldo';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM LIKE 'RESULTADO:%' THEN RAISE; END IF;
  END;
  IF (SELECT saldo FROM banco.contas WHERE id = a) <> s1 THEN RAISE EXCEPTION 'RESULTADO:rollback'; END IF;
  RAISE EXCEPTION 'RESULTADO:ok';   -- desfaz tudo o que o teste fez
END $$;
EOF
)
    case "$r" in
      RESULTADO:ok)          passou "transferência: débito e crédito, repetição ignorada e rollback no saldo insuficiente" ;;
      RESULTADO:idempotencia) falhou "a mesma chave transferiu duas vezes (ou o saldo não bateu)" ;;
      RESULTADO:saldo)       falhou "a transferência sem saldo foi aceita" ;;
      RESULTADO:rollback)    falhou "a transferência recusada deixou o saldo alterado" ;;
      *)                     falhou "não consegui testar a transferência (rode 02_transferencia.sql de novo)" ;;
    esac
  fi
  entrega adr.md "o ADR das decisões"
  ;;
# --------------------------------------------------------------------------
2)
  titulo "Backup, recuperação e criptografia"
  if ! modelo_ok; then falhou "o modelo do Lab 1 não existe. Quem faltou: make gabarito l=1"; fi

  existe /backup/dumps/globais.sql && passou "usuários e senhas: /backup/dumps/globais.sql" \
    || falhou "falta /backup/dumps/globais.sql (seção 2.2)"

  if existe /backup/dumps/banco_sudoers.dump.gpg; then
    passou "backup cifrado: /backup/dumps/banco_sudoers.dump.gpg"
    if no_container "gpg --batch -q --decrypt --passphrase-file /cofre/chave_backup /backup/dumps/banco_sudoers.dump.gpg | pg_restore -l >/dev/null"; then
      passou "a chave do cofre abre o backup cifrado"
    else
      falhou "a chave /cofre/chave_backup não abre o backup cifrado (seção 2.8)"
    fi
  else
    falhou "falta o backup cifrado /backup/dumps/banco_sudoers.dump.gpg (seção 2.8)"
  fi
  existe /backup/dumps/banco_sudoers.dump \
    && lembrete "a cópia EM CLARO /backup/dumps/banco_sudoers.dump ainda está no storage (seção 2.8)"
  if existe /cofre/chave_backup && [ -z "$(no_container "find /backup -name 'chave*'")" ]; then
    passou "chave no cofre (/cofre), longe das cópias (/backup)"
  else
    falhou "a chave do backup deveria estar só em /cofre/chave_backup (seção 2.8)"
  fi

  if sql_v "SELECT true" banco_restaurado; then
    auditoria_ok banco_restaurado "cópia isolada banco_restaurado"
  else
    falhou "a cópia isolada banco_restaurado não existe (seções 2.5 e 2.9)"
  fi
  modelo_ok && auditoria_ok banco_sudoers "produção (depois do incidente)"

  if sql_v "SELECT current_setting('ssl') = 'on'"; then passou "TLS ligado no servidor (ssl = on)"
  else falhou "o TLS está desligado (seção 2.10)"; fi
  if sql_v "SELECT EXISTS (SELECT 1 FROM pg_hba_file_rules WHERE type = 'hostnossl' AND auth_method = 'reject')"; then
    passou "conexão pela rede sem TLS é recusada (pg_hba.conf)"
  else
    falhou "falta a regra 'hostnossl ... reject' no pg_hba.conf (seção 2.10)"
  fi
  if no_container "psql 'host=producao dbname=banco_sudoers user=sudoers sslmode=verify-full sslrootcert=/cofre/ac/ac.crt' -Atc 'SELECT 1'" >/dev/null; then
    passou "conexão com verify-full: certificado e nome do servidor validados"
  else
    falhou "a conexão com sslmode=verify-full falhou (seção 2.10)"
  fi

  if sql_v "SELECT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'banco' AND table_name = 'clientes' AND column_name = 'renda_cifrada')
            AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'banco' AND table_name = 'clientes' AND column_name = 'renda_mensal')"; then
    if [ -n "$(no_container "psql -U sudoers -d banco_sudoers -Atc \"SELECT pgp_sym_decrypt(renda_cifrada, '\$(cat /cofre/chave_campos)') FROM banco.clientes WHERE renda_cifrada IS NOT NULL LIMIT 1\"")" ]; then
      passou "renda guardada cifrada (renda_cifrada) e a chave do cofre abre"
    else
      falhou "renda_cifrada existe, mas /cofre/chave_campos não abre (seção 2.11)"
    fi
  else
    falhou "a renda ainda está em claro: falta renda_cifrada no lugar de renda_mensal (seção 2.11)"
  fi
  entrega relatorio_lab2.md "tempos, perda observada e controles"
  ;;
# --------------------------------------------------------------------------
3)
  titulo "Governança, acessos e consolidação"
  if ! modelo_ok; then falhou "o modelo do Lab 1 não existe. Quem faltou: make gabarito l=2"; fi

  n=$(sql "SELECT count(*) FROM pg_roles WHERE (rolname LIKE 'perfil\_%' AND NOT rolcanlogin)
                                          OR (rolname LIKE 'usr\_%' AND rolcanlogin AND NOT rolsuper)")
  if [ "${n:-0}" -ge 7 ]; then passou "3 perfis sem login e 4 usuários com login (nenhum superusuário)"
  else falhou "faltam perfis ou usuários (seção 3.3: 01_perfis.sql)"; fi

  confere_priv() {  # confere_priv "condicao" "o que significa"
    if sql_v "SELECT $1"; then passou "$2"; else falhou "$2 — NÃO confere (seção 3.3)"; fi
  }
  if [ "${n:-0}" -ge 7 ]; then
    T="'banco.transferir(uuid,bigint,bigint,numeric,text)'"
    confere_priv "NOT has_database_privilege('usr_estagiario', 'banco_sudoers', 'CONNECT')" \
      "usuário sem perfil não conecta no banco"
    confere_priv "has_function_privilege('usr_app', $T, 'EXECUTE')
                  AND (SELECT prosecdef FROM pg_proc WHERE oid = $T::regprocedure)" \
      "app transfere pela função (SECURITY DEFINER)"
    confere_priv "NOT has_table_privilege('usr_app', 'banco.contas', 'UPDATE')
                  AND NOT has_table_privilege('usr_app', 'banco.lancamentos', 'DELETE')" \
      "app não altera saldo nem extrato direto"
    confere_priv "has_column_privilege('usr_app', 'banco.clientes', 'nome', 'SELECT')
                  AND NOT has_column_privilege('usr_app', 'banco.clientes', 'cpf', 'SELECT')" \
      "app lê o nome do cliente, mas não o CPF"
    confere_priv "NOT has_function_privilege('usr_atendimento', $T, 'EXECUTE')
                  AND NOT has_table_privilege('usr_atendimento', 'banco.clientes', 'SELECT')" \
      "atendimento não transfere e não lê as tabelas"
    confere_priv "NOT (SELECT rolcreaterole OR rolsuper FROM pg_roles WHERE rolname = 'usr_admin')" \
      "admin altera o schema, mas não cria usuários nem é superusuário"
  fi

  if sql_v "SELECT to_regclass('banco.vw_atendimento_transferencias') IS NOT NULL"; then
    confere_priv "has_table_privilege('usr_atendimento', 'banco.vw_atendimento_transferencias', 'SELECT')" \
      "atendimento consulta a visão"
    if sql_v "SELECT NOT EXISTS (SELECT 1 FROM information_schema.columns
                WHERE table_schema = 'banco' AND table_name = 'vw_atendimento_transferencias'
                  AND column_name ~ 'email|telefone|nascimento|renda')"; then
      passou "a visão não expõe e-mail, telefone, nascimento nem renda"
    else
      falhou "a visão expõe colunas que o atendimento não precisa"
    fi
  else
    falhou "falta a visão banco.vw_atendimento_transferencias (seção 3.4)"
  fi
  entrega inventario.md "o inventário dos dados"
  entrega checklist_controles.md "requisito, controle, evidência e pendência"
  entrega adr.md "o ADR, revisado com o que mudou nos labs 2 e 3"
  ;;
*)
  echo "uso: make conferir l=1   (o número do lab: 1, 2 ou 3)"; exit 1 ;;
esac

echo
if [ "$falhas" -gt 0 ]; then
  echo -e "${R}${falhas} item(ns) a corrigir.${F} A seção indicada no roteiro mostra como."
  echo; exit 1
fi
if [ "$avisos" -gt 0 ]; then
  echo -e "${V}✅ Lab $l conferido no banco.${F} ${A}Faltam ${avisos} lembrete(s) acima.${F}"
else
  echo -e "${V}✅ Lab $l conferido.${F}"
fi
echo
