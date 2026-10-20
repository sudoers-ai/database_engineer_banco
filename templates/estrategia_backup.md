# Estratégia de backup, recuperação e criptografia — Banco Sudoers

> Entrega da **Aula 03**. Copie para `entregas/estrategia_backup.md` e troque
> cada `(preencha)` pelo que a equipe **decidiu**, com a justificativa. É um
> desenho: ainda não há nada medido. No Lab 2 (seção 2.12) você compara este
> desenho com o que mediu. Metas, prazos e responsáveis que dependem da
> instituição são **hipóteses didáticas**: marque-as como tal e diga quem
> precisaria validar.

**Equipe:** (preencha)

## 1. Metas de recuperação

| Meta | Valor | De onde vem (quem pediu, qual o impacto de não cumprir) |
|---|---|---|
| **RPO**: quanto dado se aceita perder | (preencha) | (preencha) |
| **RTO**: em quanto tempo o serviço volta | (preencha) | (preencha) |

> Meta sem dono é chute. Se ninguém da instituição definiu, escreva a sua
> hipótese e "a validar com o negócio".

## 2. Tipo de backup, frequência e retenção

| Tipo | Usa? | Frequência | Retenção | Por quê |
|---|---|---|---|---|
| Lógico (`pg_dump`) | (preencha) | (preencha) | (preencha) | (preencha) |
| Físico (`pg_basebackup`) | (preencha) | (preencha) | (preencha) | (preencha) |
| PITR (físico + WAL arquivado) | (preencha) | (preencha) | (preencha) | (preencha) |

Com essa combinação, qual o RPO **real** no pior caso? Ele cumpre a meta da
seção 1?

(preencha)

> **Não invente prazo de retenção** com base em norma: escreva "definir com
> Jurídico/Compliance" e, se quiser, a hipótese que levaria para a reunião.

## 3. Onde ficam as cópias

| Cópia | Onde fica | Separada da produção como? (outro disco, servidor, região, conta) |
|---|---|---|
| (preencha) | (preencha) | (preencha) |
| (preencha) | (preencha) | (preencha) |

Se o servidor de produção e o lugar das cópias sumirem juntos (incêndio,
conta comprometida, ransomware), o que sobra?

(preencha)

## 4. Teste de restauração

Backup que nunca foi restaurado é esperança, não backup.

| Item | Decisão |
|---|---|
| Onde a restauração é testada (nunca por cima da produção) | (preencha) |
| Com que frequência | (preencha) |
| Como se prova que voltou certo (o que se confere) | (preencha) |
| Quem executa e quem confere o resultado | (preencha) |

## 5. Criptografia

| Onde | Controle escolhido | O que protege | O que **não** protege |
|---|---|---|---|
| Em trânsito (app ↔ banco) | (preencha) | (preencha) | (preencha) |
| Nos backups | (preencha) | (preencha) | (preencha) |
| Em repouso: campo (ex.: `pgcrypto`, cifragem na aplicação) | (preencha) | (preencha) | (preencha) |
| Em repouso: volume ou disco | (preencha) | (preencha) | (preencha) |
| Em repouso: TDE (cifragem transparente do banco) | (preencha) | (preencha) | (preencha) |

> O PostgreSQL da comunidade não tem TDE nativo; algumas distribuições e
> serviços gerenciados oferecem. Se for usar, diga qual e por quê.

## 6. Chaves

| Chave | Onde fica | Quem tem acesso | Separada do que ela protege? | Rotação |
|---|---|---|---|---|
| Chave do backup | (preencha) | (preencha) | (preencha) | (preencha) |
| Chave dos campos cifrados | (preencha) | (preencha) | (preencha) | (preencha) |
| Chave da AC e do certificado TLS | (preencha) | (preencha) | (preencha) | (preencha) |

O que acontece se uma chave for **perdida**? E se for **vazada**?

(preencha)

## 7. Riscos e pendências

| # | Risco ou pendência | Impacto | Quem decide |
|---|---|---|---|
| 1 | (preencha) | (preencha) | (preencha) |
| 2 | (preencha) | (preencha) | (preencha) |
| 3 | (preencha) | (preencha) | (preencha) |
