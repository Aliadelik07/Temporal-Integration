
# ------------------- trigMean function-------------------
trigMean <- function(df, start_text, end_text) {
  
  start_idx <- which(grepl(start_text, df$text))
  end_idx <- which(grepl(end_text, df$text))
  
  
  df$direction_deg <- (df$direction_deg + 360) %% 360
  
  out <- lapply(start_idx, function(s) {
    
    e <- end_idx[end_idx > s][1]
    
    if (is.na(e)) return(NULL)
    
    rows <- s:e
    
    psc_vals <- df$psc[rows]
    
    # Min-max normalize PSC within this segment
    psc_norm <- if (length(na.omit(psc_vals)) > 1 &&
                    diff(range(psc_vals, na.rm = TRUE)) > 0) {
      (psc_vals - min(psc_vals, na.rm = TRUE)) /
        (max(psc_vals, na.rm = TRUE) - min(psc_vals, na.rm = TRUE))
    } else {
      rep(NA_real_, length(psc_vals))
    }
    
    data.frame(
      start_row = s,
      end_row   = e,
      ps_mean   = mean(psc_norm, na.rm = TRUE),
      ms_mean   = mean(df$ms[rows], na.rm = TRUE),
      ms_deg = mean(
        df$direction_deg[rows][df$ms[rows] == 1] -
          mean(df$direction_deg, na.rm = TRUE),
        na.rm = TRUE
      )
    )
  })
  
  do.call(rbind, out)
}


# ------------------ EPR function-------------------
EPR <- function(
    df,
    stim_text,
    sample_rate,
    pre_ms = 500,
    post_ms = 2000,
    baseline_correct = TRUE,
    conf_level = 0.95
) {
  
  pattern <- gsub("\\*", ".*", stim_text)
  stim_idx <- which(grepl(pattern, df$text))
  
  pre_samples  <- round(pre_ms / 1000 * sample_rate)
  post_samples <- round(post_ms / 1000 * sample_rate)
  
  window_length <- pre_samples + post_samples + 1
  
  trial_matrix <- matrix(
    NA_real_,
    nrow = length(stim_idx),
    ncol = window_length
  )
  
  valid_trial <- 0
  
  for (i in seq_along(stim_idx)) {
    
    s <- stim_idx[i]
    
    start_row <- s - pre_samples
    end_row   <- s + post_samples
    
    if (start_row < 1 || end_row > nrow(df))
      next
    
    trace <- df$psc[start_row:end_row]
    
    if (baseline_correct && pre_samples > 0) {
      baseline <- mean(trace[1:pre_samples], na.rm = TRUE)
      trace <- trace - baseline
    }
    
    valid_trial <- valid_trial + 1
    trial_matrix[valid_trial, ] <- trace
  }
  
  trial_matrix <- trial_matrix[1:valid_trial, , drop = FALSE]
  
  # Mean trace
  mean_trace <- colMeans(trial_matrix, na.rm = TRUE)
  
  # Number of observations at each time point
  n_tp <- colSums(!is.na(trial_matrix))
  
  # Standard error
  se_trace <- apply(trial_matrix, 2, sd, na.rm = TRUE) / sqrt(n_tp)
  
  # t critical value
  alpha <- 1 - conf_level
  t_crit <- qt(1 - alpha / 2, df = pmax(n_tp - 1, 1))
  
  # Confidence intervals
  ci_lower <- mean_trace - t_crit * se_trace
  ci_upper <- mean_trace + t_crit * se_trace
  
  time_ms <- seq(
    from = -pre_ms,
    to = post_ms,
    length.out = window_length
  )
  
  list(
    summary = data.frame(
      time_ms = time_ms,
      mean = mean_trace,
      se = se_trace,
      ci_lower = ci_lower,
      ci_upper = ci_upper,
      n = n_tp
    ),
    trial_traces = trial_matrix
  )
}




## ---- importing modules -----
library(readr)
library(dplyr)
library(ggplot2)

subs <- c('subTH','subAL','subJU',
          'subSA','subTI','subJA')

all_data <- list()

for (sub in subs) {
  
  df <- read_csv(paste0("D:/DFF_data/", sub, "/", sub, "_pupil.csv"))
  bf <- read_csv(paste0("D:/DFF_data/", sub, "/", sub, ".csv"))
  
  if (sum(df$text == "trial", na.rm = TRUE) != 380) {
    stop(paste("Expected 380 trials for", sub))
  }
  
  df$psc <- as.numeric(scale(df$psc))
  
  PSdf <- trigMean(
    df,
    start_text = "cue_",
    end_text   = "stim2_"
  )
  
  EPRdf <- EPR(
    df = df,
    stim_text = "cue_",
    sample_rate = 500,
    pre_ms = 500,
    post_ms = 3000
  )
  
  
  combined_df <- bind_cols(bf, PSdf)
  combined_df$subject <- sub
  
  all_data[[sub]] <- combined_df
}

# combine all subjects
combined_all <- bind_rows(all_data)



## ----------------- MS degree -------------

#error bar

ggplot(combined_all,
       aes(CueType, ms_deg, fill = CueType)) +
  geom_boxplot() +
  geom_hline(yintercept = 0,
             linetype = "dashed",
             color = "red") +
  theme_classic()



#polar histogram 

neutral_mean <- mean(
  combined_all$ms_deg[combined_all$CueType == "neutral"],
  na.rm = TRUE
)

plot_df <- combined_all %>%
  filter(CueType != "neutral") %>%
  mutate(
    diff_neutral = ms_deg - neutral_mean
  )

ggplot(plot_df,
       aes(x = diff_neutral,
           fill = CueType)) +
  geom_histogram(
    binwidth = 10,
    alpha = 0.5,
    position = "identity",
    color = "black"
  ) +
  scale_fill_manual(
    values = c(
      left = "red",
      right = "blue"
    )
  ) +
  coord_polar(start = pi) +
  scale_x_continuous(
    limits = c(-180, 180),
    breaks = c(-90, 90)
  ) +
  theme_minimal() +
  theme(
    legend.position = "top",
    axis.title.y = element_blank(),
    axis.text.y = element_blank(),
    axis.ticks.y = element_blank(),
    panel.grid.major.y = element_blank(),
    panel.grid.minor = element_blank()
  ) +
  labs(
    x = "",
    title = "Microsaccade Difference to Neutral (°)",
    fill = ""
  )
## ----------------- PS model --------------
library(lme4)
library(lmerTest)
library(ggeffects)

combined_all$RespFlash2 <- factor(
  combined_all$RespFlash,
  levels = c("one", "two")
)

m <- glmer(
  RespFlash2 ~ ps_mean * ISIframes * CueValidity +
    Trial +
    (1 | subject),
  data = combined_all,
  family = binomial
)

summary(m)
pred <- ggpredict(m, terms = c("ps_mean [all]", "ISIframes"))
plot(pred)

combined_all$RespProbeBinary <- ifelse(combined_all$probe == combined_all$ResProbe, 1, 0)
combined_all$dtcolor <- round(1 - (combined_all$dtcolor / 255), 1)

m <- glmer(
  RespProbeBinary ~ ps_mean * dtcolor * CueValidity +
    Trial +
    (1 | subject),
  data = combined_all,
  family = binomial
)

summary(m)
pred <- ggpredict(m, terms = c("ps_mean [all]", "dtcolor"))
plot(pred)



m <- lmer(
  RT ~ ps_mean * ISIframes * dtcolor * CueValidity +
    Trial +
    (1 | subject),
  data = combined_all,
  control = lmerControl(autoscale = TRUE)
)

summary(m)

pred <- ggpredict(m, terms = c("ps_mean [all]", "CueValidity"))
plot(pred)



# ---------------------- Evoked Response -------------


# choose contrast !
patterns <- c(
  valid_one   = "stim1_valid_*_one_*",
  invalid_one = "stim1_invalid_*_one_*",
  neutral_one = "stim1_neutral_*_one_*",
  valid_two   = "stim1_valid_*_two_*",
  invalid_two = "stim1_invalid_*_two_*",
  neutral_two = "stim1_neutral_*_two_*"
)

patterns <- c(
  zero_one   = "stim1_*_0_*_one_*",
  three_one = "stim1_*_5_*_one_*",
  nine_one = "stim1_*_9_*_one_*",
  three_two = "stim1_*_5_*_two_*",
  nine_two = "stim1_*_9_*_two_*"
)


all_data <- list()
for (sub in subs) {
  
  df <- read_csv(
    paste0("D:/DFF_data/", sub, "/", sub, "_pupil.csv")
  )
  
  df$psc <- as.numeric(scale(df$psc))
  
  eprs <- lapply(names(patterns), function(cond) {
    
    epr <- EPR(
      df = df,
      stim_text = patterns[[cond]],
      sample_rate = 500,
      pre_ms = 100,
      post_ms = 100
    )
    
    epr$summary$condition <- cond
    epr$summary
    
  })
  
  sub_data <- bind_rows(eprs)
  
  sub_data$subject <- sub
  
  all_data[[sub]] <- sub_data
}

all_data <- bind_rows(all_data)

all_data <- all_data %>%
  rename(subject_mean = mean)

group_summary <- all_data %>%
  group_by(condition, time_ms) %>%
  summarise(
    mean = mean(subject_mean, na.rm = TRUE),
    sd = sd(subject_mean, na.rm = TRUE),
    n = sum(!is.na(subject_mean)),
    .groups = "drop"
  ) %>%
  mutate(
    se = sd / sqrt(n),
    ci_lower = mean - qt(0.975, n - 1) * se,
    ci_upper = mean + qt(0.975, n - 1) * se
  )

group_summary <- group_summary %>%
  mutate(
    level = case_when(
      grepl("^zero_", condition)  ~ "0 ms",
      grepl("^three_", condition) ~ "35 ms",
      grepl("^nine_", condition)  ~ "63 ms"
    ),
    load = case_when(
      grepl("_one$", condition) ~ "one",
      grepl("_two$", condition) ~ "two"
    )
  )

ggplot(
  group_summary,
  aes(
    time_ms,
    mean,
    colour = load,
    fill = load
  )
) +
  geom_ribbon(
    aes(
      ymin = ci_lower,
      ymax = ci_upper
    ),
    alpha = 0.2,
    colour = NA
  ) +
  geom_line(linewidth = 1.2) +
  geom_vline(
    xintercept = 0,
    linetype = "dashed",
    colour = "black"
  ) +
  facet_wrap(
    ~ level,
    ncol = 1
  ) +
  labs(
    x = "Time from stimulus (ms)",
    y = "Baseline-corrected pupil size",
    title = "Grand Average Evoked Pupil Response",
    colour = "# Flashes Percieved",
    fill = "# Flashes Percieved"
  ) 

