


PrepFastRWinProbs <- function (pbpsummary){
  
  # This function prepares a long dataframe of win probabilities and results from the FastR data.  
  
  pbpsummary <- GetpbpSummary()  
  gametimes <- GetGameTimes(pbpsummary)
  gamewinners <-GetGameWinners()
  
  WinProbLong <- pbpsummary %>%
    select (game_id, home_team, home_wp, away_team, away_wp, vegas_home_wp, vegas_away_wp, play_time_et) %>%
    rename(
      home_team_name = home_team,
      away_team_name = away_team,
      home_vegas_wp = vegas_home_wp,
      away_vegas_wp = vegas_away_wp
    ) %>%
    pivot_longer(
      cols = c(home_team_name, away_team_name, home_wp, away_wp, home_vegas_wp, away_vegas_wp),
      names_to = c("side", ".value"),
      names_pattern = "(home|away)_(.*)"
    ) %>%
    rename(
      team = team_name
    ) %>%
    select(game_id, team, wp, vegas_wp, play_time_et)%>%
    left_join(gamewinners, by = join_by(game_id)) %>%
    filter (winner != "Tie") %>%
    mutate (result = case_when( team == winner ~ 1, TRUE ~ 0))%>%
    left_join(gametimes,by = join_by(game_id)) %>%
    select(-ends_with("_utc")) %>%
    mutate(
      period = case_when(
        play_time_et < game_start_et ~ "PreGame",
        play_time_et >= game_start_et & play_time_et < q1_end_et ~ "Q1",
        play_time_et >= q1_end_et & play_time_et < q2_end_et ~ "Q2",
        play_time_et >= q2_end_et & play_time_et < q3_end_et ~ "Q3",
        play_time_et >= q3_end_et & play_time_et < q4_end_et ~ "Q4",
        ot == 1 & play_time_et >= q4_end_et & play_time_et <= game_end_et ~ "OT",
        play_time_et >= game_end_et ~ "PostGame",
        TRUE ~ NA_character_
      )
    ) %>%
    filter (!is.na (period))%>%
    filter (period != "PostGame")%>%
    select(game_id, team, wp, vegas_wp, play_time_et, period, result, period)
  
}




GetFRSampleBrierScore <- function (WinProbLong, n_per_game =1){
  
  # This function will sample from the set of FastR win probabilities 
  # and calculate a Brier score.  
  
  WP_sample <- WinProbLong %>%
    group_by(game_id) %>%
    slice_sample(n = n_per_game) %>%
    ungroup() 
  
  BrierScores <- WP_sample %>%
    summarize(
      brier_wp = mean((wp - result)^2, na.rm = TRUE),
      brier_vegas_wp = mean((vegas_wp - result)^2, na.rm = TRUE)
    )
  
  
}


GetFastRBrierSamples <- function ( FastRProbs, n = 1000, n_per_game =1){
  
  # This function will get multiple samples of Brier scores
  
  BrierSim <- map_dfr(
    1:n,
    ~ GetFRSampleBrierScore(FastRProbs, n_per_game),
    .id = "iteration"
  ) %>%
    mutate(
      iteration = as.integer(iteration)
    )
  
  BrierSimLong <- BrierSim %>%
    pivot_longer(
      cols = c(brier_wp, brier_vegas_wp),
      names_to = "score_type",
      values_to = "brier_score"
    ) %>%
    mutate(
      score_type = recode(
        score_type,
        brier_wp = "Standard WP",
        brier_vegas_wp = "Line Adjusted WP"
      )
    )
  
  return (BrierSimLong)
  
}


PlotBrierDbn <- function (BrierSim){
  
   # this function will generate a comparative density plot of the Brier score distributions
  
  
  
  BrierMeans <- BrierSim %>%
    group_by(score_type) %>%
    summarize(
      mean_brier = mean(brier_score, na.rm = TRUE),
      .groups = "drop"
    )
  
  mean_caption <- BrierMeans %>%
    mutate(
      mean_text = str_c(score_type, ": ", number(mean_brier, accuracy = 0.0001))
    ) %>%
    pull(mean_text) %>%
    str_c(collapse = " | ")
  
  BrierSim %>%
    ggplot(aes(
      x = brier_score,
      fill = score_type,
      color = score_type
    )) +
    geom_density(alpha = 0.35, linewidth = 1) +
    geom_vline(
      data = BrierMeans,
      aes(xintercept = mean_brier, color = score_type),
      linetype = "dashed",
      linewidth = 0.9
    ) +
    labs(
      title = "Distribution of Brier Scores Across Simulations",
      subtitle = "Dashed vertical lines show mean Brier score for each model",
      x = "Brier Score",
      y = "Density",
      fill = "Model",
      color = "Model",
      caption = str_c("Mean Brier scores: ", mean_caption)
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(face = "bold"),
      plot.caption = element_text(hjust = 0)
    )
  
  # BrierBenchmarks <- BrierSimLong %>%
  #   summarize(
  #     brier_coinflip = mean((0.50 - result)^2, na.rm = TRUE),
  #     brier_wp = mean((wp - result)^2, na.rm = TRUE),
  #     brier_vegas_wp = mean((vegas_wp - result)^2, na.rm = TRUE)
  #   ) %>%
  #   mutate(
  #     skill_wp = 1 - brier_wp / brier_coinflip,
  #     skill_vegas_wp = 1 - brier_vegas_wp / brier_coinflip
  #   )
  
}



PrepKalshiWinProbs <- function (pbpsummary) {
  
  
  KGP <- GetKalshiGameProbs(pbpsummary= pbpsummary)
  gamewinners <- GetGameWinners()
  gametimes <- GetGameTimes(pbpsummary)
  
  KalshiProbs <- KGP %>%
    mutate (team = case_when(team == 'JAC' ~ 'JAX', TRUE ~ team)) %>%
    left_join(gamewinners, by = join_by(game_id)) %>%
    left_join(gametimes, by = join_by(game_id)) %>%
    select(-ends_with("_utc")) %>%
    mutate (result = case_when( team == winner ~ 1, TRUE ~ 0)) %>%
    rename (Kalshi_Prob = wp) %>%
    filter (winner != "Tie")  %>%
    mutate(
      period = case_when(
        date_time < game_start_et ~ "PreGame",
        date_time >= game_start_et & date_time < q1_end_et ~ "Q1",
        date_time >= q1_end_et & date_time < q2_end_et ~ "Q2",
        date_time >= q2_end_et & date_time < q3_end_et ~ "Q3",
        date_time >= q3_end_et & date_time < q4_end_et ~ "Q4",
        ot == 1 & date_time >= q4_end_et & date_time <= game_end_et ~ "OT",
        date_time >= game_end_et ~ "PostGame",
        TRUE ~ NA_character_
      )
    ) %>%
    select(-ends_with("end_et"), -game_start_et) %>%
    filter (!is.na (period))
  
  
  
}




GetKalshiSampleBrierScores <- function (KalshiProbs, n_per_game =1){
  
  WP_sample <- KalshiProbs %>%
    group_by(game_id) %>%
    slice_sample(n = n_per_game) %>%
    ungroup() 
  
  BrierScores <- WP_sample %>%
    summarize(
      brier_wp = mean((Kalshi_Prob - result)^2, na.rm = TRUE)
    )
  
  
}

GetKalshiBrierSamples <- function ( KalshiProbs, n = 1000, n_per_game =1){
  
  KalshiBrierSim <- map_dfr(
    1:n,
    ~ GetKalshiSampleBrierScores(KalshiProbs),
    .id = "iteration"
  ) %>%
    mutate(
      iteration = as.integer(iteration)
    )
  
  
  BrierSimLong <- KalshiBrierSim %>%
    mutate (score_type = 'Kalshi') %>%
    rename (brier_score = brier_wp)%>%
    select (iteration, score_type, brier_score) 
  
  return (BrierSimLong)
  
}
