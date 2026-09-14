## ---- function --------------
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
                    "invalid" ="darkblue" ,
                    "valid" = "darkred",
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
        zaxis = list(title = z_var)#list(title = z_var, range = c(0, 1))
      ),
      legend = list(title = list(text = group_var))
    )
}


plot_glm_surface_multi <- function(data, x_var, y_var, z_vars, group_var,
                                   family = NULL) {
  
  p <- plot_ly()
  
  for (z_var in z_vars) {
    
    # auto-detect family
    if (is.null(family)) {
      if (length(unique(na.omit(data[[z_var]]))) == 2) {
        fam <- quasibinomial()
      } else {
        fam <- gaussian()
      }
    } else {
      fam <- family
    }
    
    # model
    formula_str <- paste(z_var, "~", x_var, "*", y_var, "*", group_var)
    model <- glm(as.formula(formula_str), family = fam, data = data)
    
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
    
    grid$z_pred <- predict(model, newdata = grid, type = "response")
    
    groups <- unique(grid[[group_var]])
    
    
    for (g_val in groups) {
      
      g <- subset(grid, grid[[group_var]] == g_val)
      
      base_color <- switch(as.character(g_val),
                           "invalid" ="darkblue" ,
                           "valid" = "darkred",
                           "neutral" = "black")
      
      opacity_val <- ifelse(z_var == z_vars[1], 0.5, 0.8)
      
      p <- add_surface(
        p,
        x = unique(g[[x_var]]),
        y = unique(g[[y_var]]),
        z = matrix(g$z_pred, 50, 50),
        opacity = opacity_val,
        showscale = FALSE,
        colorscale = list(c(0, base_color), c(1, base_color)),
        name = as.character(g_val),
        showlegend = (z_var == z_vars[2])      )
    }
    
  }
  
  p %>%
    layout(
      scene = list(
        xaxis = list(title = 'Contrast' ),
        yaxis = list(title = 'ISI (ms)' ),
        zaxis = list(title = "Accuracy (Two/Top)")
      ),
      legend = list(title = list(text = paste(group_var)))
    )
}



## ---- modules -----
library(dplyr)
library(ggplot2)
library(plotly)
library(gridExtra)
library(quickpsy)
library(patchwork)
library(sjPlot)
library(lme4)
library(lmerTest)

subs <- c('subSH', 'subTH','subAL','subJU','subSA','subDI','subBE','subTI','subRO',
          'subJA')

#subs <- c('subJA')
data_list <- list()

for (sub in subs) {
  df <- read.csv(paste0("D:/DFF_data/",sub,"/", sub, "RR.csv"))
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
data$ISIframes <- as.integer(data$ISIframes) * 7 # ms a frame


# When probe black and at the top    surely choice top close to one
# When probe black and at the bottom surely choice top close to zero
data$dt_top <- ifelse(data$probe == "bottom", -data$dtcolor, data$dtcolor)
# contrast 1 becomes to -1 for the bottom
data$ChoiceTop <- ifelse(data$ResProbe == "top", 1, 0)
# if they choose top 1 if not 0

# removing outliers
data_no_outliers <- data %>%
  filter(
    if_all(
      where(is.numeric),
      ~ . >= quantile(., 0.25, na.rm = TRUE) - 1.5 * IQR(., na.rm = TRUE) &
        . <= quantile(., 0.75, na.rm = TRUE) + 1.5 * IQR(., na.rm = TRUE)
    )
  )

# save data
write.csv(data, "D:/DFF_data/dataRR.csv", row.names = FALSE)

## ============= Import data ===============

data <- read.csv("D:/DFF_data/data.csv")

## ============= psychometric curves ===============

thin = 0.001
thick = 1
a = 0.01



# Spatial
p_spatial_isi <- ggplot(data, aes(x = ISIframes, y = ChoiceTop, color = CueValidity)) +
  stat_smooth(aes(group = interaction(subject, CueValidity)),
              method = "glm",
              method.args = list(family = binomial(link = "logit")),
              se = FALSE, alpha = a, linewidth = thin) +
  stat_smooth(method = "glm",
              method.args = list(family = binomial(link = "logit")),
              se = FALSE, linewidth = thick) +
  geom_hline(yintercept = 0.5, linetype = "dashed") +
  labs(title = "Spacial Resolution", y = "P(Top)", x = "ISI (ms)") +
  theme_bw() +
  theme(legend.position = "none") +
  coord_fixed(ratio = 9*7, xlim = c(0, 9*7), ylim = c(0, 1))


p_spatial_contrast <- ggplot(data, aes(x = dt_top, y = ChoiceTop, color = CueValidity)) +
  stat_smooth(aes(group = interaction(subject, CueValidity)),
              method = "glm",
              method.args = list(family = binomial(link = "logit")),
              se = FALSE, alpha = a, linewidth = thin) +
  stat_smooth(method = "glm",
              method.args = list(family = binomial(link = "logit")),
              se = FALSE, linewidth = thick) +
  geom_hline(yintercept = 0.5, linetype = "dashed") +
  labs(title = "", y = "P(Top)", x = "Contrast") +
  theme_bw() +
  coord_fixed(ratio = 2, xlim = c(-1, 1), ylim = c(0, 1))


# Temporal
p_temp_isi <- ggplot(data, aes(x = ISIframes, y = RespFlashBinary, color = CueValidity)) +
  stat_smooth(aes(group = interaction(subject, CueValidity)),
              method = "glm",
              method.args = list(family = binomial(link = "logit")),
              se = FALSE, alpha = a, linewidth = thin) +
  stat_smooth(method = "glm",
              method.args = list(family = binomial(link = "logit")),
              se = FALSE, linewidth = thick) +
  geom_hline(yintercept = 0.5, linetype = "dashed") +
  labs(title = "Temporal Resolution", y = "P(Two)", x = "ISI (ms)") +
  theme_bw() +
  theme(legend.position = "none") +
  coord_fixed(ratio = 9*7, xlim = c(0, 9*7), ylim = c(0, 1))


p_temp_contrast <- ggplot(data, aes(x = dt_top, y = RespFlashBinary, color = CueValidity)) +
  stat_smooth(aes(group = interaction(subject, CueValidity)),
              method = "glm",
              method.args = list(family = binomial(link = "logit")),
              se = FALSE, alpha = a, linewidth = thin) +
  stat_smooth(method = "glm",
              method.args = list(family = binomial(link = "logit")),
              se = FALSE, linewidth = thick) +
  geom_hline(yintercept = 0.5, linetype = "dashed") +
  labs(title = "", y = "P(Two)", x = "Contrast") +
  theme_bw() +
  coord_fixed(ratio = 2, xlim = c(-1, 1), ylim = c(0, 1))


# Combine

(p_spatial_isi | p_spatial_contrast) /
  (p_temp_isi    | p_temp_contrast) +
  plot_layout(guides = "collect") &
  theme(legend.position = "top")



p_spatial_contrast <- ggplot(data, aes(x = dt_top, y = ChoiceTop, color = CueValidity)) +
  stat_smooth(method = "glm",
              method.args = list(family = binomial(link = "logit")),
              se = TRUE, linewidth = 1) +
  geom_hline(yintercept = 0.5, linetype = "dashed") +
  labs(title = "", y = "P(Top)", x = "Contrast") +
  theme_bw() +
  theme(legend.position = "top") +
  coord_fixed(ratio = 2, xlim = c(-1, 1), ylim = c(0, 1))
p_spatial_contrast

p_temp_isi <- ggplot(data, aes(x = ISIframes, y = RespFlashBinary, color = CueValidity)) +
  stat_smooth(method = "glm",
              method.args = list(family = binomial(link = "logit")),
              se = TRUE, linewidth = 1) +
  geom_hline(yintercept = 0.5, linetype = "dashed") +
  labs(title = "", y = "P(Two)", x = "ISI (ms)") +
  theme_bw() +
  theme(legend.position = "top") +
  coord_fixed(ratio = 9*7, xlim = c(0, 9*7), ylim = c(0, 1))
p_temp_isi 


(p_temp_isi | p_spatial_contrast) +
  plot_layout(guides = "collect") &
  theme(
    legend.position = "top",
    plot.title = element_blank()
  )
## ============= dprime curves ===============



compute_dprime <- function(df, response_col, group_vars) {
  eps <- 1e-6
  df %>%
    group_by(across(all_of(group_vars))) %>%
    summarise(
      n = n(),
      p = mean(.data[[response_col]], na.rm = TRUE),
      se_p = sqrt(p * (1 - p) / n),
      .groups = "drop"
    ) %>%
    mutate(
      p = pmin(pmax(p, eps), 1 - eps),
      
      z = qnorm(p),
      dprime = sqrt(2) * z,
      
      # delta method
      phi_z = dnorm(z),
      se_dprime = sqrt(2) * se_p / phi_z,
      
      ci_low = dprime - 1.96 * se_dprime,
      ci_high = dprime + 1.96 * se_dprime
    )
}





d_spatial_isi <- compute_dprime(
  data,
  response_col = "ChoiceTop",
  group_vars = c("ISIframes", "CueValidity")
)

d_temp_isi <- compute_dprime(
  data,
  response_col = "RespFlashBinary",
  group_vars = c("ISIframes", "CueValidity")
)

d_spatial_contrast <- compute_dprime(
  data,
  response_col = "RespProbeBinary",
  group_vars = c("dtcolor", "CueValidity")
)

d_temp_contrast <- compute_dprime(
  data,
  response_col = "RespFlashBinary",
  group_vars = c("dt_top", "CueValidity")
)


ggplot(d_spatial_contrast,
       aes(x = dtcolor,
           y = dprime,
           color = CueValidity,
           group = CueValidity)) +
  aes(x = dtcolor + 1e-6) +
  geom_smooth(method = "loess", span = 1, se = FALSE, linewidth = 1.2) +
  geom_point(size = 2) +
  geom_errorbar(aes(ymin = ci_low, ymax = ci_high),
                width = 0.02,
                alpha = 0.5) +
  scale_color_manual(values = c(
    "valid"   = "darkred",
    "invalid" = "darkblue",
    "neutral" = "black"
  )) +
  labs(x = "Contrast (chroma)", y = "d'") +
  theme_classic()

ggplot(subset(d_temp_isi, ISIframes >0),
       aes(x = ISIframes,
           y = dprime,
           color = CueValidity,
           group = CueValidity)) +
  geom_smooth(method = "loess", span = 1.2, se = FALSE, linewidth = 1.2) +
  geom_point(size = 2) +
  geom_errorbar(aes(ymin = ci_low, ymax = ci_high),
                width = 0.02,
                alpha = 0.5) +
  scale_color_manual(values = c(
    "valid"   = "darkred",
    "invalid" = "darkblue",
    "neutral" = "black"
  )) +
  labs(x = "ISI (ms)", y = "d'") +
  theme_classic()


p_spatial_isi <- ggplot(d_spatial_isi,
                        aes(x = ISIframes,
                            y = dprime,
                            color = CueValidity)) +
  
  geom_line(linewidth = 1) +
  
  geom_point(size = 2) +
  
  geom_errorbar(aes(ymin = ci_low, ymax = ci_high),
                width = 0.2,
                alpha = 0.5) +
  
  labs(title = "Spatial Resolution (d')",
       y = "d'",
       x = "ISI (ms)") +
  
  theme_bw()

p_spatial_contrast <- ggplot(d_spatial_contrast,
                             aes(x = dt_top,
                                 y = dprime,
                                 color = CueValidity)) +
  geom_line(linewidth = 1) +
  geom_point(size = 2) +
  geom_errorbar(aes(ymin = ci_low, ymax = ci_high),
                width = 0.02,
                alpha = 0.5) +
  labs(x = "Contrast (chroma)", y = "d'") +
  theme_bw()

p_temp_isi <- ggplot(d_temp_isi,
                     aes(x = ISIframes,
                         y = dprime,
                         color = CueValidity)) +
  geom_line(linewidth = 1) +
  geom_point(size = 2) +
  geom_errorbar(aes(ymin = ci_low, ymax = ci_high),
                width = 0.2,
                alpha = 0.5) +
  labs(title = "Temporal Resolution (d')",
       y = "d'",
       x = "ISI (ms)") +
  theme_bw()

p_temp_contrast <- ggplot(d_temp_contrast,
                          aes(x = dt_top,
                              y = dprime,
                              color = CueValidity)) +
  geom_line(linewidth = 1) +
  geom_point(size = 2) +
  geom_errorbar(aes(ymin = ci_low, ymax = ci_high),
                width = 0.02,
                alpha = 0.5) +
  labs(x = "Contrast (chroma)", y = "d'") +
  theme_bw()


(p_spatial_isi | p_spatial_contrast) /
  (p_temp_isi    | p_temp_contrast) +
  plot_layout(guides = "collect") &
  theme(legend.position = "top")

(p_temp_isi   | p_spatial_contrast)
  plot_layout(guides = "collect") &
  theme(legend.position = "right")
## =========== Spheres ===========

plot_glm_surface(
  data,
  x_var = "dt_top",
  y_var = "ISIframes",
  z_var = "RT",
  group_var = "CueValidity",
  family = Gamma(link = "log")
)


plot_glm_surface_multi(
  data = data,
  x_var = "dt_top",
  y_var = "ISIframes",
  z_vars = c("ChoiceTop", "RespFlashBinary"),
  group_var = "CueValidity"
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

ggplot(data, aes(x = RespFlash, y = ChoiceTop)) +
  
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
  
  facet_grid(CueValidity ~ dt_top) +
  
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





summary_data <- data %>%
  group_by(RespFlashBinary, CueValidity) %>%
  summarise(
    mean = mean(RespProbeBinary, na.rm = TRUE),
    se = sd(RespProbeBinary, na.rm = TRUE) / sqrt(n()),
    .groups = "drop"
  )

ggplot(summary_data, aes(x = RespFlashBinary, y = mean, color = CueValidity)) +
  geom_point(size = 3) +
  geom_line(aes(group = CueValidity)) +
  geom_errorbar(aes(ymin = mean - se, ymax = mean + se), width = 0.1) +
  scale_x_continuous(limits = c(0, 1), breaks = c(0, 1)) +
  labs(
    x = "Number of flash",
    y = "Spatial accuracy",
    color = "CueValidity"
  ) +
  theme_classic() +
  theme(
    legend.position = c(0.8, 0.2),   # inside (right-bottom area)
    legend.background = element_rect(fill = "white", color = "black")
  )


## PSE ----------------------

pse_all <- data %>%
  group_by(CueValidity,subject) %>% # add subject, if by subject 
  do({
    m1 <- glm(ChoiceTop ~ dt_top, data = ., family = binomial)
    m2 <- glm(RespFlashBinary ~ ISIframes, data = ., family = binomial)
    
    b1 <- coef(m1)
    b2 <- coef(m2)
    
    pse_dt  <- -b1[1] / b1[2]
    pse_isi <- -b2[1] / b2[2]
    
    data.frame(PSE_dt = pse_dt,
               PSE_isi = pse_isi)
  })


ggplot(pse_all, aes(x = PSE_isi, fill = CueValidity)) +
  geom_density(alpha = 0.4) +
  labs(title = "Kernel density of PSE")

ggplot(pse_all, aes(x = PSE_dt, fill = CueValidity)) +
  geom_density(alpha = 0.4) +
  labs(title = "Kernel density of PSE")



pse_wide <- pse_all %>%
  select(subject, CueValidity, PSE_isi) %>%
  pivot_wider(names_from = CueValidity, values_from = PSE_isi)

# paired t-test
t.test(pse_wide$valid, pse_wide$invalid, paired = TRUE)

# or nonparametric if PSEs aren't normally distributed / small N
wilcox.test(pse_wide$Valid, pse_wide$Invalid, paired = TRUE)



m <- lmer(PSE_isi ~ CueValidity + (1 | subject), data = pse_all)
summary(m)


## MAX effect ----------------------

max_effect_all <- data %>%
  #group_by(subject) %>%
  do({
    # dt_top model
    m1 <- glm(ChoiceTop ~ dt_top * CueValidity, data = ., family = binomial)
    
    grid1 <- expand.grid(
      dt_top = seq(min(.$dt_top), max(.$dt_top), length.out = 200),
      CueValidity = unique(.$CueValidity)
    )
    
    grid1$pred <- predict(m1, newdata = grid1, type = "response")
    
    d1 <- pivot_wider(grid1, names_from = CueValidity, values_from = pred)
    diff1 <- abs(d1[[2]] - d1[[3]])
    
    # isi model
    m2 <- glm(RespFlashBinary ~ ISIframes * CueValidity, data = ., family = binomial)
    
    grid2 <- expand.grid(
      ISIframes = seq(min(.$ISIframes), max(.$ISIframes), length.out = 200),
      CueValidity = unique(.$CueValidity)
    )
    
    grid2$pred <- predict(m2, newdata = grid2, type = "response")
    
    d2 <- pivot_wider(grid2, names_from = CueValidity, values_from = pred)
    diff2 <- abs(d2[[2]] - d2[[3]])
    
    data.frame(
      max_diff_dt  = max(diff1),
      at_dt_top    = d1$dt_top[which.max(diff1)],
      max_diff_isi = max(diff2),
      at_ISI       = d2$ISIframes[which.max(diff2)]
    )
  })


ggplot(max_effect_all, aes(x = at_dt_top)) +
  geom_histogram(binwidth = 0.05, color = "black", fill = "steelblue") +
  labs(
    title = "Histogram of Max Difference (Valid - Invalid)",
    x = "Max difference (contrast)",
    y = "Count"
  )

ggplot(max_effect_all, aes(x = at_ISI)) +
  geom_histogram(binwidth = 0.05, color = "black", fill = "darkorange") +
  labs(
    title = "Histogram of Max Difference (Valid - Invalid)",
    x = "Max difference (ISI)",
    y = "Count"
  )

## =========== Hist of highest difference ===========
data <- read.csv("D:/DFF_data/data.csv")

unique(data$ISIframes)
unique(data$dtcolor)

subset_data <- data[data$ISIframes == 35, ]

subset_data <- data[data$dtcolor == 0.3 & data$ISIframes == 35, ]

p1<-ggplot(subset_data, aes(x = factor(RespProbeBinary), fill = CueValidity)) +
  geom_bar(position = "dodge") +theme_classic() +
  scale_y_continuous(limits = c(0, 250)) +
  scale_x_discrete(labels = c("0" = "False", "1" = "Correct"))

p2<-ggplot(subset_data, aes(x = factor(RespFlashBinary), fill = CueValidity)) +
  geom_bar(position = "dodge") +theme_classic() +
  scale_y_continuous(limits = c(0, 250)) + 
  scale_x_discrete(labels = c("0" = "One", "1" = "Two"))


(p1 | p2) +
  plot_layout(guides = "collect") &
  plot_annotation(title = paste0( unique(subset_data$dtcolor), "chroma, ", unique(subset_data$ISIframes), " ms")) &
  theme(legend.position = "top")

## -------------------- Stats ----------------

data <- read.csv("D:/DFF_data/data.csv")

library(lmerTest)
library(dplyr)

data <- data %>%
  arrange(subject, Trial) %>%
  group_by(subject) %>%
  mutate(
    ISIframes_lag1 = lag(ISIframes),
    dt_top_lag1 = lag(dt_top)
  ) %>%
  ungroup()

data$CueValidity <- factor(data$CueValidity)
data$CueValidity <- relevel(data$CueValidity, ref = "neutral")
data$numFlash <- factor(data$RespFlashBinary)

spaceModel <- glmer(
  ChoiceTop ~ CueValidity * ISIframes * ISIframes_lag1 + CueValidity * dt_top * dt_top_lag1  + Trial + (1 | subject),
  data = data,
  family = binomial(link = "logit")
)

summary(spaceModel)

timeModel <- glmer(
  RespFlashBinary ~ CueValidity * ISIframes + ISIframes_lag1 + CueValidity * dtcolor + dt_top_lag1 + Trial + (1 | subject),
  data = data,
  family = binomial(link = "logit")
)

summary(timeModel)


rtModel <- lmer(
  RT ~ CueValidity * ISIframes + CueValidity * dtcolor + Trial + (1 | subject),
  data = data)


summary(rtModel)

model <- glmer(
  RespProbeBinary ~ CueValidity * numFlash * dtcolor + Trial + (1 | subject),
  data = data,
  family = binomial(link = "logit")
)
summary(model)




## Heeger (1992) ----------------
library(lme4)

data <- read.csv("D:/DFF_data/data.csv")

loglik <- function(n, M, x, y) {
  # enforce valid parameter space
  if (n <= 0 || M <= 0) return(1e10)
  
  # Hill function
  p <- (x^n) / (x^n + M^n)
  
  #p <- plogis(n * (x - M))
                   
  # avoid log(0)
  p <- pmin(pmax(p, 1e-8), 1 - 1e-8)
  
  # negative log-likelihood
  -sum(y * log(p) + (1 - y) * log(1 - p))
}



data$dt_pos <- data$dt_top - min(data$dt_top) + 1e-6

fits <- by(data, data$CueValidity, function(df) {
  
  mle(
    function(n, M) loglik(n, M, df$dt_pos, df$ChoiceTop),
    start = list(n = 4, M = 30),
    method = "L-BFGS-B",
    lower = c(0.05, 0.05)
  )
})

model_comp <- data.frame(
  Condition = names(fits),
  AIC = sapply(fits, AIC),
  BIC = sapply(fits, BIC),
  logLik = sapply(fits, function(f) as.numeric(logLik(f)))
)

model_comp
lapply(fits, coef)



fits <- by(data, data$CueValidity, function(df) {
  
  mle(
    function(n, M) loglik(n, M, df$ISIframes, df$RespFlashBinary),
    start = list(n = 4, M = 30),
    method = "L-BFGS-B",
    lower = c(0.05, 0.05)
  )
})

model_comp <- data.frame(
  Condition = names(fits),
  AIC = sapply(fits, AIC),
  BIC = sapply(fits, BIC),
  logLik = sapply(fits, function(f) as.numeric(logLik(f)))
)

model_comp
lapply(fits, coef)

# Predictive coding ------------

# spacial
model <- glm(
  ChoiceTop ~ dt_pos * CueValidity,
  family = binomial(),
  data = data
)

summary(model)
AIC(model)
BIC(model)

# temporal
model <- glm(
  RespFlashBinary ~ ISIframes * CueValidity,
  family = binomial(),
  data = data
)

summary(model)
AIC(model)
BIC(model)

# ------------ dynamic -----------
accuracy_trial <- data %>%
  group_by(Trial, CueValidity, ISIframes) %>%
  summarise(
    accuracyTemporal = mean(RespFlashBinary, na.rm = TRUE) * 100,
    accuracySapcial = mean(RespProbeBinary, na.rm = TRUE) * 100,
    .groups = "drop"
  )




ggplot(accuracy_trial, aes(x = Trial, y = accuracyTemporal, color = CueValidity)) +
  geom_point(alpha = 0.5) +
  geom_smooth(method = "loess", span = 0.4, se = TRUE) +
  facet_wrap(~ ISIframes) +
  labs(x = "Trial", y = "Accuracy (%)", color = "Cue Validity") +
  ylim(0, 100) +
  geom_vline(xintercept = seq(min(accuracy_trial$Trial),
                              max(accuracy_trial$Trial),
                              by = 50),
             color = "black", linetype = "dashed") +
  theme_minimal()



# ----------- predictive coding
# Create stimulus range
x <- seq(-5, 5, length.out = 200)

# Logistic function
logistic <- function(x, beta0, beta1) {
  1 / (1 + exp(-(beta0 + beta1 * x)))
}

# Baseline parameters
beta0_base <- 0      # no bias
beta1_base <- 1      # moderate slope

# Case 1: decreased prediction (bias shift)
beta0_low_pred <- +1   # shift curve right (needs more evidence)

# Case 2: increased precision (steeper slope)
beta1_high_prec <- 2

# Case 3: both together
beta0_both <- +1
beta1_both <- 2

# Compute curves
p_base  <- logistic(x, beta0_base, beta1_base)
p_bias  <- logistic(x, beta0_low_pred, beta1_base)
p_prec  <- logistic(x, beta0_base, beta1_high_prec)
p_both  <- logistic(x, beta0_both, beta1_high_prec)

# Plot
plot(x, p_base, type = "l", lwd = 3, col = "black",
     ylim = c(0,1),
     xlab = "Stimulus (x)",
     ylab = "P(choice = 1)",
     main = "Psychometric Curve: Prediction vs Precision")

lines(x, p_bias, col = "blue", lwd = 3, lty = 2)
lines(x, p_prec, col = "red", lwd = 3, lty = 2)
lines(x, p_both, col = "purple", lwd = 3, lty = 3)

legend("bottomright",
       legend = c("Baseline",
                  "↓ bias",
                  "↑ Precision",
                  "Both"),
       col = c("black", "blue", "red", "purple"),
       lwd = 3,
       lty = c(1,2,2,3))


# Stimulus range (0 to 10 as requested)
x <- seq(-10, 10, length.out = 200)

# Logistic with exponential growth term
logistic_exp_growth <- function(x, beta0, beta1, alpha, gamma) {
  extra <- alpha * (exp(gamma * x) - 1)
  1 / (1 + exp(-(beta0 + beta1 * x + extra)))
}

# Base parameters
beta0 <- 0
beta1 <- 0.8

# Growth parameters
alpha_values <- c(0, 0.2, 0.5, 1)
gamma <- 0.3

# Plot
plot(x, logistic_exp_growth(x, beta0, beta1, alpha_values[1], gamma),
     type = "l", lwd = 3, ylim = c(0,1),
     xlab = "Stimulus (x)",
     ylab = "P(choice = 1)",
     main = "Zero-at-0, Exponentially Growing Effect")

cols <- c("black", "blue", "red", "purple")

for (i in 1:length(alpha_values)) {
  lines(x,
        logistic_exp_growth(x, beta0, beta1, alpha_values[i], gamma),
        col = cols[i],
        lwd = 3)
}

legend("topleft",
       legend = paste("alpha =", alpha_values),
       col = cols,
       lwd = 3)
 


# lag model -----------



data <- data %>%
  arrange(subject, Trial) %>%
  group_by(subject) %>%
  mutate(
    lag_RespFlashBinary = lag(RespFlashBinary)
  ) %>%
  ungroup()

model <- glmer(
  RespFlashBinary ~ CueValidity * ISIframes +
    lag_RespFlashBinary +
    (1 | subject),
  data = data,
  family = binomial
)

summary(model)



data <- data %>%
  arrange(subject, Trial) %>%
  group_by(subject) %>%
  mutate(
    lag_ISIframes = lag(ISIframes),
    lag_RespFlashBinary = lag(RespFlashBinary),
    lag_dtcolor = lag(dtcolor),
    lag_RespProbeBinary = lag(RespFlashBinary)
  ) %>%
  ungroup()

model <- glmer(
  RespFlashBinary ~ CueValidity * ISIframes + lag_RespFlashBinary + lag_ISIframes + dtcolor +(1 | subject),
  data = data,
  family = binomial
)

summary(model)


p <- plot_model(
  model,
  type = "est",
  show.values = TRUE,
  value.offset = .3
)+
  theme_classic()
p
p +
  scale_y_discrete(
    labels = c(
      "CueValidity" = "Cue validity",
      "ISIframes" = "ISI (frames)",
      "lag_RespFlashBinary" = "Previous response",
      "lag_ISIframes" = "Previous ISI (frames)",
      "dtcolor" = "Delta color"
    )
  ) 



model <- glmer(
  RespProbeBinary ~ CueValidity * dtcolor  + lag_RespProbeBinary + lag_ISIframes +ISIframes +(1 | subject),
  data = data,
  family = binomial
)

summary(model)

plot_model(
  model,
  type = "est",
  show.values = TRUE,
  value.offset = .3
) +
  theme_classic()



## ----------- recovery rate ---------
data$RR <- data$peakAmp2/data$peakAmp1
data$dLatency <- data$peakLat2 - data$peakLat1

plot_glm_surface(
  data,
  x_var = "dtcolor",
  y_var = "ISIframes",
  z_var = "RR",
  group_var = "CueValidity"
)

plot_glm_surface(
  data,
  x_var = "dtcolor",
  y_var = "ISIframes",
  z_var = "dLatency",
  group_var = "CueValidity"
)



model <- glmer(
  RespFlashBinary ~ RR * CueValidity +(1 | subject),
  data = data,
  family = binomial
)

summary(model)





sumdat <- data %>%
  group_by(ISIframes, CueValidity) %>%
  summarise(
    mean_RR = mean(RR, na.rm = TRUE),
    se_RR = sd(RR, na.rm = TRUE) / sqrt(n()),
    .groups = "drop"
  )

ggplot(sumdat,
       aes(x = ISIframes,
           y = mean_RR,
           color = CueValidity,
           group = CueValidity)) +
  geom_point(size = 2) +
  geom_errorbar(
    aes(ymin = mean_RR - se_RR,
        ymax = mean_RR + se_RR),
    width = 2
  ) +
  scale_color_manual(values = c(
    "valid"   = "darkred",
    "invalid" = "darkblue",
    "neutral" = "black"
  )) +
  labs(
    x = "ISI frames",
    y = "Mean RR ± SE",
    color = "Cue Validity"
  ) +
  theme_classic()


library(pROC)
thresholds <- data %>%
  group_by(CueValidity) %>%
  do({
    roc_obj <- roc(.$RespFlashBinary, .$RR)
    
    data.frame(
      threshold = coords(
        roc_obj,
        "best",
        best.method = "youden",
        ret = "threshold"
      )
    )
  })

thresholds

model <- lmer(
  RR ~ CueValidity  * dtcolor + CueValidity  * ISIframes +(1 | subject),
  data = data
)

summary(model)


## ============== mediation analysis ==============
library(lme4)

med_model <- lmer(
  RR ~ ISIframes * CueValidity + (1 | subject),
  data = data
)

summary(med_model)

out_model <- glmer(
  RespFlashBinary ~ RR + ISIframes * CueValidity +
    (1 | subject),
  data = data,
  family = binomial
)

summary(out_model)

library(mediation)

med.fit <- lm(
  RR ~ ISIframes * CueValidity,
  data = data
)

out.fit <- glm(
  RespFlashBinary ~ RR * CueValidity + ISIframes * CueValidity,
  data = data,
  family = binomial
)

med.out <- mediate(
  med.fit,
  out.fit,
  treat = "ISIframes",
  mediator = "RR",
  boot = TRUE,
  sims = 1000
)

summary(med.out)


med_df <- data.frame(
  Effect = c("ACME", "ADE", "Total Effect"),
  Estimate = c(
    med.out$d.avg,
    med.out$z.avg,
    med.out$tau.coef
  ),
  Lower = c(
    med.out$d.avg.ci[1],
    med.out$z.avg.ci[1],
    med.out$tau.ci[1]
  ),
  Upper = c(
    med.out$d.avg.ci[2],
    med.out$z.avg.ci[2],
    med.out$tau.ci[2]
  )
)

ggplot(med_df, aes(x = Effect, y = Estimate)) +
  geom_point(size = 4) +
  geom_errorbar(
    aes(ymin = Lower, ymax = Upper),
    width = .15
  ) +
  geom_hline(yintercept = 0, linetype = "dashed") +
  theme_classic() +
  labs(
    y = "Effect Estimate",
    x = "",
    title = "Mediation Analysis"
  )



##  --------- plot recovery rate ---------
sumdat <- data %>%
  group_by(ISIframes, CueValidity, RespFlashBinary) %>%
  summarise(
    mean_RR = mean(RR, na.rm = TRUE),
    se_RR = sd(RR, na.rm = TRUE) / sqrt(n()),
    .groups = "drop"
  )

ggplot(data,
       aes(x = ISIframes,
           y = RR,
           color = CueValidity,
           group = CueValidity)) +
  #geom_hline(yintercept = 0.87, linetype = "dashed", color = "black") +
  #geom_hline(yintercept = 0.57, linetype = "dashed", color = "black") +
  #geom_hline(yintercept = 0.50, linetype = "dashed", color = "black") +
  
  geom_smooth(method = "lm", formula = y ~ poly(x, 1), se = FALSE, linewidth = 1.2) +
  
  geom_point(
    data = sumdat,
    aes(y = mean_RR),
    size = 2
  ) +
  
  geom_errorbar(
    data = sumdat,
    aes(
      y = mean_RR,
      ymin = mean_RR - se_RR,
      ymax = mean_RR + se_RR
    ),
    width = 2,
    linewidth = 0.6
  ) +
  
  scale_color_manual(values = c(
    "valid"   = "darkred",
    "invalid" = "darkblue",
    "neutral" = "black"
  )) +
  labs(
    x = "ISI (ms)",
    y = "Recovery Rate"
  ) + #scale_y_continuous(limits = c(-0.5, 2)) +
  theme_classic() + facet_wrap(~RespFlashBinary)



summary_data_RR <- data %>%
  group_by(RespFlashBinary, CueValidity) %>%
  summarise(
    meanRR = mean(RR, na.rm = TRUE),
    seRR = sd(RR, na.rm = TRUE) / sqrt(n()),
    meanDL = mean(dLatency, na.rm = TRUE),
    seDL = sd(dLatency, na.rm = TRUE) / sqrt(n()),
    .groups = "drop"
  )

ggplot(summary_data_RR, aes(x = RespFlashBinary, y = meanRR, color = CueValidity)) +
  geom_point(size = 3) +
  geom_line(aes(group = CueValidity)) +
  geom_errorbar(aes(ymin = meanRR - seRR, ymax = meanRR + seRR), width = 0.1) +
  scale_x_continuous(limits = c(0, 1), breaks = c(0, 1)) +
  labs(
    x = "Number of flash",
    y = "Recovery Rate",
    color = "CueValidity"
  ) +
  theme_classic() +
  theme(
    legend.position = c(0.8, 0.2),   # inside (right-bottom area)
    legend.background = element_rect(fill = "white", color = "black")
  )

ggplot(summary_data_RR, aes(x = RespFlashBinary, y = meanDL, color = CueValidity)) +
  geom_point(size = 3) +
  geom_line(aes(group = CueValidity)) +
  geom_errorbar(aes(ymin = meanDL - seDL, ymax = meanDL + seDL), width = 0.1) +
  scale_x_continuous(limits = c(0, 1), breaks = c(0, 1)) +
  labs(
    x = "Number of flash",
    y = "Recovery Latency",
    color = "CueValidity"
  ) +
  theme_classic() +
  theme(
    legend.position = c(0.8, 0.2),   # inside (right-bottom area)
    legend.background = element_rect(fill = "white", color = "black")
  )

## ============== Bootstrap ====================

# if you want to bootstrap increase the nboot

psych_plot <- function(data, x, y, x_lab, y_lab, nboot=1) {
  set.seed(123)
  X <- deparse(substitute(x)); Y <- deparse(substitute(y))
  d <- data.frame(x=data[[X]], k=data[[Y]],
                  subject=data$subject, CueValidity=data$CueValidity)
  cues <- c("valid","invalid","neutral"); subs <- unique(d$subject)
  
  pse <- \(z) quickpsy(z,x=x,k=k,fun=logistic_fun,prob=.5)$thresholds$thre[1]
  
  boot <- lapply(1:nboot,\(b) {
    z <- d[unlist(lapply(sample(subs,length(subs),TRUE),
                         \(s) which(d$subject==s))),]
    list(
      pse=setNames(sapply(cues,\(c) pse(z[z$CueValidity==c,])),cues),
      curve=z %>% group_by(CueValidity,x) %>%
        summarise(P=mean(k),.groups="drop"))
  })
  
  bc <- bind_rows(lapply(boot,`[[`,"curve")) %>%
    group_by(CueValidity,x) %>%
    summarise(mean=mean(P),SE=sd(P),.groups="drop")
  
  curves <- bind_rows(lapply(cues,\(c) {
    f=quickpsy(d[d$CueValidity==c,],x=x,k=k,fun=logistic_fun)
    cbind(f$curves,CueValidity=c)
  }))
  
  p <- ggplot(curves,aes(x,y,colour=CueValidity)) +
    geom_line(linewidth=1.2) +
    geom_point(data=bc,aes(x,mean,colour=CueValidity),
               inherit.aes=FALSE) +
    geom_errorbar(data=bc,aes(x,ymin=mean-SE,ymax=mean+SE,
                              colour=CueValidity),
                  width=0,inherit.aes=FALSE) +
    scale_y_continuous(limits = c(0, 1)) +
    scale_colour_manual(values = c(
      valid = "darkred",
      invalid = "darkblue",
      neutral = "black"
    )) +
    labs(x = x_lab , y = y_lab , colour = "") +
    theme_classic() +
    theme(legend.position = "top", aspect.ratio = 1)
  
  sp <- d %>% group_by(subject,CueValidity) %>%
    group_modify(~data.frame(PSE=pse(.x))) %>%
    tidyr::pivot_wider(names_from=CueValidity,values_from=PSE)
  
  list(plot=p,wilcoxon=wilcox.test(sp$valid,sp$invalid,
                                   paired=TRUE,exact=FALSE))
}

res <- psych_plot(data, ISIframes, RespFlashBinary,"ISI (ms)","P(Two)")
res$plot
res$wilcoxon

res <- psych_plot(data, dt_top, ChoiceTop,"Contrast (%)","P(Top)")
res$plot
res$wilcoxon

