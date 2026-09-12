# ==============================================================================
# 01_VERIFICAR_V5.R
# ==============================================================================

rm(list = ls())
options(stringsAsFactors = FALSE, scipen = 999)

LOCAL_LIB <- file.path(getwd(), "R_libs")
if (dir.exists(LOCAL_LIB)) .libPaths(c(LOCAL_LIB, .libPaths()))

ARQ_JN <- "data/raw/justica_numeros/JN_23-Jun-2026.csv"
ARQ_IA <- "data/raw/ia/ia_adocao_validada.csv"

PACOTES <- c(
  "tidyverse","fixest","did","stargazer","broom","digest",
  "didimputation","clubSandwich","fwildclusterboot"
)

cat("\n============================================================\n")
cat("ANPEC V5 - VERIFICAÇÃO\n")
cat("============================================================\n")
cat("Working directory:", getwd(), "\n\n")

checks <- c(
  "Justiça em Números" = file.exists(ARQ_JN),
  "Cronologia IA" = file.exists(ARQ_IA),
  "Preparação" = file.exists("02_PREPARAR_DADOS_V5.R"),
  "Baseline" = file.exists("03_BASELINE_V5.R"),
  "Robustez avançada" = file.exists("04_ROBUSTEZ_AVANCADA_V5.R")
)
print(checks)

cat("\nPacotes:\n")
pkg_ok <- logical(length(PACOTES))
names(pkg_ok) <- PACOTES

for (p in PACOTES) {
  pkg_ok[p] <- requireNamespace(p, quietly = TRUE)
  ver <- if (pkg_ok[p]) as.character(packageVersion(p)) else "FALTA"
  cat(sprintf("  %-20s %s\n", p, ver))
}

if (!all(checks)) {
  stop("Estrutura do projeto incompleta.")
}

if (!all(pkg_ok)) {
  stop(
    "Há pacotes ausentes: ",
    paste(names(pkg_ok)[!pkg_ok], collapse = ", "),
    ". Rode 00_INSTALAR_PACOTES_V5.R novamente."
  )
}

if (packageVersion("fixest") < "0.13.2") {
  stop(
    "fixest é antigo (", as.character(packageVersion("fixest")),
    "). A V5 exige fixest >= 0.13.2."
  )
}

cat("\n============================================================\n")
cat("V5 PRONTA PARA EXECUÇÃO\n")
cat("Rode 02_PREPARAR_DADOS_V5.R\n")
cat("============================================================\n")
