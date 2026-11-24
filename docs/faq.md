# ❓ FAQ de aula

> ⬅️ [README principal](../README.md)

Cada roteiro tem a sua tabela de **🆘 Erros comuns** no fim. Aqui ficam os
problemas de ambiente, que valem para os três labs.

### O `make verificar` diz que o Docker não responde

* **Windows e Mac:** abra o Docker Desktop e espere a baleia parar de se mexer.
* **Linux:** `sudo systemctl start docker`.
* Se a mensagem for `permission denied while trying to connect to the Docker daemon`, o seu usuário não está no grupo `docker`. Veja o [passo 2 do guia do Ubuntu](./linux.md#passo-2--usar-o-docker-sem-sudo) e saia e entre de novo na sessão.

### `make: command not found`

No Windows, você está no PowerShell: abra o terminal do **Ubuntu**. No
Ubuntu, instale o `make` (comando do
["Perfil Ubuntu"](../README.md#-perfil-ubuntu) do README).

### `docker: 'compose' is not a docker command`

Falta o Docker Compose v2. Linux: `sudo apt install docker-compose-plugin`
(repositório da Docker) ou `sudo apt install docker-compose-v2` (pacote do
Ubuntu). No Docker Desktop ele já vem.

### A porta 5470 está ocupada

Abra o arquivo `.env` e troque `PORTA_PRODUCAO=5470` por outra (ex.: `5570`).
Depois, `make subir`.

### Colei um bloco no psql e ele parou no meio

Se um comando do bloco deu erro dentro de um `BEGIN`, os seguintes são
recusados (`current transaction is aborted`). Rode `ROLLBACK;` e cole de
novo. Se o psql ficou parado sem prompt, ele pode estar esperando outra
janela (seção 1.8): veja a outra janela, ou aperte `Ctrl+C`.

### O psql diz `relation "contas" does not exist`

O psql foi aberto antes do `01_schema.sql`, e o caminho de busca (`search_path`)
é lido na hora da conexão. Saia com `\q` e entre de novo com `make psql`.
Na cópia `banco_restaurado`, use sempre o nome completo: `banco.contas`.

### Fechei o terminal no meio de um lab. Perdi tudo?

Não. O banco, os backups e as chaves ficam nos volumes do Docker. Abra o
terminal, entre na pasta do repositório, `make subir` e `make status`.

### Faltei numa aula

`make gabarito l=1` deixa o banco como no fim do Lab 1. `l=2` faz o mesmo
para o fim do Lab 2 (e faz o Lab 1 antes, se precisar). Leia o roteiro
perdido mesmo assim: as perguntas dele caem na apresentação.

### Quero recomeçar um lab do zero

* **Lab 1:** rode de novo, na ordem, os `make sql` das seções 1.4, 1.5, 1.6 e 1.9. O `01_schema.sql` apaga e recria o schema `banco`.
* **Tudo:** `make limpar`. Ele lista o container e os volumes que vai apagar (banco, backups **e chaves**) e pede que você digite `APAGAR`.

### Preciso refazer a cifragem da renda (Lab 2, seção 2.11)

É o caso de quem cifrou a renda e depois não consegue ler: o
`pgp_sym_decrypt` responde `Wrong key or corrupt data` com a chave do cofre.
A renda foi cifrada com **outra** chave (a do cofre foi recriada depois, ou o
`\set` engoliu o resto do bloco colado), e a coluna `renda_mensal` já foi
apagada. Sem a chave certa, a `renda_cifrada` não abre mais: é o risco real
de perder uma chave.

A renda em claro ainda existe na cópia `banco_restaurado`, que veio do backup
(seção 2.9). O comando abaixo traz a coluna de volta de lá e apaga a
`renda_cifrada` ilegível.

📦 **No terminal do servidor** (`make bash`):

```bash
psql -U sudoers -d banco_restaurado -c "COPY (SELECT id, renda_mensal FROM banco.clientes) TO STDOUT" |
psql -U sudoers -d banco_sudoers -v ON_ERROR_STOP=1 -1 \
  -c "ALTER TABLE banco.clientes DROP COLUMN IF EXISTS renda_cifrada" \
  -c "ALTER TABLE banco.clientes ADD COLUMN renda_mensal numeric(12,2) CHECK (renda_mensal >= 0)" \
  -c "CREATE TEMP TABLE renda (id bigint, renda_mensal numeric(12,2))" \
  -c "COPY renda FROM STDIN" \
  -c "UPDATE banco.clientes c SET renda_mensal = r.renda_mensal FROM renda r WHERE r.id = c.id"
```

```
ALTER TABLE
ALTER TABLE
CREATE TABLE
COPY 10000
UPDATE 10000
```

O `-1` roda tudo numa transação só: se um passo falhar, nada muda. Depois,
refaça a seção 2.11 **a partir do bloco do `\set`**, sem gerar a chave de
novo (a que está no cofre serve).

* **Não tem o `banco_restaurado`?** Recrie a cópia com o bloco da seção 2.9 e rode o comando acima.
* **O erro era só `column "renda_cifrada" already exists`** e a chave do cofre abre a renda? Então a seção já está feita: siga em frente.

### O `make carga` mostra `ERROR`

A carga chama a função `transferir`. Se o Lab 1 não foi feito, a função não
existe: `make conferir l=1`. Se você está no meio do incidente do Lab 2
(tabela `lancamentos` apagada), a carga falha mesmo: termine a seção 2.6.

### O DBeaver (ou outro cliente gráfico) não conecta

`localhost`, porta `5470`, banco `banco_sudoers`, usuário `sudoers`, senha
`password`. A partir do Lab 2 a conexão exige TLS: ative o SSL no cliente
e informe o `ac.crt` como certificado da AC. Para tirá-lo do container:
`docker cp dbb_producao:/cofre/ac/ac.crt .`

### O dbdiagram.io não abre (rede da empresa)

Use o arquivo [`modelo/banco_sudoers.dbml`](../modelo/banco_sudoers.dbml) no
editor e o diagrama da seção 1.2 do Lab 1, que aparece direto no GitHub.
Desenhe o seu modelo no papel. O resto do lab não depende do dbdiagram.

### Nada disso resolveu

Rode `make diagnostico`, copie a saída inteira e mande ao instrutor. Ela não
mostra nenhuma chave nem senha além das de laboratório.
