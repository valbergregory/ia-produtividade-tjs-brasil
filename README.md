# ia-produtividade-tjs-brasil

Código e dados do estudo *Inteligência Artificial e Produtividade no Setor
Público: Evidências dos Tribunais de Justiça Brasileiros* (Valber Gregory
Barbosa Costa Bezerra Santos, UFAL / TJAL).

Pergunta de pesquisa: a primeira adoção institucional de inteligência
artificial foi acompanhada por variações mensuráveis nos indicadores agregados
de produtividade dos 27 Tribunais de Justiça estaduais? O painel anual dos TJs
(Justiça em Números, CNJ) é combinado com uma cronologia de adoção de IA por
tribunal e estimado com efeitos fixos de tribunal e ano, diferenças-em-diferenças
escalonadas (Callaway–Sant'Anna; Borusyak–Jaravel–Spiess via `didimputation`),
estudo de eventos, inferência para poucos clusters (CR2/Satterthwaite e wild
cluster bootstrap), definições alternativas da data de tratamento (A/B/C/D),
leave-one-TJ-out e cálculo de efeito mínimo detectável (MDE).

## Dados e fontes

| Arquivo | Fonte | Conteúdo |
|---|---|---|
| `data/raw/justica_numeros/JN_23-Jun-2026.csv` | CNJ — Justiça em Números (painel anual público) | indicadores anuais dos tribunais; o pipeline usa o ramo "Estadual", 27 TJs, 2009–2025 |
| `ia_adocao_validada_v10.csv` | compilação própria a partir de fontes oficiais (relatórios FGV Justiça/CNJ, portais e relatórios dos tribunais, notícias institucionais) | por tribunal: ano da primeira adoção de IA (`first_ai_any_year`) e da primeira adoção em produção (`first_ai_prod_year`), status de datação (`timing_status_*`), projeto que serve de evidência, fonte principal, URL, grau de confiança (`confianca_*`) e observação |
| `revisoes_cronologia_v10.csv` | idem | tribunais cujo ano de adoção mudou entre a cronologia anterior e a V10, com o motivo |
| `data/raw/ia/ia_adocao_validada.csv` | cópia da cronologia em uso pelos scripts (igual à V10) | — |
| `data/raw/ia/ia_adocao_validada_PRE_V10.csv` | cronologia anterior à revisão V10 | — |
| `data/processed/painel_anpec_v5.csv` | derivado por `02_PREPARAR_DADOS_V5.R` | painel TJ-ano com variáveis em log, controles defasados e as quatro definições de coorte (`g_A_any`, `g_B_prod`, `g_C_any_full`, `g_D_prod_full`) |

Definições de timing (ver `02_PREPARAR_DADOS_V5.R`): A = ano do primeiro uso
operacional; B = ano da primeira produção confirmada; C = primeiro ano completo
após o primeiro uso (definição principal); D = primeiro ano completo após a
primeira produção. Tribunais com data desconhecida permanecem `NA` e não são
convertidos em "não tratados".

## Estrutura

```
.
├── 00_INSTALAR_PACOTES_V5.R              # instala os pacotes em R_libs/ (biblioteca local, não versionada)
├── 00_INSTALAR_PACOTES_V5_1_RAPIDO.R     # instalador alternativo (fwildclusterboot via r-universe)
├── 01_VERIFICAR_V5.R                     # checa arquivos de entrada e pacotes
├── 02_PREPARAR_DADOS_V5.R                # lê JN + cronologia; gera painel_anpec_v5.csv, hashes e coortes
├── 03_BASELINE_V5.R                      # TWFE (controles legados e corrigidos), outcomes alternativos, C&S
├── 04_ROBUSTEZ_AVANCADA_V5.R             # BJS, CR2, timing A/B/C/D, leave-one-TJ-out, MDE, Sun-Abraham (opcional)
├── 05_RUN_ALL_V5.R                       # executa 01 → 04 com log em outputs/logs/
├── 06_PATCH_WILD_BOOTSTRAP_V5_2*.R       # wild cluster bootstrap (9 999 replicações) sobre a especificação preferida
├── 07_REESTIMAR_CRONOLOGIA_OFICIAL_V10.R # aplica a cronologia V10 e reexecuta 02 → 04 e o wild bootstrap
├── ia_adocao_validada_v10.csv            # cronologia de adoção (dado aberto)
├── revisoes_cronologia_v10.csv
├── data/raw/                             # insumos (CNJ e cronologia)
├── data/processed/                       # painel e modelos salvos (.rds)
├── outputs/audit/                        # CSVs de coeficientes, status dos blocos, hashes e semente
├── outputs/logs/                         # sessionInfo e logs de execução
├── outputs/{tables,figures}/             # .tex e .pdf gerados pelo pipeline (não versionados)
├── DECISOES_METODOLOGICAS_V5.md          # o que entrou na V5 e o que ficou para rodada posterior
├── LEIA_PRIMEIRO_V5.md, LEIA_ME_*.txt    # notas de execução de cada versão/patch
└── ANPEC_IA_Judiciario_V5.Rproj
```

## Como reproduzir

Requisitos: R 4.4.x (o pipeline foi executado em R 4.4.2 / Windows 11; versões
dos pacotes em `outputs/logs/sessionInfo_v5.txt`). Pacotes principais:
`tidyverse`, `fixest` (>= 0.13.2), `did`, `didimputation`, `clubSandwich`,
`fwildclusterboot`, `stargazer`, `broom`, `digest`, `dqrng`.

```r
# no RStudio, com ANPEC_IA_Judiciario_V5.Rproj aberto
source("00_INSTALAR_PACOTES_V5.R")                # cria R_libs/
source("01_VERIFICAR_V5.R")
source("07_REESTIMAR_CRONOLOGIA_OFICIAL_V10.R")   # 02 → 03 → 04 + wild bootstrap com a cronologia V10
```

`05_RUN_ALL_V5.R` executa a sequência 01 → 04 sem o wild bootstrap. A semente
(`20260809`) e os hashes SHA-256 dos insumos são gravados em
`outputs/audit/hashes_e_seed_v5.txt`. Não há credenciais ou variáveis de
ambiente necessárias.

## Licença

- Código (scripts R, configuração): MIT (`LICENSE`).
- Cronologia de adoção de IA (`ia_adocao_validada_v10.csv`,
  `revisoes_cronologia_v10.csv`, `data/raw/ia/`): CC BY 4.0.
- Dados do CNJ (`data/raw/justica_numeros/`): pertencem ao Conselho Nacional de
  Justiça e são redistribuídos apenas para reprodutibilidade acadêmica.

Detalhes em `LICENSING.md`.

## Citação

Ver `CITATION.cff`. Página do projeto:
<https://valbergregory.github.io/pesquisa/ia-produtividade-tribunais/>.
