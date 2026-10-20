# 📦 Suas entregas

Esta pasta guarda os entregáveis dos três labs. Os roteiros mandam copiar os
templates para cá na hora certa:

| Arquivo | Lab | Template |
|---|---|---|
| `meu_modelo.dbml` | 1 | o DBML que você desenhou no dbdiagram.io |
| `adr.md` | 1 (revisado no 3) | [templates/adr.md](../templates/adr.md) |
| `estrategia_backup.md` | Aula 03 (comparada no Lab 2, seção 2.12) | [templates/estrategia_backup.md](../templates/estrategia_backup.md) |
| `relatorio_lab2.md` | 2 | [templates/relatorio_lab2.md](../templates/relatorio_lab2.md) |
| `inventario.md` | 3 | [templates/inventario.md](../templates/inventario.md) |
| `checklist_controles.md` | 3 | [templates/checklist_controles.md](../templates/checklist_controles.md) |

A estratégia da Aula 03 é a única que nasce numa aula teórica. Copie o
template no fim da Aula 03 (ou no começo do Lab 2) e preencha com a equipe:

```bash
cp -n templates/estrategia_backup.md entregas/estrategia_backup.md
```

O `make conferir` avisa (⚠️) enquanto um arquivo não existe ou ainda tem
campos `(preencha)`.

> Esta pasta **não vai para o git por padrão** (só este README): assim
> ninguém publica uma entrega sem querer. Para entregar, siga o passo a
> passo abaixo.

## Como entregar pelo Git (GitHub Enterprise)

A turma entrega pelo repositório de treinamento que o instrutor indicar no
Git corporativo (GitHub Enterprise), cada pessoa no seu **branch**, com um
**pull request** para revisão. Os comandos são os mesmos nos dois perfis
(no Windows, no terminal do Ubuntu).

**Uma vez, no começo do bloco:** aponte o seu clone para o repositório de
treinamento (o endereço vem do instrutor) e crie o seu branch:

```bash
git config --global user.name "Seu Nome"
git config --global user.email "seu.email@empresa.com.br"
git remote add turma https://SEU-GITHUB-ENTERPRISE/ORGANIZACAO/REPOSITORIO.git
git checkout -b entregas/seu-nome
```

As duas primeiras linhas dizem ao git quem assina os commits. Sem elas, o
primeiro `git commit` para com `Author identity unknown`. Já configurou
antes? `git config user.email` mostra; pule essas duas.

**A cada lab**, quando o `make conferir` não mostrar mais lembretes de
`(preencha)`:

```bash
git add -f entregas/
git status --short
git commit -m "Lab 1: modelo e ADR"
git push -u turma entregas/seu-nome
```

O `git status --short` lista o que vai no commit: confira que são só os
arquivos desta pasta.

Na primeira vez, abra o **pull request** do seu branch no GitHub
Enterprise. Nas próximas, o mesmo pull request recebe os commits novos.

* O `-f` é necessário porque a pasta é ignorada pelo git de propósito.
* **Nunca** versione chaves, certificados nem dumps: elas ficam nos volumes do Docker (`/cofre`, `/backup`), fora desta pasta, e devem continuar lá.
* Os dados são sintéticos, mas o hábito vale: antes do `git add`, releia o que vai subir.
