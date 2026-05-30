


# Kalshi volume analysis
setwd("C:/Users/Owner/Dropbox/ECU Misc/Active Working Papers/Prediction Markets/KalshiNFL/R")
source ("Kalshi Functions.R") 

# This script does some basic volume analysis on the Kalshi data


######################

##  Aggregate Numbers
library(scales)


TotalTrans<- PrintSQLTableCount('kalshi_trades',"Total Transactions" )

TotalContracts<- PrintSQLTableSum ('kalshi_trades', 'count', "Total_Contracts")


###################################

nflgames <- GetNFLGames()

Q <- "SELECT game ,  
  count(*)  as Trades,
  sum([count]) as ContractVolume,
  sum(dollar_volume) as DollarVolume
  FROM kalshi_trades
  group by game;"

ContractsbyGame <- RunSQL(Q) %>%
  inner_join(nflgames)

mean (ContractsbyGame$Trades)
median (ContractsbyGame$Trades)
mean (ContractsbyGame$ContractVolume)
median (ContractsbyGame$ContractVolume)
mean (ContractsbyGame$DollarVolume)
median (ContractsbyGame$DollarVolume)



plot <- ContractsbyGame %>%
  ggplot(aes(x = ContractVolume)) +
  geom_histogram(
    bins = 25,
    fill = "lightblue",
    color = "black"
  ) +
  scale_x_continuous(
    labels = comma
  ) +
  scale_y_continuous(
    labels = comma
  ) +
  labs(
    title = "Distribution of Kalshi Contract Volume by NFL Game",
    subtitle = "Each observation represents one game",
    x = "Kalshi Contract Volume",
    y = "Number of Games",
    caption = "Contract volume represents the number of contracts traded"
  ) +
  theme_minimal()
print(plot)
SavePlotToFile(plot,"ContractsperGame")

ContractsbyGame %>%
  ggplot(aes(x = DollarVolume)) +
  geom_histogram(
    bins = 25,
    fill = "lightblue",
    color = "black"
  ) +
  scale_x_continuous(
    labels = comma
  ) +
  scale_y_continuous(
    labels = comma
  ) +
  labs(
    title = "Distribution of Kalshi Dollar Volume by NFL Game",
    subtitle = "Each observation represents one game",
    x = "Kalshi Contract Volume",
    y = "Number of Games",
    caption = "Dollar volume represents the total price paid by contract buyers"
  ) +
  theme_minimal()



ContractsbyGame %>%
  group_by(week, game_type) %>%
  summarize(
    ContractVolume = sum(ContractVolume, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  ggplot(aes(x = week, y = ContractVolume, fill = game_type)) +
  geom_col(color = "black") +
  scale_y_continuous(
    labels = comma
  ) +
  labs(
    title = "Kalshi Contract Volume by NFL Week",
    subtitle = "Volume aggregated across games and colored by game type",
    caption = "No standard contracts for the Conference Championships and the Super Bowl",
    x = "Week",
    y = "Kalshi Contract Volume",
    fill = "Game Type"
  ) +
  theme_minimal()


VolumebyGame <- ContractsbyGame %>%
  group_by(matchup, gameday) %>%
  summarize(
    ContractVolume = sum(ContractVolume, na.rm = TRUE),
    DollarVolume = sum(DollarVolume, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange (desc(DollarVolume))


library(tidyverse)
library(gt)
library(gtExtras)

VolumebyGame %>%
  arrange(desc(ContractVolume)) %>%
  slice_head(n = 10) %>%
  gt() %>%
  tab_header(
    title = md("**Top 10 NFL Games by Kalshi Contract Volume**"),
    subtitle = md("Game winner markets ranked by total contracts traded")
  ) %>%
  cols_label(
    matchup = "Matchup",
    gameday = "Game Date",
    ContractVolume = "Contract Volume",
    DollarVolume = "Cash Trading Volume"
  ) %>%
  fmt_date(
    columns = gameday,
    date_style = "iso"
  ) %>%
  fmt_number(
    columns = c(ContractVolume, DollarVolume),
    decimals = 0,
    use_seps = TRUE
  ) %>%
  tab_source_note(
    source_note = md(
      "Contract Volume is the number of $1 Kalshi contracts traded. Cash Trading Volume is calculated as `count × price` across trades."
    )
  ) %>%
  gt_theme_538()



###########################

# Per Trade Numbers

Q <- "
WITH TradeStats AS (
    SELECT
        CAST([count] AS decimal(18, 2)) AS contract_count,
        CAST(dollar_volume AS decimal(18, 2)) AS dollar_volume
    FROM [NFLPrediction].[dbo].[kalshi_trades]
)
SELECT DISTINCT
    AVG(contract_count) OVER () AS AvgContractCount,
    PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY contract_count) OVER () AS MedianContractCount,
    PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY contract_count) OVER () AS Pct90ContractCount,
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY contract_count) OVER () AS Pct95ContractCount,

    AVG(dollar_volume) OVER () AS AvgDollarVolume,
    PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY dollar_volume) OVER () AS MedianDollarVolume,
    PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY dollar_volume) OVER () AS Pct90DollarVolume,
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY dollar_volume) OVER () AS Pct95DollarVolume
FROM TradeStats;"

PTrade <- RunSQL(Q)



Q <- "SELECT TOP (1000000)
    CAST([count] AS float) AS contract_count
FROM kalshi_trades
ORDER BY NEWID();"

SampleTrades <- RunSQL(Q)


SampleTrades %>%
  ggplot(aes(x = contract_count)) +
  geom_histogram(
    bins = 60,
    fill = "lightblue",
    color = "black"
  ) +
  scale_x_log10(
    labels = comma,
    breaks = c(1, 5, 10, 25, 50, 100, 250, 500, 1000, 2500, 5000, 10000)
  ) +
  scale_y_continuous(labels = comma) +
  labs(
    title = "Distribution of Kalshi Trade Sizes",
    subtitle = "Random sample of 1,000,000 trades; x-axis shown on log scale",
    x = "Contracts Traded",
    y = "Number of Trades"
  ) +
  theme_minimal()

TopTradeSizes <- SampleTrades %>%
  count(contract_count, sort = TRUE) %>%
  slice_head(n = 10)


TopTradeSizes %>%
  gt() %>%
  tab_header(
    title = md("**Most Common Kalshi NFL Trade Sizes**"),
    subtitle = md("Top 10 contract counts by number of trades")
  ) %>%
  cols_label(
    contract_count = "Contracts Traded",
    n = "Number of Trades"
  ) %>%
  fmt_number(
    columns = c(contract_count, n),
    decimals = 0,
    use_seps = TRUE
  ) %>%
  tab_source_note(
    source_note = md("Based on a random sample of 1 million Kalshi trade records on NFL Team contracts.")
  ) %>%
  gt_theme_538()



##########################


AllKalshiPrices <- GetGamePrices1Min()     # Get all  Kalshi trades summarized at 1 min
pbpsummary <- GetpbpSummary()           # Load all plays from NFLFastR
Game_Times <-GetGameTimes(pbpsummary)

TradeTimes <- AllKalshiPrices %>%
  inner_join(Game_Times,by = join_by(game_id)) %>%
  mutate(
    period = case_when(
      trade_time_et < game_start_et ~ "PreGame",
      trade_time_et >= game_start_et & trade_time_et < game_end_et ~ "InGame",
      trade_time_et >= game_end_et ~ "InGame",
      TRUE ~ NA_character_
)) %>%
  group_by(game_id, period)%>%
  summarize (ContractsTraded=sum(total_count), .groups = "drop_last") %>%
  pivot_wider(names_from = period, values_from = ContractsTraded ) %>%
  mutate (
    Total = InGame + PreGame  ,
    PreGamePct = PreGame / Total,
    InGamePct = InGame / Total)

# Ingame contracts
sum(TradeTimes$InGame)/sum(TradeTimes$Total)
min (TradeTimes$InGamePct)
mean (TradeTimes$InGamePct)
median (TradeTimes$InGamePct)
max (TradeTimes$InGamePct)

plot <- TradeTimes %>%
  ggplot(aes(x = InGamePct)) +
  geom_histogram(
    binwidth = 0.05,
    fill = "lightblue",
    color = "black"
  ) +
  # geom_vline(
  #   xintercept = mean(TradeTimes$InGamePct, na.rm = TRUE),
  #   linetype = "dashed",
  #   linewidth = 1
  # ) +
  # geom_vline(
  #   xintercept = median(TradeTimes$InGamePct, na.rm = TRUE),
  #   linetype = "dotted",
  #   linewidth = 1
  #) +
  scale_x_continuous(labels = scales::percent_format()) +
  labs(
    title = "Distribution of In-Game Kalshi Contract Trading by NFL Game",
    subtitle = "2025 Season",
    x = "Percent of Contracts Traded In-Game",
    y = "Number of Games",
    #caption = "Dashed line = mean; dotted line = median"
    caption = str_c ("Average equals ", round (100*mean(TradeTimes$InGamePct),1),"%")
  ) +
  theme_minimal()
print (plot)
SavePlotToFile(plot, "In Game Trades")
