# ==============================================================================
# 00_INSTALAR_PACOTES_V5.R
# ANPEC Área 5 - V5
#
# Instala tudo em uma biblioteca LOCAL deste projeto.
# Isso evita conflito com versões antigas de fixest/did instaladas no Windows.
# ==============================================================================

rm(list = ls())
options(stringsAsFactors = FALSE, scipen = 999)

SEED <- 20260809L
set.seed(SEED)

LOCAL_LIB <- file.path(getwd(), "R_libs")
dir.create(LOCAL_LIB, recursive = TRUE, showWarnings = FALSE)
.libPaths(c(LOCAL_LIB, .libPaths()))

repos <- "https://cloud.r-project.org"

PACOTES_CORE <- c(
  "tidyverse",
  "fixest",
  "did",
  "stargazer",
  "broom",
  "digest"
)

PACOTES_V5 <- c(
  "didimputation",
  "clubSandwich",
  "fwildclusterboot"
)

PACOTES_AUX <- c(
  "dqrng"
)

todos <- unique(c(PACOTES_CORE, PACOTES_V5, PACOTES_AUX))

cat("\n============================================================\n")
cat("ANPEC V5 - INSTALAÇÃO LOCAL\n")
cat("============================================================\n")
cat("Biblioteca local:", LOCAL_LIB, "\n\n")

for (p in todos) {
  local_pkg <- file.path(LOCAL_LIB, p)

  if (!dir.exists(local_pkg)) {
    cat("\nInstalando:", p, "\n")
    tryCatch(
      install.packages(
        p,
        lib = LOCAL_LIB,
        repos = repos,
        dependencies = TRUE
      ),
      error = function(e) {
        stop(
          "\nFalha ao instalar ", p, ".\n",
          "Mensagem: ", conditionMessage(e), "\n",
          "Tente novamente antes de prosseguir."
        )
      }
    )
  } else {
    cat(p, "já existe na biblioteca local.\n")
  }
}

cat("\nVERSÕES DETECTADAS:\n")
for (p in todos) {
  ok <- requireNamespace(p, quietly = TRUE)
  if (ok) {
    cat(sprintf("  %-20s %s\n", p, as.character(packageVersion(p))))
  } else {
    cat(sprintf("  %-20s FALTA\n", p))
  }
}

cat("\nfixest deve ser >= 0.13.2 para compatibilidade com didimputation.\n")
if (requireNamespace("fixest", quietly = TRUE)) {
  cat("fixest atual:", as.character(packageVersion("fixest")), "\n")
}

cat("\n============================================================\n")
cat("INSTALAÇÃO V5 CONCLUÍDA\n")
cat("Agora: Session > Restart R\n")
cat("Depois rode 01_VERIFICAR_V5.R\n")
cat("============================================================\n")
