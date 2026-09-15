# Chinese-flagged fishing effort from the GFW daily CSVs, 2017 to 2020.
# Writes a weekly 0.25 degree grid for animation, an annual cell total, and
# effort summarised by FAO major fishing area.
# Run once from the project root.

library(data.table)
library(sf)

sf_use_s2(FALSE)   # the 2005 FAO polygons have self-intersections s2 rejects

raw_dir <- "raw"
fao_shp <- "~/Desktop/Work/gfw-seasonality/raw/fao/World_Fao_Zones.shp"

dir.create("data", showWarnings = FALSE)

# Mainland China: MIDs 412, 413, 414. Taiwan (416) is excluded.
china_mid <- c("412", "413", "414")

year_dirs <- list.dirs(raw_dir, recursive = FALSE)
year_dirs <- year_dirs[grepl("mmsi-daily-csvs", year_dirs)]
stopifnot(length(year_dirs) > 0)
cat("found", length(year_dirs), "year folders\n")

read_year <- function(dir) {
  files <- list.files(dir, pattern = "\\.csv$", full.names = TRUE)
  yr <- as.integer(sub(".*-(\\d{4})$", "\\1", dir))
  cat("\n", yr, ":", length(files), "files\n")

  acc <- vector("list", length(files))
  for (i in seq_along(files)) {
    d <- fread(files[i], showProgress = FALSE)
    d <- d[fishing_hours > 0]
    d[, mid := substr(as.character(mmsi), 1, 3)]
    d <- d[mid %chin% china_mid]
    if (!nrow(d)) next

    dt <- as.Date(d$date[1])
    d[, `:=`(
      year  = yr,
      week  = as.integer(format(dt, "%V")),
      month = as.integer(format(dt, "%m")),
      lat   = floor(cell_ll_lat * 4) / 4,
      lon   = floor(cell_ll_lon * 4) / 4
    )]
    acc[[i]] <- d[, .(fishing_hours = sum(fishing_hours),
                      vessels = uniqueN(mmsi)),
                  by = .(year, lat, lon, week, month)]
    if (i %% 50 == 0) cat("   ", i, "\n")
  }
  rbindlist(acc, use.names = TRUE)
}

eff <- rbindlist(lapply(year_dirs, read_year), use.names = TRUE)
gc()

weekly <- eff[, .(fishing_hours = round(sum(fishing_hours), 1),
                  vessels = sum(vessels)),
              by = .(year, lat, lon, week, month)]
rm(eff); gc()

# ---- assign FAO major fishing area to each cell -------------------------
cells <- unique(weekly[, .(lat, lon)])
pts <- st_as_sf(cells, coords = c("lon", "lat"), crs = 4326, remove = FALSE)
fao <- st_make_valid(st_read(path.expand(fao_shp), quiet = TRUE))

hits <- as.data.table(st_join(pts, fao["zone"], join = st_intersects))
hits <- unique(hits, by = c("lat", "lon"))
cells <- hits[cells, on = c("lat", "lon")]
setnames(cells, "zone", "fao_area")
cells[, geometry := NULL]

na_idx <- which(is.na(cells$fao_area))
if (length(na_idx)) {
  near <- st_nearest_feature(pts[na_idx, ], fao)
  cells[na_idx, fao_area := fao$zone[near]]
}

weekly <- cells[weekly, on = c("lat", "lon")]

# ---- outputs ------------------------------------------------------------
annual <- weekly[, .(fishing_hours = sum(fishing_hours)), by = .(year, lat, lon)]

by_area <- weekly[, .(fishing_hours = sum(fishing_hours),
                      cells = uniqueN(paste(lat, lon))),
                  by = .(year, fao_area)]
setorder(by_area, year, -fishing_hours)

saveRDS(weekly,  "data/china_weekly.rds",  compress = "xz")
saveRDS(annual,  "data/china_annual.rds",  compress = "xz")
saveRDS(by_area, "data/china_by_area.rds", compress = "xz")

cat("\n--- summary ---\n")
print(weekly[, .(hours = round(sum(fishing_hours)),
                 cells = uniqueN(paste(lat, lon))), by = year][order(year)])

cat("\n--- top FAO areas by year ---\n")
print(by_area[, head(.SD, 6), by = year])

cat("\nweekly file:", round(file.size("data/china_weekly.rds") / 1e6, 2), "MB\n")
