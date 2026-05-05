

## ---- importing modules -----
library(dplyr)
library(ggplot2)
library(plotly)
library(gridExtra)


plot_glm_surface <- function(data, x_var, y_var, z_var, group_var,
                             family = NULL) {
  
  # auto-detect family if not provided
  if (is.null(family)) {
    if (length(unique(na.omit(data[[z_var]]))) == 2) {
      family <- quasibinomial()
      message("Detected binary outcome → using quasibinomial")
    } else {
      family <- gaussian()
      message("Detected continuous outcome → using gaussian")
    }
  }
  
  # build formula
  formula_str <- paste(z_var, "~", x_var, "*", y_var, "*", group_var)
  
  model <- glm(
    as.formula(formula_str),
    family = family,
    data = data
  )
  
  # grid
  grid <- expand.grid(
    x_seq = seq(min(data[[x_var]], na.rm = TRUE),
                max(data[[x_var]], na.rm = TRUE),
                length.out = 50),
    y_seq = seq(min(data[[y_var]], na.rm = TRUE),
                max(data[[y_var]], na.rm = TRUE),
                length.out = 50),
    group = unique(data[[group_var]])
  )
  
  names(grid) <- c(x_var, y_var, group_var)
  
  # predictions
  if (family$family %in% c("binomial", "quasibinomial")) {
    grid$z_pred <- predict(model, newdata = grid, type = "response")
  } else {
    grid$z_pred <- predict(model, newdata = grid, type = "response")
  }
  
  # plot
  p <- plot_ly()
  groups <- unique(grid[[group_var]])
  
  for (g_val in groups) {
    
    g <- subset(grid, grid[[group_var]] == g_val)
    
    color <- switch(as.character(g_val),
                    "invalid" = "red",
                    "valid" = "blue",
                    "neutral" = "black",
                    "gray")
    
    p <- add_surface(
      p,
      x = unique(g[[x_var]]),
      y = unique(g[[y_var]]),
      z = matrix(g$z_pred, 50, 50),
      colorscale = list(c(0, color), c(1, color)),
      showscale = FALSE,
      opacity = 0.5,
      showlegend = FALSE
    )
    
    # legend marker
    p <- add_trace(
      p,
      x = min(grid[[x_var]]),
      y = min(grid[[y_var]]),
      z = min(grid$z_pred),
      type = "scatter3d",
      mode = "markers",
      marker = list(size = 6, color = color),
      name = as.character(g_val),
      showlegend = TRUE
    )
  }
  
  p %>%
    layout(
      scene = list(
        xaxis = list(title = x_var),
        yaxis = list(title = y_var),
        zaxis = list(title = z_var)
      ),
      legend = list(title = list(text = group_var))
    )
}

subs <- c("subSH", "subTH",'subAL')
subs <- c('subAL')
data_list <- list()

for (sub in subs) {
  df <- read.csv(paste0("/Users/ali/Documents/Experiment/DFF_data/", sub, ".csv"))
  df$subject <- sub
  data_list[[sub]] <- df
}

data <- do.call(rbind, data_list)

str(data)    # check structure

# Modifying dataframe
data$CueValidity <- ifelse(data$CueType == data$FlashSide, "valid", "invalid")
data$CueValidity[data$CueType == "neutral"] <- "neutral"
data$RespFlash <- ifelse(data$Resp %in% c(1,4),
                         "two",
                         "one")

data$ResProbe <- ifelse(data$Resp %in% c(1,2),
                        "top",
                        "bottom")



data$RespProbeBinary <- ifelse(data$probe == data$ResProbe, 1, 0)
data$dtcolor <- round(1 - (data$dtcolor / 255), 1)
data$RespFlashBinary <- ifelse(data$RespFlash == "two", 1, 0)
data$ISIframes <- as.integer(data$ISIframes)
data$dt_top <- ifelse(data$probe == "top", -data$dtcolor, data$dtcolor)
data$ChoiceTop <- ifelse(data$ResProbe == "top", 1, 0)

thin = 0.1

## =========== SPACIAL psychometric curves ===========
ggplot(data, aes(x = -dt_top, y = ChoiceTop, color = CueValidity)) +
  
  # --- subject-level curves ---
  stat_smooth(aes(group = interaction(subject, CueValidity)),
              method = "glm",
              method.args = list(family = binomial(link = "probit")),
              se = FALSE,
              alpha = 0.3,
              linewidth = thin) +
  
  # --- global curve (thicker) ---
  stat_smooth(method = "glm",
              method.args = list(family = binomial(link = "probit")),
              se = FALSE,
              linewidth = 1.5) +
  
  geom_hline(yintercept = 0.5, linetype = "dashed", color = "grey") +
  geom_vline(xintercept = 0, linetype = "dashed", color = "grey") +
  
  labs(title = "Spatial Psychometric",
       y = "P(choose top)",
       x = "Contrast (top relative)") +
  
  theme_bw() +
  coord_fixed(ratio = 2, xlim = c(-1, 1), ylim = c(0, 1))



# interference --------
p1 <- ggplot(data, aes(x = ISIframes, y = RespProbeBinary, color = CueValidity)) +
  
  # --- subject-level curves ---
  stat_smooth(aes(group = interaction(subject, CueValidity)),
              method = "glm",
              method.args = list(family = binomial(link = "probit")),
              se = FALSE,
              alpha = 0.3,
              linewidth = thin) +
  
  # --- global curve ---
  stat_smooth(method = "glm",
              method.args = list(family = binomial(link = "probit")),
              se = FALSE,
              linewidth = 1.5) +
  
  geom_hline(yintercept = 0.5, linetype = "dashed", color = "black") +
  geom_vline(xintercept = mean(range(data$ISIframes)), linetype = "dashed", color = "black") +
  labs(title = "Space resolution", y = "P(accuracy)", x = "ISI") +
  theme_bw() +
  theme(legend.position = "none")


p2 <- ggplot(data, aes(x = dtcolor, y = RespProbeBinary, color = CueValidity)) +
  
  # --- subject-level curves ---
  stat_smooth(aes(group = interaction(subject, CueValidity)),
              method = "glm",
              method.args = list(family = binomial(link = "probit")),
              se = FALSE,
              alpha = 0.3,
              linewidth = thin) +
  
  # --- global curve ---
  stat_smooth(method = "glm",
              method.args = list(family = binomial(link = "probit")),
              se = FALSE,
              linewidth = 1.5) +
  
  geom_hline(yintercept = 0.5, linetype = "dashed", color = "black") +
  geom_vline(xintercept = mean(range(data$dtcolor)), linetype = "dashed", color = "black") +
  labs(title = "", y = "P(accuracy)", x = "Contrast") +
  theme_bw() +
  theme(
    legend.position = c(0.98, 0.02),
    legend.justification = c(1, 0)
  )

grid.arrange(p1, p2, ncol = 2)
## =========== TEMPORAL psychometric curves ===========

ggplot(data, aes(x = ISIframes, y = RespFlashBinary, color = CueValidity)) +
  
  # --- subject-level curves ---
  stat_smooth(aes(group = interaction(subject, CueValidity)),
              method = "glm",
              method.args = list(family = binomial(link = "probit")),
              se = FALSE,
              alpha = 0.3,
              linewidth = thin) +
  
  # --- global curve ---
  stat_smooth(method = "glm",
              method.args = list(family = binomial(link = "probit")),
              se = FALSE,
              linewidth = 1.5) +
  
  #geom_point(alpha = 0.4, position = position_jitter(height = 0.02)) +
  
  labs(title = "Temporal psychometric",
       y = "P(choose two)",
       x = "ISI") +
  
  geom_hline(yintercept = 0.5, linetype = "dashed", color = "black") +
  geom_vline(xintercept = 5, linetype = "dashed", color = "black") +
  
  theme_bw() +
  coord_fixed(ratio = 9, xlim = c(0, 9), ylim = c(0, 1))



# interference --------
p1 <- ggplot(data, aes(x = ISIframes, y = RespFlashBinary, color = CueValidity)) +
  
  # --- subject-level curves ---
  stat_smooth(aes(group = interaction(subject, CueValidity)),
              method = "glm",
              method.args = list(family = binomial(link = "probit")),
              se = FALSE,
              alpha = 0.3,
              linewidth = thin) +
  
  # --- global curve ---
  stat_smooth(method = "glm",
              method.args = list(family = binomial(link = "probit")),
              se = FALSE,
              linewidth = 1.5) +
  
  geom_hline(yintercept = 0.5, linetype = "dashed", color = "black") +
  geom_vline(xintercept = mean(range(data$ISIframes)), linetype = "dashed", color = "black") +
  labs(title = "Temporal resolution", y = "P(accuracy)", x = "ISI") +
  theme_bw() +
  theme(legend.position = "none")


p2 <- ggplot(data, aes(x = dtcolor, y = RespFlashBinary, color = CueValidity)) +
  
  # --- subject-level curves ---
  stat_smooth(aes(group = interaction(subject, CueValidity)),
              method = "glm",
              method.args = list(family = binomial(link = "probit")),
              se = FALSE,
              alpha = 0.3,
              linewidth = thin) +
  
  # --- global curve ---
  stat_smooth(method = "glm",
              method.args = list(family = binomial(link = "probit")),
              se = FALSE,
              linewidth = 1.5) +
  
  geom_hline(yintercept = 0.5, linetype = "dashed", color = "black") +
  geom_vline(xintercept = mean(range(data$dtcolor)), linetype = "dashed", color = "black") +
  labs(title = "", y = "P(accuracy)", x = "Contrast") +
  theme_bw() +
  theme(
    legend.position = c(0.98, 0.02),
    legend.justification = c(1, 0)
  )

grid.arrange(p1, p2, ncol = 2)

## =========== Spheres ===========

plot_glm_surface(
  data = data,
  x_var = "dtcolor",
  y_var = "ISIframes",
  z_var = "RespProbeBinary",
  group_var = "CueValidity"
)

plot_glm_surface(
  data = data,
  x_var = "dtcolor",
  y_var = "ISIframes",
  z_var = "RespFlashBinary",
  group_var = "CueValidity"
)

plot_glm_surface(
  data,
  x_var = "dtcolor",
  y_var = "ISIframes",
  z_var = "RT",
  group_var = "CueValidity",
  family = Gamma(link = "log")
)

## =========== Error Bar Plot ===========
ggplot(data, aes(x = RespFlash, y = RespProbeBinary)) +
  
  # --- raw data ---
  geom_jitter(width = 0.05, alpha = 0.2, size = 1) +
  
  # --- subject-level means ---
  stat_summary(aes(group = subject),
               fun = mean,
               geom = "point",
               color = "pink",
               alpha = 0.5,
               size = 1.5,
               position = position_dodge(width = 0.2)) +
  
  # --- overall mean (bold) ---
  stat_summary(fun = mean,
               geom = "point",
               color = "purple",
               size = 2.5) +
  
  # --- overall CI ---
  stat_summary(fun.data = mean_cl_boot,
               geom = "errorbar",
               width = 0.2,
               color = "black") +
  
  facet_grid(CueValidity ~ ISIframes) +
  
  labs(
    title = "Probe Accuracy by Flash Condition, Cue Validity, and ISI",
    x = "Flash Reported",
    y = "Accuracy (RespProbeBinary)"
  ) +
  
  theme_bw()

ggplot(data, aes(x = RespFlash, y = RespProbeBinary)) +
  
  # --- raw data ---
  geom_jitter(width = 0.05, alpha = 0.2, size = 1) +
  
  # --- subject-level means ---
  stat_summary(aes(group = subject),
               fun = mean,
               geom = "point",
               color = "pink",
               alpha = 0.5,
               size = 1.5,
               position = position_dodge(width = 0.2)) +
  
  # --- overall mean (bold) ---
  stat_summary(fun = mean,
               geom = "point",
               color = "purple",
               size = 2.5) +
  
  # --- overall CI ---
  stat_summary(fun.data = mean_cl_boot,
               geom = "errorbar",
               width = 0.2,
               color = "black") +
  
  facet_grid(CueValidity ~ dtcolor) +
  
  labs(
    title = "Probe Accuracy by Flash Condition, Cue Validity, and ISI",
    x = "Flash Reported",
    y = "Accuracy (RespProbeBinary)"
  ) +
  
  theme_bw()
## =========== joint prob ===========
summary_table <- data %>%
  group_by(CueValidity, RespFlashBinary, RespProbeBinary) %>%
  summarise(n = n(), .groups = "drop") %>%
  group_by(CueValidity) %>%
  mutate(prop = n / sum(n))

ggplot(summary_table,
       aes(x = factor(RespFlashBinary),
           y = factor(RespProbeBinary),
           fill = prop)) +
  geom_tile() +
  geom_text(aes(label = round(prop, 2))) +
  facet_wrap(~ CueValidity) +
  labs(x = "Temporal accuracy",
       y = "Spacial accuracy",
       fill = "Proportion") +
  theme_classic()

