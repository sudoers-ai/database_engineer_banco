# 🏦 Banco Sudoers — Database Engineering

> **Bloco B5 — Dados: Modelagem, Armazenamento e Governança.** Trilha prática
> em três laboratórios de 3 horas. Você só precisa de Docker: tudo roda em
> containers na sua máquina, com dados 100% sintéticos.

O Banco Sudoers vai lançar um serviço simples de **contas, transferências
internas e extrato**. Você é a pessoa de dados do time: vai modelar o banco,
garantir que nenhuma transferência crie ou some com dinheiro, provar que
consegue recuperar tudo depois de um incidente, proteger os dados com
criptografia e documentar quem pode ver o quê.

Um mesmo caso do começo ao fim: o banco que você cria no Lab 1 é o que você
recupera no Lab 2 e governa no Lab 3.

---

## 🎯 O que você vai aprender

| Lab | Pergunta que você vai saber responder | Com o quê |
|---|---|---|
| 1 | "Como garantir que uma transferência nunca debita sem creditar, nem roda duas vezes?" | modelagem no dbdiagram.io, chaves, `CHECK`, transação, idempotência, `EXPLAIN ANALYZE` |
| 2 | "Apagaram o extrato. Quanto perdemos, em quanto tempo voltamos, e o backup está protegido?" | `pg_dump`/`pg_restore`, RPO e RTO medidos, `gpg`, TLS com `verify-full`, `pgcrypto` |
| 3 | "Quem pode ver o CPF do cliente? E como você prova?" | inventário de dados, perfis com `GRANT`/`REVOKE`, visão com dados mínimos, checklist de controles |

Ao final, a turma entrega: **modelo de dados, justificativa das decisões
(ADR), banco implementado, recuperação comprovada, controles de criptografia
e documentação de governança**.

---

## 🏗️ O ambiente

Um servidor PostgreSQL 17 num container, com três "discos" separados de
propósito:

```
                 ┌───────────────────────────────────────────┐
  make psql ───► │  producao  (PostgreSQL 17)                │
  make carga     │  localhost:5470                           │
  (o "app")      │                                           │
                 │  banco_sudoers     o banco do Banco       │
                 │  banco_restaurado  a cópia isolada (Lab 2)│
                 └──────┬──────────────────┬─────────────────┘
                        │                  │
          ┌─────────────▼──────┐   ┌───────▼─────────────────┐
          │ /backup            │   │ /cofre                  │
          │ as CÓPIAS (dumps)  │   │ as CHAVES (backup,      │
          │                    │   │ campos, AC do TLS)      │
          └────────────────────┘   └─────────────────────────┘
```

* O banco `banco_sudoers` nasce **vazio**. No Lab 1 você roda o modelo e a
  carga sintética, que já estão prontos em `labs/1_modelagem/sql/`.
* `/backup` e `/cofre` são volumes diferentes: guardar a chave junto com a
  cópia que ela protege anula a proteção. Esse é um dos assuntos do Lab 2.

---

## ✅ Pré-requisitos

* [ ] **Docker** e **Docker Compose v2** (o comando é `docker compose`, com espaço)
* [ ] **`make`** — todos os comandos da trilha começam com ele
* [ ] ~1 GB de RAM livre e ~1 GB de disco para a imagem
* [ ] Um navegador, para o [dbdiagram.io](https://dbdiagram.io/d) (gratuito; não precisa de conta para desenhar)

> **Você não precisa instalar PostgreSQL nem cliente nenhum.** Tudo roda
> dentro do container.

A turma tem **dois perfis**: quem usa **Windows** e quem usa **Linux**. Os
labs são os mesmos para os dois; o que muda é a preparação da máquina e o
terminal onde você digita. Escolha o seu e faça o guia uma vez só, **antes
da primeira aula**:

| Perfil | Guia de preparação | Onde você digita os comandos | Tempo |
|---|---|---|---|
| 🪟 **Windows 10 ou 11** | **[Preparando o Windows](./docs/windows.md)** (WSL2 + Docker) | no terminal do **Ubuntu (WSL)**, nunca no PowerShell | ~20 min |
| 🐧 **Ubuntu** (22.04 ou 24.04) | **[Preparando o Ubuntu](./docs/linux.md)** (Docker Engine ou Podman) | no terminal do Ubuntu | ~10 min |

> 🏢 **Computador ou rede da empresa?** Comece por **[Computador e rede da empresa](./docs/ambiente_corporativo.md)**:
> o que pedir à TI, Docker sem o Docker Desktop (Docker Engine no WSL ou
> Podman), imagem do registro interno ou em arquivo, proxy e certificado da
> empresa. Tudo testado nos dois perfis.

Ao terminar o guia, volte para cá e continue do passo
[3. Confira o terreno](#3-confira-o-terreno).

### 🪟 Perfil Windows

* Tudo roda dentro do **WSL2** (um Ubuntu dentro do Windows). O Docker pode
  ser o **Docker Desktop** ou, em computador da empresa sem licença, o
  **Docker Engine instalado no próprio Ubuntu** (opção B do guia). Depois de
  instalado, **todos os comandos da trilha são digitados no terminal do
  Ubuntu**, nunca no PowerShell nem no Prompt de Comando: eles não têm
  `make` e não rodam os scripts.
* O repositório fica **dentro do Ubuntu** (`~/database_engineer_banco`), não
  numa pasta do Windows (`/mnt/c/...`).
* Para editar as entregas, abra a pasta no VS Code a partir do Ubuntu, com
  `code .` (o VS Code instala sozinho a extensão do WSL), ou no Explorador
  de Arquivos com `explorer.exe .`.

### 🐧 Perfil Ubuntu

* O Docker roda direto no sistema: é o caminho mais simples.
* Se você já tem Docker, confira com `docker compose version` (com espaço).
  Se responder com um número de versão, falta só o `make`:

  ```bash
  sudo apt update && sudo apt install -y make git
  ```

* Sem permissão para instalar o Docker? O [Podman](./docs/ambiente_corporativo.md#ubuntu-podman-no-lugar-do-docker)
  funciona com os mesmos comandos.

> Usa Mac? Não é um perfil da turma, mas há um [guia](./docs/mac.md).

Se você tem um PostgreSQL instalado na máquina, ele **não atrapalha**: a
porta deste repositório (5470) é outra.

---

## ▶️ Começando em 5 minutos (o preflight)

Faça esta parte **antes da primeira aula**. Ela baixa a imagem do PostgreSQL
(uns 450 MB) e confere cada ferramenta que os três labs usam.

### 1. Baixe o repositório

```bash
git clone https://github.com/sudoers-ai/database_engineer_banco.git
cd database_engineer_banco
```

(Se você seguiu um dos guias de preparação, já fez isso. No Windows, dentro
do terminal do Ubuntu.)

### 2. Confira se você tem o `make`

<!-- rodar: shell -->
```bash
make --version
```

Tem que aparecer a versão, em algo como:

```text
GNU Make 4.3
```

Se aparecer `make: command not found` (ou `comando não encontrado`):

* **no Windows**, você provavelmente está no PowerShell. Abra o terminal do
  **Ubuntu** e veja o [guia de preparação](./docs/windows.md);
* **no Ubuntu**, instale com o comando da tabela do
  [perfil Ubuntu](#-perfil-ubuntu) e repita este passo.

### 3. Confira o terreno

<!-- rodar: shell -->
```bash
make verificar
```

Ele checa Docker, Compose, porta e memória, e diz em português o que fazer
se algo estiver errado:

```
Conferindo o ambiente

  ✅ Docker respondendo (29.9.0)
  ✅ Docker Compose v2 (5.6.0)
  ✅ porta 5470 livre
  ✅ memória disponível para o Docker: 31 GB

Tudo certo.
```

> Se a porta estiver ocupada, a mensagem diz qual linha do arquivo `.env`
> trocar. Não precisa mexer em mais nada.

### 4. Rode o preflight

<!-- rodar: shell -->
```bash
make preflight
```

Ele sobe o banco e testa, dentro do container, tudo o que os labs vão usar:

```
...
Preflight: as ferramentas dos três labs

  ✅ PostgreSQL no ar 17.11 (Debian 17.11-1.pgdg13+2)
  ✅ pg_dump e pg_restore (Lab 2) pg_dump (PostgreSQL) 17.11 (Debian 17.11-1.pgdg13+2)
  ✅ pgbench, para a carga (Lab 2) pgbench (PostgreSQL) 17.11 (Debian 17.11-1.pgdg13+2)
  ✅ gpg, cifra o backup (Lab 2) gpg (GnuPG) 2.4.7
  ✅ openssl, certificados TLS (Lab 2) OpenSSL 3.5.7 9 Jun 2026 (Library: OpenSSL 3.5.7 9 Jun 2026)
  ✅ pgcrypto disponível (Lab 2) versão 1.3
  ✅ pasta /backup gravável (cópias) ok
  ✅ pasta /cofre gravável (chaves) permissão 700
  ✅ arquivos do repositório visíveis /repo

Pronto para o Lab 1. Até a aula, pode desligar com make derruba.
```

Algum ❌? Rode `make diagnostico` e mande a saída ao instrutor **antes** da
aula.

### 5. Veja onde você está

<!-- rodar: shell -->
```bash
make status
```

```
  producao   no ar   PostgreSQL 17.11   banco_sudoers: 7510 kB   porta 5470

  Lab 1  ⬜ modelo   ⬜ transferência   ⬜ carga   ⬜ índices
  Lab 2  ⬜ dump   ⬜ cópia isolada   ⬜ backup cifrado   ⬜ TLS   ⬜ renda cifrada
  Lab 3  ⬜ perfis   ⬜ visão do atendimento   ⬜ inventário   ⬜ checklist

  Detalhe de cada lab: make conferir l=1 (ou 2, 3)
```

É o seu "onde eu parei?". Rode no começo de toda aula.

---

## 🚪 O que subiu

| Nó | Container | Endereço | Bancos |
|---|---|---|---|
| `producao` | `dbb_producao` | `localhost:5470` | `banco_sudoers` (e, no Lab 2, `banco_restaurado`) |

Usuário `sudoers`, senha `password` (de laboratório). Duas formas de entrar:

```bash
make psql      # abre o psql (o "prompt do banco")   - saia com \q
make bash      # abre um terminal DENTRO do servidor - saia com exit
```

O `make bash` é o equivalente a entrar por SSH no servidor: é lá que rodam
`pg_dump`, `gpg` e `openssl`.

---

## 📖 Como ler os roteiros

Todo bloco de comando dos roteiros diz **onde** ele deve ser colado:

| Aviso antes do bloco | Onde colar |
|---|---|
| 🖥️ **No seu terminal** | no terminal da sua máquina, na pasta do repositório |
| 🐘 **No psql** | dentro do `make psql` (o prompt mostra `banco_sudoers=#`) |
| 📦 **No terminal do servidor** | dentro do `make bash` (o prompt mostra `postgres@producao`) |
| 🌐 **No dbdiagram** | no navegador, em https://dbdiagram.io/d |

> **Dica:** deixe três janelas abertas: o seu terminal, o psql e o terminal
> do servidor. Errar de janela é o erro número 1 desta disciplina.

### O começo de cada aula, em cada perfil

| | 🪟 Windows | 🐧 Linux |
|---|---|---|
| 1. Ligar o Docker | opção A: abra o **Docker Desktop** e espere a baleia parar. Opção B (Docker Engine no Ubuntu): nada, ele sobe sozinho | já está ligado (se não: `sudo systemctl start docker`; com Podman, nada a fazer) |
| 2. Abrir o terminal | menu Iniciar → **Ubuntu** | o terminal do Ubuntu |
| 3. Entrar na pasta | `cd ~/database_engineer_banco` | `cd ~/database_engineer_banco` (ou onde você clonou) |
| 4. Subir e ver onde parou | `make subir && make status` | `make subir && make status` |
| Mais terminais | nova aba do Windows Terminal → Ubuntu, e o `cd` do passo 3 | nova aba do terminal, e o `cd` do passo 3 |
| Colar blocos de comando | `Ctrl+Shift+V` ou botão direito | `Ctrl+Shift+V` |
| Editar as entregas | `code .` ou `explorer.exe .` no Ubuntu | o editor que preferir |

Cada roteiro começa com uma tabela de tempo e termina com o
`make conferir`, que confere o estado do banco (não o que você digitou).

---

## 🗺️ A trilha

**Siga na ordem**: cada lab parte do banco como o anterior deixou.

| Lab | Tema | Tempo | A prova de que deu certo |
|---|---|---|---|
| 1 | [Modelagem e implementação](./labs/1_modelagem/README.md) | 180 min | `make conferir l=1` + o seu ADR |
| 2 | [Backup, recuperação e criptografia](./labs/2_backup_criptografia/README.md) | 180 min | `make conferir l=2` + o relatório de recuperação |
| 3 | [Governança, acessos e consolidação](./labs/3_governanca/README.md) | 180 min | `make conferir l=3` + inventário, checklist e apresentação |

### Entre uma aula e outra

O ambiente guarda **tudo** (banco, backups e chaves) entre as aulas:

```bash
make derruba     # no fim da aula: para o container e MANTÉM tudo
make subir       # no começo da próxima: volta de onde parou
make status      # onde eu parei?
```

> **Faltou numa aula?** `make gabarito l=1` deixa o banco como no fim do
> Lab 1 (`l=2` como no fim do Lab 2), rodando os mesmos arquivos do
> roteiro. Leia o roteiro que você perdeu mesmo assim: as perguntas dele
> caem na apresentação do Lab 3.

---

## 📺 Recursos complementares

Os vídeos abaixo, do canal da Sudoers, explicam os fundamentos que esta
trilha coloca em prática.

- [Aula 02 - Transacional](https://www.youtube.com/watch?v=e5jm15ui1T0&list=PLD3-a_5KsN3kBwoeBT78q1ZyARwtwhjwT&index=13) — o tipo de banco que você vai modelar (antes do Lab 1)  
- [Aula 03 - A importância do ACID](https://www.youtube.com/watch?v=3GlHqI0LP9w&list=PLD3-a_5KsN3kBwoeBT78q1ZyARwtwhjwT&index=14) — atomicidade é o que garante a transferência (antes do Lab 1)  
- [Aula 16 - A importância da Durabilidade](https://www.youtube.com/watch?v=SbPvboEf5lE&list=PLD3-a_5KsN3kBwoeBT78q1ZyARwtwhjwT&index=37) — o que "confirmado" significa para o banco (antes do Lab 2)  
- [Curso de SQL Básico](https://www.youtube.com/watch?v=aQd5_vcn18U&list=PLD3-a_5KsN3nuXukrq8kCYtxnZR4FD2nJ) — se o `SELECT`, o `INSERT` e o `UPDATE` ainda não são naturais para você, comece por aqui  

Deixe seu like e comentário nos vídeos do YouTube, isso ajuda e incentiva nosso trabalho.

---

## 📚 Material de apoio

* [✅ Checklist do aluno](./docs/checklist.md) — para marcar o que já fez
* [📖 Glossário](./docs/glossario.md) — idempotência, RPO, TLS, RBAC... em português claro
* [❓ FAQ de aula](./docs/faq.md) — erros comuns e como resolver
* [⌨️ Comandos](./docs/comandos.md) — todo `make` e o `docker` equivalente
* [🧩 Modelo de referência em DBML](./modelo/banco_sudoers.dbml) — para colar no dbdiagram.io
* [🎬 Demonstração de WAL e PITR](./demos/pitr/README.md) — a recuperação até um instante, mostrada na aula de ciclo de vida e backup
* [📝 Templates dos entregáveis](./templates/) — ADR, relatório, inventário e checklist
* [🪟 Windows](./docs/windows.md) · [🐧 Ubuntu](./docs/linux.md) — preparação, passo a passo, para os dois perfis da turma
* [🏢 Computador e rede da empresa](./docs/ambiente_corporativo.md) — o que pedir à TI, Docker Engine no WSL, Podman, registro interno, proxy, certificado
* [👩‍🏫 Material do instrutor](./instrutor/README.md) — preparação, os seis encontros, demonstração de PITR e avaliação

---

## 🧰 Comandos do dia a dia

```bash
make ajuda          # lista todos os comandos
make status         # onde eu parei?
make psql           # entra no banco
make carga t=30     # simula 30 segundos de transferências pelo "app"
make conferir l=2   # confere o Lab 2
make derruba        # para tudo, MANTENDO os dados (use ao fim da aula)
make subir          # volta de onde parou
make limpar         # APAGA banco, backups e chaves (pede confirmação)
make diagnostico    # relatório para mandar ao instrutor
```

---

## 🤝 Contribuição

Antes de enviar uma mudança nos roteiros, rode as duas conferências de quem
mantém o repositório (precisam de Python 3 na máquina; o aluno não precisa):

```bash
python3 tests/conferir_docs.py                            # links, âncoras e comandos make (sem Docker)
make limpar SIM=1 && python3 tests/seguir_trilha.py       # executa os três labs, como um aluno (~2 min)
```

O `seguir_trilha.py` roda cada bloco marcado com `<!-- rodar: ... -->` nos
READMEs, na ordem. Se um roteiro mandar o aluno fazer algo que não
funciona, ele quebra.

## 📜 Licença

Este projeto está licenciado sob a **Licença SUDOERS**.

---

# ➡️ Comece em [labs/1_modelagem/README.md](./labs/1_modelagem/README.md)
