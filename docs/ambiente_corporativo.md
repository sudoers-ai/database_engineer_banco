# 🏢 Computador e rede da empresa

> ⬅️ [README principal](../README.md) · Guias: [🪟 Windows](./windows.md) · [🐧 Linux](./linux.md)

Este guia é para quem faz a trilha num **computador corporativo** ou numa
**rede corporativa**. Os guias do Windows e do Linux funcionam em casa sem
ajuste. Na empresa, quatro coisas costumam travar:

| Situação | Sintoma | Solução |
|---|---|---|
| O Docker Desktop exige licença paga | instalação bloqueada ou proibida pela TI | [Docker Engine no WSL](#windows-docker-engine-dentro-do-wsl-sem-docker-desktop) ou [Podman](#linux-podman-no-lugar-do-docker) |
| O Docker Hub está bloqueado | `make preflight` para em `failed to resolve reference "docker.io/library/postgres:17"` ou `Forbidden` | [imagem do registro interno](#a-imagem-do-postgresql-vem-de-outro-lugar) ou [arquivo `.tar`](#sem-registro-nenhum-a-imagem-em-arquivo) |
| Há proxy na saída para a internet | `git clone`, `apt` ou download do Docker ficam sem resposta | [proxy](#proxy-corporativo) |
| Um site está bloqueado | o dbdiagram.io não abre | o Lab 1 tem alternativa: o diagrama Mermaid do roteiro e o `.dbml` no editor |

> **Faça este guia uma semana antes da primeira aula**, junto com o
> preflight. Se nada aqui resolver, mande a saída de `make diagnostico` ao
> instrutor **antes** da aula.

---

## Windows: Docker Engine dentro do WSL, sem Docker Desktop

O Docker Desktop é só uma forma de ter o Docker. O **Docker Engine**, que é o
Docker de verdade, é gratuito e roda direto no Ubuntu do WSL. Faça o
[passo 1 do guia do Windows](./windows.md#passo-1--instalar-o-wsl2-com-ubuntu)
(o WSL2 com Ubuntu) e, **no lugar do passo 2**:

**1. Ligue o systemd no Ubuntu** (ele é quem mantém o Docker rodando). No
terminal do Ubuntu:

```bash
printf '[boot]\nsystemd=true\n' | sudo tee /etc/wsl.conf
```

Feche o Ubuntu e, no **PowerShell**, reinicie o WSL:

```powershell
wsl --shutdown
```

**2. Instale o Docker Engine.** Abra o Ubuntu de novo e siga os
[passos 1 e 2 do guia do Linux](./linux.md#passo-1--instalar-o-docker). Se
o script avisar que você está no WSL e recomendar o Docker Desktop, espere:
ele continua sozinho em 20 segundos. No passo 2 do guia do Linux, "sair e
entrar de novo na sessão" no WSL é: feche o Ubuntu, rode `wsl --shutdown` no
PowerShell e abra o Ubuntu de novo.

**3. Confira:**

```bash
docker run --rm hello-world
docker compose version
```

Depois siga o [passo 3 do guia do Windows](./windows.md#passo-3--instalar-o-make-e-o-git).
O resto da trilha é igual: tudo no terminal do Ubuntu.

> Nesse modo **não existe a baleia** do Docker Desktop. O Docker sobe junto
> com o Ubuntu. Se ele não responder, rode `sudo systemctl start docker`.

---

## Linux: Podman no lugar do Docker

O Podman é uma alternativa ao Docker sem licença comercial e sem serviço
rodando como root. Com o pacote `podman-docker`, o comando `docker` passa a
chamar o Podman, e **todos os comandos da trilha funcionam sem mudança**.

Ubuntu 24.04 ou mais novo (Podman 4.7+):

```bash
sudo apt update
sudo apt install -y podman podman-docker
sudo touch /etc/containers/nodocker          # tira o aviso "Emulate Docker CLI"
systemctl --user enable --now podman.socket  # o "docker compose" conversa com o Podman por aqui
```

O `docker compose` precisa do Compose v2. Se `docker compose version` não
responder com um número de versão, instale o plugin:

```bash
sudo apt install -y docker-compose-v2
```

Fedora: `sudo dnf install -y podman podman-docker docker-compose` e o mesmo
`systemctl --user enable --now podman.socket`.

Confira:

```bash
docker --version          # tem que dizer "podman version ..."
docker compose version    # tem que mostrar um número de versão
make verificar
```

> **No Windows, prefira o Docker Engine dentro do WSL** (seção anterior). O
> Podman Desktop do Windows roda numa máquina virtual própria, e os comandos
> da trilha, digitados no Ubuntu, não a enxergam sem configuração extra.

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

Se o registro pedir login, entre uma vez:

```bash
docker login registro.suaempresa.com.br
```

E siga com `make preflight`. Use sempre a **versão 17**: os roteiros e as
saídas de exemplo foram feitos com ela.

## Sem registro nenhum: a imagem em arquivo

O instrutor (ou alguém com acesso ao Docker Hub) gera um arquivo com a
imagem:

```bash
docker pull postgres:17
docker save postgres:17 -o postgres17.tar      # uns 450 MB
```

E distribui o `postgres17.tar` (pasta compartilhada, pendrive). Cada aluno
carrega o arquivo:

```bash
docker load -i postgres17.tar
docker image ls postgres                       # tem que aparecer postgres 17
```

No Windows, copie o `.tar` para dentro do Ubuntu antes (ex.:
`cp /mnt/c/Users/SEU_USUARIO/Downloads/postgres17.tar ~/`). Depois
`make preflight` usa a imagem carregada, sem acessar a internet.

---

## Proxy corporativo

Pergunte à TI o endereço do proxy (algo como
`http://proxy.suaempresa.com.br:8080`).

* **Docker Desktop**: Settings → Resources → Proxies → *Manual proxy configuration*.
* **Docker Engine (Linux e WSL)**: o serviço do Docker não lê as variáveis do terminal. Configure assim:

  ```bash
  sudo mkdir -p /etc/systemd/system/docker.service.d
  printf '[Service]\nEnvironment="HTTPS_PROXY=http://proxy.suaempresa.com.br:8080"\n' \
    | sudo tee /etc/systemd/system/docker.service.d/proxy.conf
  sudo systemctl daemon-reload && sudo systemctl restart docker
  ```

* **git e apt**, no terminal: `export https_proxy=http://proxy.suaempresa.com.br:8080` antes do comando.

> Se a rede da empresa **inspeciona** o HTTPS (o `docker pull` reclama de
> `x509: certificate signed by unknown authority`), a TI precisa fornecer o
> certificado da empresa para instalar na máquina. Não desligue a
> verificação de certificados.

---

## O repositório no Git da empresa

Se a turma usa o Git corporativo (GitHub Enterprise), o instrutor passa o
endereço do repositório de treinamento. Troque só a URL do `git clone` dos
guias; o resto é igual. Como entregar as atividades por lá está em
[entregas/README.md](../entregas/README.md).
