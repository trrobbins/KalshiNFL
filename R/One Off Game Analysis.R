

setwd("C:/Users/Owner/Dropbox/ECU Misc/Active Working Papers/Prediction Markets/KalshiNFL/R")
source ("Kalshi Functions.R") 

FRgame<- "2025_16_LA_SEA"

mygame <- GetKalshiGame( FRgame) # Translate FastR to Kalshi ID
mygameid <- GetFastRGameID(mygame)
print (mygame)      # Kalshi version
print (mygameid)    # NFL FastR version

myKgameid <- 'KXNFLGAME-26JAN10GBCHI'
myFRgameid <-'2025_07_LV_KC'
	
myFRgameid <- GetFastRGameID(myKgameid)
myKgameid <- GetKalshiGame(myFRgameid)



Prices <- GetGamePrices1Min(myKgameid)     # Get Kalshi trades for a specific game 
pbpsummary <- GetpbpSummary()           # Load all plays from NFLFastR
Game_Times <-GetGameTimes(pbpsummary)   # Calculate game times from pbp information

GenGameBetVolAreaGraph(Prices, pbpsummary)  # Plot betting volume for this game
GenGameBetVolAreaGraph(Prices, pbpsummary, bydollar = FALSE)  # Plot contract volume for this game


# Plot the two win probabilities calculated by NFLFastR
PlotFastRWinProb(pbpsummary, myFRgameid, "Home")
PlotFastRWinProb(pbpsummary, myFRgameid, "Away")

#GetMatchupName(mygameid)

PlotKalshiTeamProbs( pbpsummary, myKgameid, Team = "Home", MA = FALSE, myspan = .2)
PlotKalshiTeamProbs(pbpsummary,myKgameid, Team = "Away")
PlotKalshiTeamProbs(pbpsummary,myKgameid, Team = "Away", MA = FALSE)
PlotKalshiTeamProbs(pbpsummary,myKgameid, Team = "Home", MA = FALSE)

PlotKalshiTeamProbs(pbpsummary,myKgameid, Team = "Home", PlotLive = TRUE,  MA=FALSE)


PlotFastRWinProb (pbpsummary, "2025_07_NYG_DEN", team= "Home")
########################

#Kalshi

Team <- "Home"

parts <- str_split_fixed(mygameid, "_", 4)

year        <- as.integer(parts[1])
season_week <- as.integer(parts[2])
away_team   <- parts[3]
home_team   <- parts[4]

if (Team == "Home"){
  select_team <- home_team
} else {
  select_team <- home_team
}


Prices <- GetGamePrices1Min(mygame)  # Get trades for a specific game




WinTrades <- Prices %>%
  filter (contract_team == select_team) %>%
  filter (taker_side == 'yes') %>%
  arrange (trade_minute) %>%
  mutate(
    cum_total_dollar_volume = cumsum(total_dollar_volume),

    # IMPORTANT: trade_minute is a UTC clock reading that is currently unlabeled
    trade_time_utc = force_tz(trade_minute, "UTC"),

    # now convert that instant to Eastern
    trade_time_et  = with_tz(trade_time_utc, "America/New_York")
  )

if (PlotLive == TRUE){
  Game_Times <-GetGameTimes(pbpsummary)
  WinTrades  <- WinTrades %>%
    left_join(Game_Times, by = join_by(game_id)) %>%
    filter (trade_minute >= game_start_utc) 
}




WinTrades %>%
  ggplot(aes(
    x = trade_time_et,
    y = vwap_yes_price
  )) +
  geom_line(linewidth = 1) + geom_smooth(se=FALSE, span = .25)+
  scale_y_continuous(
    limits = c(0, 100),
    labels = scales::percent_format(scale = 1)
  ) +
  labs(
    title = "Kalshi Market Implied Probability Over Time",
    subtitle = "VWAP Yes Price (1-Minute Aggregation)",
    x = "Time (UTC)",
    y = "Implied Probability (%)"
  ) +
  theme_minimal(base_size = 13) +
  theme(
    plot.title = element_text(face = "bold"),
    plot.subtitle = element_text(color = "gray40"),
    axis.title.y = element_text(margin = margin(r = 10)),
    axis.title.x = element_text(margin = margin(t = 10))
  )





CHIWin %>%
  ggplot (aes (x = trade_minute, y = cum_total_dollar_volume))+ geom_line()




CHIWin <- CHIWin %>%
  arrange(trade_minute) %>%
  mutate(
    cum_total_dollar_volume = cumsum(total_dollar_volume),
    
    # IMPORTANT: trade_minute is a UTC clock reading that is currently unlabeled
    trade_time_utc = force_tz(trade_minute, "UTC"),
    
    # now convert that instant to Eastern
    trade_time_et  = with_tz(trade_time_utc, "America/New_York")
  )


head (CHIWin)

KalshiTime <- CHIWin %>%
  select (trade_minute, trade_time_utc, trade_time_et)
head(KalshiTime)

CHIWINLive <- CHIWin %>%
  filter (trade_time_utc >= GameStartUTC)
####################################


CHIWin <- Prices %>%
  filter (contract_team == "CHI") %>%
  filter (taker_side == 'yes') %>%
  mutate (trade_time_et  = with_tz(trade_minute, "America/New_York"))



CHIWINLive  <- CHIWin %>%
  left_join(Game_Times, by = join_by(game_id)) %>%
  filter (trade_minute >= game_start_utc) %>%
  select (game_id, trade_minute, game_start_utc, everything())


CHIWINLive %>%
  ggplot(aes(
    x = trade_time_et,
    y = vwap_yes_price
  )) +
  geom_line(linewidth = 1) + geom_smooth(se=FALSE, span = .25)+
  scale_y_continuous(
    limits = c(0, 100),
    labels = scales::percent_format(scale = 1)
  ) +
  labs(
    title = "Kalshi Market Implied Probability Over Time",
    subtitle = "VWAP Yes Price (1-Minute Aggregation)",
    x = "Time (UTC)",
    y = "Implied Probability (%)"
  ) +
  theme_minimal(base_size = 13) +
  theme(
    plot.title = element_text(face = "bold"),
    plot.subtitle = element_text(color = "gray40"),
    axis.title.y = element_text(margin = margin(r = 10)),
    axis.title.x = element_text(margin = margin(t = 10))
  )




CHIGBpbp %>%
  arrange(play_time_et) %>%
  filter(!is.na(play_time_et), !is.na(vegas_home_wp)) %>%
  ggplot(aes(x = play_time_et, y = vegas_home_wp)) +
  geom_line(linewidth = 1) +   geom_smooth(se=FALSE)+
  scale_y_continuous(limits = c(0, 1), labels = scales::percent) +
  labs(
    title = "Home Win Probability (NFLFastR)",
    x = "Play time (ET)",
    y = "Win probability"
  ) +
  theme_minimal(base_size = 12)

min (CHIGBpbp$home_wp)
min (CHIWin$vwap_yes_price_dollars)

DollarbyMin <- Prices %>%
  group_by(trade_minute)%>%
  summarize (DollarVol = sum (total_dollar_volume))


DollarbyMin %>%
  ggplot(aes(x = trade_minute, y = DollarVol)) +
  geom_col() +
  labs(
    x = "Minute",
    y = "Dollar Volume",
    title = "Dollar Volume by Minute"
  ) +
  theme_minimal()

DollarbyMin %>%
  arrange(trade_minute) %>%
  mutate(CumDollarVol = cumsum(DollarVol)) %>%
  ggplot(aes(x = trade_minute, y = CumDollarVol)) +
  geom_area(alpha = 0.7) +
  labs(
    x = "Minute",
    y = "Cumulative Dollar Volume",
    title = "Cumulative Dollar Volume by Minute"
  ) +
  scale_y_continuous(labels = scales::dollar_format()) +
  theme_minimal()



DollarbyMin %>%
  mutate(trade_15min = floor_date(trade_minute, unit = "15 minutes")) %>%
  group_by(trade_15min) %>%
  summarise(
    DollarVol_15min = sum(DollarVol, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  ggplot(aes(x = trade_15min, y = DollarVol_15min)) +
  geom_col() +
  labs(
    x = "15-Minute Interval",
    y = "Dollar Volume",
    title = "Dollar Volume by 15-Minute Interval"
  ) +
  scale_y_continuous(labels = scales::dollar_format()) +
  scale_x_datetime(
    date_breaks = "30 min",
    date_labels = "%H:%M"
  ) +
  theme_minimal()

x1 <- KalshiProbs %>% select (contract_team)%>% distinct() %>% rename (team_abbr = contract_team)
x2 <- KalshiProbs %>% select (winner)%>% distinct()

d1 <- teams %>%
  anti_join(x1)
