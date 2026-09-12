# ==============================================================================
# 04_ROBUSTEZ_AVANCADA_V5.R
#
# Melhorias selecionadas:
# 1) BJS / didimputation
# 2) Wild cluster bootstrap
# 3) CR2 + Satterthwaite
# 4) Timing A/B/C/D
# 5) Leave-one-TJ-out
# 6) MDE / poder aproximado
# 7) Sun-Abraham opcional (não bloqueia a execução)
# ==============================================================================

rm(list = ls())
options(stringsAsFactors = FALSE, scipen = 999)

SEED <- 20260809L
set.seed(SEED)

LOCAL_LIB <- file.path(getwd(), "R_libs")
if (dir.exists(LOCAL_LIB)) .libPaths(c(LOCAL_LIB, .libPaths()))

req <- c(
  "tidyverse","fixest","did","didimputation","clubSandwich",
  "fwildclusterboot","stargazer","broom"
)

missing <- req[!sapply(req, requireNamespace, quietly=TRUE)]
if (length(missing)>0) {
  stop(
    "Pacotes ausentes: ", paste(missing,collapse=", "),
    ". Rode 00_INSTALAR_PACOTES_V5.R."
  )
}

suppressPackageStartupMessages({
  library(tidyverse)
  library(fixest)
  library(did)
  library(didimputation)
  library(clubSandwich)
  library(fwildclusterboot)
  library(stargazer)
  library(broom)
})

ARQ <- "data/processed/painel_anpec_v5.csv"
DIR_TAB <- "outputs/tables"
DIR_FIG <- "outputs/figures"
DIR_AUDIT <- "outputs/audit"
DIR_LOG <- "outputs/logs"

for (d in c(DIR_TAB,DIR_FIG,DIR_AUDIT,DIR_LOG)) {
  dir.create(d,recursive=TRUE,showWarnings=FALSE)
}

if (!file.exists(ARQ)) stop("Falta painel_anpec_v5.csv.")
if (!file.exists("data/processed/modelo_twfe_preferido_v5.rds")) {
  stop("Falta o modelo baseline. Rode 03_BASELINE_V5.R.")
}

painel <- read_csv(ARQ,show_col_types=FALSE)
m_pref <- readRDS("data/processed/modelo_twfe_preferido_v5.rds")

amostra <- painel %>%
  filter(
    ano>=2014,ano<=2025,
    !is.na(ai_any_lag1),
    !is.na(ln_ipm),
    !is.na(ln_cn_lag1),
    !is.na(ln_sajudp_lag1),
    !is.na(ln_dpj_lag1)
  )

# ==========================================================================
# 1. BJS - BORUSYAK, JARAVEL & SPIESS
#
# Sem covariáveis time-varying no first stage principal.
# Isso evita condicionar o contrafactual a variáveis potencialmente afetadas
# pela adoção de IA.
# ==========================================================================

cat("\n[V5] Estimando BJS / didimputation...\n")

bjs_data <- painel %>%
  filter(
    ano>=2014,ano<=2025,
    !is.na(ln_ipm),
    !is.na(g_C_any_full)
  )

bjs_static <- tryCatch(
  didimputation::did_imputation(
    data=bjs_data,
    yname="ln_ipm",
    gname="g_C_any_full",
    tname="ano",
    idname="tribunal",
    first_stage=~ 0 | tribunal + ano,
    cluster_var="tribunal"
  ),
  error=function(e) {
    message("BJS falhou: ",conditionMessage(e))
    NULL
  }
)

if (!is.null(bjs_static)) {
  write_csv(
    as.data.frame(bjs_static),
    file.path(DIR_AUDIT,"bjs_static_v5.csv")
  )

  stargazer(
    as.data.frame(bjs_static),
    type="latex",
    summary=FALSE,
    rownames=FALSE,
    header=FALSE,
    digits=4,
    title="Borusyak-Jaravel-Spiess: estimador de imputação",
    out=file.path(DIR_TAB,"tab3b_v5_bjs.tex")
  )
} else {
  writeLines(
    "BJS não foi estimado; consultar Console para a mensagem de erro.",
    file.path(DIR_LOG,"BJS_STATUS.txt")
  )
}

# ==========================================================================
# 2. INFERÊNCIA COM POUCOS CLUSTERS
# ==========================================================================

cat("\n[V5] Wild cluster bootstrap...\n")

boot_obj <- tryCatch(
  fwildclusterboot::boottest(
    m_pref,
    param="ai_any_lag1",
    B=9999,
    clustid="tribunal",
    engine="R-lean",
    type="rademacher",
    conf_int=TRUE
  ),
  error=function(e) {
    message("Wild cluster bootstrap falhou: ",conditionMessage(e))
    NULL
  }
)

wild_tab <- tibble(
  metodo="Wild cluster bootstrap",
  estimativa=NA_real_,
  p_valor=NA_real_,
  ci_inf=NA_real_,
  ci_sup=NA_real_,
  status="não estimado"
)

if (!is.null(boot_obj)) {
  ci <- tryCatch(as.numeric(boot_obj$conf_int), error=function(e) c(NA_real_,NA_real_))

  wild_tab <- tibble(
    metodo="Wild cluster bootstrap",
    estimativa=as.numeric(boot_obj$point_estimate),
    p_valor=as.numeric(boot_obj$p_val),
    ci_inf=ifelse(length(ci)>=1,ci[1],NA_real_),
    ci_sup=ifelse(length(ci)>=2,ci[2],NA_real_),
    status="OK"
  )
}

write_csv(wild_tab,file.path(DIR_AUDIT,"wild_cluster_v5.csv"))

# --------------------------------------------------------------------------
# CR2:
# Replica a especificação preferida em lm com dummies de TJ e ano.
# Isso permite aplicar clubSandwich::coef_test(vcov="CR2").
# --------------------------------------------------------------------------

cat("[V5] CR2 / Satterthwaite...\n")

lm_pref <- lm(
  ln_ipm ~ ai_any_lag1 + ln_cn_lag1 + ln_sajudp_lag1 + ln_dpj_lag1 +
    factor(tribunal) + factor(ano),
  data=amostra
)

cr2_raw <- clubSandwich::coef_test(
  lm_pref,
  vcov="CR2",
  cluster=amostra$tribunal,
  test="Satterthwaite",
  coefs="ai_any_lag1"
)

cr2_df <- as.data.frame(cr2_raw)
write_csv(cr2_df,file.path(DIR_AUDIT,"cr2_satterthwaite_v5.csv"))

# CR1 convencional do fixest preferido
td_pref <- broom::tidy(m_pref) %>% filter(term=="ai_any_lag1")

# Tabela consolidada de inferência
find_numeric <- function(df, patterns) {
  nm <- names(df)
  idx <- which(Reduce(`|`,lapply(patterns,function(p) grepl(p,nm,ignore.case=TRUE))))
  if (length(idx)==0) return(NA_real_)
  suppressWarnings(as.numeric(df[[idx[1]]][1]))
}

cr2_est <- find_numeric(cr2_df,c("^beta$","estimate","coef"))
cr2_se  <- find_numeric(cr2_df,c("^se$","std"))
cr2_p   <- find_numeric(cr2_df,c("p.*satt","p_val","p-val","pvalue"))

infer_tab <- tibble(
  Metodo=c("CR1 cluster TJ","CR2 Satterthwaite","Wild cluster bootstrap"),
  Estimativa=c(td_pref$estimate[1],cr2_est,wild_tab$estimativa[1]),
  EP=c(td_pref$std.error[1],cr2_se,NA_real_),
  p_valor=c(td_pref$p.value[1],cr2_p,wild_tab$p_valor[1]),
  IC_inf=c(
    td_pref$estimate[1]-1.96*td_pref$std.error[1],
    ifelse(is.na(cr2_est)|is.na(cr2_se),NA,cr2_est-1.96*cr2_se),
    wild_tab$ci_inf[1]
  ),
  IC_sup=c(
    td_pref$estimate[1]+1.96*td_pref$std.error[1],
    ifelse(is.na(cr2_est)|is.na(cr2_se),NA,cr2_est+1.96*cr2_se),
    wild_tab$ci_sup[1]
  )
)

write_csv(infer_tab,file.path(DIR_AUDIT,"inferencia_poucos_clusters_v5.csv"))

stargazer(
  infer_tab,
  type="latex",
  summary=FALSE,
  rownames=FALSE,
  header=FALSE,
  digits=4,
  title="Inferência com poucos clusters",
  out=file.path(DIR_TAB,"tab6_v5_inferencia_poucos_clusters.tex")
)

# ==========================================================================
# 3. TIMING A/B/C/D
# ==========================================================================

cat("\n[V5] Sensibilidade ao timing A/B/C/D...\n")

run_cs_timing <- function(gvar,label) {
  dat <- painel %>%
    filter(
      ano>=2014,ano<=2025,
      !is.na(ln_ipm),
      !is.na(.data[[gvar]])
    ) %>%
    mutate(g_temp=as.integer(.data[[gvar]]))

  out <- tryCatch({
    obj <- did::att_gt(
      yname="ln_ipm",
      tname="ano",
      idname="id_tj",
      gname="g_temp",
      xformla=~1,
      data=dat,
      panel=TRUE,
      control_group="notyettreated",
      anticipation=0,
      est_method="dr",
      bstrap=TRUE,
      biters=499,
      clustervars="id_tj",
      cband=FALSE,
      print_details=FALSE
    )

    a <- did::aggte(obj,type="simple",na.rm=TRUE)

    tibble(
      Definicao=label,
      ATT=a$overall.att,
      SE=a$overall.se,
      IC95_inf=a$overall.att-1.96*a$overall.se,
      IC95_sup=a$overall.att+1.96*a$overall.se,
      Efeito_pct=100*(exp(a$overall.att)-1),
      N_TJs=n_distinct(dat$tribunal),
      Status="OK"
    )
  },error=function(e) {
    tibble(
      Definicao=label,
      ATT=NA_real_,SE=NA_real_,IC95_inf=NA_real_,IC95_sup=NA_real_,
      Efeito_pct=NA_real_,N_TJs=n_distinct(dat$tribunal),
      Status=paste0("Não estimável: ",conditionMessage(e))
    )
  })

  out
}

timing_tab <- bind_rows(
  run_cs_timing("g_A_any","A - primeiro uso operacional"),
  run_cs_timing("g_B_prod","B - primeira produção confirmada"),
  run_cs_timing("g_C_any_full","C - primeiro ano completo após uso (principal)"),
  run_cs_timing("g_D_prod_full","D - primeiro ano completo após produção")
)

write_csv(timing_tab,file.path(DIR_AUDIT,"timing_abcd_v5.csv"))

stargazer(
  timing_tab,
  type="latex",
  summary=FALSE,
  rownames=FALSE,
  header=FALSE,
  digits=4,
  title="Sensibilidade à definição temporal da adoção de IA",
  out=file.path(DIR_TAB,"tab5_v5_timing_abcd.tex")
)

# ==========================================================================
# 4. LEAVE-ONE-TJ-OUT - C&S PRINCIPAL
# ==========================================================================

cat("\n[V5] Leave-one-TJ-out (27 reestimações)...\n")

TJS <- sort(unique(painel$tribunal))

loo <- map_dfr(TJS,function(tj_out) {
  dat <- painel %>%
    filter(
      tribunal != tj_out,
      ano>=2014,ano<=2025,
      !is.na(ln_ipm),
      !is.na(g_C_any_full)
    ) %>%
    mutate(
      id_loo=as.integer(factor(tribunal)),
      g_loo=as.integer(g_C_any_full)
    )

  tryCatch({
    obj <- did::att_gt(
      yname="ln_ipm",
      tname="ano",
      idname="id_loo",
      gname="g_loo",
      xformla=~1,
      data=dat,
      panel=TRUE,
      control_group="notyettreated",
      anticipation=0,
      est_method="dr",
      bstrap=FALSE,
      cband=FALSE,
      print_details=FALSE
    )

    a <- did::aggte(obj,type="simple",na.rm=TRUE)

    tibble(
      tribunal_removido=tj_out,
      ATT=a$overall.att,
      SE=a$overall.se,
      Efeito_pct=100*(exp(a$overall.att)-1),
      status="OK"
    )
  },error=function(e) {
    tibble(
      tribunal_removido=tj_out,
      ATT=NA_real_,
      SE=NA_real_,
      Efeito_pct=NA_real_,
      status=paste0("Falhou: ",conditionMessage(e))
    )
  })
})

write_csv(loo,file.path(DIR_AUDIT,"leave_one_tj_out_v5.csv"))

# Baseline C&S para referência
cs_base <- read_csv(
  file.path(DIR_AUDIT,"callaway_santanna_principal_v5.csv"),
  show_col_types=FALSE
)
att_base <- cs_base$ATT[1]

p_loo <- loo %>%
  filter(status=="OK") %>%
  ggplot(aes(x=reorder(tribunal_removido,ATT),y=ATT)) +
  geom_hline(yintercept=att_base,linetype="dashed",linewidth=.4) +
  geom_hline(yintercept=0,linewidth=.4) +
  geom_point(size=2) +
  coord_flip() +
  labs(
    x="Tribunal removido",
    y="ATT agregado",
    title="Sensibilidade leave-one-TJ-out"
  ) +
  theme_minimal(base_size=10)

ggsave(
  file.path(DIR_FIG,"fig4_v5_leave_one_tj_out.pdf"),
  p_loo,width=7,height=6
)

loo_summary <- loo %>%
  filter(status=="OK") %>%
  summarise(
    N_estimacoes=n(),
    Media=mean(ATT),
    Mediana=median(ATT),
    Min=min(ATT),
    Max=max(ATT),
    DP=sd(ATT)
  )

stargazer(
  loo_summary,
  type="latex",
  summary=FALSE,
  rownames=FALSE,
  header=FALSE,
  digits=4,
  title="Resumo do leave-one-TJ-out",
  out=file.path(DIR_TAB,"tab8_v5_leave_one_out.tex")
)

# ==========================================================================
# 5. MDE E INTERVALOS INTERPRETÁVEIS
# ==========================================================================

cat("\n[V5] MDE / poder aproximado...\n")

cs_tab <- read_csv(
  file.path(DIR_AUDIT,"callaway_santanna_principal_v5.csv"),
  show_col_types=FALSE
)

mde_tab <- tibble(
  Estimador=c("TWFE preferido","Callaway-Sant'Anna"),
  Beta=c(td_pref$estimate[1],cs_tab$ATT[1]),
  SE=c(td_pref$std.error[1],cs_tab$SE[1])
) %>%
  mutate(
    MDE_log_80pct=2.8*SE,
    MDE_pct_80pct=100*(exp(MDE_log_80pct)-1),
    IC95_inf_log=Beta-1.96*SE,
    IC95_sup_log=Beta+1.96*SE,
    IC95_inf_pct=100*(exp(IC95_inf_log)-1),
    IC95_sup_pct=100*(exp(IC95_sup_log)-1)
  )

write_csv(mde_tab,file.path(DIR_AUDIT,"mde_poder_v5.csv"))

stargazer(
  mde_tab,
  type="latex",
  summary=FALSE,
  rownames=FALSE,
  header=FALSE,
  digits=3,
  title="Poder estatístico e efeitos mínimos detectáveis",
  out=file.path(DIR_TAB,"tabA_v5_mde_poder.tex")
)

# ==========================================================================
# 6. SUN & ABRAHAM - OPCIONAL
# Nunca interrompe a V5.
# ==========================================================================

sunab_status <- "não executado"

if ("sunab" %in% getNamespaceExports("fixest")) {
  tryCatch({
    sa_dat <- painel %>%
      filter(
        ano>=2014,ano<=2025,
        !is.na(ln_ipm),
        !is.na(g_C_any_full)
      ) %>%
      mutate(
        cohort_sa=ifelse(g_C_any_full==0,10000L,g_C_any_full)
      )

    m_sa <- feols(
      ln_ipm ~ sunab(cohort_sa,ano,ref.p=-1) | tribunal + ano,
      data=sa_dat,
      cluster=~tribunal
    )

    sa <- broom::tidy(m_sa,conf.int=TRUE)
    write_csv(sa,file.path(DIR_AUDIT,"sun_abraham_v5.csv"))

    capture.output(
      fixest::etable(m_sa,tex=TRUE,digits=3),
      file=file.path(DIR_TAB,"tabA_v5_sun_abraham.tex")
    )

    pdf(file.path(DIR_FIG,"fig3_v5_sun_abraham.pdf"),width=7,height=4.5)
    fixest::iplot(
      m_sa,
      ref.line=0,
      xlim=c(-4,4),
      xlab="Tempo relativo ao primeiro ano completo de exposição",
      main="Event study - Sun e Abraham"
    )
    dev.off()

    sunab_status <- "OK"
  },error=function(e) {
    sunab_status <<- paste0("Falhou: ",conditionMessage(e))
  })
} else {
  sunab_status <- paste0(
    "sunab não exportado por fixest ",
    as.character(packageVersion("fixest"))
  )
}

writeLines(sunab_status,file.path(DIR_LOG,"SUNAB_STATUS_V5.txt"))

# ==========================================================================
# 7. STATUS FINAL
# ==========================================================================

status <- tibble(
  Bloco=c(
    "BJS",
    "Wild cluster bootstrap",
    "CR2",
    "Timing A/B/C/D",
    "Leave-one-TJ-out",
    "MDE/poder",
    "Sun-Abraham"
  ),
  Status=c(
    ifelse(is.null(bjs_static),"FALHOU/VER LOG","OK"),
    wild_tab$status[1],
    "OK",
    "OK",
    ifelse(any(loo$status=="OK"),"OK","FALHOU"),
    "OK",
    sunab_status
  )
)

write_csv(status,file.path(DIR_AUDIT,"STATUS_ROBUSTEZ_V5.csv"))

capture.output(
  sessionInfo(),
  file=file.path(DIR_LOG,"sessionInfo_v5.txt")
)

cat("\n============================================================\n")
cat("ROBUSTEZ AVANÇADA V5 CONCLUÍDA\n")
cat("============================================================\n")
print(status)
cat("\nConfira outputs/audit/STATUS_ROBUSTEZ_V5.csv\n")
cat("============================================================\n")
