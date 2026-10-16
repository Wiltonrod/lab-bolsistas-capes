/*
 * copiador.c
 *
 * Copia registros de um CSV de origem para um CSV de destino sem inserir
 * registros cujo campo Nome ja exista no destino. Conta quantas comparacoes
 * entre nomes foram feitas e grava as estatisticas em um terceiro CSV.
 *
 * Uso:   ./copiador origem.csv destino.csv estatisticas.csv
 * Saida: mensagens "ERRO: nome redundante encontrado: <nome>" na saida padrao.
 *
 * Convencoes (ver relatorio, secoes 2 e 5):
 *  - A busca por redundancia e sequencial, na ordem das linhas do destino.
 *  - Toda linha do destino participa da busca, inclusive o cabecalho
 *    ("Nome,Modalidade,Nivel,Agencia"), cujo campo Nome e "Nome".
 *  - Uma comparacao e uma chamada a strcmp entre o Nome lido da origem e o
 *    Nome de uma linha do destino.
 */
#define _POSIX_C_SOURCE 200809L

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>

#define CABECALHO       "Nome,Modalidade,Nivel,Agencia"
#define CABECALHO_NOME  "Nome"
#define CABECALHO_STATS "nomes_inseridos,comparacoes"

/* Nomes das linhas do destino, na mesma ordem em que aparecem no arquivo. */
typedef struct {
    char  **nomes;
    size_t  tamanho;
    size_t  capacidade;
} Cadastro;

/* Contador global de comparacoes entre nomes. */
static unsigned long long comparacoes = 0;

static void erro_fatal(const char *contexto, const char *caminho)
{
    fprintf(stderr, "copiador: %s: %s (%s)\n", contexto, caminho, strerror(errno));
    exit(1);
}

static void sem_memoria(void)
{
    fprintf(stderr, "copiador: memoria insuficiente\n");
    exit(1);
}

/* Remove \n e \r do fim da linha. */
static void remover_fim_de_linha(char *s)
{
    size_t n = strlen(s);
    while (n > 0 && (s[n - 1] == '\n' || s[n - 1] == '\r'))
        s[--n] = '\0';
}

/* Pula a marca BOM do UTF-8 (EF BB BF), se existir. */
static char *pular_bom(char *s)
{
    if ((unsigned char)s[0] == 0xEF && (unsigned char)s[1] == 0xBB &&
        (unsigned char)s[2] == 0xBF)
        return s + 3;
    return s;
}

/* Devolve uma copia alocada do primeiro campo (Nome) da linha CSV.
 * Aceita campo entre aspas ("SOBRENOME, NOME"). */
static char *extrair_nome(const char *linha)
{
    char *nome = malloc(strlen(linha) + 1);
    if (nome == NULL)
        sem_memoria();

    size_t k = 0;
    if (linha[0] == '"') {
        const char *p = linha + 1;
        while (*p != '\0') {
            if (*p == '"') {
                if (p[1] == '"') {      /* aspas escapadas */
                    nome[k++] = '"';
                    p += 2;
                    continue;
                }
                break;                  /* fim do campo */
            }
            nome[k++] = *p++;
        }
    } else {
        for (const char *p = linha; *p != '\0' && *p != ','; p++)
            nome[k++] = *p;
    }
    nome[k] = '\0';
    return nome;
}

/* Acrescenta um nome ao cadastro (assume a posse da string). */
static void cadastro_adicionar(Cadastro *c, char *nome)
{
    if (c->tamanho == c->capacidade) {
        size_t nova = c->capacidade ? c->capacidade * 2 : 1024;
        char **tmp = realloc(c->nomes, nova * sizeof *tmp);
        if (tmp == NULL)
            sem_memoria();
        c->nomes = tmp;
        c->capacidade = nova;
    }
    c->nomes[c->tamanho++] = nome;
}

/* Busca sequencial. Cada visita a uma linha do destino e uma comparacao. */
static int nome_existe(const Cadastro *c, const char *nome)
{
    for (size_t i = 0; i < c->tamanho; i++) {
        comparacoes++;
        if (strcmp(c->nomes[i], nome) == 0)
            return 1;
    }
    return 0;
}

/* Le o destino (se existir) para o cadastro. Devolve 1 se a ultima linha do
 * arquivo nao termina em \n (para podermos completar antes de anexar). */
static int carregar_destino(const char *caminho, Cadastro *c)
{
    FILE *f = fopen(caminho, "r");
    if (f == NULL) {
        if (errno == ENOENT)
            return 0;
        erro_fatal("nao foi possivel abrir o destino", caminho);
    }

    char *linha = NULL;
    size_t cap = 0;
    ssize_t len;
    int sem_quebra = 0;
    int primeira = 1;

    while ((len = getline(&linha, &cap, f)) != -1) {
        sem_quebra = (len > 0 && linha[len - 1] != '\n');
        remover_fim_de_linha(linha);
        char *reg = primeira ? pular_bom(linha) : linha;
        primeira = 0;
        if (reg[0] == '\0')
            continue;
        cadastro_adicionar(c, extrair_nome(reg));
    }
    free(linha);
    fclose(f);
    return sem_quebra;
}

int main(int argc, char **argv)
{
    if (argc != 4) {
        fprintf(stderr, "Uso: %s origem.csv destino.csv estatisticas.csv\n", argv[0]);
        return 2;
    }
    const char *caminho_origem  = argv[1];
    const char *caminho_destino = argv[2];
    const char *caminho_stats   = argv[3];

    /* 1. Carrega o destino atual (cabecalho + registros ja existentes). */
    Cadastro cad = {0};
    int sem_quebra = carregar_destino(caminho_destino, &cad);

    FILE *destino = fopen(caminho_destino, "a");
    if (destino == NULL)
        erro_fatal("nao foi possivel abrir o destino para escrita", caminho_destino);

    if (cad.tamanho == 0) {             /* destino novo ou vazio: cria cabecalho */
        fprintf(destino, "%s\n", CABECALHO);
        cadastro_adicionar(&cad, strdup(CABECALHO_NOME));
        if (cad.nomes[0] == NULL)
            sem_memoria();
    } else if (sem_quebra) {
        fputc('\n', destino);
    }

    /* 2. Percorre a origem. */
    FILE *origem = fopen(caminho_origem, "r");
    if (origem == NULL)
        erro_fatal("nao foi possivel abrir a origem", caminho_origem);

    char *linha = NULL;
    size_t cap = 0;
    unsigned long long numero = 0, inseridos = 0;

    while (getline(&linha, &cap, origem) != -1) {
        numero++;
        remover_fim_de_linha(linha);
        char *reg = (numero == 1) ? pular_bom(linha) : linha;
        if (reg[0] == '\0')
            continue;

        char *nome = extrair_nome(reg);

        /* A primeira linha da origem e o cabecalho: nao e copiada. */
        if (numero == 1 && strcmp(nome, CABECALHO_NOME) == 0) {
            free(nome);
            continue;
        }

        if (nome_existe(&cad, nome)) {
            printf("ERRO: nome redundante encontrado: %s\n", nome);
            free(nome);
            continue;
        }

        if (fprintf(destino, "%s\n", reg) < 0)
            erro_fatal("falha ao escrever no destino", caminho_destino);
        cadastro_adicionar(&cad, nome);
        inseridos++;
    }
    free(linha);
    fclose(origem);
    if (fclose(destino) != 0)
        erro_fatal("falha ao fechar o destino", caminho_destino);

    /* 3. Estatisticas: uma linha por execucao (cabecalho se o arquivo e novo). */
    struct stat st;
    int novo = (stat(caminho_stats, &st) != 0 || st.st_size == 0);
    FILE *stats = fopen(caminho_stats, "a");
    if (stats == NULL)
        erro_fatal("nao foi possivel abrir o arquivo de estatisticas", caminho_stats);
    if (novo)
        fprintf(stats, "%s\n", CABECALHO_STATS);
    fprintf(stats, "%llu,%llu\n", inseridos, comparacoes);
    if (fclose(stats) != 0)
        erro_fatal("falha ao fechar o arquivo de estatisticas", caminho_stats);

    fprintf(stderr, "copiador: %llu nomes inseridos, %llu comparacoes\n",
            inseridos, comparacoes);

    for (size_t i = 0; i < cad.tamanho; i++)
        free(cad.nomes[i]);
    free(cad.nomes);
    return 0;
}
