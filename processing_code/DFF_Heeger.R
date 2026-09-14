library(dplyr)
library(tidyr)
library(ggplot2)
library(minpack.lm)

compute_dprime <- function(df, response_col, group_vars) {
  
  eps <- 1e-6
  
  out <- df %>%
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
      
      phi_z = dnorm(z),
      se_dprime = sqrt(2) * se_p / phi_z,
      
      ci_low = dprime - 1.96 * se_dprime,
      ci_high = dprime + 1.96 * se_dprime
    )
  
  # Shift everything upward if needed
  shift <- max(0, -min(out$dprime, na.rm = TRUE))
  
  out %>%
    mutate(
      dprime = dprime + shift,
      ci_low = ci_low + shift,
      ci_high = ci_high + shift
    )
}



data <- read.csv("D:/DFF_data/data.csv")


p_spatial_c <- compute_dprime(
  data,
  response_col = "RespProbeBinary",
  group_vars = c("dtcolor", "CueValidity")
)

p_spatial_c$x <-p_spatial_c$dtcolor

p_temp_isi <- compute_dprime(
  subset(data,ISIframes>1),
  response_col = "RespFlashBinary",
  group_vars = c("ISIframes", "CueValidity")
)
p_temp_isi$x <- p_temp_isi$ISIframes

# ---------------------------------------------------------
# Fit g, n and halfISI separately for each CueValidity
# ---------------------------------------------------------

fits <- p_spatial_c %>%
  group_by(CueValidity) %>%
  group_modify(~ {
    
    dat <- .x
    
    # Maximum observed d-prime for this CueValidity
    max_dp <- max(dat$dprime, na.rm = TRUE)
    
    # Fit model
    fit <- nlsLM(
      dprime ~ g * max_dp *
        (x^n /
           (x^n + halfx^n)),
      
      data = dat,
      
      start = list(
        g = 1,
        n = 2,
        halfx = 15
      ),
      
      lower = c(
        g = -Inf,
        n = 0.01,
        halfx = 0.01
      ),
      
      upper = c(
        g = Inf,
        n = 20,
        halfx = Inf
      ),
      
      weights = 1 / se_dprime^2
    )
    
    tibble(
      g = coef(fit)[["g"]],
      n = coef(fit)[["n"]],
      halfx = coef(fit)[["halfx"]],
      max_dprime = max_dp
    )
  }) %>%
  ungroup()


# ---------------------------------------------------------
# Look at the three sets of fitted parameters
# ---------------------------------------------------------

fits


pred <- fits %>%
  tidyr::crossing(
    x = seq(
      min(p_spatial_c$x),
      max(p_spatial_c$x),
      length.out = 300
    )
  ) %>%
  mutate(
    dprime_fit =
      g * max_dprime *
      (x^n /
         (x^n + halfx^n))
  )

ggplot(
  p_spatial_c,
  aes(x = x*100, y = dprime, colour = CueValidity)
) +
  
  geom_errorbar(
    aes(ymin = ci_low, ymax = ci_high),
    width = 0,
    alpha = 0.4
  ) +
  
  geom_point(size = 3) +
  
  geom_line(
    data = pred,
    aes(y = dprime_fit),
    linewidth = 1.2
  ) + scale_colour_manual(values = c(
    valid = "darkred",
    invalid = "darkblue",
    neutral = "black"
  )) +
  labs(x = "Contrast (%)" , y = "dPrime" , colour = "") +
  theme_classic() +
  theme(legend.position = "top", aspect.ratio = 1)






# ---------------------------------------------------------
# Fit g, n and halfISI separately for each CueValidity
# ---------------------------------------------------------

fits <- p_temp_isi %>%
  group_by(CueValidity) %>%
  group_modify(~ {
    
    dat <- .x
    
    # Maximum observed d-prime for this CueValidity
    max_dp <- max(dat$dprime, na.rm = TRUE)
    
    # Fit model
    fit <- nlsLM(
      dprime ~ g * max_dp *
        (x^n /
           (x^n + halfx^n)),
      
      data = dat,
      
      start = list(
        g = 1,
        n = 2,
        halfx = 15
      ),
      
      lower = c(
        g = -Inf,
        n = 0.01,
        halfx = 0.01
      ),
      
      upper = c(
        g = Inf,
        n = 20,
        halfx = Inf
      ),
      
      weights = 1 / se_dprime^2
    )
    
    tibble(
      g = coef(fit)[["g"]],
      n = coef(fit)[["n"]],
      halfx = coef(fit)[["halfx"]],
      max_dprime = max_dp
    )
  }) %>%
  ungroup()


# ---------------------------------------------------------
# Look at the three sets of fitted parameters
# ---------------------------------------------------------

fits


pred <- fits %>%
  tidyr::crossing(
    x = seq(
      min(p_temp_isi$x),
      max(p_temp_isi$x),
      length.out = 300
    )
  ) %>%
  mutate(
    dprime_fit =
      g * max_dprime *
      (x^n /
         (x^n + halfx^n))
  )

ggplot(
  p_temp_isi,
  aes(x = x, y = dprime, colour = CueValidity)
) +
  
  geom_errorbar(
    aes(ymin = ci_low, ymax = ci_high),
    width = 0,
    alpha = 0.4
  ) +
  
  geom_point(size = 3) +
  
  geom_line(
    data = pred,
    aes(y = dprime_fit),
    linewidth = 1.2
  ) + scale_colour_manual(values = c(
    valid = "darkred",
    invalid = "darkblue",
    neutral = "black"
  )) +
  labs(x = "ISI (ms)" , y = "dPrime" , colour = "") +
  theme_classic() +
  theme(legend.position = "top", aspect.ratio = 1)

