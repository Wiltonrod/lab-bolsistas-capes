#!/usr/bin/env bash
# Testes automatizados do copiador. Uso: bash tests/run_tests.sh  (ou make test)
set -u
cd "$(dirname "$0")/.."

BIN=./copiador
[ -x "$BIN" ] || make -s copiador || exit 1

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
CAB="Nome,Modalidade,Nivel,Agencia"
falhas=0

ok()    { echo "  ok     - $1"; }
falha() { echo "  FALHA  - $1"; falhas=$((falhas + 1)); }
confere() {   # descricao esperado obtido
    if [ "$2" == "$3" ]; then ok "$1"; else
        falha "$1"; echo "           esperado: $2"; echo "           obtido:   $3"
    fi
}

echo "Teste 1: exemplo do enunciado (mesmo Nome, outros campos diferentes)"
cp tests/exemplo/destino-antes.csv "$TMP/destino.csv"
saida=$($BIN tests/exemplo/origem.csv "$TMP/destino.csv" "$TMP/stats.csv" 2>/dev/null)
confere "mensagem de erro na saida padrao" "$(cat tests/exemplo/saida-esperada.txt)" "$saida"
if diff -q tests/exemplo/destino-esperado.csv "$TMP/destino.csv" > /dev/null; then
    ok "arquivo de destino igual ao esperado"; else falha "arquivo de destino diferente do esperado"; fi
confere "estatisticas (1 inserido, 4 comparacoes)" $'nomes_inseridos,comparacoes\n1,4' "$(cat "$TMP/stats.csv")"

echo "Teste 2: destino inexistente e nomes distintos (1+2+3 = 6 comparacoes)"
printf '%s\nA,PQ,A,CNPq\nB,DS,M,CAPES\nC,PQ,C,CNPq\n' "$CAB" > "$TMP/o2.csv"
saida=$($BIN "$TMP/o2.csv" "$TMP/d2.csv" "$TMP/s2.csv" 2>/dev/null)
confere "sem mensagens de erro" "" "$saida"
confere "destino com cabecalho e 3 registros" "$(cat "$TMP/o2.csv")" "$(cat "$TMP/d2.csv")"
confere "estatisticas" $'nomes_inseridos,comparacoes\n3,6' "$(cat "$TMP/s2.csv")"

echo "Teste 3: redundancia dentro da propria origem (A, B, A)"
printf '%s\nA,PQ,A,CNPq\nB,DS,M,CAPES\nA,PQ,C,CNPq\n' "$CAB" > "$TMP/o3.csv"
saida=$($BIN "$TMP/o3.csv" "$TMP/d3.csv" "$TMP/s3.csv" 2>/dev/null)
confere "erro apenas para o A repetido" "ERRO: nome redundante encontrado: A" "$saida"
confere "destino sem a linha repetida" $'Nome,Modalidade,Nivel,Agencia\nA,PQ,A,CNPq\nB,DS,M,CAPES' "$(cat "$TMP/d3.csv")"
confere "estatisticas (2 inseridos, 1+2+2 = 5 comparacoes)" $'nomes_inseridos,comparacoes\n2,5' "$(cat "$TMP/s3.csv")"

echo "Teste 4: estatisticas acumulam uma linha por execucao"
$BIN "$TMP/o2.csv" "$TMP/d4a.csv" "$TMP/s4.csv" > /dev/null 2>&1
$BIN "$TMP/o3.csv" "$TMP/d4b.csv" "$TMP/s4.csv" > /dev/null 2>&1
confere "um cabecalho e duas linhas" $'nomes_inseridos,comparacoes\n3,6\n2,5' "$(cat "$TMP/s4.csv")"

echo "Teste 5: n = 50 nomes distintos -> n(n+1)/2 = 1275"
{ echo "$CAB"; for i in $(seq 1 50); do echo "NOME $i,PQ,A,CNPq"; done; } > "$TMP/o5.csv"
$BIN "$TMP/o5.csv" "$TMP/d5.csv" "$TMP/s5.csv" > /dev/null 2>&1
confere "estatisticas" $'nomes_inseridos,comparacoes\n50,1275' "$(cat "$TMP/s5.csv")"

echo "Teste 6: destino sem quebra de linha final e origem com CRLF"
printf '%s\nX,PQ,A,CNPq' "$CAB" > "$TMP/d6.csv"
printf '%s\r\nY,DS,M,CAPES\r\n' "$CAB" > "$TMP/o6.csv"
$BIN "$TMP/o6.csv" "$TMP/d6.csv" "$TMP/s6.csv" > /dev/null 2>&1
confere "destino com 3 linhas bem formadas" $'Nome,Modalidade,Nivel,Agencia\nX,PQ,A,CNPq\nY,DS,M,CAPES' "$(tr -d '\r' < "$TMP/d6.csv")"
confere "estatisticas (1 inserido, 2 comparacoes: cabecalho e X)" $'nomes_inseridos,comparacoes\n1,2' "$(cat "$TMP/s6.csv")"

echo
if [ "$falhas" -eq 0 ]; then echo "Todos os testes passaram."; else echo "$falhas teste(s) falharam."; exit 1; fi
