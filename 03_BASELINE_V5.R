# ==============================================================================
# 03_BASELINE_V5.R
#
# Preserva o baseline legado e acrescenta especificações corrigidas.
# Não faz BJS/wild/CR2/leave-one-out: isso fica em 04_ROBUSTEZ_AVANCADA_V5.R.
# ==============================================================================

rm(list = ls())
options(stringsAsFactors = FALSE, scipen = 999)

SEED <- 20260809L
set.seed(SEED)

LOCAL_LIB <- file.path(getwd(), "R_libs")
if (dir.exists(LOCAL_LIB)) .libPaths(c(LOCAL_LIB, .libPaths()))

suppressPackageStartupMessages({
  library(tidyverse)
  library(fixest)
  library(did)
  library(stargazer)
  library(broom)
})

ARQ <- "data/processed/painel_anpec_v5.csv"
DIR_TAB <- "outputs/tables"
DIR_FIG <- "outputs/figures"
DIR_AUDIT <- "outputs/audit"

if (!file.exists(ARQ)) {
  stop("Falta painel_anpec_v5.csv. Rode primeiro 02_PREPARAR_DADOS_V5.R.")
}

painel <- read_csv(ARQ, show_col_types = FALSE)
dir.create(DIR_TAB, recursive = TRUE, showWarnings = FALSE)
dir.create(DIR_FIG, recursive = TRUE, showWarnings = FALSE)
dir.create(DIR_AUDIT, recursive = TRUE, showWarnings = FALSE)

stars_p <- function(p) {
  case_when(
    is.na(p) ~ "",
    p < .01 ~ "***",
    p < .05 ~ "**",
    p < .10 ~ "*",
    TRUE ~ ""
  )
}

simple_model_table <- function(models, labels, outfile, title) {
  rows <- map2_dfr(models, labels, function(m, lab) {
    td <- broom::tidy(m)
    td %>% mutate(modelo = lab, .before = 1)
  })

  write_csv(
    rows,
    file.path(DIR_AUDIT, paste0(tools::file_path_sans_ext(basename(outfile)), ".csv"))
  )

  key <- rows %>%
    filter(term == "ai_any_lag1") %>%
    transmute(
      Modelo = modelo,
      Beta_IA = estimate,
      EP = std.error,
      p = p.value,
      Efeito_pct = 100 * (exp(estimate) - 1)
    )

  stargazer(
    key,
    type="latex",
    summary=FALSE,
    rownames=FALSE,
    header=FALSE,
    digits=4,
    title=title,
    out=outfile
  )

  invisible(rows)
}

amostra <- painel %>%
  filter(
    ano >= 2014, ano <= 2025,
    !is.na(ai_any_lag1),
    !is.na(ln_ipm)
  )

# ------------------------------------------------------------------
# MODELO 1A - LEGADO
# Preservado exatamente em espírito: ratios prontos cm/sajudmag.
# ------------------------------------------------------------------

m_legacy <- feols(
  ln_ipm ~ ai_any_lag1 + ln_cm_lag1 + ln_sajudmag_lag1 + ln_dpj_lag1 |
    tribunal + ano,
  data=amostra,
  cluster=~tribunal
)

# ------------------------------------------------------------------
# MODELO 1B - PREFERIDO
# Componentes separados; SEM procel/inf1/f5.
# ------------------------------------------------------------------

m_pref <- feols(
  ln_ipm ~ ai_any_lag1 + ln_cn_lag1 + ln_sajudp_lag1 + ln_dpj_lag1 |
    tribunal + ano,
  data=amostra,
  cluster=~tribunal
)

# ------------------------------------------------------------------
# MODELO 1C - PREFERIDO + PORTE JUDICIAL
# Inclui magp apenas como robustez de capacidade/porte.
# ------------------------------------------------------------------

m_pref_mag <- feols(
  ln_ipm ~ ai_any_lag1 + ln_cn_lag1 + ln_sajudp_lag1 +
    ln_dpj_lag1 + ln_magp_lag1 |
    tribunal + ano,
  data=amostra,
  cluster=~tribunal
)

# ------------------------------------------------------------------
# MODELO 1D - TECNOLOGIA POTENCIALMENTE PÓS-TRATAMENTO
# NÃO é especificação principal.
# ------------------------------------------------------------------

m_tech <- feols(
  ln_ipm ~ ai_any_lag1 + ln_cn_lag1 + ln_sajudp_lag1 +
    ln_dpj_lag1 + procel_lag1 + inf1_lag1 |
    tribunal + ano,
  data=amostra,
  cluster=~tribunal
)

baseline_long <- simple_model_table(
  list(m_legacy, m_pref, m_pref_mag, m_tech),
  c(
    "Legado: razões",
    "Preferido: componentes",
    "Preferido + magistrados",
    "Robustez: controles tecnológicos"
  ),
  file.path(DIR_TAB, "tab2_v5_comparacao_controles.tex"),
  "Efeito da IA sobre produtividade: comparação de controles"
)

# Tabela completa dos coeficientes
coef_all <- bind_rows(
  broom::tidy(m_legacy) %>% mutate(modelo="Legado"),
  broom::tidy(m_pref) %>% mutate(modelo="Preferido"),
  broom::tidy(m_pref_mag) %>% mutate(modelo="Preferido + MagP"),
  broom::tidy(m_tech) %>% mutate(modelo="Tecnologia pós-tratamento")
)

write_csv(coef_all, file.path(DIR_AUDIT, "coeficientes_twfe_v5.csv"))

# ------------------------------------------------------------------
# OUTCOME ALTERNATIVO MAIS LIMPO: PRODUÇÃO ABSOLUTA
# ln(tbaix) com inputs produtivos explícitos.
# ------------------------------------------------------------------

m_tbaix <- feols(
  ln_tbaix ~ ai_any_lag1 + ln_magp_lag1 + ln_cn_lag1 +
    ln_sajudp_lag1 + ln_dpj_lag1 |
    tribunal + ano,
  data=amostra,
  cluster=~tribunal
)

# Outcomes já usados + tbaix / baixados por magistrado
outcome_specs <- list(
  "Log(IPM)" = "ln_ipm",
  "Log(IPSJud)" = "ln_ipsjud",
  "IAD" = "iad",
  "Congestionamento" = "tc",
  "Congestionamento líquido" = "tcl",
  "IPC-Jus" = "eff",
  "Log(Processos baixados)" = "ln_tbaix",
  "Log(Baixados/magistrado)" = "ln_baix_mag"
)

mods_out <- imap(outcome_specs, function(y, label) {
  if (y == "ln_tbaix") return(m_tbaix)

  if (y == "ln_baix_mag") {
    return(
      feols(
        ln_baix_mag ~ ai_any_lag1 + ln_cn_lag1 + ln_sajudp_lag1 +
          ln_dpj_lag1 |
          tribunal + ano,
        data=amostra,
        cluster=~tribunal
      )
    )
  }

  f <- as.formula(
    paste0(
      y,
      " ~ ai_any_lag1 + ln_cn_lag1 + ln_sajudp_lag1 + ln_dpj_lag1 | tribunal + ano"
    )
  )
  feols(f, data=amostra, cluster=~tribunal)
})

out_key <- imap_dfr(mods_out, function(m, label) {
  td <- broom::tidy(m)
  x <- td %>% filter(term=="ai_any_lag1")
  tibble(
    Outcome=label,
    Beta_IA=x$estimate,
    EP=x$std.error,
    p=x$p.value,
    Efeito_pct=ifelse(
      label %in% c("Log(IPM)","Log(IPSJud)","Log(Processos baixados)",
                   "Log(Baixados/magistrado)"),
      100*(exp(x$estimate)-1),
      NA_real_
    )
  )
})

write_csv(out_key, file.path(DIR_AUDIT, "outcomes_alternativos_v5.csv"))

stargazer(
  out_key,
  type="latex",
  summary=FALSE,
  rownames=FALSE,
  header=FALSE,
  digits=4,
  title="IA e indicadores alternativos de desempenho judicial",
  out=file.path(DIR_TAB,"tab4_v5_outcomes_alternativos.tex")
)

# ------------------------------------------------------------------
# CALLAWAY & SANT'ANNA PRINCIPAL
# xformla = ~1 para não introduzir controles potencialmente pós-tratamento.
# ------------------------------------------------------------------

did_data <- painel %>%
  filter(
    ano >= 2014, ano <= 2025,
    !is.na(ln_ipm),
    !is.na(g_C_any_full)
  )

cs_main <- did::att_gt(
  yname="ln_ipm",
  tname="ano",
  idname="id_tj",
  gname="g_C_any_full",
  xformla=~1,
  data=did_data,
  panel=TRUE,
  control_group="notyettreated",
  anticipation=0,
  est_method="dr",
  bstrap=TRUE,
  biters=999,
  clustervars="id_tj",
  cband=TRUE,
  print_details=FALSE
)

cs_simple <- did::aggte(cs_main, type="simple", na.rm=TRUE)
cs_dyn <- did::aggte(
  cs_main, type="dynamic",
  min_e=-4, max_e=4, na.rm=TRUE
)

tab_cs <- tibble(
  ATT=cs_simple$overall.att,
  SE=cs_simple$overall.se,
  IC95_inf=cs_simple$overall.att-1.96*cs_simple$overall.se,
  IC95_sup=cs_simple$overall.att+1.96*cs_simple$overall.se,
  Efeito_pct=100*(exp(cs_simple$overall.att)-1)
)

write_csv(tab_cs, file.path(DIR_AUDIT,"callaway_santanna_principal_v5.csv"))

stargazer(
  tab_cs,
  type="latex",
  summary=FALSE,
  rownames=FALSE,
  header=FALSE,
  digits=4,
  title="Callaway-Sant'Anna: efeito médio da adoção de IA",
  out=file.path(DIR_TAB,"tab3a_v5_callaway_santanna.tex")
)

dyn <- tibble(
  tempo=cs_dyn$egt,
  ATT=cs_dyn$att.egt,
  SE=cs_dyn$se.egt
) %>%
  mutate(
    IC95_inf=ATT-1.96*SE,
    IC95_sup=ATT+1.96*SE
  )

write_csv(dyn, file.path(DIR_AUDIT,"event_study_cs_v5.csv"))

p_cs <- ggplot(dyn,aes(tempo,ATT)) +
  geom_hline(yintercept=0,linewidth=.4) +
  geom_vline(xintercept=-.5,linetype="dashed",linewidth=.4) +
  geom_errorbar(aes(ymin=IC95_inf,ymax=IC95_sup),width=.12) +
  geom_point(size=2) +
  geom_line(linewidth=.5) +
  scale_x_continuous(breaks=-4:4) +
  labs(
    x="Anos em relação ao primeiro ano completo de exposição",
    y="ATT sobre log(IPM)",
    title="Efeitos dinâmicos da adoção de IA"
  ) +
  theme_minimal(base_size=11)

ggsave(
  file.path(DIR_FIG,"fig2_v5_event_study_cs.pdf"),
  p_cs,width=7,height=4.5
)

# Salva objetos necessários para a etapa avançada
saveRDS(m_pref, file.path("data/processed","modelo_twfe_preferido_v5.rds"))
saveRDS(m_legacy, file.path("data/processed","modelo_twfe_legado_v5.rds"))
saveRDS(cs_main, file.path("data/processed","modelo_cs_principal_v5.rds"))

cat("\n============================================================\n")
cat("BASELINE V5 CONCLUÍDO\n")
cat("Modelos preservados + controles corrigidos + C&S prontos.\n")
cat("Agora rode 04_ROBUSTEZ_AVANCADA_V5.R\n")
cat("============================================================\n")
