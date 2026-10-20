# 🏢 Computador e rede da empresa

> ⬅️ [README principal](../README.md) · Guias: [🪟 Windows](./windows.md) · [🐧 Ubuntu](./linux.md)

Este guia é para quem faz a trilha num **computador corporativo** ou numa
**rede corporativa**, nos dois perfis da turma: **Windows** (com o Ubuntu no
WSL2) e **Ubuntu**. Na empresa, cinco coisas costumam travar:

| Situação | Sintoma | Solução |
|---|---|---|
| Falta permissão de administrador | `wsl --install` ou `sudo apt install` recusados | [o que pedir à TI](#o-que-pedir-à-ti) |
| O Docker Desktop exige licença paga | instalação bloqueada ou proibida pela TI | Windows: [Docker Engine dentro do Ubuntu](./windows.md#opção-b--docker-engine-dentro-do-ubuntu-sem-docker-desktop). Ubuntu: o [Docker Engine](./linux.md) já é gratuito. O [Podman](#ubuntu-podman-alternativa-em-validação) está em validação |
| O Docker Hub está bloqueado | `make preflight` para em `failed to resolve reference "docker.io/library/postgres:17"`, `Forbidden` ou `timeout` | [imagem do registro interno](#a-imagem-do-postgresql-vem-de-outro-lugar) ou [arquivo `.tar`](#sem-registro-nenhum-a-imagem-em-arquivo) |
| Há proxy na saída para a internet | `git clone`, `apt` ou `docker pull` ficam sem resposta | [proxy](#proxy-corporativo) |
| A rede inspeciona o HTTPS | `x509: certificate signed by unknown authority` | [certificado da empresa](#a-rede-inspeciona-o-https) |

> **Faça este guia uma semana antes da primeira aula**, junto com o
> preflight. Se nada aqui resolver, mande a saída de `make diagnostico` ao
> instrutor **antes** da aula.

> **Licença, em uma frase:** o que é pago em empresa grande é o **Docker
> Desktop** (o programa com a baleia). O **Docker Engine** (o serviço do
> Linux) é gratuito, de código aberto, e é o caminho recomendado nos dois
> perfis. O Podman também é gratuito, mas ainda é uma alternativa em
> validação.

---

## O que pedir à TI

Mande esta lista à TI (ou confira com o instrutor) **antes** de começar:

**🪟 Perfil Windows**

* [ ] WSL2 habilitado e o **Ubuntu** instalado (exige administrador; a virtualização, *Intel VT-x* ou *AMD-V*, precisa estar ligada no BIOS).
* [ ] Permissão de `sudo` dentro do Ubuntu do WSL (normalmente o próprio usuário já tem: é ele quem cria a senha).
* [ ] Docker Desktop **com licença** da empresa, **ou** autorização para usar o Docker Engine dentro do Ubuntu (gratuito).

**🐧 Perfil Ubuntu** (22.04 ou 24.04)

* [ ] Permissão de `sudo` (para instalar o Docker, o `make` e o `git`), ou o Docker Engine já instalado pela TI com o seu usuário no grupo `docker`.

**🌐 Nos dois perfis: acessos de rede**

| Para quê | Endereço | Se estiver bloqueado |
|---|---|---|
| Baixar o repositório | `github.com` (ou o GitHub Enterprise da empresa) | o instrutor indica o repositório no Git interno |
| Pacotes do Ubuntu (`apt`) | `archive.ubuntu.com`, `security.ubuntu.com` | a TI costuma ter um espelho interno já configurado |
| Instalar o Docker Engine | `get.docker.com`, `download.docker.com` | a TI instala o Docker Engine |
| Baixar a imagem do PostgreSQL | `registry-1.docker.io`, `auth.docker.io`, `production.cloudflare.docker.com` | [registro interno](#a-imagem-do-postgresql-vem-de-outro-lugar) ou [arquivo `.tar`](#sem-registro-nenhum-a-imagem-em-arquivo) |
| Desenhar o modelo (Lab 1) | `dbdiagram.io` | o Lab 1 tem alternativa: o diagrama Mermaid do roteiro e o `.dbml` no editor |
| Instalar o Ubuntu no WSL (Windows) | Microsoft Store, ou `github.com` com `--web-download` | a TI instala |

A trilha **não precisa** de nenhuma porta aberta para fora: o banco escuta só
em `127.0.0.1:5470`, dentro da própria máquina.

---

## Ubuntu: Podman (alternativa em validação)

> ⚠️ **Alternativa em validação.** Use o Podman **só depois que o instrutor
> rodar a trilha completa com ele e liberar para a turma**. Até lá, use o
> Docker Engine do [guia do Ubuntu](./linux.md) (ou, no Windows, a
> [opção B](./windows.md#opção-b--docker-engine-dentro-do-ubuntu-sem-docker-desktop)).

O **Podman** roda os containers sem um serviço como root. Com o pacote
`podman-docker`, o comando `docker` passa a chamar o Podman. Os passos
abaixo ficam aqui para a validação e para depois dela; quando liberado, eles
substituem os passos 1 e 2 do [guia do Ubuntu](./linux.md).

> **Só no Ubuntu 24.04 ou mais novo.** O Podman do 22.04 (versão 3.4) não
> tem o `docker compose`. No 22.04, use o Docker Engine do
> [guia do Ubuntu](./linux.md), que também é gratuito.
>
> **No Windows, use o Docker Engine dentro do Ubuntu**
> ([opção B do guia](./windows.md#opção-b--docker-engine-dentro-do-ubuntu-sem-docker-desktop)),
> e não o Podman Desktop: ele roda numa máquina virtual própria, que o
> Ubuntu do WSL não enxerga.

```bash
sudo apt update
sudo apt install -y podman
sudo apt install -y --no-install-recommends podman-docker docker-compose-v2
sudo touch /etc/containers/nodocker          # tira o aviso "Emulate Docker CLI"
systemctl --user enable --now podman.socket  # o "docker compose" conversa com o Podman por aqui
```

> ⚠️ **Não tire o `--no-install-recommends` da segunda linha.** Sem ele, o
> `apt` instala junto o `docker-compose` antigo (1.29, que não funciona no
> Ubuntu 24.04) e o pacote `docker.io`, que **remove o `podman-docker`** e
> troca o Podman pelo Docker sem avisar.

Confira:

```bash
docker --version          # tem que dizer "podman version 4.9..." (ou mais novo)
docker compose version    # tem que mostrar "Docker Compose version 2..."
make verificar
```

O `docker compose` mostra antes uma linha
`Executing external compose provider ...`: é normal, é o Podman avisando que
chamou o Compose.

Se `docker --version` responder `Docker version ...` (e não `podman`), o
Docker entrou no lugar do Podman. Volte ao Podman com:

```bash
sudo apt purge -y docker.io docker-compose python3-compose
sudo apt install -y --no-install-recommends podman-docker docker-compose-v2
hash -r
```

---

## A imagem do PostgreSQL vem de outro lugar

A trilha usa a imagem oficial `postgres:17`, baixada do Docker Hub. Se a
rede bloqueia o Docker Hub, a empresa costuma ter um **registro interno**
(Artifactory, Nexus, Harbor, ECR) com uma cópia das imagens públicas. O
instrutor passa o endereço.

Abra o arquivo `.env` na pasta do repositório (o `make` cria esse arquivo na
primeira execução; se ainda não existe, rode `make ajuda` uma vez) e troque a
linha:

```text
IMAGEM_POSTGRES=postgres:17
```

pelo endereço do registro interno, por exemplo:

```text
IMAGEM_POSTGRES=registro.suaempresa.com.br/dockerhub/library/postgres:17
```

Não tem a linha `IMAGEM_POSTGRES` no seu `.env` (ele foi criado antes desta
opção existir)? Acrescente-a no fim do arquivo.

Se o registro pedir login, entre uma vez:

```bash
docker login registro.suaempresa.com.br
```

E siga com `make preflight`. Use sempre a **versão 17**, na variante padrão
(Debian), a mesma do Docker Hub: os roteiros e as saídas foram feitos com
ela. Outras variantes (`alpine`, imagens "endurecidas" da empresa) não foram
testadas.

## Sem registro nenhum: a imagem em arquivo

O instrutor (ou alguém com acesso ao Docker Hub) gera um arquivo com a
imagem:

```bash
docker pull postgres:17
docker save postgres:17 -o postgres17.tar      # de 160 a 450 MB, conforme o Docker
```

E distribui o `postgres17.tar` (pasta compartilhada, pendrive). Cada aluno
carrega o arquivo:

```bash
docker load -i postgres17.tar
docker image ls | grep postgres                # tem que aparecer postgres 17
```

No Windows, copie o `.tar` para dentro do Ubuntu antes (ex.:
`cp /mnt/c/Users/SEU_USUARIO/Downloads/postgres17.tar ~/`). Depois
`make preflight` usa a imagem carregada, sem acessar a internet.

---

## Proxy corporativo

Pergunte à TI o endereço do proxy (algo como
`http://proxy.suaempresa.com.br:8080`). Nos exemplos abaixo, troque pelo da
sua empresa. Cada programa lê o proxy de um jeito, por isso são vários lugares:

**1. O terminal** (`curl`, `git`): acrescente ao `~/.bashrc` e abra um
terminal novo:

```bash
cat >> ~/.bashrc <<'EOF'
export http_proxy=http://proxy.suaempresa.com.br:8080
export https_proxy=$http_proxy HTTP_PROXY=$http_proxy HTTPS_PROXY=$http_proxy
export no_proxy=localhost,127.0.0.1 NO_PROXY=localhost,127.0.0.1
EOF
```

**2. O `apt`**, que roda com `sudo` e **não** lê as variáveis acima:

```bash
printf 'Acquire::http::Proxy "http://proxy.suaempresa.com.br:8080";\nAcquire::https::Proxy "http://proxy.suaempresa.com.br:8080";\n' \
  | sudo tee /etc/apt/apt.conf.d/95proxy
```

Pelo mesmo motivo, o script de instalação do Docker roda com `sudo -E` (o
`-E` repassa o proxy do terminal): `sudo -E sh instalar-docker.sh`.

**3. O Docker Engine** (Ubuntu e opção B do Windows), que é um serviço e
também não lê o terminal:

```bash
sudo mkdir -p /etc/systemd/system/docker.service.d
printf '[Service]\nEnvironment="HTTP_PROXY=http://proxy.suaempresa.com.br:8080" "HTTPS_PROXY=http://proxy.suaempresa.com.br:8080" "NO_PROXY=localhost,127.0.0.1"\n' \
  | sudo tee /etc/systemd/system/docker.service.d/proxy.conf
sudo systemctl daemon-reload && sudo systemctl restart docker
```

**Ou, com Podman** (alternativa em validação), o serviço do Podman (é ele que baixa a imagem para o
`docker compose`):

```bash
mkdir -p ~/.config/systemd/user/podman.service.d
printf '[Service]\nEnvironment="HTTP_PROXY=http://proxy.suaempresa.com.br:8080" "HTTPS_PROXY=http://proxy.suaempresa.com.br:8080" "NO_PROXY=localhost,127.0.0.1"\n' \
  > ~/.config/systemd/user/podman.service.d/proxy.conf
systemctl --user daemon-reload && systemctl --user restart podman.socket
```

**4. O Docker Desktop** (opção A do Windows): Settings → Resources → Proxies
→ *Manual proxy configuration*.

O banco em si **não** precisa de internet: o proxy só importa para instalar e
para baixar a imagem.

## A rede inspeciona o HTTPS

Se o `git clone`, o `apt` ou o `docker pull` reclamam de
`x509: certificate signed by unknown authority` (ou `SSL certificate
problem`), a rede da empresa abre o HTTPS no meio do caminho. A TI fornece o
**certificado raiz da empresa** (um arquivo `.crt`). Instale no Ubuntu e
reinicie o Docker:

```bash
sudo cp certificado-da-empresa.crt /usr/local/share/ca-certificates/
sudo update-ca-certificates
sudo systemctl restart docker      # só com Docker Engine
```

No Windows com Docker Desktop, o certificado vai no Windows (a TI costuma já
ter instalado). **Não desligue** a verificação de certificados
(`sslVerify=false`, `--insecure`): é exatamente o tipo de atalho que o Lab 2
ensina a não tomar.

---

## O repositório no Git da empresa

Se a turma usa o Git corporativo (GitHub Enterprise), o instrutor passa o
endereço do repositório de treinamento. Troque só a URL do `git clone` dos
guias; o resto é igual. Como entregar as atividades por lá está em
[entregas/README.md](../entregas/README.md).
