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

## ---- importing modules -----
library(readr)
library(dplyr)
library(ggplot2)

subs <- c('subTH','subAL','subJU',
          'subSA','subTI')

all_data <- list()

for (sub in subs) {
  
  df <- read_csv(paste0("D:/DFF_data/", sub, "/", sub, "_pupil.csv"))
  bf <- read_csv(paste0("D:/DFF_data/", sub, "/", sub, ".csv"))
  
  if (sum(df$text == "trial", na.rm = TRUE) != 380) {
    stop(paste("Expected 380 trials for", sub))
  }
  
  PSdf <- trigMean(
    df,
    start_text = "cue_",
    end_text   = "stim2_"
  )
  
  combined_df <- bind_cols(bf, PSdf)
  combined_df$subject <- sub
  
  all_data[[sub]] <- combined_df
}

# combine all subjects
combined_all <- bind_rows(all_data)







## ----------------- MS degree -------------

#---- error bar

ggplot(combined_all,
       aes(CueType, ms_deg, fill = CueType)) +
  geom_boxplot() +
  geom_hline(yintercept = 0,
             linetype = "dashed",
             color = "red") +
  theme_classic()



#---- polar histogram 

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
