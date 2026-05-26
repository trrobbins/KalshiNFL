

# This script will retrieve the NFL schedule along with results to date
library(nflfastR)


#  https://www.nflfastr.com/articles/beginners_guide.html
#  https://nflreadr.nflverse.com/reference/index.html



Games <- nflreadr::load_schedules(2025)

Teams <- nflfastR::teams_colors_logos

Sched <- Games  %>%
  select (-div_game, -roof, -surface, - temp, - wind, -away_qb_id, -home_qb_id, -away_qb_name, -home_qb_name, -away_coach , -home_coach, -referee,
          -stadium_id, -stadium, -old_game_id, -espn, -gsis,-location, - nfl_detail_id, -pfr, -pff,
          -away_rest, -home_rest, -ftn)

CompletedGames <- Sched %>%
  filter (!is.na(home_score))

CompleteSummary <- CompletedGames %>%
  select (game_id, gameday, gametime, game_type, result, home_team, away_team, home_score, away_score, home_moneyline, away_moneyline)


names(CompleteSummary)


TeamSummary <- CompleteSummary %>%
  pivot_longer(
    cols = c(home_team, away_team,
             home_score, away_score,
             home_moneyline, away_moneyline),
    names_to = c("side", ".value"),
    names_pattern = "(home|away)_(.*)"
  ) %>%
  mutate(
    Outcome = case_when(
      side == "home" & result > 0  ~ "Win",
      side == "home" & result < 0  ~ "Loss",
      side == "home" & result == 0 ~ "Tie",
      side == "away" & result < 0  ~ "Win",
      side == "away" & result > 0  ~ "Loss",
      side == "away" & result == 0 ~ "Tie"
    )
  ) %>%
  select(-result)

write.table(TeamSummary, row.names =   FALSE, "NFLGameSummary.csv", sep=",")

Uniqueteams <- TeamSummary %>%
  select (team) %>%
  distinct()


write.table(Uniqueteams, row.names =   FALSE, "Teams.csv", sep=",")

