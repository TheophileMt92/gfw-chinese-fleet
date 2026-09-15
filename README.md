# Chinese fleet: reach and concentration

Animated map of Chinese fishing effort through 2020, built from Global Fishing
Watch AIS data.

Work in progress.

## Reproducing

    source("prep/01_extract_china.R")   # needs the raw GFW daily CSVs
    source("R/02_explore.R")
    source("R/03_animate.R")

Raw GFW daily CSVs are not committed. Set `daily_dir` in prep/01_extract_china.R
to wherever they live locally.
