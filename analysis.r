# Setup

library("ggplot2")
library("tidyverse")
library("plyr")
library("dplyr")
library("magrittr")
library("cowplot")
library("geojsonio")
library("broom")

postes <- read.csv("./dataset/postes_2020.csv", sep = ";")
mapping <- read.csv("./dataset/varmod_postes_2020.csv", sep = ";")

# =========== Map with Percentage of people earing more/less than X euros yearly per region =========

# Read geojson
spdf <- geojson_read("departements.geojson", what = "sp")
spdf_fortified <- tidy(spdf, region = "code")

trancheRevenuParRegion <- postes %>%
    select(TRBRUTT, DEPR) %>%
    filter(DEPR != "") %>%
    dplyr::count(DEPR, TRBRUTT)
nbPeoplePerRegion <- trancheRevenuParRegion %>%
    group_by(DEPR) %>%
    dplyr::summarise(n = sum(n))

tmp <- trancheRevenuParRegion %>% filter(TRBRUTT <= 12)
tmp <- tmp %>%
    group_by(DEPR) %>%
    dplyr::summarise(regroup = sum(n))
tmp <- tmp %>% left_join(., nbPeoplePerRegion, by = c("DEPR" = "DEPR"))
percentageRevenuParRegion$lowPercentage <- tmp$regroup / tmp$n

tmp <- trancheRevenuParRegion %>% filter(TRBRUTT > 21)
tmp <- tmp %>%
    group_by(DEPR) %>%
    dplyr::summarise(regroup = sum(n))
tmp <- tmp %>% left_join(., nbPeoplePerRegion, by = c("DEPR" = "DEPR"))
percentageRevenuParRegion$highPercentage <- tmp$regroup / tmp$n

percentageRevenuParRegion$DEPR <- as.character(percentageRevenuParRegion$DEPR)


spdf_fortified <- spdf_fortified %>% left_join(., percentageRevenuParRegion, by = c("id" = "DEPR"))


graph1 <- ggplot() +
    geom_polygon(data = spdf_fortified, aes(fill = lowPercentage, x = long, y = lat, group = group)) +
    scale_fill_gradient(low = "#eeebc5", high = "#bb0600") +
    theme_void() +
    coord_map()

graph2 <- ggplot() +
    geom_polygon(data = spdf_fortified, aes(fill = highPercentage, x = long, y = lat, group = group)) +
    scale_fill_gradient(low = "#eeebc5", high = "#bb0600") +
    theme_void() +
    coord_map()

# Generate and save map

jpeg("./images/heat_map_salaries.jpg", width = 1920, height = 1080)
plot_grid(graph1, graph2)
dev.off()


# =========== Age and work category relationship ==========

# get valid data dropping NA and invalid ages
ageCS <- postes %>%
    select(AGE_TR, CS) %>%
    drop_na() %>%
    filter(AGE_TR > 0)

# normalise data by percentage
ageCS <- ageCS %>% dplyr::count(AGE_TR, CS, name="n")
ageCS <- ageCS %>% group_by(CS) %>% dplyr::mutate(cs_total = sum(n))
ageCS$percentage <- 100 * ageCS$n / ageCS$cs_total

# take out insignificative data (manually selected)
ageCS <- filter(ageCS, CS %in% c(31, 55, 67, 69, 33, 45, 62))

age_mapping <- mapping[mapping$COD_VAR == "CS", ]
ageCS$label <- mapvalues(ageCS$CS, age_mapping$COD_MOD, age_mapping$LIB_MOD)

jpeg("./images/age_cs_lines.jpg",  width = 960, height = 540)
ggplot(ageCS, aes(x = AGE_TR, y = percentage, color = label)) +
    labs(
        title = "Pourcentage d'employes par age",
        x = "Age",
        y = "Pourcentage",
        color = "categorie professionelle"
    ) +
    theme(legend.position="bottom") +
    geom_line()
dev.off()

# ============== salaire par tranche de salaire par sexe ================

repartitionSEXE <- postes %>% select(TRBRUTT, SEXE)
repartitionSEXE$SEXE <- replace(as.character(repartitionSEXE$SEXE), repartitionSEXE$SEXE == "1", "H")
repartitionSEXE$SEXE <- replace(as.character(repartitionSEXE$SEXE), repartitionSEXE$SEXE == "2", "F")

jpeg("images/repartition-sexe-salaire.jpg")
repartitionSEXE %>%
    ggplot(aes(x = TRBRUTT, fill = SEXE)) +
    geom_histogram(binwidth = 1, color = "white", alpha = .5, position = "identity")
dev.off()

# =============== heatmap salaire x age ==================

# get and filter needed data
df <- postes %>%
    dplyr::count(TRBRUTT, AGE_TR) %>%
    filter(AGE_TR != 0)

# create factors using the varmod labels
trbrutt_mapping <- mapping[mapping$COD_VAR == "TRBRUTT", ]
df$TRBRUTT <- factor(sprintf("%02d", df$TRBRUTT), levels = trbrutt_mapping$COD_MOD, labels = trbrutt_mapping$LIB_MOD)

age_mapping <- mapping[mapping$COD_VAR == "AGE_TR", ]
df$AGE_TR <- factor(sprintf("%02d", df$AGE_TR), levels = age_mapping$COD_MOD, labels = age_mapping$LIB_MOD)

# generate heatmap
jpeg("images/heatmap-salaire-par-age.jpg")
ggplot(df, aes(AGE_TR, TRBRUTT, fill = n)) +
    geom_tile() +
    scale_fill_gradient(low = "purple", high = "yellow") +
    theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust = 1))
dev.off()

df <- postes %>%
    filter(A6 != "") %>%
    filter(AGE_TR != "") %>%
    dplyr::count(AGE_TR, SEXE, A6)

df$SEXE[df$SEXE == 1] <- "Homme"
df$SEXE[df$SEXE == 2] <- "Femme"

age_mapping <- mapping[mapping$COD_VAR == "AGE_TR", ]
df$AGE_TR <- factor(sprintf("%02d", df$AGE_TR), levels = age_mapping$COD_MOD, labels = age_mapping$LIB_MOD)
df <- mutate(df, n_graphic = ifelse(df$SEXE == "Homme", n, -n))

jpeg("images/travailleurs-par-sexe-par-domaine.jpg")
ggplot(
    df,
    aes(
        x = n_graphic,
        y = AGE_TR,
        fill = SEXE
    )
) +
    facet_wrap(vars(A6)) +
    geom_col()
dev.off()
