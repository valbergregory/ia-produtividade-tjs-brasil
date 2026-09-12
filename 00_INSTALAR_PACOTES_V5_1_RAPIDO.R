# ==============================================================================
# 00_INSTALAR_PACOTES_V5_1_RAPIDO.R
# ==============================================================================

rm(list = ls())
options(stringsAsFactors = FALSE, scipen = 999)

SEED <- 20260809L
set.seed(SEED)

LOCAL_LIB <- file.path(getwd(), "R_libs")
dir.create(LOCAL_LIB, recursive = TRUE, showWarnings = FALSE)

locks <- list.files(LOCAL_LIB, pattern = "^00LOCK", full.names = TRUE)
if (length(locks) > 0) unlink(locks, recursive = TRUE, force = TRUE)

.libPaths(c(LOCAL_LIB, .libPaths()))

CRAN <- "https://cloud.r-project.org"
REPOS_WILD <- c(
  s3alfisc = "https://s3alfisc.r-universe.dev",
  CRAN = CRAN
)

cat("\n============================================================\n")
cat("ANPEC V5.1 - INSTALAÇÃO RÁPIDA\n")
cat("============================================================\n")
cat("Biblioteca local:", LOCAL_LIB, "\n\n")

is_available <- function(pkg) requireNamespace(pkg, quietly = TRUE)

pkg_version_ok <- function(pkg, minimum = NULL) {
  if (!is_available(pkg)) return(FALSE)
  if (is.null(minimum)) return(TRUE)
  packageVersion(pkg) >= minimum
}

install_fast <- function(pkg, repos = CRAN, force_local = FALSE) {
  if (!force_local && is_available(pkg)) {
    cat(sprintf("[OK] %-20s %s (já disponível)\n",
                pkg, as.character(packageVersion(pkg))))
    return(invisible(TRUE))
  }

  cat("\nInstalando", pkg, "...\n")
  install.packages(
    pkg,
    lib = LOCAL_LIB,
    repos = repos,
    dependencies = NA
  )

  .libPaths(c(LOCAL_LIB, .libPaths()))

  if (!is_available(pkg)) {
    stop("\nNão consegui disponibilizar o pacote ", pkg,
         ".\nEnvie as últimas linhas do Console.")
  }

  cat(sprintf("[OK] %-20s %s\n",
              pkg, as.character(packageVersion(pkg))))
  invisible(TRUE)
}

# Reaproveita pacotes comuns já instalados.
comuns <- c("tidyverse","did","stargazer","broom","digest","clubSandwich")
for (p in comuns) install_fast(p)

# didimputation exige fixest >= 0.13.2.
if (!pkg_version_ok("fixest", "0.13.2")) {
  cat("\nfixest ausente ou antigo. Instalando versão atual localmente...\n")
  local_fixest <- file.path(LOCAL_LIB, "fixest")
  if (dir.exists(local_fixest)) unlink(local_fixest, recursive = TRUE, force = TRUE)
  install_fast("fixest", repos = CRAN, force_local = TRUE)
}

if (packageVersion("fixest") < "0.13.2") {
  stop("fixest continua abaixo de 0.13.2: ",
       as.character(packageVersion("fixest")))
}

cat("[OK] fixest compatível:", as.character(packageVersion("fixest")), "\n")

install_fast("didimputation")

# fwildclusterboot está fora do CRAN; usa R-universe do autor.
if (!is_available("fwildclusterboot")) {
  cat("\nInstalando fwildclusterboot pelo R-universe do autor...\n")
  install.packages(
    "fwildclusterboot",
    lib = LOCAL_LIB,
    repos = REPOS_WILD,
    dependencies = NA
  )
  .libPaths(c(LOCAL_LIB, .libPaths()))
}

if (!is_available("fwildclusterboot")) {
  stop("\nfwildclusterboot não foi instalado.\nEnvie as últimas linhas do Console.")
}

cat("[OK] fwildclusterboot:",
    as.character(packageVersion("fwildclusterboot")), "\n")

if (!is_available("dqrng")) install_fast("dqrng")

necessarios <- c(
  "tidyverse","fixest","did","stargazer","broom","digest",
  "didimputation","clubSandwich","fwildclusterboot"
)

cat("\nVERSÕES FINAIS:\n")
for (p in necessarios) {
  if (is_available(p)) {
    cat(sprintf("  %-20s %s\n", p, as.character(packageVersion(p))))
  } else {
    cat(sprintf("  %-20s FALTA\n", p))
  }
}

faltam <- necessarios[!vapply(necessarios, is_available, logical(1))]
if (length(faltam) > 0) {
  stop("\nAinda faltam: ", paste(faltam, collapse = ", "))
}

cat("\n============================================================\n")
cat("INSTALAÇÃO RÁPIDA V5.1 CONCLUÍDA\n")
cat("Agora use: Session > Restart R\n")
cat("Depois rode: 01_VERIFICAR_V5.R\n")
cat("============================================================\n")
