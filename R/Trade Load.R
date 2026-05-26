
setwd("C:/Users/Owner/Dropbox/ECU Misc/Active Working Papers/Prediction Markets")
source ("Kalshi Functions.R") 


UseSQLdb()
UploadTradeFiles()  # Load any files down loaded from Kalshi but not yet stored in the db


UpdateGamedb()  #update the SQL database with the current list of completed games





###################################

pbp <- GetpbpSummary()




###############
# Build Mapping

games <- nflreadr::load_schedules(
  seasons = 2025)


tradepre <- 'KXNFLGAME-'


#   Problem with games after Jan 1   Season 25 but year 26.  Kalshi ticker is 26

gamemap <- games %>%
  mutate (
    away_team = str_replace(away_team, "JAX", "JAC"),
    home_team = str_replace(home_team, "JAX", "JAC"),
    year = as.character(season -2000),  
    year2 = year(gameday)-2000,
    game_date = as.Date(gameday),
    month_3 = toupper(month(game_date, label = TRUE, abbr = TRUE)),
    day_num   = format(game_date, "%d"),   # <- "04", "21", etc (character)
    game = str_c(tradepre, year2,month_3,day_num,away_team,  home_team)
    ) %>%
  select ( game, game_id) 

# Save the data frame as a CSV file
file_path <- "gamemap.csv"
write.csv(gamemap, file_path, row.names = FALSE)


Q <- "SELECT Distinct game
  FROM kalshi_trades "


QR <- RunSQL(Q)%>%
  mutate (Len =str_length(game)) 
  


head (QR)
head (gamemap)


match <- QR %>%
  left_join(gamemap, by = join_by(game) )

head(match)

NoMatch <- match %>%
  filter(is.na(game_id)) %>%
  mutate (Len =str_length(game))


##################################



################################
pbpsummary <- GetpbpSummary()




  
