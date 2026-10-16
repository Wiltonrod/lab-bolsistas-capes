#!/usr/bin/env bash
# Experimentos do relatorio. Uso: bash scripts/experimentos.sh  (ou make experimentos)
#
# Para cada tamanho n:
#   1. monta tests/entrada/bolsistas-n.csv com o cabecalho + os n primeiros nomes
#      DISTINTOS de data/bolsistas-2025.csv;
#   2. cria resultados/amostras/cadastro-n.csv contendo so o cabecalho;
#   3. executa ./copiador e acumula a linha de estatisticas.
# Alem disso, faz uma execucao completa com o arquivo inteiro (com redundancias).
set -euo pipefail
cd "$(dirname "$0")/.."

BIN=./copiador
FONTE=data/bolsistas-2025.csv
ENTRADAS=tests/entrada
RES=resultados
CAB="Nome,Modalidade,Nivel,Agencia"
OBRIGATORIOS="10 20 40 80 160"
AMPLIADOS="320 640 1280 2560 5120"

make -s copiador

rm -rf "$RES" "$ENTRADAS"
mkdir -p "$RES/amostras" "$RES/completa" "$ENTRADAS"

# Nomes distintos, na ordem de aparicao (a primeira linha e o cabecalho).
UNICOS=$(mktemp)
trap 'rm -f "$UNICOS"' EXIT
awk -F, 'NR > 1 && !visto[$1]++' "$FONTE" > "$UNICOS"
TOTAL=$(wc -l < "$UNICOS")
echo "Nomes distintos disponiveis em $FONTE: $TOTAL"

serie() {   # $1 = arquivo de estatisticas; demais argumentos = tamanhos
    local stats=$1; shift
    local n
    for n in "$@"; do
        if [ "$n" -gt "$TOTAL" ]; then
            echo "aviso: n=$n maior que o numero de nomes distintos ($TOTAL); ignorado" >&2
            continue
        fi
        { echo "$CAB"; head -n "$n" "$UNICOS"; } > "$ENTRADAS/bolsistas-$n.csv"
        echo "$CAB" > "$RES/amostras/cadastro-$n.csv"
        "$BIN" "$ENTRADAS/bolsistas-$n.csv" "$RES/amostras/cadastro-$n.csv" "$stats" \
            > "$RES/amostras/saida-$n.txt" 2> /dev/null
        printf '  n=%-5s ok\n' "$n"
    done
}

echo "Serie obrigatoria:"
serie "$RES/estatisticas.csv" $OBRIGATORIOS
echo "Serie ampliada:"
serie "$RES/estatisticas-ampliado.csv" $AMPLIADOS

echo "Execucao completa com o arquivo de origem inteiro:"
echo "$CAB" > "$RES/completa/cadastro.csv"
"$BIN" "$FONTE" "$RES/completa/cadastro.csv" "$RES/completa/estatisticas.csv" \
    > "$RES/completa/saida.txt" 2> /dev/null
echo $(( $(wc -l < "$FONTE") - 1 )) > "$RES/completa/linhas-lidas.txt"

{
    echo "compilador: $(${CC:-gcc} --version | head -n 1)"
    echo "sistema: $(uname -sr)"
    echo "data: $(date +%d/%m/%Y)"
} > "$RES/ambiente.txt"

echo
echo "resultados/estatisticas.csv:"
cat "$RES/estatisticas.csv"
