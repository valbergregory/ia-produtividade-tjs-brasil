# ==============================================================================
# 06_PATCH_WILD_BOOTSTRAP_V5_2.R
#
# Corrige SOMENTE o wild cluster bootstrap.
# Não refaz Callaway-Sant'Anna, BJS, timing nem leave-one-out.
#
# Estratégia:
# - reestima a especificação TWFE preferida como lm com dummies de TJ e ano;
# - aplica fwildclusterboot::boottest() ao objeto lm;
# - usa generics::tidy() para extrair resultado de forma compatível com v0.14.x;
# - combina o resultado com CR1 e CR2 já existentes.
# ==============================================================================

rm(list = ls())
options(stringsAsFactors = FALSE, scipen = 999)

SEED <- 20260809L
set.seed(SEED)

LOCAL_LIB <- file.path(getwd(), "R_libs")
if (dir.exists(LOCAL_LIB)) .libPaths(c(LOCAL_LIB, .libPaths()))

req <- c(
  "tidyverse",
  "fwildclusterboot",
  "dqrng",
  "stargazer"
)

missing <- req[!vapply(req, requireNamespace, logical(1), quietly = TRUE)]

if (length(missing) > 0) {
  stop(
    "Pacotes ausentes: ", paste(missing, collapse = ", "),
    ". Rode o instalador V5.1 antes deste patch."
  )
}

suppressPackageStartupMessages({
  library(tidyverse)
  library(fwildclusterboot)
  library(stargazer)
})

ARQ <- "data/processed/painel_anpec_v5.csv"
DIR_AUDIT <- "outputs/audit"
DIR_TAB <- "outputs/tables"
DIR_LOG <- "outputs/logs"

if (!file.exists(ARQ)) {
  stop("Não encontrei data/processed/painel_anpec_v5.csv.")
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
cat("V5.2 - WILD CLUSTER BOOTSTRAP\n")
cat("============================================================\n")
cat("Observações:", nrow(amostra), "\n")
cat("Clusters:", dplyr::n_distinct(amostra$tribunal), "\n")

# A regressão abaixo é algebraicamente equivalente ao TWFE preferido,
# mas usa dummies explícitas. Isso torna a interface com boottest mais robusta.
lm_pref <- lm(
  ln_ipm ~ ai_any_lag1 + ln_cn_lag1 + ln_sajudp_lag1 + ln_dpj_lag1 +
    factor(tribunal) + factor(ano),
  data = amostra
)

# Reprodutibilidade conforme fwildclusterboot >= 0.13.
set.seed(SEED)
dqrng::dqset.seed(SEED)

cat("Rodando 9.999 replicações wild cluster bootstrap...\n")

boot <- fwildclusterboot::boottest(
  lm_pref,
  param = "ai_any_lag1",
  B = 9999,
  clustid = "tribunal",
  type = "rademacher",
  engine = "R-lean",
  conf_int = TRUE
)

# A API atual oferece tidy() diretamente para objetos boottest.
boot_tidy <- generics::tidy(boot)

if (nrow(boot_tidy) < 1) {
  stop("boottest rodou, mas tidy() não retornou resultado.")
}

wild <- tibble(
  Metodo = "Wild cluster bootstrap",
  Estimativa = as.numeric(boot_tidy$estimate[1]),
  Estatistica = as.numeric(boot_tidy$statistic[1]),
  p_valor = as.numeric(boot_tidy$p.value[1]),
  IC_inf = as.numeric(boot_tidy$conf.low[1]),
  IC_sup = as.numeric(boot_tidy$conf.high[1]),
  B = 9999,
  Clusters = n_distinct(amostra$tribunal)
)

write_csv(
  wild,
  file.path(DIR_AUDIT, "wild_cluster_v5_2.csv")
)

# Atualiza tabela consolidada com CR1 e CR2 já existentes.
cr1_cr2_file <- file.path(DIR_AUDIT, "inferencia_poucos_clusters_v5.csv")

if (!file.exists(cr1_cr2_file)) {
  stop(
    "Não encontrei inferencia_poucos_clusters_v5.csv. ",
    "A V5 avançada precisa ter sido executada antes deste patch."
  )
}

old <- read_csv(cr1_cr2_file, show_col_types = FALSE)

base2 <- old %>%
  filter(Metodo != "Wild cluster bootstrap") %>%
  select(Metodo, Estimativa, EP, p_valor, IC_inf, IC_sup)

new_wild <- tibble(
  Metodo = "Wild cluster bootstrap",
  Estimativa = wild$Estimativa,
  EP = NA_real_,
  p_valor = wild$p_valor,
  IC_inf = wild$IC_inf,
  IC_sup = wild$IC_sup
)

final <- bind_rows(base2, new_wild)

write_csv(
  final,
  file.path(DIR_AUDIT, "inferencia_poucos_clusters_v5_2.csv")
)

stargazer(
  final,
  type = "latex",
  summary = FALSE,
  rownames = FALSE,
  header = FALSE,
  digits = 4,
  title = "Inferência com poucos clusters",
  out = file.path(DIR_TAB, "tab6_v5_2_inferencia_poucos_clusters.tex")
)

capture.output(
  print(boot),
  file = file.path(DIR_LOG, "wild_cluster_bootstrap_v5_2.txt")
)

cat("\nRESULTADO:\n")
print(wild)

cat("\n============================================================\n")
cat("WILD BOOTSTRAP V5.2 CONCLUÍDO\n")
cat("============================================================\n")
cat("Envie:\n")
cat("- outputs/audit/wild_cluster_v5_2.csv\n")
cat("- outputs/audit/inferencia_poucos_clusters_v5_2.csv\n")
cat("============================================================\n")
