# Inventário de dados — Banco Sudoers

> Copie para `entregas/inventario.md` e preencha. Todos os dados do banco
> são **sintéticos**. As classificações, responsáveis e prazos que você
> escrever são **hipóteses didáticas**: marque-as como tal e indique quem
> precisaria validar.

**Equipe:** (preencha)

## Como preencher cada coluna

| Coluna | O que escrever |
|---|---|
| **Campo** | `tabela.coluna` |
| **Origem** | de onde o dado vem: o cliente informou, o sistema gerou, outro sistema enviou |
| **Finalidade** | para que o banco usa o dado. Dado sem finalidade é candidato a não ser coletado |
| **Classificação** | Pública / Interna / Confidencial / Restrita (escala didática abaixo) |
| **Dado pessoal?** | sim / não / a validar. Se sim, identifica a pessoa sozinho ou combinado? |
| **Responsável** | a área ou o papel que responde pelo dado (nunca "TI") |
| **Quem acessa** | perfis do Lab 3 que leem o campo, e como (tabela, visão, função) |
| **Compartilhamento** | com quem o dado sai do banco (outra área, parceiro) e sob que condição |
| **Retenção** | por quanto tempo guardar. **Não invente prazo**: "definir com Jurídico/Compliance" |
| **Descarte** | como apagar ou anonimizar no fim da retenção, inclusive nos backups |
| **Proteção atual** | o que já existe: cifrado, mascarado na visão, privilégio por coluna... |

**Escala didática de classificação**

| Nível | Significado (hipótese) |
|---|---|
| Pública | pode ser divulgada sem dano |
| Interna | uso dentro da empresa; vazamento causa dano pequeno |
| Confidencial | acesso restrito a quem precisa; vazamento causa dano relevante ao cliente ou ao banco |
| Restrita | o mais sensível; acesso mínimo, nominal e registrado |

## Exemplos (hipóteses didáticas)

| Campo | Origem | Finalidade | Classificação | Dado pessoal? | Responsável | Quem acessa | Compartilhamento | Retenção | Descarte | Proteção atual |
|---|---|---|---|---|---|---|---|---|---|---|
| `clientes.cpf` | informado pelo cliente na abertura | identificar o titular | Restrita *(hipótese)* | sim, identifica sozinho | Produto Contas *(hipótese)* | `perfil_admin` (tabela); atendimento só mascarado (visão) | nenhum *(a validar)* | definir com Jurídico/Compliance | definir; lembrar dos backups | máscara na visão; app sem acesso à coluna; **em claro na tabela** |
| `contas.saldo` | calculado pelo sistema | mostrar saldo; recusar transferência sem saldo | Confidencial *(hipótese)* | sim, combinado com a conta e o titular | Produto Contas *(hipótese)* | `perfil_aplicacao` (leitura), função `transferir` (escrita) | nenhum | definir com Jurídico/Compliance | definir | escrita só pela função |
| `transferencias.chave_idempotencia` | gerado pelo app | não processar duas vezes a mesma solicitação | Interna *(hipótese)* | não | Engenharia do app *(hipótese)* | `perfil_aplicacao` | nenhum | enquanto a transferência existir | junto com a transferência | — |

## O inventário

| Campo | Origem | Finalidade | Classificação | Dado pessoal? | Responsável | Quem acessa | Compartilhamento | Retenção | Descarte | Proteção atual |
|---|---|---|---|---|---|---|---|---|---|---|
| `clientes.id` | (preencha) | (preencha) | (preencha) | (preencha) | (preencha) | (preencha) | (preencha) | (preencha) | (preencha) | (preencha) |
| `clientes.nome` | (preencha) | (preencha) | (preencha) | (preencha) | (preencha) | (preencha) | (preencha) | (preencha) | (preencha) | (preencha) |
| `clientes.email` | (preencha) | (preencha) | (preencha) | (preencha) | (preencha) | (preencha) | (preencha) | (preencha) | (preencha) | (preencha) |
| `clientes.telefone` | (preencha) | (preencha) | (preencha) | (preencha) | (preencha) | (preencha) | (preencha) | (preencha) | (preencha) | (preencha) |
| `clientes.data_nascimento` | (preencha) | (preencha) | (preencha) | (preencha) | (preencha) | (preencha) | (preencha) | (preencha) | (preencha) | (preencha) |
| `clientes.renda_cifrada` | (preencha) | (preencha) | (preencha) | (preencha) | (preencha) | (preencha) | (preencha) | (preencha) | (preencha) | (preencha) |
| `clientes.criado_em` | (preencha) | (preencha) | (preencha) | (preencha) | (preencha) | (preencha) | (preencha) | (preencha) | (preencha) | (preencha) |
| `contas.agencia` + `contas.numero` | (preencha) | (preencha) | (preencha) | (preencha) | (preencha) | (preencha) | (preencha) | (preencha) | (preencha) | (preencha) |
| `transferencias.valor` | (preencha) | (preencha) | (preencha) | (preencha) | (preencha) | (preencha) | (preencha) | (preencha) | (preencha) | (preencha) |
| `lancamentos` (a tabela) | (preencha) | (preencha) | (preencha) | (preencha) | (preencha) | (preencha) | (preencha) | (preencha) | (preencha) | (preencha) |

## Perguntas em aberto

Decisões que dependem da instituição, com quem decide:

1. (preencha)
2. (preencha)
