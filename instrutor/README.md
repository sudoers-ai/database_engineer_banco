# 👩‍🏫 Material do instrutor

> ⬅️ [README principal](../README.md) · Gabarito: [gabarito.md](./gabarito.md)

> ⚠️ **Visibilidade.** Esta pasta está no mesmo repositório dos alunos. Se o
> repositório for público, mova `instrutor/gabarito.md` para um repositório
> privado antes de divulgar o link à turma.

## Visão geral

| | Lab 1 | Lab 2 | Lab 3 |
|---|---|---|---|
| Tema | Modelagem e implementação | Backup, recuperação e criptografia | Governança, acessos e consolidação |
| Duração | 180 min | 180 min | 180 min (45 de apresentações) |
| Entregáveis | `meu_modelo.dbml`, `adr.md` | `relatorio_lab2.md` | `inventario.md`, `checklist_controles.md`, `adr.md` revisado, apresentação |
| Conferência automática | `make conferir l=1` | `make conferir l=2` | `make conferir l=3` |
| Quem faltou | — | `make gabarito l=1` | `make gabarito l=2` |

Critério de sucesso da trilha: a turma entrega **modelo de dados,
justificativa das decisões, banco implementado, recuperação comprovada,
controles de criptografia e documentação de governança**.

## Preparação

### Uma semana antes

* [ ] Envie aos alunos o link do repositório e peça o **preflight** (README, "Começando em 5 minutos"): instalar Docker, `make preflight` terminando em **Pronto para o Lab 1**.
* [ ] Pergunte quem usa **computador corporativo**: o Docker Desktop exige licença paga em empresas grandes, e WSL ou Docker podem estar bloqueados. Combine máquinas alternativas (laboratório, máquina pessoal) ou o Docker Engine direto no WSL (guia do Linux, passos 1 e 2).
* [ ] Confirme que `https://dbdiagram.io` abre na rede da sala. Se não abrir, o Lab 1 funciona com o diagrama Mermaid do roteiro e o `.dbml` no editor.

### Na véspera de cada aula

* [ ] Rode a trilha inteira na sua máquina, do zero, em uns 3 minutos:
  `make limpar SIM=1 && python3 tests/seguir_trilha.py` (precisa de Python 3). Depois apague as cópias que o teste deixa em `entregas/`.
* [ ] Deixe um ambiente no fim de cada lab para demonstrar: `make gabarito l=1` (ou 2, 3).

### No começo de cada aula (5 min)

* [ ] `make subir && make status` na tela, e peça o mesmo à turma.
* [ ] Quem está sem o lab anterior: `make gabarito l=N` (o Lab 1 leva ~20 s; o Lab 2 leva ~40 s).

## Cronograma detalhado

### Lab 1 — 180 min

| Min | Seção | O que acontece | Ponto de atenção |
|---|---|---|---|
| 0–15 | 1.1 | `make subir`; leitura do enunciado em voz alta | as simplificações didáticas: deixe claro que é um banco de brinquedo |
| 15–55 | 1.2 | duplas desenham no dbdiagram.io; aos 40 min, comparam com a referência | circule perguntando "onde está o extrato?" e "o que impede duas vezes?" |
| 55–90 | 1.3–1.6 | export, revisão (o que falta), `01`, `02`, `03` | o export não gera `CHECK`: é o gancho para "o banco garante a regra" |
| 90–125 | 1.7–1.8 | restrições, `UPDATE 0`, rollback, idempotência, duas janelas | o `UPDATE 0` é o momento "uau": deixe a turma sentir os 100 reais sumindo |
| 125–160 | 1.9 | `EXPLAIN ANALYZE` antes e depois, ordem do índice composto, extrato com saldo | números variam por máquina: compare a ordem de grandeza |
| 160–180 | 1.10 | ADR + `make conferir l=1` | o ADR pode terminar em casa; o conferir, não |

### Lab 2 — 180 min

| Min | Seção | O que acontece | Ponto de atenção |
|---|---|---|---|
| 0–15 | 2.1 | metas de RPO e RTO; estado de partida | metas são **hipóteses**: discuta de onde viriam no mundo real |
| 15–45 | 2.2–2.3 | `pg_dump`, `globais`, sumário; `make carga t=20` | anotar a hora do backup e o número da carga |
| 45–80 | 2.4–2.7 | incidente, restauração isolada, `pg_restore -L`, perda medida, conciliação, RTO | a conciliação só funcionou por causa do **modelo**, não do backup |
| 80–110 | 2.8–2.9 | dump em claro lido; chave no cofre; `gpg`; "ladrão" do volume; adulteração; restauração cifrada | compactação não é criptografia; perder a chave = perder o backup |
| 110–145 | 2.10 | AC, CSR, certificado, `ssl=on`, `pg_hba`, testes negativo e positivos | `require` cifra, mas não protege contra impostor |
| 145–165 | 2.11 | CPF achado no arquivo da tabela; renda com `pgcrypto`; limites; volume cifrado | **não** deixar a turma sair achando que "o banco está criptografado" |
| 165–180 | 2.12 | relatório + `make conferir l=2` + discussão | pergunta 1 da discussão abre o PITR como estudo complementar |

### Lab 3 — 180 min

| Min | Seção | O que acontece | Ponto de atenção |
|---|---|---|---|
| 0–15 | 3.1 | os quatro pedidos e o estagiário | o parceiro de marketing é decisão da instituição, não do DBA |
| 15–55 | 3.2 | inventário em equipe | ninguém inventa prazo de retenção nem base legal |
| 55–85 | 3.3 | perfis, `\du`, `\dp`, logins reais pela rede com TLS | `PUBLIC` pode conectar e executar por padrão: surpreende muita gente |
| 85–110 | 3.4–3.5 | visão do atendimento, limites, 15 testes | máscara não é anonimização |
| 110–135 | 3.6 | checklist, BACEN/PCI como "a avaliar", ADR revisado | PCI DSS é sobre dados de cartão: este banco não tem |
| 135–180 | 3.7 | 6 min + 3 min por equipe; perguntas individuais | ver rubrica abaixo |

## Avaliação

### Rubrica (por equipe, 0 a 3 em cada linha)

| Critério | 0 | 1 | 2 | 3 |
|---|---|---|---|---|
| **Modelo e ADR** | ausente | modelo sem justificativa | decisões justificadas com os requisitos | justificadas com requisitos **e** números (EXPLAIN, auditoria); alternativas comparadas |
| **Banco implementado** | `conferir l=1` falha | parcial | todos ✅ | todos ✅ e explicam o que cada teste prova |
| **Recuperação comprovada** | sem relatório | relatório sem números | RPO e RTO medidos | medidos, comparados com as metas e com proposta de melhoria |
| **Criptografia** | `conferir l=2` falha | parcial | todos ✅ | todos ✅ e sabem dizer o que **não** está protegido |
| **Governança** | sem inventário | inventário parcial | inventário de `clientes` completo e checklist com evidências | e pendências com responsável, sem obrigação inventada |
| **Apresentação** | não apresentou | leu slides | clara, no tempo | clara, no tempo, com limites reconhecidos |

### Perguntas individuais

Faça **uma ou duas** por pessoa, sorteando o lab. As respostas esperadas
estão no [gabarito](./gabarito.md#perguntas-individuais). Avalie o
entendimento, não as palavras exatas.

1. Por que dinheiro não vai em `float`? E o que o `numeric(15,2)` faz com 10,005?
2. O que impede a mesma transferência de rodar duas vezes, mesmo com as duas chegando ao mesmo tempo?
3. Por que a função trava as contas sempre na ordem do id?
4. A consulta do extrato ficou 200 vezes mais rápida. Por que o índice é `(conta_id, criado_em)` e não o contrário?
5. Por que restaurar numa base isolada antes de mexer na produção?
6. Por que o `pg_restore -t` seria um erro silencioso?
7. A perda do Lab 2 foi recuperada. Isso significa que o RPO do backup foi zero?
8. Onde fica a chave do backup e por que não junto com ele?
9. Qual a diferença entre `sslmode=require` e `verify-full`?
10. Cifrar a renda com `pgcrypto` deixou o banco "criptografado"? O que continua exposto?
11. Por que o app não tem `UPDATE` em `contas`, se ele precisa mudar saldos?
12. Por que o atendente lê a visão sem ter acesso às tabelas?
13. A visão mascara o CPF. Isso anonimiza o dado?
14. Por que perfis (roles sem login) em vez de dar `GRANT` direto para cada usuário?
15. Este banco precisa cumprir o PCI DSS? Como você descobriria?

## Limitações conhecidas (conte à turma quando for o caso)

* O cofre (`/cofre`) é montado no mesmo container do banco por praticidade. A separação demonstrada é de **armazenamento** (quem leva o volume de backup não leva as chaves), não de servidor.
* A chave dos campos passa pelo SQL (variável do psql). Em produção, a cifragem costuma ficar na aplicação, com a chave vinda de um KMS.
* As senhas dos usuários do Lab 3 são de laboratório e ficam no `~/.pgpass` do container.
* O backup cifrado da seção 2.8 é anterior à cifragem da renda: ele guarda a renda em claro (cifrada pelo `gpg`). Isso é discutido no roteiro.
* Backup físico (`pg_basebackup`) e PITR ficaram fora dos 180 minutos. Eles aparecem como estudo complementar na discussão do Lab 2.
* Os tempos (`real`, `EXPLAIN`, RTO) dependem da máquina. As saídas dos roteiros vêm de uma execução real; os números dos alunos serão outros.

## Manutenção

```bash
python3 tests/conferir_docs.py                        # links, âncoras e comandos make
make limpar SIM=1 && python3 tests/seguir_trilha.py   # os três labs, como um aluno (~3 min)
python3 tests/seguir_trilha.py --comparar             # avisa onde a saída real difere da do roteiro
```
