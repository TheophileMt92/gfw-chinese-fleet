# Animated global map of Chinese fishing effort accumulating through the year,
# with a weekly total panel above and an FAO area panel to the right.
#
# Run from the project root after prep/01_extract_china.R.
# Needs: install.packages(c("patchwork", "av", "maps"))

library(data.table)
library(ggplot2)
library(patchwork)

weekly <- as.data.table(readRDS("data/china_weekly.rds"))

# Set to a single year (e.g. 2020) to animate that year alone, or NULL for the
# 2017-2020 mean. 2020 has the best AIS coverage of the four.
use_year <- NULL

outdir <- "outputs/frames"
dir.create(outdir, recursive = TRUE, showWarnings = FALSE)

# Week 53 is partial and not present in every year.
weekly <- weekly[week %between% c(1, 52)]

if (is.null(use_year)) {
  n_years <- uniqueN(weekly$year)
  avg <- weekly[, .(hours = sum(fishing_hours) / n_years),
                by = .(lat, lon, week, fao_area)]
  period_label <- paste0(min(weekly$year), "-", max(weekly$year), " mean")
} else {
  avg <- weekly[year == use_year, .(hours = sum(fishing_hours)),
                by = .(lat, lon, week, fao_area)]
  period_label <- as.character(use_year)
}

wk_tot <- avg[, .(hours = sum(hours)), by = week][order(week)]

area_names <- c("61" = "NW Pacific", "87" = "SE Pacific", "71" = "WC Pacific",
                "77" = "EC Pacific", "51" = "W Indian", "34" = "EC Atlantic",
                "41" = "SW Atlantic", "57" = "E Indian", "81" = "SW Pacific",
                "47" = "SE Atlantic", "67" = "NE Pacific", "27" = "NE Atlantic",
                "37" = "Mediterranean", "31" = "WC Atlantic", "21" = "NW Atlantic")

top_areas <- avg[, .(h = sum(hours)), by = fao_area][order(-h)][1:6, fao_area]
area_wk <- avg[fao_area %in% top_areas, .(hours = sum(hours)),
               by = .(fao_area, week)]
area_wk[, label := area_names[as.character(fao_area)]]
area_wk[is.na(label), label := paste("Area", fao_area)]
area_lv <- area_wk[, .(h = sum(hours)), by = label][order(h), label]
area_wk[, label := factor(label, levels = area_lv)]

# ---- cumulative state per cell -----------------------------------------
setorder(avg, lat, lon, week)
cum_all <- avg[, .(lat, lon, week, hours)]
cum_all[, cum := cumsum(hours), by = .(lat, lon)]

# Carry each cell forward to every later week so the map accumulates rather
# than flickering: take the running total as at week wk.
cum_at <- function(wk) {
  cum_all[week <= wk, .(cum = sum(hours)), by = .(lat, lon)]
}

final_cum <- cum_at(52)
fill_lim <- c(0, log10(quantile(final_cum$cum, 0.999) + 1))
area_max <- max(area_wk$hours)
tot_max  <- max(wk_tot$hours)

magma <- c("#0b0724", "#3b0f70", "#8c2981", "#de4968", "#fe9f6d", "#fcfdbf")

land <- maps::map("world", plot = FALSE, fill = TRUE)
lnd <- data.frame(lon = land$x, lat = land$y, group = cumsum(is.na(land$x)))
lnd <- lnd[!is.na(lnd$lon), ]

week_start <- as.Date("2019-12-30") + (0:51) * 7

# ---- one frame ----------------------------------------------------------
draw_frame <- function(wk) {
  g <- cum_at(wk)
  g[, logh := log10(cum + 1)]
  lab <- format(week_start[wk], "%d %B")

  p_map <- ggplot() +
    geom_tile(data = g, aes(lon + 0.125, lat + 0.125, fill = logh),
              width = 0.25, height = 0.25) +
    geom_polygon(data = lnd, aes(lon, lat, group = group),
                 fill = "#2a2f36", colour = "#5a636c", linewidth = 0.15) +
    scale_fill_gradientn(colours = magma, limits = fill_lim,
                         oob = scales::squish,
                         breaks = c(0, 1, 2, 3, 4),
                         labels = c("1", "10", "100", "1,000", "10,000"),
                         name = "Cumulative fishing hours (log scale)") +
    coord_fixed(xlim = c(-180, 180), ylim = c(-60, 75), expand = FALSE) +
    labs(x = NULL, y = NULL) +
    theme_minimal(base_size = 12) +
    theme(panel.background = element_rect(fill = "#0b0724", colour = NA),
          panel.grid = element_blank(),
          axis.text = element_blank(),
          legend.position = "inside",
          legend.position.inside = c(0.012, 0.03),
          legend.justification.inside = c(0, 0),
          legend.direction = "horizontal",
          legend.key.width = unit(1.6, "cm"),
          legend.key.height = unit(0.22, "cm"),
          legend.title = element_text(size = 8, colour = "grey85", hjust = 0.5),
          legend.text = element_text(size = 7, colour = "grey85"),
          legend.background = element_rect(fill = alpha("#0b0724", 0.55),
                                           colour = NA),
          legend.margin = margin(4, 8, 4, 8),
          legend.title.position = "top",
          plot.margin = margin(1, 1, 1, 1))

  p_top <- ggplot(wk_tot, aes(week, hours)) +
    geom_col(fill = "#3a4148", width = 0.85) +
    geom_col(data = wk_tot[week == wk], fill = "#fe9f6d", width = 0.85) +
    scale_y_continuous(limits = c(0, tot_max * 1.05), expand = c(0, 0),
                       labels = scales::label_number(scale = 1e-3, suffix = "k")) +
    scale_x_continuous(breaks = c(1, 14, 27, 40),
                       labels = c("Jan", "Apr", "Jul", "Oct"),
                       expand = c(0.01, 0)) +
    labs(x = NULL, y = NULL,
         title = "Chinese industrial fishing fleet, effort accumulating through the year",
         subtitle = paste0("Week of ", lab, "   |   ", period_label,
                           "   |   weekly hours, all waters")) +
    theme_minimal(base_size = 11) +
    theme(panel.grid.minor = element_blank(),
          panel.grid.major.x = element_blank(),
          axis.text.y = element_text(size = 8),
          plot.title = element_text(face = "bold", size = 14),
          plot.subtitle = element_text(size = 10, colour = "grey35"),
          plot.margin = margin(4, 4, 1, 4))

  aw <- area_wk[week == wk]
  aw <- merge(data.table(label = factor(area_lv, levels = area_lv)), aw,
              by = "label", all.x = TRUE)
  aw[is.na(hours), hours := 0]

  p_right <- ggplot(aw, aes(hours, label)) +
    geom_col(fill = "#8c2981", width = 0.7) +
        geom_text(aes(label = ifelse(hours > 0, scales::label_number(scale = 1e-3,
                  suffix = "k", accuracy = 1)(hours), "")),
              hjust = -0.15, size = 2.4, colour = "grey40") +
    scale_x_continuous(limits = c(0, area_max * 1.3), expand = c(0, 0),
                       labels = NULL) +
    labs(x = NULL, y = NULL) +
    theme_minimal(base_size = 9) +
    theme(panel.grid.minor = element_blank(),
          panel.grid.major.y = element_blank(),
          axis.text.y = element_text(size = 8),
          plot.margin = margin(1, 2, 1, 1)) 
    

  row <- (p_map | p_right) + plot_layout(widths = c(11, 1))

  (p_top / row) +
    plot_layout(heights = c(1, 8)) +
    plot_annotation(
      caption = "Apparent fishing effort from AIS, Global Fishing Watch. Mainland Chinese flag (MMSI 412/413/414).",
      theme = theme(plot.caption = element_text(colour = "grey50", size = 8))
    )
}

# ---- render -------------------------------------------------------------
for (wk in 1:52) {
  ggsave(file.path(outdir, sprintf("frame_%03d.png", wk)),
         draw_frame(wk), width = 13, height = 5.9, dpi = 120, bg = "white")
  if (wk %% 10 == 0) cat("frame", wk, "\n")
}

# Hold the final frame so the finished map stays on screen
final <- file.path(outdir, "frame_052.png")
for (k in 53:60) file.copy(final, file.path(outdir, sprintf("frame_%03d.png", k)),
                           overwrite = TRUE)

frames <- sort(list.files(outdir, pattern = "^frame_.*\\.png$", full.names = TRUE))

if (requireNamespace("av", quietly = TRUE)) {
  # H.264 requires even pixel dimensions; the filter trims an odd row or column.
  av::av_encode_video(frames, "outputs/china_fleet_year.mp4", framerate = 6,
                      vfilter = "scale=trunc(iw/2)*2:trunc(ih/2)*2")
  cat("wrote outputs/china_fleet_year.mp4\n")
} else {
  gifski::gifski(frames, "outputs/china_fleet_year.gif",
                 width = 1560, height = 708, delay = 1/6)
  cat("wrote outputs/china_fleet_year.gif\n")
}
