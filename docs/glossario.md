# 📖 Glossário

> ⬅️ [README principal](../README.md)

| Termo | Em português claro |
|---|---|
| **ACID** | As quatro garantias de uma transação: Atomicidade (tudo ou nada), Consistência (as regras valem antes e depois), Isolamento (transações simultâneas não se atrapalham), Durabilidade (confirmou, não se perde) |
| **ADR** | *Architecture Decision Record*: registro curto de uma decisão, com contexto, alternativas e consequências |
| **AC** | Autoridade certificadora: quem assina certificados. O cliente confia no servidor porque confia na AC que assinou o certificado dele |
| **Aporte** | Neste caso, dinheiro que entra de fora do banco: um crédito sem transferência |
| **Auditoria (invariantes)** | `banco.auditoria()`: confere regras que precisam valer sempre, como "saldo = créditos − débitos" |
| **`CHECK`** | Restrição que o banco confere em toda linha gravada (ex.: `saldo >= 0`) |
| **Chave estrangeira (FK)** | Coluna que aponta para a chave de outra tabela; o banco impede apontar para o que não existe |
| **Classificação da informação** | Nível de sensibilidade de um dado (ex.: Pública, Interna, Confidencial, Restrita), que define como ele é protegido |
| **CSR** | Pedido de certificado: o servidor envia à AC a sua chave pública e o seu nome, e a AC devolve o certificado assinado |
| **Dado pessoal** | Informação que identifica ou pode identificar uma pessoa, sozinha ou combinada com outras |
| **Deadlock** | Duas transações esperando uma pela outra para sempre; o PostgreSQL detecta e cancela uma delas |
| **DBML** | Linguagem de texto para descrever modelos de dados, usada pelo dbdiagram.io |
| **`EXPLAIN ANALYZE`** | Executa a consulta e mostra o plano que o banco usou, com o tempo de cada passo |
| **Idempotência** | Repetir a mesma operação não muda o resultado além da primeira vez. Aqui: reenviar a transferência não debita de novo |
| **Índice composto** | Índice sobre mais de uma coluna; a ordem importa (igualdade primeiro, intervalo depois) |
| **Minimização** | Expor ou coletar só os dados necessários para a finalidade |
| **Máscara** | Esconder parte de um dado na exibição (`***.456.789-**`). Não é anonimização |
| **`numeric(15,2)`** | Número decimal exato: até 15 dígitos, 2 depois da vírgula. O tipo certo para dinheiro |
| **`pg_dump` / `pg_restore`** | Backup lógico (o banco como comandos SQL) e a sua restauração, inteira ou em parte |
| **`pg_hba.conf`** | Arquivo que decide quem conecta, de onde, em qual banco e como se autentica; a primeira regra que casa vence |
| **`pgcrypto`** | Extensão do PostgreSQL com funções de criptografia, como `pgp_sym_encrypt` |
| **Perfil (role sem login)** | Role que recebe privilégios; os usuários são membros dela e herdam os direitos |
| **PITR** | *Point-in-time recovery*: restaurar o banco a um instante qualquer, com backup físico e arquivamento de WAL. Visto em conceito na Aula 03; há uma [demonstração opcional](../demos/pitr/README.md) para estudo |
| **`PUBLIC`** | A role implícita "todo mundo". Por padrão pode conectar em qualquer banco e executar qualquer função |
| **RBAC** | Controle de acesso baseado em papéis (perfis), e não em pessoas |
| **RPO** | *Recovery Point Objective*: quanto dado se aceita perder num incidente |
| **RTO** | *Recovery Time Objective*: quanto tempo se aceita ficar fora num incidente |
| **`SECURITY DEFINER`** | Função que roda com os direitos do dono dela, não de quem a chama |
| **`security_barrier`** | Opção de visão que impede filtros da consulta de "espiarem" linhas antes do filtro da visão |
| **`sslmode=verify-full`** | O cliente cifra a conexão, confere a AC do certificado **e** o nome do servidor |
| **TDE** | *Transparent Data Encryption*: cifra os arquivos do banco inteiros. Não existe no PostgreSQL da comunidade |
| **TLS** | O protocolo que cifra a conexão (o mesmo do "cadeado" do navegador) |
| **UUID** | Identificador de 128 bits, gerado sem consultar o banco; praticamente nunca se repete |
| **Visão (view)** | Uma consulta com nome, usada como tabela; roda com os direitos do dono |
| **Window function** | Função que calcula sobre um conjunto de linhas sem agrupá-las (ex.: saldo acumulado no extrato) |
