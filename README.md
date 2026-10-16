# Cadastro de Bolsistas da CAPES — Análise de Algoritmos (Relatório 3)

Programa em C que copia registros de um CSV de origem para um CSV de destino sem
inserir nomes já existentes, conta as comparações entre nomes (busca sequencial) e
grava estatísticas em CSV. O relatório (`relatorio/relatorio.pdf`) traz a análise
teórica, a demonstração por indução e a validação experimental.

**Resultado principal:** com nomes distintos e destino contendo só o cabeçalho,
`C(n) = n(n+1)/2` comparações, ou seja, `Θ(n²)`.

## Estrutura

| Caminho | Conteúdo |
|---|---|
| `src/copiador.c` | código-fonte do programa |
| `Makefile` | compilação, testes, experimentos e relatório |
| `data/bolsistas-2025.csv` | arquivo de origem usado nos experimentos |
| `tests/run_tests.sh`, `tests/exemplo/` | testes automatizados (inclui o exemplo do enunciado) |
| `tests/entrada/` | arquivos de entrada gerados para cada experimento (`bolsistas-N.csv`) |
| `scripts/experimentos.sh` | roda os experimentos |
| `scripts/gerar_dados_relatorio.py` | gera tabelas, valores e gráfico do relatório a partir dos CSV |
| `resultados/estatisticas.csv` | estatísticas da série obrigatória (10, 20, 40, 80, 160) |
| `resultados/estatisticas-ampliado.csv` | série ampliada (320 a 5120) |
| `resultados/amostras/` | destinos (`cadastro-N.csv`) e saídas do programa (`saida-N.txt`) |
| `resultados/completa/` | execução com o arquivo de origem inteiro (com redundâncias) |
| `relatorio/` | fonte LaTeX e PDF do relatório |

## Compilação

Requer `gcc` e `make`.

```bash
make
```

(equivale a `gcc -std=c11 -O2 -Wall -Wextra -pedantic -o copiador src/copiador.c`)

## Execução

```bash
./copiador data/bolsistas-2025.csv cadastro.csv estatisticas.csv
```

- Redundâncias são avisadas na saída padrão: `ERRO: nome redundante encontrado: <nome>`.
- Se `cadastro.csv` não existir ou estiver vazio, é criado com o cabeçalho.
- Cada execução acrescenta uma linha `nomes_inseridos,comparacoes` a `estatisticas.csv`.

## Testes e experimentos

```bash
make test           # testes automatizados
make experimentos   # regenera tests/entrada/ e resultados/
```

## Relatório

Requer `xelatex` e Python 3 com `matplotlib`.

```bash
make relatorio REPO_URL=https://github.com/<usuario>/<repositorio>
```

## Convenção de contagem

A busca percorre todas as linhas do arquivo de destino e o cabeçalho é uma delas
(seu campo Nome vale `Nome`), portanto conta como uma comparação. Com `n` nomes
distintos inseridos a partir de um destino só com o cabeçalho, a `k`-ésima
inserção faz `k` comparações e o total é `n(n+1)/2`, o que reproduz o exemplo do
enunciado (10 → 55, 20 → 210, 40 → 820, 80 → 3240, 160 → 12880).
