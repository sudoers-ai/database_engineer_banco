# -*- coding: utf-8 -*-
"""
Segue a trilha EXATAMENTE como esta escrita nos READMEs.

Ferramenta de quem MANTEM o repositorio (o aluno nao precisa dela). Ela le
os READMEs na ordem da trilha e executa cada bloco de codigo marcado:

    <!-- rodar: shell -->              comando no terminal da maquina, na raiz do repo
    <!-- rodar: producao -->           SQL colado no psql (make psql)
    <!-- rodar: bash-producao -->      comando no terminal DENTRO do servidor (make bash)

Bloco sem marca (saida esperada, comando interativo, exemplo) e ignorado.
`<!-- rodar: ... falha-esperada -->` = o comando DEVE falhar (ex.: escrever
na tabela uma linha que viola um CHECK).

`<!-- teste: comando -->` = comando que so este script roda, no lugar de um
trecho que o aluno faz de forma interativa (ex.: apertar Ctrl+C num comando
pendurado, ou uma segunda janela do psql segurando uma transacao).

Se a documentacao mandar o aluno fazer algo que nao funciona, este script
quebra. E assim que se garante que o passo a passo nao envelhece.

Uso (roda na SUA maquina, nao num container - ele chama docker e make):
    python3 tests/seguir_trilha.py                 # a trilha inteira
    python3 tests/seguir_trilha.py --listar        # so mostra os blocos
    python3 tests/seguir_trilha.py --de 2 --ate 3  # so os labs 2 e 3
    python3 tests/seguir_trilha.py --comparar      # avisa onde a saida real
                                                   # difere da escrita no roteiro

Comece SEMPRE de um ambiente limpo:  make limpar SIM=1 && python3 tests/seguir_trilha.py
(as entregas copiadas para entregas/ durante o teste ficam la: apague depois)
"""
import argparse
import os
import re
import subprocess
import sys
import time

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# (numero do lab, arquivo)
TRILHA = [
    (0, "README.md"),
    (1, "labs/1_modelagem/README.md"),
    (2, "labs/2_backup_criptografia/README.md"),
    (3, "labs/3_governanca/README.md"),
    (4, "demos/pitr/README.md"),          # demonstracao da Aula 03 (nao mexe no banco dos labs)
]
NOS = ("producao",)

MARCA = re.compile(r"<!--\s*rodar:\s*([\w-]+)([^>]*?)-->\s*\n```[\w]*\n(.*?)\n```"
                   r"|<!--\s*teste:\s*(.+?)\s*-->", re.S)
SAIDA = re.compile(r"\A\s*(?:[^\n`<#]*\n){0,6}?\s*```\w*\n(.*?)\n```", re.S)
V, A, R, C, N, F = "\033[92m", "\033[93m", "\033[91m", "\033[90m", "\033[1m", "\033[0m"


def blocos_de(arquivo):
    with open(os.path.join(RAIZ, arquivo), encoding="utf-8") as fh:
        texto = fh.read()
    achados = list(MARCA.finditer(texto))
    for i, m in enumerate(achados):
        linha = texto.count("\n", 0, m.start()) + 1
        if m.group(4):      # <!-- teste: comando -->
            yield {"tipo": "shell", "opcoes": ["so-no-teste"], "codigo": m.group(4), "linha": linha,
                   "esperado": None}
            continue
        # a "saida esperada" e o bloco que vem logo depois do comando
        fim = achados[i + 1].start() if i + 1 < len(achados) else len(texto)
        s = SAIDA.match(texto[m.end():fim])
        yield {"tipo": m.group(1), "opcoes": m.group(2).split(), "codigo": m.group(3), "linha": linha,
               "esperado": s.group(1) if s else None}


def comando(bloco):
    """Devolve (argv, stdin) para executar o bloco."""
    tipo, codigo = bloco["tipo"], bloco["codigo"]
    if tipo == "shell":
        return ["bash", "-eo", "pipefail", "-c", codigo], None
    if tipo in NOS:
        return ["docker", "exec", "-i", "dbb_" + tipo, "psql", "-X", "-v", "ON_ERROR_STOP=1",
                "-U", "sudoers", "-d", "banco_sudoers"], codigo + "\n"
    if tipo.startswith("bash-") and tipo[5:] in NOS:
        return ["docker", "exec", "-i", "-u", "postgres", "dbb_" + tipo[5:],
                "bash", "-eo", "pipefail", "-c", codigo], None
    raise SystemExit("tipo de bloco desconhecido: %s" % tipo)


def limpar(texto):
    texto = re.sub(r"\x1b\[[0-9;]*m", "", texto)
    return [re.sub(r"\s+", " ", l).strip() for l in texto.splitlines() if l.strip()]


def comparar(esperado, real):
    """Devolve None se a saida real contem a esperada; senao, a 1a linha que nao bateu.

    Uma linha so com "..." no esperado vale como "qualquer coisa aqui".
    """
    real = limpar(real)
    pos = 0
    for linha in limpar(esperado):
        if linha == "...":
            continue
        achou = next((i for i in range(pos, len(real)) if linha in real[i]), None)
        if achou is None:
            return linha
        pos = achou + 1
    return None


def executar(bloco, mostrar):
    argv, entrada = comando(bloco)
    proc = subprocess.run(argv, input=entrada, cwd=RAIZ, stdout=subprocess.PIPE,
                          stderr=subprocess.STDOUT, text=True)
    falhou = proc.returncode != 0
    esperava_falha = "falha-esperada" in bloco["opcoes"]
    ok = falhou == esperava_falha
    if mostrar or not ok:
        saida = proc.stdout.rstrip()
        if saida:
            print("\n".join("      " + l for l in saida.splitlines()[-(mostrar or 40):]))
    bloco["saida"] = proc.stdout
    return ok


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--de", type=int, default=0)
    ap.add_argument("--ate", type=int, default=99)
    ap.add_argument("--listar", action="store_true")
    ap.add_argument("--mostrar", type=int, default=0, help="mostra as ultimas N linhas da saida de cada bloco")
    ap.add_argument("--salvar", help="grava a saida de cada bloco neste arquivo (para atualizar os roteiros)")
    ap.add_argument("--comparar", action="store_true",
                    help="avisa quando a saida real difere da 'saida esperada' escrita no roteiro")
    args = ap.parse_args()

    total = diferentes = 0
    inicio = time.time()
    salvar = open(args.salvar, "w", encoding="utf-8") if args.salvar else None
    for lab, arquivo in TRILHA:
        if not (args.de <= lab <= args.ate):
            continue
        print()
        print("%s== lab %d: %s%s" % (N, lab, arquivo, F))
        for b in blocos_de(arquivo):
            total += 1
            resumo = b["codigo"].strip().splitlines()[0][:90]
            rotulo = "%s:%d [%s%s]" % (arquivo, b["linha"], b["tipo"],
                                        " " + " ".join(b["opcoes"]) if b["opcoes"] else "")
            if args.listar:
                print("   %s%s%s  %s" % (C, rotulo, F, resumo))
                continue
            print("   %s▶%s %s%s%s  %s" % (A, F, C, rotulo, F, resumo))
            if not executar(b, args.mostrar):
                print()
                print("%s❌ o bloco acima %s.%s" % (
                    R, "deveria ter falhado e passou" if "falha-esperada" in b["opcoes"] else "falhou", F))
                print("   %s" % rotulo)
                return 1
            if salvar:
                salvar.write("\n######## %s\n%s\n-------- saida:\n%s\n" % (rotulo, b["codigo"], b.get("saida", "")))
                salvar.flush()
            if args.comparar and b["esperado"]:
                diff = comparar(b["esperado"], b.get("saida", ""))
                if diff:
                    diferentes += 1
                    print("     %s≠ a saída real não tem a linha:%s %s" % (A, F, diff[:100]))
    if args.listar:
        print("\n%d blocos." % total)
        return 0
    print()
    print("%s✅ %d blocos executados sem erro em %ds.%s" % (V, total, time.time() - inicio, F))
    if args.comparar:
        print("   %d bloco(s) com saída diferente da escrita no roteiro (números variam; confira os demais)."
              % diferentes)
    return 0


if __name__ == "__main__":
    sys.exit(main())
