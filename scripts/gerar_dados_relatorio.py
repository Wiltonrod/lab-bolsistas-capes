#!/usr/bin/env python3
"""Gera tabelas (.tex), macros de valores (.tex) e o grafico do relatorio a
partir dos CSVs em resultados/. Uso: python3 scripts/gerar_dados_relatorio.py"""
import csv
import math
import pathlib
import sys

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

RAIZ = pathlib.Path(__file__).resolve().parent.parent
RES = RAIZ / "resultados"
SAIDA = RAIZ / "relatorio" / "gerado"
SAIDA.mkdir(parents=True, exist_ok=True)


def ler_stats(caminho):
    if not caminho.exists():
        return []
    with caminho.open(newline="") as f:
        return [(int(r["nomes_inseridos"]), int(r["comparacoes"]))
                for r in csv.DictReader(f)]


def prev(n):
    return n * (n + 1) // 2


def milhar(x):
    return f"{x:,}".replace(",", ".")


def dec(x, casas=3):
    return f"{x:.{casas}f}".replace(".", ",")


def esc(s):
    for a, b in [("\\", r"\textbackslash{}"), ("&", r"\&"), ("%", r"\%"),
                 ("$", r"\$"), ("#", r"\#"), ("_", r"\_"), ("{", r"\{"),
                 ("}", r"\}"), ("~", r"\textasciitilde{}"), ("^", r"\textasciicircum{}")]:
        s = s.replace(a, b)
    return s


def escrever(nome, texto):
    (SAIDA / nome).write_text(texto, encoding="utf-8")


obrig = ler_stats(RES / "estatisticas.csv")
ampl = ler_stats(RES / "estatisticas-ampliado.csv")
todos = sorted(obrig + ampl)
if [n for n, _ in obrig] != [10, 20, 40, 80, 160]:
    sys.exit("resultados/estatisticas.csv deve conter n = 10, 20, 40, 80, 160")
for n, c in todos:
    if c != prev(n):
        sys.exit(f"n={n}: observado {c} != previsto {prev(n)}; o texto do "
                 "relatorio assume diferenca nula e precisa ser revisto")

# ---- Tabela 1: experimentos obrigatorios -----------------------------------
linhas = "".join(f"{n} & {milhar(c)} & {milhar(prev(n))} & {c - prev(n)} \\\\\n"
                 for n, c in obrig)
escrever("tabela-obrigatoria.tex",
         "\\begin{tabular}{rrrr}\n\\toprule\n"
         "$n$ & Observado & Previsto $\\frac{n(n+1)}{2}$ & Diferença \\\\\n\\midrule\n"
         + linhas + "\\bottomrule\n\\end{tabular}\n")

# ---- Tabela 2: todos os tamanhos, C/n^2 e razoes ao dobrar -----------------
obs = dict(todos)
linhas = ""
for n, c in todos:
    if n % 2 == 0 and n // 2 in obs:
        r_obs = dec(c / obs[n // 2])
        r_teo = dec(4 * (n + 1) / (n + 2))
    else:
        r_obs = r_teo = "---"
    linhas += (f"{milhar(n)} & {milhar(c)} & {dec(c / n**2, 4)} & {r_obs} & {r_teo} \\\\\n")
escrever("tabela-razoes.tex",
         "\\begin{tabular}{rrrrr}\n\\toprule\n"
         "$n$ & $C(n)$ observado & $C(n)/n^2$ & $\\dfrac{C(n)}{C(n/2)}$ observada & "
         "$\\dfrac{4(n+1)}{n+2}$ \\\\\n\\midrule\n"
         + linhas + "\\bottomrule\n\\end{tabular}\n")

# ---- Inclinacao log-log (regressao de ln C contra ln n) --------------------
xs = [math.log(n) for n, _ in todos]
ys = [math.log(c) for _, c in todos]
mx, my = sum(xs) / len(xs), sum(ys) / len(ys)
inclinacao = (sum((x - mx) * (y - my) for x, y in zip(xs, ys))
              / sum((x - mx) ** 2 for x in xs))

# ---- Execucao completa (com redundancias) ----------------------------------
completa = ler_stats(RES / "completa" / "estatisticas.csv")[-1]
m, comp = completa
saida_txt = (RES / "completa" / "saida.txt").read_text(encoding="utf-8", errors="replace")
d = sum(1 for linha in saida_txt.splitlines() if linha.startswith("ERRO:"))
lidas = int((RES / "completa" / "linhas-lidas.txt").read_text().strip())
if m + d != lidas:
    sys.exit(f"inseridos ({m}) + redundantes ({d}) != linhas lidas ({lidas})")
base = prev(m)
excesso = comp - base
media = excesso / d if d else 0.0
escrever("tabela-completa.tex",
         "\\begin{tabular}{lr}\n\\toprule\nGrandeza & Valor \\\\\n\\midrule\n"
         f"Registros lidos da origem & {milhar(lidas)} \\\\\n"
         f"Nomes inseridos ($m$) & {milhar(m)} \\\\\n"
         f"Nomes redundantes ($d$) & {milhar(d)} \\\\\n"
         f"Comparações observadas & {milhar(comp)} \\\\\n"
         f"$m(m+1)/2$ (custo das inserções) & {milhar(base)} \\\\\n"
         f"Excesso (custo das $d$ buscas com sucesso) & {milhar(excesso)} \\\\\n"
         f"Excesso médio por redundante & {dec(media, 1)} \\\\\n"
         "\\bottomrule\n\\end{tabular}\n")

# ---- Ambiente ---------------------------------------------------------------
amb = {}
for linha in (RES / "ambiente.txt").read_text(encoding="utf-8").splitlines():
    k, _, v = linha.partition(": ")
    amb[k] = v

maior_n, maior_c = todos[-1]
macros = {
    "totalpontos": str(len(todos)),
    "maiorN": milhar(maior_n),
    "inclinacao": dec(inclinacao, 3),
    "cnnMaior": dec(maior_c / maior_n ** 2, 4),
    "razaoMaior": dec(maior_c / obs[maior_n // 2], 3),
    "cLidas": milhar(lidas), "cInseridos": milhar(m), "cRedundantes": milhar(d),
    "cComp": milhar(comp), "cBase": milhar(base), "cExcesso": milhar(excesso),
    "cMedia": dec(media, 1),
    "ambCompilador": esc(amb.get("compilador", "")),
    "ambSistema": esc(amb.get("sistema", "")),
    "ambData": esc(amb.get("data", "")),
}
escrever("valores.tex",
         "".join(f"\\newcommand{{\\{k}}}{{{v}}}\n" for k, v in macros.items()))

# ---- Grafico ----------------------------------------------------------------
plt.rcParams.update({"font.size": 9})
fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(7.2, 3.1))

xs_cont = list(range(0, 161))
ax1.plot(xs_cont, [prev(n) for n in xs_cont], color="0.55", lw=1.6,
         label=r"previsto $n(n+1)/2$")
ax1.plot([n for n, _ in obrig], [c for _, c in obrig], "o", color="#1f4e9c",
         ms=5, label="observado")
ax1.set_xlabel("nomes inseridos ($n$)")
ax1.set_ylabel("comparações")
ax1.set_title("(a) $n$ de 10 a 160", fontsize=9)
ax1.legend(frameon=False)
ax1.grid(alpha=0.25)

grade = [10 * 1.04 ** k for k in range(0, 200)]
grade = [g for g in grade if g <= maior_n * 1.1]
ax2.loglog(grade, [g * (g + 1) / 2 for g in grade], color="0.55", lw=1.6,
           label=r"previsto $n(n+1)/2$")
ax2.loglog([n for n, _ in todos], [c for _, c in todos], "o", color="#1f4e9c",
           ms=5, label="observado")
ax2.loglog(grade, [0.5 * g ** 2 for g in grade], "--", color="#b5481f", lw=1,
           label=r"referência $n^2/2$")
ax2.set_xlabel("nomes inseridos ($n$)")
ax2.set_title("(b) escala log-log, todos os tamanhos", fontsize=9)
ax2.legend(frameon=False)
ax2.grid(alpha=0.25, which="both")

fig.tight_layout()
fig.savefig(SAIDA / "grafico.pdf")
print("relatorio/gerado atualizado:", len(todos), "pontos; inclinacao log-log =",
      dec(inclinacao, 3))
