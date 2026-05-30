

##   Kalshi Functions


# This file contains a series of functions used in a research project on the Kalshi prediction
# initially focused on the NFL.  

library(tidyverse)
library(RODBC)
library (scales)
library(moments)

connection <- odbcConnect("sqlserver")
db <- "NFLPrediction"

source ("Basic Utility Functions.R") 


UseSQLdb <- function (db = "NFLPrediction"){
  
  # This function will execute a USE command to specify what data base
  # to use in upcoming transactions.  This is needed because we may have 
  # multiple databases defined in our SQL Server.  
  
  Q<- str_c("USE [", db, "]")
  print (Q)
  QR <- RunSQL (Q, Time = FALSE)
}

RunSQL <- function(Query, db = "NFLPrediction", Connection = connection, Time = TRUE) {
  
  StartTime <- Sys.time()
  X <- sqlQuery(Connection, Query, errors = FALSE)
  EndTime <- Sys.time()
  
  if (Time == TRUE) {
    print(EndTime - StartTime)
  }
  
  if (!is.data.frame(X)) {
    
    if (length(X) == 1 && X == -1) {
      print("SQL Error")
      X <- sqlQuery(Connection, Query, errors = TRUE)
      print(X)
    }
    
  }
  
  return(X)
}

LoadSQLTable <- function (table,db = "NFLPrediction", Connection = connection, Time = TRUE, WC = NA){
  
  # This function will load the contents of a SQL table/view with an optional where clause
  
  Q <- str_c("Select * from ", table )
  
  if (! is.na(WC)){
    
    Q <- str_c (Q, " where ", WC)
    
  }
  
  QR <- RunSQL(Q)
  return (QR)
  
}


GetSQLTableCount <- function (table,db = "NFLPrediction", Connection = connection, Time = TRUE, WC = NA){
  
  # This function will load the contents of a SQL table/view with an optional where clause
  
  Q <- str_c("Select count(*) from ", table )
  
  if (! is.na(WC)){
    
    Q <- str_c (Q, " where ", WC)
    
  }
  
  QR <-as.integer( RunSQL(Q))
  return (QR)
  
}

PrintSQLTableCount <- function(table, description, WC = NA) {
  
  # This function will get the record count from a table and print ir
  
  n <- GetSQLTableCount(table, WC)
  str_c( description, ": ", comma(n)) %>%
    print()
  
  return (n)
}

PrintSQLTableSum <- function (table, col, description, WC = NA){
  
  
  # This function will return the sum of a db column with an optional where clause
  
  QBase <- 'SELECT SUM(CAST([[COL]] AS bigint)) AS [CL] FROM [DT]'
  
  Q <- QBase %>%
    str_replace ( "\\[COL\\]", col) %>%
    str_replace ("\\[CL\\]", description) %>%  
    str_replace ("\\[DT\\]", table) 
  
  if (! is.na(WC)){
    Q <- str_c (Q, " where ", WC)
    
  }
  
  
  QR <- RunSQL(Q)
  n <- as.numeric(QR[1,1])
  
  str_c( description, ": ", comma(n)) %>%
    print()
  
  return (n)
  
}

UseSQLdb()

GetLoadedTradeFiles <- function (){
  
  # This function will retrieve the set of trade files that 
  # Have been loaded to the SQL Server database
  
  
  Q <- "SELECT ticker
      ,FName
  FROM kalshi_trade_files"
  
  
  QR <- RunSQL(Q)
  return (QR)
  
}



GetFastRGameID <- function (game){
  
  # This function will translate the Kalshi game indicator into a NFLFastR game ID
  Q <- str_c( "Select game_id from gamemap where game = '", game,"'")
  QR <- RunSQL(Q)
  
  mygameid <- QR$game_id[1]
  
  return (mygameid)
  
}


GetKalshiGame <- function (game_id){
  
  # This function will translate the NFLFastR game ID into a Kalshi game indicator
  Q <- str_c( "Select game from gamemap where game_id = '", game_id,"'")
  QR <- RunSQL(Q)
  
  mygame <- QR$game[1]
  
  return (mygame)
  
}



GetGameFilesList <- function (dir = "E:/PredMktData/TradeExports"){
  
  # This function will get a list of game files that have been 
  # downloaded to the directory vai the Kalshi API
  
  mydir <- getwd()
  setwd (dir)
  
  Gamefiles <- list.files(dir, pattern = "\\.csv$") %>%
    tibble(FName = .)%>%
    filter (str_detect(FName,"Trades")==TRUE)
  
  setwd (mydir)
  return (Gamefiles)
  
  
}


GetGamestoLoad <- function (dir = "E:/PredMktData/TradeExports"){
  
  # This function will determine the list of trade files that
  #  have been downloaded from Kalshi but not yet uploaded to the 
  # SQL Server database
  
  
  LoadedFiles <- GetLoadedTradeFiles()
  Gamefiles <- GetGameFilesList(dir)
  
  GamestoLoad <- Gamefiles %>%
    anti_join(LoadedFiles, by = join_by(FName))
  
  
}


UploadTradeFiles <- function (dir = "E:/PredMktData/TradeExports/") {
  
  # This function will find all the trade files that have been downloaded from 
  # Kalshi, but not yet uploaded to the SQL Server db and upload them.  
  
  GamestoLoad <- GetGamestoLoad(dir)
  
  for (fname in GamestoLoad$FName) {
    sql_stmt <- sprintf(
      "EXEC dbo.LoadKalshiTradeFile @FilePath = '%s%s';",
      dir,
      fname
    )
    cat(sql_stmt, "\n")
    QR <- RunSQL(sql_stmt)
  }
}


GetpbpSummary  <- function (season = 2025){
  
  # This function will load  play by play summary for the specified
  # season from NFLfastR.
  #
  # It will extract the key fields needs and do some data cleaning /interpolation
  
  
  pbp <- nflreadr::load_pbp(season)# Play by Play
  

  pbpsummary <- pbp %>%
    group_by(game_id) %>%
    arrange(play_id, .by_group = TRUE) %>%
    mutate(
      # 1) parse once (NA stays NA)
      time_of_day_dt = ymd_hms(time_of_day, tz = "UTC"),
      
      # 2) carry forward time for END QUARTER rows when missing
      time_of_day_dt = if_else(
        is.na(time_of_day_dt) & str_starts(desc, "END QUARTER"),
        lag(time_of_day_dt),
        time_of_day_dt
      ),
      
      # 3) set GAME / END GAME using (now-filled) time_of_day_dt
      time_of_day_dt = case_when(
        desc == "GAME"     ~ min(time_of_day_dt, na.rm = TRUE) - seconds(5),
        desc == "END GAME" ~ max(time_of_day_dt, na.rm = TRUE) + seconds(5),
        TRUE               ~ time_of_day_dt
      ),
      
      # 4) derived times
      play_time_utc = time_of_day_dt,
      play_time_et  = with_tz(play_time_utc, "America/New_York")
    ) %>%
    ungroup() %>%
    select(
      game_id, play_id, home_team, away_team,
      play_time_utc, play_time_et, time_of_day_dt,
      contains("wp"), desc
    ) %>%
    select(-contains("wpa")) %>%
    mutate(vegas_away_wp = 1 - vegas_home_wp)
  
  return (pbpsummary)
  
  
  
  
}

GetGamePrices1Min <- function (game=NA ){
  # This function will return Kalshi prices for a game aggregated to the 1 min level  
  
  if (!is.na (game)){
    Q <- str_c("select * from kalshi_trades_1min_vwap  where game = '" , game,"'")
  }   else{
    Q <- str_c("select * from kalshi_trades_1min_vwap  ")
    
  }
  
  QR <- RunSQL(Q) 
  
  if (nrow (QR)> 0){
    QR <- QR   %>%
      mutate(
        trade_minute = lubridate::force_tz(trade_minute, "UTC"),
        trade_time_et  = with_tz(trade_minute, "America/New_York"))
  } else {
    print (str_c("No records returned for game ", game))
  }

  return (QR)
  
}




GetGameTimes<- function (pbp){
  
  # This function will calculate key games times, including game
  # start, end and end of quarters based on play by play data.  
  
  Game_Times <- pbp %>%
    filter(
      desc %in% c("GAME", "END GAME") |
        str_detect(desc, "^END QUARTER \\d+$")
    ) %>%
    mutate(
      key = case_when(
        desc == "GAME"     ~ "game_start_utc",
        desc == "END GAME" ~ "game_end_utc",
        TRUE ~ str_c("q", str_match(desc, "^END QUARTER (\\d+)$")[, 2], "_end_utc")
      )
    ) %>%
    select(game_id, key, play_time_utc) %>%
    pivot_wider(
      names_from  = key,
      values_from = play_time_utc,
      values_fn   = dplyr::first
    ) %>%
    mutate(
      # OT if game ends after regulation
      ot = as.integer(!is.na(q4_end_utc) & game_end_utc > q4_end_utc),
      
      # Ensure q4_end_utc always populated
      q4_end_utc = coalesce(q4_end_utc, game_end_utc),
      
      # ET conversions
      game_start_et = with_tz(game_start_utc, "America/New_York"),
      q1_end_et     = with_tz(q1_end_utc,     "America/New_York"),
      q2_end_et     = with_tz(q2_end_utc,     "America/New_York"),
      q3_end_et     = with_tz(q3_end_utc,     "America/New_York"),
      q4_end_et     = with_tz(q4_end_utc,     "America/New_York"),
      game_end_et   = with_tz(game_end_utc,   "America/New_York")
    ) %>%
    select(
      game_id,
      game_start_utc,
      q1_end_utc, q2_end_utc, q3_end_utc, q4_end_utc,
      game_end_utc,
      game_start_et,
      q1_end_et, q2_end_et, q3_end_et, q4_end_et,
      game_end_et,
      ot
    )
  
}

GetTradeSummary1Min <- function() {
  
  # This function will retrieve all trading activity 
  # summarized to 1 minute intervals
  
  print ("Loading all trades at 1 minute intervals")
  
  Q <- "select * from kalshi_trades_1min_vwap"
  AllTrades  <- RunSQL(Q)
  
  return (AllTrades)
  
}


GetGameWinners <- function(JAX=TRUE) {
  
  # This function will retrieve game winners
  
  Q <- "Select * from game_winners"
  
  QR <- RunSQL (Q)
  
  if (JAX == TRUE){
    QR <- QR %>%
      mutate (winner = case_when(winner == "JAX" ~ "JAC", TRUE ~ winner))
  }
}


PlotCalibration <- function (bin_summary, source){
  
  # This function will plot a calibration curve.
  # It assumes the data frame has fields PredWinProb, 
  # and ActualWinProb
  
  
  myTitle <- str_c ("Market Calibration - ",source)
  
  ggplot(bin_summary, aes(x = PredWinProb, y = ActualWinProb)) +
    geom_abline(
      intercept = 0, slope = 1,
      linetype = "dashed",
      color = "gray50",
      linewidth = 1
    ) +
    geom_point(
      size = 3,
      color = "#2C7FB8",
      alpha = 0.9
    ) +
    geom_line(
      linewidth = 1,
      color = "#2C7FB8"
    ) +
    scale_x_continuous(
      limits = c(0, 1),
      labels = scales::percent_format(accuracy = 1)
    ) +
    scale_y_continuous(
      limits = c(0, 1),
      labels = scales::percent_format(accuracy = 1)
    ) +
    labs(
      title = myTitle,
      subtitle = "Predicted vs Actual Win Probability",
      x = "Predicted Win Probability (VWAP Yes Price)",
      y = "Actual Win Probability",
      caption = "Dashed line indicates perfect calibration"
    ) +
    theme_minimal(base_size = 13) +
    theme(
      plot.title = element_text(face = "bold"),
      plot.subtitle = element_text(color = "gray40"),
      axis.title.x = element_text(margin = margin(t = 10)),
      axis.title.y = element_text(margin = margin(r = 10))
    )
}



PlotFastRWinProb <- function (pbp, game_id, team= "Home", Save = TRUE){
  
  
  # This function will plot the two win probabilities calculated in the NFLFastR 
  # data set.  One includes pre-games odds, the other does not.  
  
  myGame <- game_id
  mypbp <- pbp %>%
    filter (game_id == myGame )
  myMatchup <- GetMatchupName(myGame , ticker=FALSE)
  
  if (team == "Home"){
    mypbp <- mypbp %>%
      mutate (
        WP = home_wp,
        VegasWP = vegas_home_wp
      )
    myTeam <- mypbp$home_team
  } else {
    mypbp <- mypbp %>%
      mutate (
        WP = away_wp,
        VegasWP = vegas_away_wp
      )
    myTeam <- mypbp$away_team
  }
  myGame <- game_id
  
  myTitle <- str_c (myTeam , " - NFLFastR In Game Win Probability" )
  mySub <- str_replace_all (mypbp$game_id[1], "_", " ")
  

  mypbplong <- mypbp %>%
    select(game_id, play_time_et, WP, VegasWP) %>%
    rename(
      Standard_WP = WP,
      Line_Adjusted_WP = VegasWP
    ) %>%
    pivot_longer(
      cols = c(Standard_WP, Line_Adjusted_WP),
      names_to = "source",
      values_to = "wp"
    )
  
  plot <- mypbplong %>%
    filter (game_id == myGame ) %>%
    ggplot(aes(
      x = play_time_et,
      y = wp,
      color = source,
      shape = source,
      group = source
    )) +
    geom_line(
      linewidth = 0.7,
      alpha = 0.55
    ) +
    geom_point(
      size = 2.4,
      alpha = 0.85
    ) +
    scale_color_manual(
      values = c(
        "Standard_WP" = "purple",
        "Line_Adjusted_WP" = "red",
        "Kalshi" = "#0072B2"
      )
    ) +
    scale_shape_manual(
      values = c(
        "Standard_WP" = 15,
        "Line_Adjusted_WP" = 16,
        "Kalshi" = 17
      )
    ) +
    scale_y_continuous(
      limits = c(0, 1),
      labels = scales::percent_format(accuracy = 1)
    ) +
    labs(
      title = str_c( "In Game Win Probability Comparison - ",myTeam),
      #subtitle = "FastR Standard and Line Adjusted Models",
      subtitle = myMatchup,
      x = "Time",
      y = "Win Probability",
      color = "Source",
      shape = "Source"
    ) +
    theme_minimal(base_size = 13) +
    theme(
      plot.title = element_text(face = "bold"),
      plot.subtitle = element_text(color = "gray40"),
      legend.position = "bottom"
    )
  print (plot)
  
  if (Save == TRUE){
    SavePlotToFile(plot,"FastR Win Prob Compare")
  }
}

UpdateGamedb <- function (){
  
  # This function will update the SQL database with the current list of completed games
  
  
  Q <- "Select * from games"
  db_games <- RunSQL(Q)
  names (db_games)
  
  games <- nflreadr::load_schedules(
    seasons = 2025)
  
  names (games)
  
  game_summary <- games %>%
    select (game_id,game_type, gameday,weekday, home_team,  away_team, home_moneyline,away_moneyline, home_score, away_score ) %>%
    filter (!is.na(home_score))
  
  games_toload <- game_summary %>% anti_join (db_games,by = join_by(game_id))
  
  numgames <- nrow (games_toload)
  print (str_c ("Adding ",numgames, " game to database"))
  
  
  library(RODBC)
  
  sqlSave(
    channel   = connection,
    dat       = games_toload,
    tablename = "dbo.games",   # schema included here
    append    = TRUE,
    rownames  = FALSE,
    safer     = TRUE,
    fast      = TRUE
  )
  
  
  
}

PlotKalshiTeamProbs <- function (pbpsummary, mygame, Team = "Home", PlotLive = TRUE , myspan = .25, MA = TRUE){
  
  # This function will graph the win probabilities for yes contracts on an NFL 
  # team for a specific game
  
  
  Prices <- GetGamePrices1Min(mygame)  # Get trades for a specific game
  mygameid <- GetFastRGameID(mygame)
  
  parts <- str_split_fixed(mygameid, "_", 4)
  
  year        <- as.integer(parts[1])
  season_week <- as.integer(parts[2])
  away_team   <- parts[3]
  home_team   <- parts[4]
  
 
  
  if (Team == "Home"){
    select_team <- home_team
  } else {
    select_team <- away_team
  }
  
  
  teamcolor <- GetTeamColor(select_team)
  teamname <- GetTeamName(select_team)
  matchup <- GetMatchupName(mygame)
  
  # print (teamcolor)
  # scales::show_col(teamcolor)
  
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
  
  WinTrades <- WinTrades %>%
    select (trade_time_et, contract_team, vwap_yes_price)
  
  
  myTitle <- str_c("Kalshi Market Implied Probability for ", teamname)
  mySub <- matchup
  
  plot <- WinTrades %>%
    ggplot(aes(
      x = trade_time_et,
      y = vwap_yes_price
    )) +
    geom_line(linewidth = 1, color = teamcolor) +
    scale_y_continuous(
      limits = c(0, 100),
      labels = scales::percent_format(scale = 1)
    ) +
    labs(
      title = myTitle,
      subtitle = mySub,
      caption = "VWAP Yes Price (1-Minute Aggregation)",
      x = "Time (ET)",
      y = "Implied Probability (%)"
    ) +
    theme_minimal(base_size = 13) +
    theme(
      plot.title = element_text(face = "bold"),
      plot.subtitle = element_text(color = "gray40"),
      axis.title.y = element_text(margin = margin(r = 10)),
      axis.title.x = element_text(margin = margin(t = 10))
    )
  
  if (MA == TRUE){
    plot <- plot + geom_smooth(se=FALSE, span = myspan)

  }
  
  print(plot)
  return (plot)
}



GenGameBetVolAreaGraph <- function (GamePrices, pbp, bydollar = TRUE, Save = TRUE){
  
  # This function will generate an area graph that shows cummualtive
  # trade volume for a game, colored by pre and in game trades
  
  myGame <- Prices$game_id[1]
  

  myMatchup <- GetMatchupName (myGame, ticker=FALSE)
  
  myGameTimes <- GetGameTimes(pbpsummary) %>%
    select (game_id, game_start_utc)
  
  
  myPrices <- GamePrices %>% 
    left_join(myGameTimes, by = join_by(game_id))
  
  TradebyMin <- myPrices %>%
    group_by(trade_minute, game_start_utc)%>%
    summarize (DollarVol = sum (total_dollar_volume),
               ContractVol = sum (total_count),
               .groups = "drop_last")%>%
    ungroup()%>%
    mutate(
      CumDollarVol = cumsum(DollarVol),
      CumContractVol = cumsum(ContractVol),
      PreGameDollar  = if_else(trade_minute <= game_start_utc, DollarVol, 0),
      InGameDollar = if_else(trade_minute >= game_start_utc, DollarVol, 0),
      PreGameDollarCum  = if_else(trade_minute <= game_start_utc, CumDollarVol, 0),
      InGameDollarCum = if_else(trade_minute >= game_start_utc, CumDollarVol, 0),
      
      PreGameContract  = if_else(trade_minute <= game_start_utc, ContractVol, 0),
      InGameContract = if_else(trade_minute >= game_start_utc, ContractVol, 0),
      PreGameContractCum  = if_else(trade_minute <= game_start_utc, CumContractVol, 0),
      InGameContractCum = if_else(trade_minute >= game_start_utc, CumContractVol, 0)
    ) 
  
  if (bydollar == TRUE){
    TotalVol <- sum(TradebyMin$DollarVol)
    PreVol <- sum(TradebyMin$PreGameDollar, na.rm = TRUE)
    InVol <- sum(TradebyMin$InGameDollar, na.rm = TRUE)
    MilVol <- round(TotalVol / 10^6, 1)
    IGP <- round(InVol/ TotalVol,3)*100
    
    myCaption <- str_c("$",MilVol," Mil in total dollar volume, ", IGP, "% in game")
    myY <- "Cumulative Dollar Volume of Kalshi Transctions"
    myTitle <- "Cumulative Dollar Volume"    
    
    TradebyMin <- TradebyMin %>% 
      mutate (
        PreGameCum = PreGameDollarCum,
        InGameCum = InGameDollarCum)
    
  } else {
    TotalVol <- sum(TradebyMin$ContractVol)
    PreVol <- sum(TradebyMin$PreGameContract, na.rm = TRUE)
    InVol <- sum(TradebyMin$InGameContract, na.rm = TRUE)
    MilVol <- round(TotalVol / 10^6, 1)
    IGP <- round(InVol/ TotalVol,1)*100
    
    myCaption <- str_c(MilVol," Mil in total contract volume, ", IGP, "% in game")
    myY <- "Cumulative Count Volume of Kalshi Contracts"
    myTitle <-  "Cumulative Contract Volume" 
    
    TradebyMin <- TradebyMin %>% 
      mutate (
        PreGameCum = PreGameContractCum,
        InGameCum = InGameContractCum)
  }
  

  
  plot <- TradebyMin %>%
    arrange(trade_minute) %>%
    ggplot(aes(x = trade_minute)) +
    
    # Pre-game area
    geom_area(aes(y = PreGameCum), fill = "steelblue", alpha = 0.7)  +
    # Post-game area
    geom_area(aes(y = InGameCum), fill = "firebrick", alpha = 0.7) +
    
    # Game start vertical line
    geom_vline(
      aes(xintercept = game_start_utc),
      linetype = "dashed",
      linewidth = 1
    ) +
    
    labs(
      x = " ",
      y = myY,
      title = myTitle,
      subtitle = myMatchup,
      caption = myCaption
    ) +theme_minimal()
    
    
  
    if (bydollar == TRUE){
      plot <- plot + scale_y_continuous(labels = scales::dollar_format()) 
    } else {
      plot <- plot + scale_y_continuous(labels = scales::comma_format()) 
    }
    
  print (plot)
  if (Save == TRUE){
    SavePlotToFile(plot ,"CumVolTiming")
  }

  return (plot)
  
}

GetPerGameVol<- function(){
  
  
  # This function will retrieve a data frame with the overall volume 
  # of trades per game along with basic game data
  
  Q <- "SELECT
    game, SUM(total_dollar_volume) AS total_dollar_volume
    FROM dbo.kalshi_trades_1hr_vwap
    group by game;"
  
  Vol <- RunSQL (Q)
  
  Q <- "select * from gamemap"
  GameMap <- RunSQL (Q)
  
  Q <- "select * from games"
  Games <- RunSQL (Q)
  
  GameVol <- Vol %>%
    left_join(GameMap,by = join_by(game)) %>%
    left_join(Games,by = join_by(game_id)) 
  
  
} 

GetNFLGames <- function (season=2025){
  
  # This function will build a data frame of games with both the NFLFastr
  # and Kalshi IDs as well as full team names and a match up name
  
  fastrgames <- nflreadr::load_schedules(2025)
  
  teams <- nflfastR::teams_colors_logos %>%
    select (team_abbr, team_name, team_color)
  
  gm <- LoadSQLTable("gamemap")
  
  games <- gm %>%
    left_join(fastrgames, by = join_by(game_id)) %>%
    select (game, game_id, game_type, week, gameday, away_team, home_team)
  
  
  games_named <- games %>%
    left_join(
      teams %>%
        select(team_abbr, home_team_name = team_name, home_team_color = team_color),
      by = c("home_team" = "team_abbr")
    ) %>%
    left_join(
      teams %>%
        select(team_abbr, away_team_name = team_name,away_team_color = team_color),
      by = c("away_team" = "team_abbr")
    ) %>%
    mutate(
      matchup = str_c(away_team_name, " @ ", home_team_name)
    )
  return (games_named)
  
  
}

GetTeamColor <- function (team , selectcolor = 1, show = FALSE){
  
  # This function will get the color for the select team from the NFLFastR data
  
  teamcolors <- nflfastR::teams_colors_logos 
  
  teamcolor <- teamcolors %>%
    filter (team_abbr == team )%>%
    select(team_color, team_color2, team_color3, team_color4) %>%
    pull(var= selectcolor)
  
  if (show == TRUE){
    scales::show_col(teamcolor)
  }
  return (teamcolor)
}

GetTeamName <- function (team ){
  
  # This function will get the name for the select team from the NFLFastr data
  
  teamcolors <- nflfastR::teams_colors_logos 
  
  teamname <- teamcolors %>%
    filter (team_abbr == team )%>%
     pull(var= team_name)

  return (teamname)
}

GetMatchupName <- function (id, ticker=TRUE){
  
  # This function will get the matchup name for the specified game ID
  
  games <- GetNFLGames()
  
  
  if (ticker == TRUE){
    matchupname <- games %>%
      filter (game == id )%>%
      pull(var= matchup)
    
  } else{
    matchupname <- games %>%
      filter (game_id == id )%>%
      pull(var= matchup)
    
  }

  
  return (matchupname)

}


GetKalshiGameProbs <- function (Kgame = NA, pbpsummary, team = "Home", LiveOnly = TRUE){
  
  # This function will get the Kalshi prices/probabilities for a specific game
  #
  # If the game ID is NA it gets all games
  
  Prices <- GetGamePrices1Min(Kgame)  # Get trades for a specific game

  
  
  ## Address the discrepancy between JAC and JAX
  

  
  if (!is.na (Kgame)){
    
    FRgame <- GetFastRGameID(Kgame)
    
    parts <- str_split_fixed(FRgame, "_", 4)
    
    year        <- as.integer(parts[1])
    season_week <- as.integer(parts[2])
    away_team   <- parts[3]
    home_team   <- parts[4]
    
    
    if (away_team == 'JAX'){
      away_team <- 'JAC'
    }
    
    if (home_team == 'JAX'){
      home_team <- 'JAC'
    }
    
    if (team == "Home"){
      select_team <- home_team
    } else {
      select_team <- away_team
    }
    
    Prices <- Prices %>%
      filter (contract_team == select_team)
    
  }
  

  WinTrades <- Prices  %>%
    filter (taker_side == 'yes') %>%
    arrange (trade_minute) %>%
    mutate(
      cum_total_dollar_volume = cumsum(total_dollar_volume),
      
      # IMPORTANT: trade_minute is a UTC clock reading that is currently unlabeled
      trade_time_utc = force_tz(trade_minute, "UTC"),
      
      # now convert that instant to Eastern
      trade_time_et  = with_tz(trade_time_utc, "America/New_York")
    )
  
  if (LiveOnly == TRUE){
    Game_Times <-GetGameTimes(pbpsummary)
    WinTrades  <- WinTrades %>%
      left_join(Game_Times, by = join_by(game_id)) %>%
      filter (trade_minute >= game_start_utc) 
  }
  
  KalshiProb <- WinTrades %>%
    mutate (Kalshi_WP = vwap_yes_price/100)%>%
    mutate (source = 'Kalshi')%>%
    select (source, game_id, contract_team, trade_time_et,  Kalshi_WP) %>%
    rename (team = contract_team, date_time = trade_time_et, wp = Kalshi_WP) %>%
    arrange (date_time)
  
}

GetFastRGameProbs <- function (FRgame, pbpsummary, team = "Home", type = 'Vegas'){
  
  # This function will get all the NFLfastR probabilites for a game
  
  mypbp <- pbpsummary %>%
    filter (game_id == FRgame )
  
  if (team == "Home"){
    mypbp <- mypbp %>%
      mutate (
        WP = home_wp,
        VegasWP = vegas_home_wp,
        team = home_team
      )
    myTeam <- mypbp$home_team
  } else {
    mypbp <- mypbp %>%
      mutate (
        WP = away_wp,
        VegasWP = vegas_away_wp,
        team = away_team
      )
    myTeam <- mypbp$away_team
  }
  
  if (type == "Vegas"){
    
    FastRWP <- mypbp %>%
      mutate (source = "FastR Vegas") %>%
      select (source, game_id, team, play_time_et, VegasWP) %>%
      rename (date_time = play_time_et, wp = VegasWP)
    
  } else {
    
    FastRWP <- mypbp %>%
      mutate (source = "FastR") %>%
      select (source, game_id, team, play_time_et, WP) %>%
      rename (date_time = play_time_et, wp = WP)
    
  }
}


GetCombinedProbs <- function(FRgame, team = "Home", type = 'Vegas', LiveOnly = TRUE){
  
  
  # This function will merge Kalshi and NFLFastR win probabilities for a game.
  
  KGame <- GetKalshiGame( FRgame) # Get Kalshi ID
  pbps <- GetpbpSummary()
  
  FRProbs <- GetFastRGameProbs (FRgame, pbps, team , type )
  KalshiProbs <- GetKalshiGameProbs (KGame,pbps, team , LiveOnly )
  
  ProbCombo <- rbind (FRProbs,KalshiProbs )%>%
    arrange (date_time)
  
  
}


PlotGameProbs <- function (GameProbs){
  
  # This function will plot multiple probability series for a game
  
  myGameID <- GameProbs$game_id[1]
  myTeam <- GameProbs$team[1]
  myMatchup <- GetMatchupName (myGameID, ticker=FALSE)
  
  GameProbs %>%
    ggplot(aes(
      x = date_time,
      y = wp,
      color = source,
      shape = source,
      group = source
    )) +
    geom_line(
      linewidth = 0.7,
      alpha = 0.55
    ) +
    geom_point(
      size = 2.4,
      alpha = 0.85
    ) +
    scale_color_manual(
      values = c(
        "FastR" = "purple",
        "FastR Vegas" = "red",
        "Kalshi" = "#0072B2"
      )
    ) +
    scale_shape_manual(
      values = c(
        "FastR" = 15,
        "FastR Vegas" = 16,
        "Kalshi" = 17
      )
    ) +
    scale_y_continuous(
      limits = c(0, 1),
      labels = scales::percent_format(accuracy = 1)
    ) +
    labs(
      title = str_c( "In Game Win Probability Comparison - ",myTeam),
      #subtitle = "FastR Vegas model vs. Kalshi market-implied probability",
      subtitle = myMatchup,
      x = "Time",
      y = "Win Probability",
      color = "Source",
      shape = "Source"
    ) +
    theme_minimal(base_size = 13) +
    theme(
      plot.title = element_text(face = "bold"),
      plot.subtitle = element_text(color = "gray40"),
      legend.position = "bottom"
    )
}

GetGameWinners <- function (Year = 2025){
  
  # this function will biold a df of all games wth winners and lsoers
  myYear = 2025
  gamewinners <- nflreadr::load_schedules(myYear)%>%
    mutate (winner = case_when(home_score > away_score ~ home_team, home_score < away_score ~ away_team, TRUE ~ 'Tie')) %>%
    mutate (loser = case_when(home_score < away_score ~ home_team, home_score > away_score ~ away_team, TRUE ~ 'Tie')) %>%
    select (game_id, winner, loser)
  
  return (gamewinners)
  
}


