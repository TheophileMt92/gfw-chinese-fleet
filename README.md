# Chinese industrial fishing fleet: a year of effort

An animated global map of Chinese-flagged industrial fishing effort accumulating
through an average year, built from Global Fishing Watch AIS data for 2017-2020.

![](outputs/china_fleet_year.mp4)

## What it shows

The map accumulates fishing hours per 0.25 degree cell from the first week of
January onwards, so by the end of the loop it is the full annual footprint. The
panel above tracks weekly effort across all waters; the panel to the right breaks
the current week down by FAO major fishing area.

Two things come out of it.

**Most of the effort is close to home.** Around three quarters of Chinese fishing
hours fall in FAO Area 61, the Northwest Pacific, inside roughly 8% of the cells
the fleet touches globally. The remaining quarter is spread across five
distant-water areas covering tens of thousands of cells.

**The annual rhythm is a management signal.** Effort in the Northwest Pacific
collapses by more than 90% between weeks 18 and 19 and stays down until week 31.
That is China's summer fishing moratorium, in force from 1 May to 16 September,
and it is visible in the data without any need to look for it.

Across 2017-2020 the fleet fished 113,511 distinct cells at least once, against
roughly 66,000 in any single year.

## Pipeline

    prep/01_extract_china.R   # raw GFW daily CSVs -> weekly grid + FAO areas
    R/02_animate_china.R      # renders 52 frames and encodes the video

Raw GFW daily CSVs are not committed; they run to several gigabytes per year. Set
`raw_dir` and `fao_shp` in the extraction script to wherever they live locally.
The extraction writes three small files to `data/`, which are committed.

The FAO major fishing area polygons come from the pipeline in
[gfw-seasonality](https://github.com/TheophileMt92/gfw-seasonality).

## Method notes

Flag state is derived from the first three digits of each MMSI, the Maritime
Identification Digits. Mainland China is 412, 413 and 414. Taiwan (416) is
deliberately excluded.

Frames average the four years rather than showing a single one. AIS coverage
improved over the period, so year-on-year differences in detected effort cannot
cleanly be separated from improvements in detection, and no trend is claimed here.

Cells are 0.25 degrees and so shrink in area toward the poles. The colour scale is
logarithmic and fixed across every frame.

## Caveats

This is the industrial fleet, not the fishing fleet. AIS carriage is mandatory for
large vessels and largely absent below roughly 25 metres, so small-scale fishing
is essentially invisible here. Apparent fishing effort is a model output: Global
Fishing Watch classifies vessel behaviour to infer fishing rather than steaming,
and that classification carries its own error. AIS can also be switched off.

## Licence

Code MIT. Fishing effort data: Global Fishing Watch, CC BY 4.0.
