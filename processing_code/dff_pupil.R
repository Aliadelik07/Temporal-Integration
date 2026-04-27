# importing modules -----

require(eyelinker)
require(dplyr)
require(tidyr)
require(ggplot2)
require(intervals)
require(stringr)
library("readxl")
library(readr)


peaks_list <- list()

sub = "subSH"

dat <- read.asc(paste0("/Users/ali/Documents/Experiment/DFF_data/",sub,".asc"))


viewing_distance <- 80 #cm to monitor

# importing time, pupil, coordinates ------
dfp <- data.frame(time = dat$raw$time, psl = dat$raw$psl, xl_deg = dat$raw$xpl/viewing_distance, yl_deg = dat$raw$ypl/viewing_distance,psr = dat$raw$psr, xr_deg = dat$raw$xpr/viewing_distance, yr_deg = dat$raw$ypr/viewing_distance)

# Events -------
dfp <- merge(dat$msg, dfp, by = "time", all = TRUE)

#blinks -------
dfp$blink <- 0

# Loop through each blink period and mark the blink column
for (i in 1:length(dat[["blinks"]][["stime"]])) {
  # Define the blink window for this blink
  start_time <- dat[["blinks"]][["stime"]][i] - 100
  end_time <- dat[["blinks"]][["etime"]][i] + 100
  
  # Mark time points within the blink window as 1
  dfp$blink[dfp$time >= start_time & dfp$time <= end_time] <- 1
}

#removeing blinks
dfp[dfp$blink == 1, c("psl", "xl_deg", "yl_deg","psr", "xr_deg", "yr_deg")] <- NA

#adding fixation ----
dfp$fix <- 0
# Loop through each fix period and mark the fix column
for (i in 1:length(dat[["fix"]][["stime"]])) {
  # Define the fixation window for this fixation
  start_time <- dat[["fix"]][["stime"]][i]
  end_time <- dat[["fix"]][["etime"]][i]
  
  # Mark time points within the fix window as 1
  dfp$fix[dfp$time >= start_time & dfp$time <= end_time] <- 1
}

# combine both eyes
dfp$xc_deg <- rowMeans(dfp[, c("xr_deg", "xl_deg")], na.rm = TRUE)
dfp$yc_deg <- rowMeans(dfp[, c("yr_deg", "yl_deg")], na.rm = TRUE)
dfp$psc <- rowMeans(dfp[, c("psr", "psl")], na.rm = TRUE)


# Create the plot with custom color gradient
hfig <- ggplot(dfp, aes(x = xc_deg, y = yc_deg)) +
  geom_bin2d() +
  scale_fill_gradientn(
    colors = c("blue", "green", "red"),
    trans = "log",
    name = "Count"
  ) +
  labs(
    title = "Heatmap of Eye Positions",
    x = "Horizontal",
    y = "Vertical"
  ) +
  theme_minimal()

hfig

dfp <- dfp %>%
  mutate(direction_deg = atan2(lead(yc_deg) - yc_deg,
                               lead(xc_deg) - xc_deg) * 180 / pi)

ggplot(dfp, aes(x = direction_deg)) +
  geom_histogram(binwidth = 10, fill = "steelblue") +
  xlim(-180, 180) +
  labs(title = "Saccade Distribution of Direction_deg") +
  theme_minimal()

# microsaccade -----
# Define the sampling rate and delta_t
delta_t <- 0.002  # 2 ms

# Compute horizontal velocity component using a centered difference method
dfp <- dfp %>%
  mutate(vxr = (lead(xr_deg, 2) + lead(xr_deg, 1) - lag(xr_deg, 1) - lag(xr_deg, 2)) / (6 * delta_t),
         vyr = (lead(yr_deg, 2) + lead(yr_deg, 1) - lag(yr_deg, 1) - lag(yr_deg, 2)) / (6 * delta_t),
         vxl = (lead(xl_deg, 2) + lead(xl_deg, 1) - lag(xl_deg, 1) - lag(xl_deg, 2)) / (6 * delta_t),
         vyl = (lead(yl_deg, 2) + lead(yl_deg, 1) - lag(yl_deg, 1) - lag(yl_deg, 2)) / (6 * delta_t))

sigma_xr = (median((dfp$vxr)^2,na.rm = TRUE) - median(dfp$vxr, na.rm = TRUE)^2)^0.5
sigma_yr = (median((dfp$vyr)^2,na.rm = TRUE) - median(dfp$vyr, na.rm = TRUE)^2)^0.5
sigma_xl = (median((dfp$vxl)^2,na.rm = TRUE) - median(dfp$vxl, na.rm = TRUE)^2)^0.5
sigma_yl = (median((dfp$vyl)^2,na.rm = TRUE) - median(dfp$vyl, na.rm = TRUE)^2)^0.5

# Calculate the velocity magnitude (Euclidean norm of vx and vy)
dfp <- dfp %>%
  mutate(velocity_r = sqrt(vxr^2 + vyr^2),velocity_l = sqrt(vxl^2 + vyl^2))

lambda <- 6 # threshold

# Calculate thresholds for microsaccade detection
threshold_xr <- lambda * sigma_xr
threshold_yr <- lambda * sigma_yr
threshold_xl <- lambda * sigma_xl
threshold_yl <- lambda * sigma_yl

# Apply the microsaccade detection criterion
dfp <- dfp %>%
  mutate(ms = ifelse(fix == 1 &
                       ((vxr / threshold_xr)^2 + (vyr / threshold_yr)^2 > 1) &
                       ((vxl / threshold_xl)^2 + (vyl / threshold_yl)^2 > 1),
                     1, 0))


# Compute magnitude (Euclidean distance between consecutive points)
dfp <- dfp %>%
  mutate(magnitude_c = sqrt((lead(xc_deg, 1) - xc_deg)^2 + (lead(yc_deg, 1) - yc_deg)^2))

# Find peaks (local maxima of velocity)
dfp$velocity_c <- rowMeans(dfp[, c("velocity_r", "velocity_l")], na.rm = TRUE)
dfp <- dfp %>%
  mutate(v_peak = (velocity_c > lag(velocity_c)) & (velocity_c > lead(velocity_c)))

# Filter to get only peak velocities during micro-saccade
peaks <- dfp %>%
  filter(v_peak == TRUE, ms == 1) %>%
  select(time, velocity_c, magnitude_c)

# Add the processed data frame to the list
peaks_list[[1]] <- peaks




# Combine all data frames into one
peaks_combined <- bind_rows(peaks_list)

fig <- ggplot(peaks, aes(x = magnitude_c, y = velocity_c)) +
  geom_point(color = 'blue') +
  geom_smooth(method = 'lm', color = 'red', se = TRUE) +  # Optional: Add a trend line
  labs(title = sub, x = "Magnitude (degrees)", y = "Peak Velocity (degrees per second)") +
  theme_minimal()

print(fig)

ggplot(subset(dfp,ms==1), aes(x = direction_deg)) +
  geom_histogram(binwidth = 10, fill = "steelblue") +
  xlim(-180, 180) +
  labs(title = "Microsaccade Distribution of Direction_deg") +
  theme_minimal()

hfig <- ggplot(subset(dfp, ms == 1), aes(x = xc_deg, y = yc_deg)) +
  geom_bin2d() +
  scale_fill_gradientn(
    colors = c("blue", "green", "red"),
    trans = "log",
    name = "Count"
  ) +
  labs(
    title = "Heatmap of Eye Positions",
    x = "Horizontal",
    y = "Vertical"
  ) +
  theme_minimal()

hfig

write.csv(dfp, paste0("/Users/ali/Documents/Experiment/DFF_data/",sub,"_pupil.csv"))

#dfp <- read_csv(paste0("/Users/ali/Documents/Experiment/DFF_data/subOC_pupil.csv"))
