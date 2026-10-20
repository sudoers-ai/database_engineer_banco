# 🪟 Preparando o Windows

> ⬅️ [README principal](../README.md)

Este repositório roda em Linux. No Windows, isso se resolve com o **WSL2**: um
Linux de verdade rodando dentro do Windows, mantido pela Microsoft. Você
prepara uma vez e usa na disciplina inteira.

São quatro passos, cerca de 20 minutos (a maior parte é download).

| Passo | O que instala | Onde |
|---|---|---|
| 1 | WSL2 com Ubuntu | PowerShell |
| 2 | O Docker: **A)** Docker Desktop **ou B)** Docker Engine dentro do Ubuntu | Windows ou terminal do Ubuntu |
| 3 | `make` e `git` | terminal do Ubuntu |
| 4 | O repositório | terminal do Ubuntu |

> 🏢 **Computador da empresa?** Leia antes o
> [Computador e rede da empresa](./ambiente_corporativo.md): ele diz o que
> pedir à TI (WSL, acesso de administrador, sites liberados) e o que fazer
> se o Docker Hub estiver bloqueado.

> ⚠️ **A regra que evita quase todos os problemas:** depois do passo 1,
> **todos os comandos da trilha são digitados no terminal do Ubuntu**, nunca
> no PowerShell nem no Prompt de Comando. O PowerShell não tem `make` e não
> roda os scripts do repositório.

---

## Passo 1 — Instalar o WSL2 com Ubuntu

Abra o **PowerShell como administrador** (clique com o botão direito no menu
Iniciar → *Terminal (Admin)* ou *Windows PowerShell (Admin)*) e rode:

```powershell
wsl --install
```

**Reinicie o computador** quando terminar.

Depois de reiniciar, o Ubuntu abre sozinho e pede para você criar um **usuário
e uma senha do Linux**. Pode ser qualquer um; anote a senha, você vai usá-la
quando um comando começar com `sudo`. (Ao digitar a senha nada aparece na
tela. É normal.)

Confira, ainda no PowerShell:

```powershell
wsl -l -v
```

Tem que aparecer o Ubuntu com **VERSION 2**:

```text
  NAME      STATE           VERSION
* Ubuntu    Running         2
```

> Se aparecer `VERSION 1`, converta com `wsl --set-version Ubuntu 2`.
>
> Se o `wsl --install` disser que o WSL já está instalado mas não houver
> nenhuma distribuição, rode `wsl --install -d Ubuntu`.
>
> **Sem acesso de administrador?** O `wsl --install` exige. Num computador
> da empresa, peça à TI para habilitar o WSL2 e instalar o Ubuntu.
>
> **A Microsoft Store está bloqueada** (o download do Ubuntu não sai do
> lugar)? Use `wsl --install -d Ubuntu --web-download`, que baixa direto,
> sem a loja.

**Como abrir o terminal do Ubuntu daqui em diante:** menu Iniciar → digite
**Ubuntu** → Enter. É nele que você vai trabalhar.

---

## Passo 2 — Instalar o Docker

Há dois caminhos. Os dois rodam a trilha igual; escolha **um**:

| | **A) Docker Desktop** | **B) Docker Engine dentro do Ubuntu** |
|---|---|---|
| Quando usar | computador pessoal, ou empresa **com** licença do Docker Desktop | computador da empresa **sem** licença do Docker Desktop |
| Licença | grátis para uso pessoal e empresas pequenas; **paga** em empresas grandes | grátis (código aberto) |
| Como é | programa do Windows, com a baleia na bandeja | serviço do Ubuntu, sem janela |
| No começo de cada aula | abrir o Docker Desktop | nada: sobe junto com o Ubuntu |

Na dúvida, num computador da empresa, use o **B**.

### Opção A — Docker Desktop

1. Baixe e instale o **Docker Desktop para Windows**:
   https://www.docker.com/products/docker-desktop
2. Abra o Docker Desktop e espere o ícone da baleia parar de se mexer.
3. Vá em **Settings** (a engrenagem) → **General** e confirme que
   **Use the WSL 2 based engine** está marcado.
4. Vá em **Settings → Resources → WSL Integration** e ligue a chave do
   **Ubuntu**. Clique em **Apply & restart**.

Confira, agora **no terminal do Ubuntu**:

```bash
docker --version
docker compose version
```

Os dois têm que responder com um número de versão.

> **O Docker Desktop precisa estar aberto** sempre que você for trabalhar na
> disciplina. Se o terminal responder
> `Cannot connect to the Docker daemon`, é porque ele está fechado.

Pule para o [passo 3](#passo-3--instalar-o-make-e-o-git).

### Opção B — Docker Engine dentro do Ubuntu (sem Docker Desktop)

O Docker Desktop é só uma forma de ter o Docker. O **Docker Engine**, que é o
Docker propriamente dito, é gratuito e roda direto no Ubuntu do WSL. Tudo
abaixo é no **terminal do Ubuntu**, menos o `wsl --shutdown`, que é no
PowerShell.

> Tem o Docker Desktop instalado? Não misture os dois: desligue a integração
> com o Ubuntu (Docker Desktop → Settings → Resources → WSL Integration) ou
> desinstale o Docker Desktop antes.

**B1. Ligue o systemd no Ubuntu.** É ele que mantém o Docker rodando:

```bash
grep -qs '^systemd=true' /etc/wsl.conf || printf '\n[boot]\nsystemd=true\n' | sudo tee -a /etc/wsl.conf
```

(Se o arquivo já tem `systemd=true`, o comando não faz nada; se não tem,
acrescenta no fim, sem apagar o que já estava lá.)

Feche o Ubuntu e, no **PowerShell** (não precisa ser administrador):

```powershell
wsl --shutdown
```

Abra o Ubuntu de novo e confira: `systemctl is-system-running` tem que
responder `running` ou `degraded` (os dois servem).

**B2. Instale o Docker Engine** com o script oficial da Docker:

```bash
curl -fsSL https://get.docker.com -o instalar-docker.sh
sudo sh instalar-docker.sh
```

O script avisa que você está no WSL e recomenda o Docker Desktop. **Espere:**
ele continua sozinho em 20 segundos. Leva um ou dois minutos.

**B3. Use o Docker sem `sudo`:**

```bash
sudo usermod -aG docker $USER
```

O grupo novo só vale numa sessão nova: feche o Ubuntu, rode `wsl --shutdown`
no PowerShell e abra o Ubuntu de novo.

**B4. Confira**, agora **sem** `sudo`:

```bash
docker run --rm hello-world
docker compose version
```

Tem que aparecer `Hello from Docker!` e um número de versão. Se aparecer
`permission denied`, a sessão ainda é a antiga: repita o `wsl --shutdown`.

> Nesse modo **não existe a baleia**. O Docker sobe junto com o Ubuntu. Se
> um dia ele não responder (`Cannot connect to the Docker daemon`), rode
> `sudo systemctl start docker`.
>
> O `localhost:5470` continua acessível pelo Windows (DBeaver, pgAdmin): o
> WSL2 repassa as portas sozinho.

---

## Passo 3 — Instalar o `make` e o `git`

No terminal do Ubuntu:

```bash
sudo apt update && sudo apt install -y make git
```

Confira:

```bash
make --version
```

```text
GNU Make 4.3
```

---

## Passo 4 — Baixar o repositório no lugar certo

No terminal do Ubuntu:

```bash
cd ~
git clone https://github.com/sudoers-ai/database_engineer_banco.git
cd database_engineer_banco
```

> ⚠️ **Clone dentro do Linux (`~`), e não numa pasta do Windows
> (`/mnt/c/...`).** O `cd ~` da primeira linha existe para isso. O Docker
> fica muito mais lento quando lê arquivos que estão no disco do Windows, e
> os finais de linha podem quebrar os scripts.

Pronto. Volte ao README principal e siga do passo
**[3. Confira o terreno](../README.md#3-confira-o-terreno)** (`make verificar`).

---

## Dicas para o dia a dia no Windows

**Colar no terminal.** No terminal do Ubuntu, cole com `Ctrl+Shift+V` ou com
o **botão direito do mouse** (`Ctrl+V` nem sempre funciona). Você vai colar
muitos blocos de SQL: se aparecer um aviso sobre "colar várias linhas",
confirme em **Colar mesmo assim**.

**Conectar um cliente gráfico (DBeaver, pgAdmin...).** Não é necessário
para a trilha, mas funciona: os containers rodam dentro do WSL, e o Docker
Desktop publica as portas no Windows. Use `localhost`, porta `5470`, banco `banco_sudoers`, usuário `sudoers`, senha `password`. A
partir do Lab 2 a conexão exige TLS: nas opções de SSL do cliente, use o
certificado da AC (`ac.crt`) gerado no lab.

**Ver os arquivos do repositório no Windows.** No terminal do Ubuntu, dentro
da pasta do repositório:

```bash
explorer.exe .
```

Abre o Explorador de Arquivos naquela pasta. Com o VS Code instalado,
`code .` abre o projeto inteiro.

**Vários terminais.** Todas as etapas pedem mais de um terminal (um com o
`psql` aberto, outro para os comandos `make`, às vezes um terceiro dentro de
um nó). Abra outro Ubuntu pelo menu Iniciar,
ou uma nova aba no Windows Terminal, e entre na pasta:

```bash
cd ~/database_engineer_banco
```

**Ao fim da aula.** `make derruba` para os containers e mantém o seu
progresso. Na próxima aula: abra o Docker Desktop (só na opção A), abra o
Ubuntu, `cd ~/database_engineer_banco` e `make subir`.

---

## 🆘 Problemas comuns no Windows

| O que apareceu | O que é | O que fazer |
|---|---|---|
| `make: command not found` | Você está no PowerShell, ou pulou o passo 3 | Abra o terminal do **Ubuntu**. Se já está nele, refaça o passo 3 |
| `Cannot connect to the Docker daemon` | Opção A: o Docker Desktop está fechado. Opção B: o serviço parou | A: abra o Docker Desktop e espere a baleia parar. B: `sudo systemctl start docker` |
| `permission denied while trying to connect to the Docker daemon` | Opção B: a sessão é anterior ao `usermod` | Feche o Ubuntu, `wsl --shutdown` no PowerShell, abra de novo (B3) |
| `System has not been booted with systemd` | Opção B: o systemd não está ligado | Refaça o B1 e o `wsl --shutdown` |
| `The command 'docker' could not be found in this WSL 2 distro` | Opção A: a integração com o WSL está desligada | Opção A, item 4 |
| O `wsl --install` não sai do lugar, ou a loja está bloqueada | Rede da empresa | `wsl --install -d Ubuntu --web-download` |
| `wsl --install` pede administrador | Computador da empresa | Peça à TI para habilitar o WSL2 e instalar o Ubuntu |
| `wsl --install` não é reconhecido | Windows desatualizado | Rode o Windows Update e tente de novo |
| Erro de virtualização ao instalar o WSL ou o Docker | A virtualização está desligada no BIOS/UEFI | Ligue *Intel VT-x* ou *AMD-V* (ou *SVM*) no BIOS do computador |
| Tudo muito lento | O repositório está em `/mnt/c/...` | Rode `pwd`. Se o caminho começar com `/mnt/`, clone de novo dentro de `~` (passo 4) |
| `$'\r': command not found` ou `bad interpreter` | Os arquivos foram baixados com final de linha do Windows | Clone de novo **pelo terminal do Ubuntu**, dentro de `~` |
| O computador fica sem memória | O WSL usa, por padrão, até metade da RAM | Feche o que não estiver usando. Com 8 GB de RAM a trilha roda com folga |
| O DBeaver/pgAdmin não conecta em `localhost:5470` | O banco não está no ar, a porta foi trocada no `.env`, ou falta o SSL (a partir do Lab 2) | `make status`, confira a porta no `.env` e ative o SSL no cliente |

Não resolveu? Rode `make diagnostico` no terminal do Ubuntu, copie a saída e
mande ao instrutor. Veja também o [FAQ geral](./faq.md).
