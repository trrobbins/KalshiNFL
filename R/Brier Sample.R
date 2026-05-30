

setwd("C:/Users/Owner/Dropbox/ECU Misc/Active Working Papers/Prediction Markets/KalshiNFL/R")
source ("Kalshi Functions.R") 
source ("Accuracy Functions.R") 

############################################



pbpsummary <- GetpbpSummary()
FastRSet <- PrepFastRWinProbs(pbpsummary) 
TestSet <- FastRSet %>% filter (period == "Q1")

set.seed(123)
BrierSimFastR <- GetFastRBrierSamples(TestSet, 500, n_per_game = 1)


BrierSimFastR %>%
  group_by(score_type)%>%
  summarize (N=n(),
             Avg = mean(brier_score))

#PlotFastRBrierDbn(BrierSimFastR)


##################################




KalshiWinProbs <- PrepKalshiWinProbs(pbpsummary)
SubKalshiWinProbs <- KalshiWinProbs  %>% filter (period == "Q1")
BrierSimKalshi <- GetKalshiBrierSamples (SubKalshiWinProbs, n=500)



mySampleSize <- 10000
AllBrierSims <- GetCombinedSims (FastRSet, KalshiWinProbs, n=mySampleSize) %>% mutate(periods = "All")
Q1BrierSims <- GetCombinedSims (FastRSet, KalshiWinProbs, periods = c("Q1"), n=mySampleSize)
Q2BrierSims <- GetCombinedSims (FastRSet, KalshiWinProbs, periods = c("Q2"), n=mySampleSize)
Q3BrierSims <- GetCombinedSims (FastRSet, KalshiWinProbs, periods = c("Q3"), n=mySampleSize)
Q4BrierSims <- GetCombinedSims (FastRSet, KalshiWinProbs, periods = c("Q4"), n=mySampleSize)
OTBrierSims <- GetCombinedSims (FastRSet, KalshiWinProbs, periods = c("OT"), n=mySampleSize)




PlotBrierDbn(AllBrierSims)
PlotBrierDbn(AllBrierSims%>% filter (score_type != "Standard WP"))
PlotBrierDbn(Q1BrierSims %>% filter (score_type != "Standard WP"))
PlotBrierDbn(Q2BrierSims%>% filter (score_type != "Standard WP"))
PlotBrierDbn(Q3BrierSims%>% filter (score_type != "Standard WP"))
PlotBrierDbn(Q4BrierSims%>% filter (score_type != "Standard WP"))
PlotBrierDbn(OTBrierSims%>% filter (score_type != "Standard WP"))



MergeSims <- rbind (AllBrierSims, Q1BrierSims, Q2BrierSims, Q3BrierSims, Q4BrierSims, OTBrierSims)

SimComp <- MergeSims %>%
  group_by(periods, score_type) %>%
  summarize(mean = mean(brier_score), .groups = "drop") %>% # Cleaned up your grouping warning too!
  pivot_wider(names_from = score_type, values_from = mean) %>%
  mutate(
    # 1. Turn periods into a factor with your exact desired order
    periods = factor(periods, levels = c("All", "Q1", "Q2", "Q3", "Q4", "OT")),
    
    # 2. Keep your difference calculation
    Kalshi_Difference = `Line Adjusted WP` - Kalshi
  ) %>% 
  # 3. Physically sort the table rows by this new order
  arrange(periods)
SimComp


library(ggplot2)
library(tidyr)
library(dplyr)

# Filter out 'All' to keep the chronological sequence clean on the x-axis
plot_data_long <- SimComp %>%
  filter(periods != "All") %>%
  pivot_longer(cols = c(Kalshi, `Line Adjusted WP`), 
               names_to = "Metric", 
               values_to = "Brier_Score")

ggplot() +
  # 1. Draw the connecting gap lines
  geom_line(data = plot_data_long, 
            aes(x = periods, y = Brier_Score, group = periods), 
            color = "grey70", linewidth = 1.5) +
  # 2. Draw the absolute points
  geom_point(data = plot_data_long, 
             aes(x = periods, y = Brier_Score, color = Metric), 
             size = 4) +
  # 3. Clean up the look
  scale_color_manual(values = c("Kalshi" = "#E66101", "Line Adjusted WP" = "#5E3C99")) +
  labs(
    title = "Brier Score Comparison by Period",
    subtitle = "Lower scores indicate better predictive accuracy (Line Adjusted wins in Q3, Q4)",
    x = "Game Period",
    y = "Brier Score",
    color = "Model"
  ) +
  theme_minimal() +
  theme(legend.position = "top")

ggplot(filter(SimComp, periods != "All"), aes(x = periods, y = Kalshi_Difference, group = 1)) +
  # Reference line at 0 (where both models are equal)
  geom_hline(yintercept = 0, linetype = "dashed", color = "grey50") +
  # The difference path
  geom_line(color = "#5E3C99", linewidth = 1.2) +
  geom_point(color = "#5E3C99", size = 3) +
  labs(
    title = "Value Added by Line Adjustment",
    subtitle = "Values below 0 mean the Line Adjusted model outperformed Kalshi",
    x = "Game Period",
    y = "Brier Score Difference (Adjusted - Kalshi)"
  ) +
  theme_minimal() +
  # Shading the "win" zones can make this incredibly easy to read at a glance
  annotate("text", x = 1.5, y = 0.02, label = "Kalshi Better", color = "#E66101", fontface = "bold") +
  annotate("text", x = 1.5, y = -0.004, label = "Line Adjusted Better", color = "#5E3C99", fontface = "bold")


library(ggplot2)
library(tidyr)
library(dplyr)

# 1. Pivot the data to long format and filter out 'All'
plot_data_lines <- SimComp %>%
  filter(periods != "All") %>%
  pivot_longer(cols = c(Kalshi, `Line Adjusted WP`), 
               names_to = "Model", 
               values_to = "Brier_Score")

# 2. Build the plot
ggplot(plot_data_lines, aes(x = periods, y = Brier_Score, color = Model, group = Model)) +
  # Draw the lines connecting the periods
  geom_line(linewidth = 1.2) +
  # Add points to emphasize the actual data values
  geom_point(size = 3) +
  # Custom corporate-friendly colors
  scale_color_manual(values = c("Kalshi" = "#E66101", "Line Adjusted WP" = "#5E3C99")) +
  labs(
    title = "Brier Score Trajectory by Game Period",
    subtitle = "Lower scores indicate better predictive accuracy",
    x = "Game Period",
    y = "Brier Score",
    color = "Model"
  ) +
  theme_minimal() +
  theme(
    legend.position = "top",
    panel.grid.minor = element_blank() # Cleans up background clutter
  )

ggplot(plot_data_lines, aes(x = periods, y = Brier_Score, color = Model)) +
  # position_dodge keeps the points from sitting directly on top of each other
  geom_point(size = 4, position = position_dodge(width = 0.4)) +
  scale_color_manual(values = c("Kalshi" = "#E66101", "Line Adjusted WP" = "#5E3C99")) +
  labs(
    title = "Brier Score Comparison by Game Period",
    subtitle = "Lower scores indicate better predictive accuracy (Discrete segments)",
    x = "Game Period",
    y = "Brier Score",
    color = "Model"
  ) +
  theme_minimal() +
  theme(
    legend.position = "top",
    panel.grid.minor = element_blank()
  )


ggplot(plot_data_lines, aes(x = periods, y = Brier_Score, fill = Model)) +
  # stat = "identity" uses the actual data values; position = "dodge" puts them side-by-side
  geom_bar(stat = "identity", position = position_dodge(width = 0.7), width = 0.6) +
  scale_fill_manual(values = c("Kalshi" = "#E66101", "Line Adjusted WP" = "#5E3C99")) +
  labs(
    title = "Brier Score Comparison by Game Period",
    subtitle = "Lower bars indicate better predictive accuracy",
    x = "Game Period",
    y = "Brier Score",
    fill = "Model"
  ) +
  theme_minimal() +
  theme(
    legend.position = "top",
    panel.grid.minor = element_blank()
  )
# BadPredictions <- KalshiProbs %>%
#   filter (result == 1,
#           Kalshi_Prob < .1) %>%
#   select (game_id) %>% 
#   distinct()

#AllBrierSims <- GetCombinedSims (FastRSet, KalshiWinProbs,  n=25000, n_per_game = 1, periods = "Q1")
PlotBrierDbn(AllBrierSims)

AllBrierSims %>%
  group_by(score_type)%>%
  summarize (N=n(),
             Avg = mean(brier_score),
             Median = median (brier_score),
             SD = sd(brier_score),
             Skew =skewness(brier_score))



AllBrierSims %>%
  filter (score_type %in% c('Line Adjusted WP', "Standard WP")) %>%
  PlotBrierDbn()


AllBrierSims %>%
  filter (score_type %in% c('Line Adjusted WP', "Kalshi")) %>%
  PlotBrierDbn()




binned_sample <- KalshiWinProbs %>%
  group_by(game_id) %>%
  slice_sample(n = 10) %>%
  ungroup() %>%
  mutate(ProbBin = ntile(Kalshi_Prob, 20))%>%
  group_by(ProbBin) %>%
  summarize (n= n(),
             FWP = mean (Kalshi_Prob),
             ActualWP = mean (result))%>%
  mutate (Error = (FWP-ActualWP),
          SE = (FWP-ActualWP)^2)

bin_score <- binned_sample %>%
  mutate (bin =str_c ("Bin ", ProbBin))%>%
  select (bin, Error) %>% 
  pivot_wider (names_from = bin, values_from = Error)

WP_sample %>%
  ggplot(aes(x = FWP, y = ActualWP)) +
  geom_abline(
    intercept = 0,
    slope = 1,
    linetype = "dashed",
    color = "gray50",
    linewidth = 0.8
  ) +
  geom_point(size = 3, color = "steelblue") +
  #geom_line(color = "steelblue", linewidth = 0.8) +
  scale_x_continuous(
    labels = percent_format(accuracy = 1),
    limits = c(0, 1)
  ) +
  scale_y_continuous(
    labels = percent_format(accuracy = 1),
    limits = c(0, 1)
  ) +
  labs(
    title = "Calibration Plot: Forecasted vs. Actual Win Probability",
    subtitle = "Ventiles based on forecasted win probability",
    x = "Forecasted Win Probability",
    y = "Actual Win Probability",
    caption = "Dashed line indicates perfect calibration"
  ) +
  theme_minimal(base_size = 13) +
  theme(
    plot.title = element_text(face = "bold"),
    panel.grid.minor = element_blank()
  )


#######################

AllBrierSims %>%
  group_by(score_type) %>%
  summarize (
    n=n(),
    min = min (brier_score),
    mean = mean (brier_score),
    max = max (brier_score),
    sd = sd (brier_score)
  )


# Stat Testing 
library(infer)

# 1. Fit the linear model / ANOVA
anova_model <- aov(brier_score ~ score_type, data = AllBrierSims)

# 2. View the overall ANOVA table
summary(anova_model)

# 3. Run the post-hoc pairwise Tukey HSD test
tukey_results <- TukeyHSD(anova_model)

# 4. View the pairwise comparisons (p-values, estimates, and confidence intervals)
print(tukey_results)



# calculate the observed statistic
observed_f_statistic <- AllBrierSims %>%
  specify(brier_score ~ score_type) %>%
  hypothesize(null = "independence") %>%
  calculate(stat = "F")

observed_f_statistic


# generate the null distribution using randomization
null_dist <- AllBrierSims %>%
  specify(brier_score ~ score_type) %>%
  hypothesize(null = "independence") %>%
  generate(reps = 1000, type = "permute") %>%   # Testing for independence - use permute
  calculate(stat = "F")  # The statistic for this type of test is an F stat.  Still need to know that

mean (null_dist$stat)

null_dist %>%
  visualize() + 
  shade_p_value(observed_f_statistic,
                direction = "greater")

#########################

# Compare Kalshi and Line Adjusted

KLATest <- AllBrierSims %>%
  filter (score_type != 'Standard WP') %>%
  ungroup()

# Traditional Welch's Two-Sample t-test
parametric_t <- t.test(brier_score ~ score_type, data = KLATest)

# View the test statistic, degrees of freedom, and p-value
print(parametric_t)

KLATest %>%
  group_by(score_type) %>%
  summarize(
    n = n(),
    mean = mean(brier_score),
    sd = sd(brier_score),
    se = sd / sqrt(n),
    .groups = "drop"
  )




# calculate the observed statistic - the difference in means between the 2 groups
observed_statistic <- KLATest %>%
  specify(brier_score ~ score_type) %>%
  calculate(stat = "diff in means",order = c("Kalshi", "Line Adjusted WP"))

observed_statistic


# generate the null distribution with randomization
null_dist_2_sample <- KLATest %>%    
  specify(brier_score ~ score_type) %>%
  hypothesize(null = "independence") %>%  # independence assumes the category variable makes no difference
  generate(reps = 1000, type = "permute") %>%  # With a two sample test we us permute
  calculate(stat = "diff in means", order =c("Kalshi", "Line Adjusted WP"))

mean (null_dist_2_sample$stat)  # Permute randomizes the category as if null is true

# visualize the randomization-based null distribution and test statistic!
null_dist_2_sample %>%
  visualize() + 
  shade_p_value(observed_statistic,
                direction = "two-sided")

# calculate the p value from the randomization-based null 
# distribution and the observed statistic
p_value_2_sample <- null_dist_2_sample %>%
  get_p_value(obs_stat = observed_statistic,
              direction = "two-sided")

p_value_2_sample

