# ia-produtividade-tjs-brasil

Compêndio reproduzível do estudo (formato ANPEC, Área 5):

> **Inteligência Artificial e Produtividade no Setor Público: Evidências dos
> Tribunais de Justiça Brasileiros**
> Valber Gregory Barbosa Costa Bezerra Santos (UFAL / TJAL)

Pergunta: a primeira adoção institucional oficial de inteligência artificial
foi acompanhada por ganhos agregados mensuráveis de produtividade nos 27
Tribunais de Justiça estaduais? O painel anual dos TJs (Justiça em Números,
CNJ) é combinado com uma **cronologia auditada de adoção** (`ia_adocao_validada_v10.csv`,
com fonte e grau de confiança por tribunal) e estimado por efeitos fixos,
diferenças-em-diferenças escalonadas (Callaway–Sant'Anna, BJS/`didimputation`),
estudos de eventos, inferência para poucos clusters (CR2 + wild cluster
bootstrap), sensibilidade ao timing (A/B/C/D), leave-one-TJ-out e análise de
poder (MDE).

**Situação (2026-09):** núcleo econométrico consolidado (pipeline V5 com a
cronologia V10). As tabelas e figuras em `outputs/`
são os resultados oficiais do pipeline. Conforme
`DECISOES_METODOLOGICAS_V5.md`, os resultados não autorizam, por si, linguagem
causal.

![R](https://img.shields.io/badge/R-4.4-276DC3?logo=r) ![fixest](https://img.shields.io/badge/did-fixest%20%7C%20did%20%7C%20didimputation-1f6b73) ![License](https://img.shields.io/badge/code-MIT-green) ![Data](https://img.shields.io/badge/cronologia-CC%20BY%204.0-blue)

## Dados

| Arquivo | Fonte | Conteúdo |
|---|---|---|
| `data/raw/justica_numeros/` | CNJ — Justiça em Números (painel anual público) | indicadores de produtividade, acervo, força de trabalho e despesa dos 27 TJs |
| `ia_adocao_validada_v10.csv` | compilação própria a partir de fontes oficiais (relatórios FGV Justiça/CNJ, portais dos tribunais, notícias institucionais) | ano da primeira adoção de IA (qualquer uso e em produção), status de validação, evidência, URL da fonte e grau de confiança por tribunal |
| `revisoes_cronologia_v10.csv` | idem | revisões da V10 em relação à cronologia anterior (`data/raw/ia/ia_adocao_validada_PRE_V10.csv`) |
| `data/processed/painel_anpec_v5.csv` | derivado | painel TJ-ano usado na estimação |

A cronologia é um dado aberto reutilizável (CC BY 4.0). Os dados do CNJ
pertencem à fonte e são redistribuídos apenas para reprodutibilidade.

## Estrutura

```
.
├── 00_INSTALAR_PACOTES_V5.R          # instala os pacotes em R_libs/ (biblioteca local; não versionada)
├── 00_INSTALAR_PACOTES_V5_1_RAPIDO.R
├── 01_VERIFICAR_V5.R                 # checagem do ambiente
├── 02_PREPARAR_DADOS_V5.R            # painel TJ-ano + cronologia
├── 03_BASELINE_V5.R                  # TWFE com controles corrigidos
├── 04_ROBUSTEZ_AVANCADA_V5.R         # C&S, BJS, CR2, timing, leave-one-out, MDE
├── 05_RUN_ALL_V5.R                   # roda 02 → 04
├── 06_PATCH_WILD_BOOTSTRAP_V5_2*.R   # wild cluster bootstrap (9 999 replicações)
├── 07_REESTIMAR_CRONOLOGIA_OFICIAL_V10.R   # aplica a cronologia V10 e reestima tudo
├── ia_adocao_validada_v10.csv        # cronologia auditada (dado aberto)
├── revisoes_cronologia_v10.csv
├── data/{raw,processed}/
├── outputs/{audit,tables,figures,logs}/   # resultados oficiais + sessionInfo
├── DECISOES_METODOLOGICAS_V5.md, LEIA_PRIMEIRO_V5.md, LEIA_ME_*.txt   # notas de execução
└── ANPEC_IA_Judiciario_V5.Rproj
```

## Como reproduzir

Requisitos: R 4.4.x (o pipeline foi executado em R 4.4.2 no Windows; versões
exatas dos pacotes em `outputs/logs/sessionInfo_v5.txt`).

```r
# no RStudio, com ANPEC_IA_Judiciario_V5.Rproj aberto
source("00_INSTALAR_PACOTES_V5.R")               # cria R_libs/ com fixest, did, didimputation,
                                                 # clubSandwich, fwildclusterboot, tidyverse…
source("01_VERIFICAR_V5.R")
source("07_REESTIMAR_CRONOLOGIA_OFICIAL_V10.R")  # 02 → 03 → 04 + wild bootstrap com a cronologia V10
```

Semente e hashes dos insumos ficam em `outputs/audit/hashes_e_seed_v5.txt`.
Migração para `renv` está prevista, mas não é necessária para reproduzir.

## Licença

Código: MIT (`LICENSE`). Cronologia de adoção: CC BY 4.0. Dados do CNJ: termos
da fonte. Ver `LICENSING.md`.

Página do projeto: <https://valbergregory.github.io/pesquisa/ia-produtividade-tribunais/>.
