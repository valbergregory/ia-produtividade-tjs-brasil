# ==============================================================================
# 06_PATCH_WILD_BOOTSTRAP_V5_2_1.R
#
# CORREÇÃO do patch V5.2:
# - não usa stargazer;
# - calcula wild cluster bootstrap;
# - lê CR2 já calculado pela V5;
# - exporta CSVs;
# - gera LaTeX manualmente, sem tentar arredondar colunas textuais.
# ==============================================================================

rm(list = ls())
options(stringsAsFactors = FALSE, scipen = 999)

SEED <- 20260809L
set.seed(SEED)

LOCAL_LIB <- file.path(getwd(), "R_libs")
if (dir.exists(LOCAL_LIB)) .libPaths(c(LOCAL_LIB, .libPaths()))

req <- c("tidyverse","fwildclusterboot","dqrng")
missing <- req[!vapply(req, requireNamespace, logical(1), quietly = TRUE)]

if (length(missing) > 0) {
  stop(
    "Pacotes ausentes: ", paste(missing, collapse = ", "),
    ". Rode primeiro o instalador rápido V5.1."
  )
}

suppressPackageStartupMessages({
  library(tidyverse)
  library(fwildclusterboot)
})

ARQ <- "data/processed/painel_anpec_v5.csv"
ARQ_CR2 <- "outputs/audit/cr2_satterthwaite_v5.csv"
DIR_AUDIT <- "outputs/audit"
DIR_TAB <- "outputs/tables"
DIR_LOG <- "outputs/logs"

if (!file.exists(ARQ)) {
  stop("Falta data/processed/painel_anpec_v5.csv.")
}

if (!file.exists(ARQ_CR2)) {
  stop("Falta outputs/audit/cr2_satterthwaite_v5.csv. Rode a V5 avançada primeiro.")
}

dir.create(DIR_AUDIT, recursive = TRUE, showWarnings = FALSE)
dir.create(DIR_TAB, recursive = TRUE, showWarnings = FALSE)
dir.create(DIR_LOG, recursive = TRUE, showWarnings = FALSE)

painel <- readr::read_csv(ARQ, show_col_types = FALSE)

amostra <- painel %>%
  filter(
    ano >= 2014,
    ano <= 2025,
    !is.na(ai_any_lag1),
    !is.na(ln_ipm),
    !is.na(ln_cn_lag1),
    !is.na(ln_sajudp_lag1),
    !is.na(ln_dpj_lag1)
  )

cat("\n============================================================\n")
cat("V5.2.1 - WILD CLUSTER BOOTSTRAP\n")
cat("============================================================\n")
cat("N =", nrow(amostra), "\n")
cat("Clusters =", n_distinct(amostra$tribunal), "\n")

# Mesmo TWFE preferido, escrito como OLS com dummies explícitas.
lm_pref <- lm(
  ln_ipm ~ ai_any_lag1 + ln_cn_lag1 + ln_sajudp_lag1 + ln_dpj_lag1 +
    factor(tribunal) + factor(ano),
  data = amostra
)

beta_ols <- unname(coef(lm_pref)["ai_any_lag1"])

set.seed(SEED)
dqrng::dqset.seed(SEED)

cat("\nRodando 9.999 replicações...\n")

boot <- fwildclusterboot::boottest(
  lm_pref,
  param = "ai_any_lag1",
  B = 9999,
  clustid = "tribunal",
  type = "rademacher",
  engine = "R-lean",
  conf_int = TRUE
)

# API oficial atual do fwildclusterboot.
bt <- generics::tidy(boot)

required_cols <- c("estimate","statistic","p.value","conf.low","conf.high")
missing_cols <- setdiff(required_cols, names(bt))

if (length(missing_cols) > 0) {
  stop(
    "boottest executou, mas tidy() não trouxe as colunas esperadas: ",
    paste(missing_cols, collapse = ", "),
    ". Colunas encontradas: ", paste(names(bt), collapse = ", ")
  )
}

wild <- tibble(
  Metodo = "Wild cluster bootstrap",
  Estimativa = as.numeric(bt$estimate[1]),
  Estatistica = as.numeric(bt$statistic[1]),
  p_valor = as.numeric(bt$p.value[1]),
  IC_inf = as.numeric(bt$conf.low[1]),
  IC_sup = as.numeric(bt$conf.high[1]),
  Replicacoes = 9999L,
  Clusters = n_distinct(amostra$tribunal)
)

write_csv(
  wild,
  file.path(DIR_AUDIT, "wild_cluster_v5_2_1.csv")
)

# --------------------------------------------------------------------------
# CR1 convencional: usa coeficiente OLS equivalente e SE/p da V5 já calculada.
# --------------------------------------------------------------------------

old_inf_file <- "outputs/audit/inferencia_poucos_clusters_v5.csv"

if (!file.exists(old_inf_file)) {
  stop("Falta outputs/audit/inferencia_poucos_clusters_v5.csv.")
}

old_inf <- read_csv(old_inf_file, show_col_types = FALSE)
cr1 <- old_inf %>% filter(Metodo == "CR1 cluster TJ")

if (nrow(cr1) != 1) {
  stop("Não consegui identificar a linha CR1 em inferencia_poucos_clusters_v5.csv.")
}

# --------------------------------------------------------------------------
# CR2: usa diretamente o arquivo correto, sem parser genérico.
# --------------------------------------------------------------------------

cr2raw <- read_csv(ARQ_CR2, show_col_types = FALSE)

cr2row <- cr2raw %>%
  filter(Coef == "ai_any_lag1")

if (nrow(cr2row) != 1) {
  stop("Não consegui identificar ai_any_lag1 em cr2_satterthwaite_v5.csv.")
}

# IC CR2 com t crítico e gl de Satterthwaite.
tcrit <- qt(0.975, df = cr2row$df_Satt[1])

cr2_ci_low <- cr2row$beta[1] - tcrit * cr2row$SE[1]
cr2_ci_high <- cr2row$beta[1] + tcrit * cr2row$SE[1]

final <- tibble(
  Metodo = c(
    "CR1 cluster TJ",
    "CR2 Satterthwaite",
    "Wild cluster bootstrap"
  ),
  Estimativa = c(
    cr1$Estimativa[1],
    cr2row$beta[1],
    wild$Estimativa[1]
  ),
  EP = c(
    cr1$EP[1],
    cr2row$SE[1],
    NA_real_
  ),
  p_valor = c(
    cr1$p_valor[1],
    cr2row$p_Satt[1],
    wild$p_valor[1]
  ),
  IC_inf = c(
    cr1$IC_inf[1],
    cr2_ci_low,
    wild$IC_inf[1]
  ),
  IC_sup = c(
    cr1$IC_sup[1],
    cr2_ci_high,
    wild$IC_sup[1]
  )
)

write_csv(
  final,
  file.path(DIR_AUDIT, "inferencia_poucos_clusters_v5_2_1.csv")
)

# --------------------------------------------------------------------------
# LaTeX MANUAL - sem stargazer
# --------------------------------------------------------------------------

fmt <- function(x, digits = 4) {
  ifelse(is.na(x), "--", formatC(x, format = "f", digits = digits))
}

latex_rows <- apply(final, 1, function(r) {
  paste0(
    r[["Metodo"]], " & ",
    fmt(as.numeric(r[["Estimativa"]])), " & ",
    fmt(as.numeric(r[["EP"]])), " & ",
    fmt(as.numeric(r[["p_valor"]])), " & ",
    "[", fmt(as.numeric(r[["IC_inf"]])), "; ",
    fmt(as.numeric(r[["IC_sup"]])), "] \\\\"
  )
})

latex <- c(
  "\\begin{table}[!htbp]",
  "\\centering",
  "\\caption{Inferência com poucos clusters}",
  "\\label{tab:smallcluster_v5}",
  "\\begin{tabular}{lcccc}",
  "\\hline",
  "Método & Estimativa & EP & p-valor & IC 95\\% \\\\",
  "\\hline",
  latex_rows,
  "\\hline",
  "\\end{tabular}",
  "\\begin{flushleft}",
  "\\footnotesize Notas: CR1 = erros-padrão agrupados por Tribunal de Justiça. ",
  "CR2 utiliza correção de pequena amostra com graus de liberdade de Satterthwaite. ",
  "Wild cluster bootstrap utiliza 9.999 replicações e pesos de Rademacher.",
  "\\end{flushleft}",
  "\\end{table}"
)

writeLines(
  latex,
  file.path(DIR_TAB, "tab6_v5_2_1_inferencia_poucos_clusters.tex")
)

capture.output(
  summary(boot),
  file = file.path(DIR_LOG, "wild_cluster_bootstrap_v5_2_1.txt")
)

cat("\nRESULTADO WILD:\n")
print(wild)

cat("\nCOMPARAÇÃO FINAL:\n")
print(final)

cat("\n============================================================\n")
cat("WILD BOOTSTRAP V5.2.1 CONCLUÍDO\n")
cat("============================================================\n")
cat("Envie somente:\n")
cat("1. outputs/audit/wild_cluster_v5_2_1.csv\n")
cat("2. outputs/audit/inferencia_poucos_clusters_v5_2_1.csv\n")
cat("============================================================\n")
