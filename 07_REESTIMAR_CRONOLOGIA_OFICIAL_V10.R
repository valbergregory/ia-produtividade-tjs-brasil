# ==============================================================================
# 07_REESTIMAR_CRONOLOGIA_OFICIAL_V10.R
#
# Atualiza SOMENTE a cronologia de adoção com a auditoria V10 e reexecuta
# preparação, baseline, robustez avançada e, se disponível, wild bootstrap.
#
# Execute NA RAIZ do projeto V5.
# ==============================================================================

rm(list = ls())
options(stringsAsFactors = FALSE, scipen = 999)

LOCAL_LIB <- file.path(getwd(), "R_libs")
if (dir.exists(LOCAL_LIB)) .libPaths(c(LOCAL_LIB, .libPaths()))

novo <- "ia_adocao_validada_v10.csv"
dest <- "data/raw/ia/ia_adocao_validada.csv"
backup <- "data/raw/ia/ia_adocao_validada_PRE_V10.csv"

if (!file.exists(novo)) {
  stop("Copie ia_adocao_validada_v10.csv para a raiz do projeto V5 antes de executar.")
}
if (!file.exists(dest)) {
  stop("Não encontrei data/raw/ia/ia_adocao_validada.csv. Execute na raiz do projeto V5.")
}

if (!file.exists(backup)) {
  file.copy(dest, backup, overwrite = FALSE)
  message("Backup criado: ", backup)
}

file.copy(novo, dest, overwrite = TRUE)
message("Cronologia V10 aplicada em: ", dest)

scripts <- c(
  "02_PREPARAR_DADOS_V5.R",
  "03_BASELINE_V5.R",
  "04_ROBUSTEZ_AVANCADA_V5.R"
)

for (s in scripts) {
  if (!file.exists(s)) stop("Script ausente: ", s)
  message("\n============================================================")
  message("REEXECUTANDO: ", s)
  message("============================================================")
  sys.source(s, envir = .GlobalEnv)
}

wild_candidates <- c(
  "06_PATCH_WILD_BOOTSTRAP_V5_2_1.R",
  "06_PATCH_WILD_BOOTSTRAP_V5_2.R"
)

wild <- wild_candidates[file.exists(wild_candidates)][1]

if (!is.na(wild) && length(wild) == 1) {
  message("\nReexecutando wild bootstrap: ", wild)
  sys.source(wild, envir = .GlobalEnv)
} else {
  message("\nWild bootstrap não foi reexecutado automaticamente.")
  message("Se o script 06_PATCH_WILD_BOOTSTRAP_V5_2_1.R estiver em outra pasta, copie-o para a raiz e rode-o após este patch.")
}

dir.create("outputs/audit", recursive = TRUE, showWarnings = FALSE)
writeLines(
  c(
    "CRONOLOGIA V10 APLICADA E MODELOS REESTIMADOS",
    paste("Data/hora:", Sys.time()),
    "Correções principais: TJAC/TJAL/TJAM/TJAP/TJCE -> primeira adoção em 2019.",
    "TJES permanece com datação 2020 marcada como incerta e deve ser objeto de sensibilidade."
  ),
  "outputs/audit/STATUS_CRONOLOGIA_V10.txt"
)

message("\n============================================================")
message("REESTIMAÇÃO V10 CONCLUÍDA")
message("============================================================")
message("Compacte outputs/ e data/processed/ e envie para atualização final do Overleaf.")
