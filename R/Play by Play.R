

# Play by play win probs



library(nflfastR)

myYear <- 2025

pbp <- nflreadr::load_pbp(myYear)
pbpnames <-as.data.frame( names(pbp))



games <- nflreadr::load_schedules(myYear)
gamenames <-as.data.frame( names(games))


gamedf <- games %>%
  select (game_id, game_type, gameday, weekday, home_team, away_team, home_moneyline, away_moneyline,
          home_score, away_score)

CompleteGames <- gamedf %>%
  filter (!is.na(home_score))

write.table(CompleteGames,row.names =   FALSE, col.names =   TRUE,"CompleteGames.CSV", sep=",")


pbpwinprob <- pbp %>%
  select (game_id, play_id, time_of_day, 
          game_seconds_remaining, down, ydstogo, epa, wp, home_wp, away_wp, vegas_wp,	
          vegas_home_wp)%>%
  mutate(
    time_of_day_clean = str_replace(time_of_day, "\\.\\d+Z$", "Z"),
    time_of_day_dt = ymd_hms(time_of_day_clean, tz = "UTC")
  )%>%
  select (-time_of_day_clean)


str(pbpwinprob)
head (pbpwinprob)

starttime <- pbpwinprob %>%
  group_by(game_id)%>%
  filter (!is.na(time_of_day_dt))%>%
  summarize (
    start_time = min (time_of_day_dt)
  )


pbpdata <- gamedf %>%
  right_join(pbpwinprob,by = join_by(game_id))%>%
  left_join(starttime,by = join_by(game_id)) %>%
  filter (!is.na(time_of_day_dt))


###############

# Team Info
data("teams_colors_logos")
nflfastRTeam <- teams_colors_logos %>%
    select (team_abbr,team_name, team_nick,team_conf, team_division)

write.table(nflfastRTeam,row.names =   FALSE, col.names =   TRUE,"nflfastRTeam.CSV", sep=",")
