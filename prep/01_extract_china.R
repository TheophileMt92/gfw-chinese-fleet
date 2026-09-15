# Extract Chinese-flagged fishing effort from the GFW 2020 daily CSVs.
# Writes a weekly 0.25 degree grid for animation, plus an annual cell total.
# Run once from the project root.

library(data.table)

# Raw GFW daily CSVs live outside this repo. Point this wherever they are.
daily_dir <- "~/Desktop/Work/gfw-seasonality/raw/mmsi-daily-csvs-10-v2-2020"

dir.create("data", showWarnings = FALSE)

# Chinese MIDs. 412, 413 and 414 are mainland China; 416 is Taiwan and is
# deliberately excluded here.
china_mid <- c("412", "413", "414")

files <- list.files(path.expand(daily_dir), pattern = "\\.csv$", full.names = TRUE)
stopifnot(length(files) > 0)
cat(length(files), "daily files\n")

acc <- vector("list", length(files))

for (i in seq_along(files)) {
  d <- fread(files[i], showProgress = FALSE)
  d <- d[fishing_hours > 0]
  d[, mid := substr(as.character(mmsi), 1, 3)]
  d <- d[mid %chin% china_mid]
  if (!nrow(d)) next

  dt <- as.Date(d$date[1])
  d[, `:=`(
    week  = as.integer(format(dt, "%V")),
    month = as.integer(format(dt, "%m")),
    # 0.25 degree bins: fine enough to read, coarse enough to animate
    lat   = floor(cell_ll_lat * 4) / 4,
    lon   = floor(cell_ll_lon * 4) / 4
  )]

  acc[[i]] <- d[, .(fishing_hours = sum(fishing_hours),
                    vessels = uniqueN(mmsi)),
                by = .(lat, lon, week, month)]

  if (i %% 25 == 0) cat("  ", i, "files\n")
}

eff <- rbindlist(acc, use.names = TRUE)
rm(acc); gc()

# Collapse to one row per cell per week
weekly <- eff[, .(fishing_hours = round(sum(fishing_hours), 1),
                  vessels = sum(vessels)),
              by = .(lat, lon, week, month)]

# Annual total per cell, for the concentration analysis
annual <- weekly[, .(fishing_hours = sum(fishing_hours)), by = .(lat, lon)]
setorder(annual, -fishing_hours)
annual[, cum_share := cumsum(fishing_hours) / sum(fishing_hours)]

saveRDS(weekly, "data/china_weekly.rds", compress = "xz")
saveRDS(annual, "data/china_annual.rds", compress = "xz")

cat("\nweekly:", nrow(weekly), "rows,",
    round(file.size("data/china_weekly.rds") / 1e6, 2), "MB\n")
cat("annual:", nrow(annual), "cells,",
    round(file.size("data/china_annual.rds") / 1e6, 2), "MB\n")
cat("total fishing hours:", format(round(sum(annual$fishing_hours)), big.mark = ","), "\n")
cat("cells holding half the effort:", which(annual$cum_share >= 0.5)[1], "\n")
