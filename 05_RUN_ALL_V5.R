# ==============================================================================
# 05_RUN_ALL_V5.R
#
# Orquestrador. Para pela primeira falha dos blocos essenciais.
# ==============================================================================

rm(list = ls())
options(stringsAsFactors = FALSE, scipen = 999)

SEED <- 20260809L
set.seed(SEED)

LOCAL_LIB <- file.path(getwd(), "R_libs")
if (dir.exists(LOCAL_LIB)) .libPaths(c(LOCAL_LIB, .libPaths()))

scripts <- c(
  "01_VERIFICAR_V5.R",
  "02_PREPARAR_DADOS_V5.R",
  "03_BASELINE_V5.R",
  "04_ROBUSTEZ_AVANCADA_V5.R"
)

dir.create("outputs/logs",recursive=TRUE,showWarnings=FALSE)
logfile <- file.path(
  "outputs/logs",
  paste0("run_all_v5_",format(Sys.time(),"%Y%m%d_%H%M%S"),".log")
)

sink(logfile,split=TRUE)
on.exit(sink(),add=TRUE)

cat("ANPEC V5 - RUN ALL\n")
cat("Início:",as.character(Sys.time()),"\n\n")

for (s in scripts) {
  cat("\n============================================================\n")
  cat("EXECUTANDO:",s,"\n")
  cat("============================================================\n")

  tryCatch(
    sys.source(s,envir=.GlobalEnv),
    error=function(e) {
      cat("\nERRO NO SCRIPT:",s,"\n")
      cat("MENSAGEM:",conditionMessage(e),"\n")
      stop(e)
    }
  )
}

cat("\n============================================================\n")
cat("PIPELINE V5 CONCLUÍDO\n")
cat("Fim:",as.character(Sys.time()),"\n")
cat("============================================================\n")
