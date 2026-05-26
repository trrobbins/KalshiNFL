
game_id <- "2025_20_BUF_DEN"
game_id <- "2025_03_GB_CLE"
game_id  <- "2025_07_NYG_DEN"
game_id  <- "2025_10_NYG_CHI"
game_id  <- "2025_09_CAR_GB"
game_id  <- "2025_16_LA_SEA" 
game_id  <- "2025_10_JAX_HOU" 


game_id  <- "2025_10_JAX_HOU" 
game_id  <- "2025_05_HOU_BAL" 
game_id  <- "2025_16_SF_IND" 

game_id <- '2025_01_ARI_NO'

FRgame <- game_id
Kgame <- GetKalshiGame( FRgame)

x <- GetKalshiGameProbs(Kgame)
x <- GetKalshiGameProbs(Kgame, team = "Away")

y <- GetFastRGameProbs (game_id, team = "Away" , type = 'WP')

z <- GetCombinedProbs (game_id , team = "Away" , type = 'Vegas')
z <- GetCombinedProbs (game_id , team = "Away" , type = 'WP')



############################



game_id  <- '2025_09_JAX_LV'
Kgame <- GetKalshiGame(game_id)

games <- nflreadr::load_schedules(
  seasons = 2025)


RandomGameId <- games %>%
  slice_sample(n = 1) %>%
  pull(game_id)

#ProbCombo<- GetCombinedProbs (RandomGameId , team = "Away" , type = 'WP')
ProbCombo<- GetCombinedProbs (RandomGameId , team = "Away" , type = 'Vegas')
PlotGameProbs(ProbCombo)

LiveOnly <- 'TRUE'

pbps<-GetpbpSummary()

KalshiProbsHome <- GetKalshiGameProbs (Kgame,pbps, "Home" , LiveOnly )
KalshiProbsAway <- GetKalshiGameProbs (Kgame,pbps, "Away" , LiveOnly )
KalshiBothSide <- rbind (KalshiProbsHome, KalshiProbsAway) %>%
  arrange (date_time) %>%
  pivot_wider(names_from = team, values_from = wp)%>%
  mutate(
    TotalWP = rowSums(across(3:4), na.rm = TRUE)
  )

FGame <- GetFastRGameID((Kgame))
x1 <- GetKalshiGameProbs (Kgame,pbps, "Home" , LiveOnly )
x2 <- QR2 %>% filter  (game_id == FGame) %>% filter (contract_team == 'DEN') %>% arrange (trade_minute)


QR2A <- QR %>% filter  (game_id == FGame)%>% filter (contract_team == 'DEN') %>% arrange (trade_minute)
