CC     ?= gcc
CFLAGS ?= -std=c11 -O2 -Wall -Wextra -pedantic

# URL do repositorio que aparece no relatorio (passe na linha de comando):
#   make relatorio REPO_URL=https://github.com/usuario/repositorio
REPO_URL ?= https://github.com/SEU-USUARIO/lab-bolsistas-capes

.PHONY: all test experimentos relatorio clean

all: copiador

copiador: src/copiador.c
	$(CC) $(CFLAGS) -o $@ $<

test: copiador
	bash tests/run_tests.sh

experimentos: copiador
	bash scripts/experimentos.sh

relatorio:
	python3 scripts/gerar_dados_relatorio.py
	printf '\\newcommand{\\repourl}{\\href{%s}{\\nolinkurl{%s}}}\n' '$(REPO_URL)' '$(REPO_URL)' > relatorio/repo-url.tex
	cd relatorio && xelatex -interaction=nonstopmode -halt-on-error relatorio.tex > /dev/null \
	             && xelatex -interaction=nonstopmode -halt-on-error relatorio.tex > /dev/null

clean:
	rm -f copiador relatorio/*.aux relatorio/*.log relatorio/*.out relatorio/*.toc
