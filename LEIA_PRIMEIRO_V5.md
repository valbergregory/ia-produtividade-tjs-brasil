# ANPEC Área 5 — PIPELINE V5 DE ROBUSTEZ

## Objetivo

A V5 NÃO substitui a análise que já fizemos. Ela preserva o baseline e acrescenta
seis melhorias econométricas selecionadas após a auditoria externa:

1. controles corrigidos;
2. BJS / didimputation;
3. inferência com poucos clusters (CR2 + wild bootstrap);
4. timing A/B/C/D;
5. leave-one-TJ-out;
6. MDE / poder estatístico.

Sun-Abraham permanece como robustez opcional.

## O ZIP JÁ CONTÉM

- JN_23-Jun-2026.csv
- ia_adocao_validada.csv
- todos os scripts
- estrutura de outputs
- biblioteca local R_libs (inicialmente vazia)

Não copie arquivos de V3/V4 para esta pasta.

---

## PASSO A PASSO MAIS SEGURO

### 1. Feche o RStudio antigo
Não salve `.RData`.

### 2. Extraia o ZIP em uma pasta NOVA

Exemplo:

D:/R - Projetos/Anpec - 2026 - Artigo/anpec_area5_pipeline_v5_robustez/

### 3. Abra

ANPEC_IA_Judiciario_V5.Rproj

### 4. Rode

00_INSTALAR_PACOTES_V5.R

Ao final:
`INSTALAÇÃO V5 CONCLUÍDA`

### 5. Session > Restart R

### 6. Rode

01_VERIFICAR_V5.R

Ao final:
`V5 PRONTA PARA EXECUÇÃO`

### 7. Rode

02_PREPARAR_DADOS_V5.R

Ao final:
`PREPARAÇÃO V5 CONCLUÍDA`

### 8. Rode

03_BASELINE_V5.R

Ao final:
`BASELINE V5 CONCLUÍDO`

### 9. Rode

04_ROBUSTEZ_AVANCADA_V5.R

Ao final:
`ROBUSTEZ AVANÇADA V5 CONCLUÍDA`

Depois que tudo estiver validado, `05_RUN_ALL_V5.R` pode reproduzir a sequência.

---

## O QUE MUDOU NOS CONTROLES

### Legado
Mantém:
- ln(cm)
- ln(sajudmag)
- ln(dpj)

### Preferido V5
Usa:
- ln(cn)
- ln(sajudp)
- ln(dpj)

As razões cm e sajudmag não são usadas no modelo preferido porque compartilham
denominadores com medidas de produtividade e podem gerar correlação mecânica.

### Robustez
- adiciona ln(magp), separadamente;
- adiciona procel e inf1 SOMENTE numa coluna identificada como potencialmente
  pós-tratamento.

---

## TRATAMENTO

A — primeiro uso operacional;
B — primeira produção institucional confirmada;
C — primeiro ano completo após o primeiro uso (PRINCIPAL);
D — primeiro ano completo após a primeira produção.

Datas de produção desconhecidas continuam NA. O script nunca as converte
artificialmente em "não tratado".

---

## MODELOS

### Modelo 1
TWFE legado + TWFE preferido.

### Modelo 2
Callaway & Sant'Anna:
- not-yet-treated;
- xformla = ~1;
- primeiro ano completo como timing principal.

### Modelo 3
Borusyak-Jaravel-Spiess / didimputation.

### Small-cluster inference
- CR1;
- CR2/Satterthwaite;
- wild cluster bootstrap.

### Sensibilidades
- timing A/B/C/D;
- leave-one-TJ-out;
- MDE/poder.

### Sun-Abraham
Opcional. Se falhar, gera log e NÃO invalida a V5.

---

## PRINCIPAIS SAÍDAS

### outputs/tables
- tab2_v5_comparacao_controles.tex
- tab3a_v5_callaway_santanna.tex
- tab3b_v5_bjs.tex
- tab4_v5_outcomes_alternativos.tex
- tab5_v5_timing_abcd.tex
- tab6_v5_inferencia_poucos_clusters.tex
- tab8_v5_leave_one_out.tex
- tabA_v5_mde_poder.tex

### outputs/figures
- fig2_v5_event_study_cs.pdf
- fig4_v5_leave_one_tj_out.pdf
- fig3_v5_sun_abraham.pdf (se disponível)

### outputs/audit
- coeficientes_twfe_v5.csv
- callaway_santanna_principal_v5.csv
- bjs_static_v5.csv
- cr2_satterthwaite_v5.csv
- wild_cluster_v5.csv
- inferencia_poucos_clusters_v5.csv
- timing_abcd_v5.csv
- leave_one_tj_out_v5.csv
- mde_poder_v5.csv
- STATUS_ROBUSTEZ_V5.csv

---

## IMPORTANTE

Não procure significância.

A finalidade da V5 é verificar:
- se o resultado depende de controles mecanicamente relacionados ao IPM;
- se outro estimador moderno confirma o C&S;
- se a inferência convencional está otimista com apenas 27 clusters;
- se o resultado depende da data escolhida para adoção;
- se algum TJ domina o ATT;
- qual tamanho de efeito o desenho consegue efetivamente detectar.
