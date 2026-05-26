

setwd("C:/Users/Owner/Dropbox/ECU Misc/Active Working Papers/Prediction Markets/KalshiNFL/R")

source ("Kalshi Functions.R") 
UseSQLdb()
Q <- "SELECT
    game, SUM(total_dollar_volume) AS total_dollar_volume
FROM dbo.kalshi_trades_1hr_vwap
group by game;"


GameVol <- GetPerGameVol()

GameVolStats <- GameVol %>%
  summarize (Min = min (total_dollar_volume),
             Avg = mean (total_dollar_volume),
             Max = max (total_dollar_volume))
  



library(scales)

GameVol %>%
  ggplot(aes(x = total_dollar_volume)) +
  geom_histogram(
    #bins = 30,
    binwidth = 2000000,
    fill = "steelblue",
    color = "white",
    alpha = 0.8
  ) +
  scale_x_continuous(
    labels = dollar_format(prefix = "$", scale = 1e-6, suffix = "M")
  ) +
  labs(
    title = "Distribution of Kalshi NFL Game Dollar Volume",
    subtitle = "Per-game executed notional volume",
    x = "Total Dollar Volume (Millions USD)",
    y = "Number of Games"
  ) +
  theme_minimal(base_size = 13)

################################

Q <- "Select * from kalshi_trades_1min_vwap where game = 'KXNFLGAME-25DEC08PHILAC'"
GameTrades = RunSQL(Q)


library(tidyverse)
library(scales)
names (GameTrades)


GameTrades %>%
  mutate (trade_date = as.Date(trade_minute))%>%
  filter (trade_date >= event_date)%>%
  ggplot(aes(
    x = trade_minute,
    y = vwap_yes_price_dollars,
    color = contract_team
  )) +
  geom_line(linewidth = 1.1) +
  geom_point(size = 2, alpha = 0.8) +
  scale_y_continuous(
    labels = percent_format(accuracy = 1),
    limits = c(0, 1)
  ) +
  labs(
    title = "Kalshi Implied Win Probabilities Over Time",
    subtitle = "1-minute VWAP of YES contracts",
    x = "Time",
    y = "Implied Win Probability",
    color = "Team"
  ) +
  theme_minimal(base_size = 13)

pbp25 <- nflreadr::load_pbp(2025)# Play by Play

pbpteam <- pbp25 %>%
  select (home_team)%>%
  distinct() %>%
  mutate (PBP = "PBP")%>%
  rename (team = home_team)

Q <- "SELECT distinct
      [contract_team]

  FROM [NFLPrediction].[dbo].[kalshi_trades_1min_vwap]"

KalshiTeam <- RunSQL(Q)%>%
  mutate (Kalshi = "Kalshi") %>%
  rename (team = contract_team)
  

TeamMatchL <- KalshiTeam %>%
  left_join(pbpteam) 


TeamMatchR <- KalshiTeam %>%
  right_join(pbpteam) 


###################################################

pbpsummary <- GetpbpSummary()
game_times <- GetGameTimes(pbpsummary)
AllTrades <- GetTradeSummary1Min()
Winners <- GetGameWinners() %>%
  select(game_id, winner, tie)

library(dplyr)
library(stringr)

AllTradesLive <- AllTrades %>%
  left_join(game_times, by = join_by(game_id)) %>%
  left_join(Winners,    by = join_by(game_id)) %>%
  mutate(
    contract_team = str_trim(contract_team),
    winner        = str_trim(winner),
    win           = if_else(contract_team == winner, 1L, 0L)
  ) %>%
  filter(tie != 1) %>%
  filter(taker_side == "yes") %>%
  filter(trade_minute >= game_start_utc) %>%
  select(game, game_id, contract_team,taker_side, vwap_yes_price_dollars, winner, win)

set.seed(123)

BrierSample <- CalculateSampleBrier (AllTradesLive)

set.seed(123)

B <- 10000

bootstrap_results <- bind_rows(
  replicate(B, CalculateSampleBrier(AllTradesLive), simplify = FALSE)
)


bootstrap_results %>%
  summarise(
    raw_mean   = mean(raw_brier),
    raw_sd     = sd(raw_brier),
    binned_mean = mean(binned_brier),
    binned_sd   = sd(binned_brier)
  )



ggplot(bootstrap_results, aes(x = raw_brier)) +
  geom_histogram(
    bins = 30,
    fill = "lightblue",
    color = "black",
    alpha = 0.9
  ) +
  labs(
    title = "Bootstrap Distribution of Raw Brier Score",
    subtitle = "10 stratified samples per game",
    x = "Raw Brier Score",
    y = "Frequency"
  ) +
  theme_minimal(base_size = 13) +
  theme(
    plot.title = element_text(face = "bold"),
    plot.subtitle = element_text(color = "gray40"),
    axis.title.x = element_text(margin = margin(t = 10)),
    axis.title.y = element_text(margin = margin(r = 10))
  )


ggplot(bootstrap_results, aes(x = binned_brier)) +
  geom_histogram(
    bins = 30,
    fill = "lightblue",
    color = "black",
    alpha = 0.9
  ) +
  labs(
    title = "Bootstrap Distribution of Binned Brier Score",
    subtitle = "Ventile-level calibration error",
    x = "Binned Brier Score",
    y = "Frequency"
  ) +
  theme_minimal(base_size = 13) +
  theme(
    plot.title = element_text(face = "bold"),
    plot.subtitle = element_text(color = "gray40"),
    axis.title.x = element_text(margin = margin(t = 10)),
    axis.title.y = element_text(margin = margin(r = 10))
  )


ggplot(bootstrap_results, aes(x = raw_brier)) +
  geom_density(
    fill = "lightblue",
    color = "black",
    alpha = 0.8,
    linewidth = 1
  ) +
  labs(
    title = "Bootstrap Distribution of Raw Brier Score",
    subtitle = "Kernel density estimate",
    x = "Raw Brier Score",
    y = "Density"
  ) +
  theme_minimal(base_size = 13)


AllTrades_sample <- AllTradesLive %>%
  slice_sample(
    n = 10,
    by = game
  ) %>%
  mutate (SE =  (vwap_yes_price_dollars - win )^2)


Brier <- mean (AllTrades_sample$SE)

binned_traded <- AllTrades_sample %>%
  mutate(
    bin = ntile(vwap_yes_price_dollars, 20)
  )

bin_summary <- binned_traded %>%
  group_by(bin) %>%
  summarize (
    N = n(),
    PredWinProb = mean (vwap_yes_price_dollars),
    ActualWinProb = mean(win))



binned_brier <- bin_summary %>%
  summarise(
    brier = weighted.mean(
      (PredWinProb - ActualWinProb)^2,
      w = N
    )
  ) %>%
  pull(brier)

binned_brier


PlotCalibration(bin_summary, "Kalshi Trades")

library(dplyr)

CalculateSampleBrier <- function(AllTrades) {
  
  AllTrades_sample <- AllTrades %>%
    slice_sample(
      n = 10,
      by = game
    )
  
  # raw Brier
  raw_brier <- mean((AllTrades_sample$vwap_yes_price_dollars - 
                       AllTrades_sample$win)^2)
  
  # binned Brier
  bin_summary <- AllTrades_sample %>%
    mutate(bin = ntile(vwap_yes_price_dollars, 20)) %>%
    group_by(bin) %>%
    summarise(
      N = n(),
      PredWinProb = mean(vwap_yes_price_dollars),
      ActualWinProb = mean(win),
      .groups = "drop"
    )
  
  binned_brier <- with(
    bin_summary,
    weighted.mean((PredWinProb - ActualWinProb)^2, w = N)
  )
  
  tibble(
    raw_brier = raw_brier,
    binned_brier = binned_brier
  )
}




pbp25 <- GetpbpSummary()

PreGame <- pbp25 %>%
  filter (desc == 'GAME') %>%
  select (game_id, home_wp, away_wp, vegas_home_wp, vegas_away_wp)


library(tidyverse)



myGame <- "2025_07_NYG_DEN"


PlotFastRWinProb(pbp25, myGame, "Home")
PlotFastRWinProb(pbp25, myGame, "Away")



game <- 'KXNFLGAME-25DEC20GBCHI'

x <- GetFastRGameID("KXNFLGAME-25DEC20GBCHI")
x <- GetKalshiGame("2025_16_GB_CHI")



###########################################

game_times <- GetGameTimes(pbpsummary)
AllTrades <- GetTradeSummary1Min()


TradeTimes <- game_times %>%
  select (game_id, game_start_utc, game_end_utc) %>%
  left_join(AllTrades)

AllTradesSplit <- AllTrades %>%
  mutate (event_date = as.Date(event_date))  %>%
  left_join(game_times, by = join_by(game_id)) %>%
  mutate( Period = case_when(trade_minute >= game_start_utc ~ "Live", TRUE ~ "Pregame") ) %>%
  group_by( ticker , Period, event_date)%>%
  summarize (TradeVol = sum (total_dollar_volume)) %>%
  pivot_wider(names_from = Period, values_from = TradeVol) %>%
  mutate (
    Total = Live +Pregame,
    PctPre = Pregame /  Total,
    PctLive = Live / Total,
    event_date = as.Date(event_date) %>%
  filter (event_date >= '2025-09-04')
   


