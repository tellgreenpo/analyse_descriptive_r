 # SETUP

library("ggplot2")
library("tidyverse")
library("plyr")
library("dplyr")
library("magrittr")
library('cowplot')


postes <- read.csv("./dataset/postes_2020.csv", sep = ";")
mapping <- read.csv("./dataset/varmod_postes_2020.csv", sep = ";")





spdf <- geojson_read('departements.geojson',what='sp')
spdf_fortified <- tidy(spdf,region="code")
str(spdf_fortified)

# Percentage of people earningh more/less than X euros yearly per region
tranchesRevenuParRegion <- postes %>% select(TRBRUTT,DEPR) %>% filter(DEPR != "") %>% count(DEPR,TRBRUTT)
percentageRevenuParRegion = tranchesRevenuParRegion %>% group_by(DEPR) %>% mutate(percentage = n/sum(n)) %>%  filter(TRBRUTT >= 22) %>% group_by(DEPR) %>% summarise(highPercentage = sum(percentage))
percentageRevenuParRegion['lowPercentage'] <- tranchesRevenuParRegion %>% group_by(DEPR) %>% mutate(percentage = n/sum(n)) %>%  filter(TRBRUTT <= 13) %>% group_by(DEPR) %>% summarise(lowPercentage = sum(percentage)) %>% select(lowPercentage)
percentageRevenuParRegion$DEPR = as.character(percentageRevenuParRegion$DEPR)

create_varmod_factor <- function(df, column) {
    factor_mapping = mapping[mapping$COD_VAR==column,]
    values = sprintf("%02d", df[[column]])
    print(values)
    return(factor(values,
    levels=factor_mapping$COD_MOD,
    labels=factor_mapping$LIB_MOD))
}

df <- postes %>% dplyr::count(TRBRUTT, AGE_TR) %>%
    filter(AGE_TR != 0)

df$TRBRUTT = create_varmod_factor(df, "TRBRUTT")
df$AGE_TR = create_varmod_factor(df, "AGE_TR")


graph1 <- ggplot() +
  geom_polygon(data = spdf_fortified, aes(fill=lowPercentage,x = long, y = lat, group = group)) +
  scale_fill_gradient(low='#eeebc5',high='#bb0600') +
  theme_void() +
  coord_map()

graph2 <- ggplot() +
  geom_polygon(data = spdf_fortified, aes(fill=highPercentage,x = long, y = lat, group = group)) +
  scale_fill_gradient(low='#eeebc5',high='#bb0600') +
  theme_void() +
  coord_map()

# Save map
jpeg("./images/heat_map_salaries.jpg",width=1920,height=1080)
plot_grid(graph1,graph2)
dev.off()


# Checking distributions =============================================

revenus = postes['TRBRUTT']

# Revenus repartition
jpeg('revenus_repartition.jpg')
revenus['TRBRUTT'] %>%
ggplot(aes(x=TRBRUTT)) +
    geom_histogram(binwidth=1,fill="steelblue",color='black') +
    geom_vline(aes(xintercept=median(TRBRUTT)),color = 'red', linetype='dashed',size=1)
dev.off()


# Repartition population selon domaine
revenusNomenclature = postes['A38']

jpeg('nomenclature_repartition.jpg')
revenusNomenclature['A38'] %>%
ggplot(aes(x=A38)) +
    geom_histogram(stat="count",binwidth=1,fill="beige",color='black')
dev.off()

# Repartition age
repartitionAGE_TR = postes['AGE_TR'] %>% drop_na('AGE_TR')
jpeg('AGE_TR_repartition.jpg')
repartitionAGE_TR['AGE_TR'] %>%
ggplot(aes(x=AGE_TR)) +
    geom_histogram(binwidth=1,fill="pink",color='black')
dev.off()


# Repartition departement residence et entreprise
repartitionResidence = postes['DEPR'] %>% drop_na('DEPR')
repartitionEntreprise = postes['DEPT'] %>% drop_na('DEPT')

jpeg('DEPR_repartition.jpg')
ggplot() +
    geom_histogram(data = repartitionResidence['DEPR'],aes(x=DEPR),fill='yellow',binwidth=1,color='black',stat='count',alpha=0.4)+
    geom_histogram(data=repartitionEntreprise['DEPT'],aes(x=DEPT),fill='red',binwidth=1,color='black',stat='count',alpha=0.4)
dev.off()

# Repartition categorie socio pro emploi
repartitionCS = postes['CS'] %>% drop_na('CS')
jpeg('CS_repartition.jpg')
repartitionCS['CS'] %>%
ggplot(aes(x=CS)) +
    geom_histogram(stat="count",binwidth=1,fill="yellow",color='black')
dev.off()

# nombre genre
postes['SEXE'] %>% count(SEXE)


# Repartition sexe revenus
repartitionSEXE = postes %>% select(TRBRUTT,SEXE)
repartitionSEXE$SEXE = replace(as.character(repartitionSEXE$SEXE),repartitionSEXE$SEXE=='1','H')
repartitionSEXE$SEXE = replace(as.character(repartitionSEXE$SEXE),repartitionSEXE$SEXE=='2','F')

jpeg('SEXE_repartition.jpg')
repartitionSEXE %>%
ggplot(aes(x=TRBRUTT,fill=SEXE)) +
    geom_histogram(binwidth=1,color='white',alpha=.5,position='identity')
dev.off()


# Repartition type de contrat
repartitionCONT_TRAV = postes['CONT_TRAV'] %>% drop_na('CONT_TRAV')
jpeg('CONT_TRAV_repartition.jpg')
repartitionCONT_TRAV['CONT_TRAV'] %>%
ggplot(aes(x=CONT_TRAV)) +
    geom_histogram(binwidth=1,fill="pink",color='black',stat='count')
dev.off()


# =======================================================

# Revenus par age

# Revenus par region
jpeg('heatmap-salaire-par-age.jpg')
ggplot(df, aes(AGE_TR, TRBRUTT, fill = n)) +
geom_tile() +
theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust=1))
dev.off()
