# ==============================================================================
# 02_PREPARAR_DADOS_V5.R
#
# Centraliza:
# - leitura dos dados;
# - variáveis de outcome;
# - controles legados e corrigidos;
# - TODAS as definições de timing.
#
# Nenhum script posterior recalcula cohorts manualmente.
# ==============================================================================

rm(list = ls())
options(stringsAsFactors = FALSE, scipen = 999)

SEED <- 20260809L
set.seed(SEED)

LOCAL_LIB <- file.path(getwd(), "R_libs")
if (dir.exists(LOCAL_LIB)) .libPaths(c(LOCAL_LIB, .libPaths()))

suppressPackageStartupMessages({
  library(tidyverse)
  library(digest)
})

ARQ_JN <- "data/raw/justica_numeros/JN_23-Jun-2026.csv"
ARQ_IA <- "data/raw/ia/ia_adocao_validada.csv"
DIR_PROC <- "data/processed"
DIR_AUDIT <- "outputs/audit"

dir.create(DIR_PROC, recursive = TRUE, showWarnings = FALSE)
dir.create(DIR_AUDIT, recursive = TRUE, showWarnings = FALSE)

TJS <- c(
  "TJAC","TJAL","TJAM","TJAP","TJBA","TJCE","TJDFT","TJES","TJGO",
  "TJMA","TJMG","TJMS","TJMT","TJPA","TJPB","TJPE","TJPI","TJPR",
  "TJRJ","TJRN","TJRO","TJRR","TJRS","TJSC","TJSE","TJSP","TJTO"
)

vars_num <- c(
  "ipm","ipsjud","iad","tc","tcl","tbaix","cn","cp","dpj","procel","eff",
  "magp","serv","sajudp","cm","sajudmag","inf1","f5"
)

jn <- readr::read_delim(
  ARQ_JN,
  delim = ";",
  locale = locale(
    decimal_mark = ",",
    grouping_mark = ".",
    encoding = "Latin1"
  ),
  na = c("", "NA", "nd", "ND"),
  show_col_types = FALSE,
  progress = FALSE,
  trim_ws = TRUE
)

faltantes <- setdiff(c("ano","justica","sigla",vars_num), names(jn))
if (length(faltantes) > 0) {
  stop("Variáveis ausentes: ", paste(faltantes, collapse = ", "))
}

to_num_br <- function(x) {
  if (is.numeric(x)) return(as.numeric(x))
  readr::parse_number(
    as.character(x),
    locale = locale(decimal_mark = ",", grouping_mark = ".")
  )
}

painel <- jn %>%
  filter(justica == "Estadual", sigla %in% TJS) %>%
  transmute(
    tribunal = sigla,
    ano = as.integer(ano),
    across(all_of(vars_num), to_num_br)
  ) %>%
  arrange(tribunal, ano)

stopifnot(n_distinct(painel$tribunal) == 27)
stopifnot(min(painel$ano) == 2009)
stopifnot(max(painel$ano) == 2025)
stopifnot(nrow(painel) == 459)

ia <- readr::read_csv(
  ARQ_IA,
  show_col_types = FALSE,
  na = c("", "NA")
) %>%
  mutate(
    tribunal = trimws(tribunal),
    first_ai_any_year = as.integer(first_ai_any_year),
    first_ai_prod_year = as.integer(first_ai_prod_year)
  )

stopifnot(n_distinct(ia$tribunal) == 27)

painel <- painel %>%
  left_join(ia, by = "tribunal") %>%
  group_by(tribunal) %>%
  arrange(ano, .by_group = TRUE) %>%
  mutate(
    # ---------------------------------------------------------------
    # TRATAMENTO DE REFERÊNCIA / LEGADO
    # ---------------------------------------------------------------
    ai_any = case_when(
      timing_status_any == "never_through_2025" ~ 0,
      !is.na(first_ai_any_year) & ano >= first_ai_any_year ~ 1,
      !is.na(first_ai_any_year) & ano < first_ai_any_year ~ 0,
      TRUE ~ NA_real_
    ),

    ai_prod = case_when(
      !is.na(first_ai_prod_year) & ano >= first_ai_prod_year ~ 1,
      !is.na(first_ai_prod_year) & ano < first_ai_prod_year ~ 0,
      TRUE ~ NA_real_
    ),

    ai_any_lag1 = lag(ai_any, 1),
    ai_prod_lag1 = lag(ai_prod, 1),

    # ---------------------------------------------------------------
    # OUTCOMES
    # ---------------------------------------------------------------
    ln_ipm = if_else(ipm > 0, log(ipm), NA_real_),
    ln_ipsjud = if_else(ipsjud > 0, log(ipsjud), NA_real_),
    ln_tbaix = if_else(tbaix > 0, log(tbaix), NA_real_),
    baix_mag = if_else(tbaix > 0 & magp > 0, tbaix / magp, NA_real_),
    ln_baix_mag = if_else(baix_mag > 0, log(baix_mag), NA_real_),

    # ---------------------------------------------------------------
    # CONTROLES LEGADOS
    # Razões prontas - mantidas SOMENTE para comparação.
    # ---------------------------------------------------------------
    ln_cm = if_else(cm > 0, log(cm), NA_real_),
    ln_sajudmag = if_else(sajudmag > 0, log(sajudmag), NA_real_),

    # ---------------------------------------------------------------
    # CONTROLES CORRIGIDOS
    # Componentes separados reduzem correlação mecânica com IPM.
    # ---------------------------------------------------------------
    ln_cn = if_else(cn > 0, log(cn), NA_real_),
    ln_sajudp = if_else(sajudp > 0, log(sajudp), NA_real_),
    ln_dpj = if_else(dpj > 0, log(dpj), NA_real_),
    ln_magp = if_else(magp > 0, log(magp), NA_real_),

    # Defasagens
    ln_cm_lag1 = lag(ln_cm, 1),
    ln_sajudmag_lag1 = lag(ln_sajudmag, 1),

    ln_cn_lag1 = lag(ln_cn, 1),
    ln_sajudp_lag1 = lag(ln_sajudp, 1),
    ln_dpj_lag1 = lag(ln_dpj, 1),
    ln_magp_lag1 = lag(ln_magp, 1),

    procel_lag1 = lag(procel, 1),
    inf1_lag1 = lag(inf1, 1),
    f5_lag1 = lag(f5, 1)
  ) %>%
  ungroup()

# ------------------------------------------------------------------
# TIMING CENTRALIZADO A/B/C/D
#
# A = primeiro uso operacional no próprio ano
# B = primeira produção confirmada no próprio ano
# C = primeiro ano COMPLETO após primeiro uso (PRINCIPAL)
# D = primeiro ano COMPLETO após primeira produção confirmada
#
# Nunca tratados dentro da janela recebem 0.
# Datas desconhecidas continuam NA, nunca são transformadas em controle.
# ------------------------------------------------------------------

painel <- painel %>%
  mutate(
    g_A_any = case_when(
      timing_status_any == "never_through_2025" ~ 0L,
      !is.na(first_ai_any_year) & first_ai_any_year <= 2025L ~ first_ai_any_year,
      TRUE ~ NA_integer_
    ),

    g_B_prod = case_when(
      timing_status_any == "never_through_2025" ~ 0L,
      !is.na(first_ai_prod_year) & first_ai_prod_year <= 2025L ~ first_ai_prod_year,
      TRUE ~ NA_integer_
    ),

    g_C_any_full = case_when(
      timing_status_any == "never_through_2025" ~ 0L,
      !is.na(first_ai_any_year) & first_ai_any_year + 1L > 2025L ~ 0L,
      !is.na(first_ai_any_year) ~ first_ai_any_year + 1L,
      TRUE ~ NA_integer_
    ),

    g_D_prod_full = case_when(
      timing_status_any == "never_through_2025" ~ 0L,
      !is.na(first_ai_prod_year) & first_ai_prod_year + 1L > 2025L ~ 0L,
      !is.na(first_ai_prod_year) ~ first_ai_prod_year + 1L,
      TRUE ~ NA_integer_
    ),

    id_tj = as.integer(factor(tribunal, levels = TJS))
  )

# Hash de auditoria
hash_jn <- digest::digest(file = ARQ_JN, algo = "sha256")
hash_ia <- digest::digest(file = ARQ_IA, algo = "sha256")

writeLines(
  c(
    paste("SHA256 Justiça em Números:", hash_jn),
    paste("SHA256 cronologia IA:", hash_ia),
    paste("Seed:", SEED)
  ),
  file.path(DIR_AUDIT, "hashes_e_seed_v5.txt")
)

# Tamanho das cohorts nas quatro definições
cohort_counts <- bind_rows(
  painel %>% distinct(tribunal, g_A_any) %>% count(g_A_any, name="n") %>%
    mutate(definicao="A - uso operacional"),
  painel %>% distinct(tribunal, g_B_prod) %>% count(g_B_prod, name="n") %>%
    mutate(definicao="B - produção"),
  painel %>% distinct(tribunal, g_C_any_full) %>% count(g_C_any_full, name="n") %>%
    mutate(definicao="C - ano completo uso"),
  painel %>% distinct(tribunal, g_D_prod_full) %>% count(g_D_prod_full, name="n") %>%
    mutate(definicao="D - ano completo produção")
)

write_csv(cohort_counts, file.path(DIR_AUDIT, "coortes_timing_v5.csv"))
write_csv(painel, file.path(DIR_PROC, "painel_anpec_v5.csv"))

cat("\n============================================================\n")
cat("PREPARAÇÃO V5 CONCLUÍDA\n")
cat("Painel:", nrow(painel), "observações;", n_distinct(painel$tribunal), "TJs.\n")
cat("Arquivo: data/processed/painel_anpec_v5.csv\n")
cat("============================================================\n")
