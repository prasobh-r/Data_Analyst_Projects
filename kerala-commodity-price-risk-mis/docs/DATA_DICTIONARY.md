# Data dictionary

**Source:** daily retail prices from the Department of Economics and Statistics, Government of Kerala (ecostat.kerala.gov.in), collected on working days at the 14 district headquarters; yearly source files 2023 to 2026 cleaned into the files below. Independent analysis, not official statistics.

## Input files (`data/`)

| File | Columns |
|---|---|
| `fact_daily_prices_clean.csv` | `price_id`, `date_id` (to dim_date), `district_id` (to dim_district), `item_id` (to dim_item), `price` (Rs per the item's unit), `source_file` (yearly source file) |
| `dim_item.csv` | `item_id`, `item_name_raw` (as in source), `item_name_clean`, `item_group`, `unit` (Kg, Ltr, Dozen, 100gm, 10 Nos, ...) |
| `dim_district.csv` | `district_id`, `district_name` |
| `dim_date.csv` | `full_date`, `date_id`, `year`, `month`, `month_name`, `quarter` |
| `seasonal_index.csv` | `item_id`, `item_name_clean`, `month` (1 to 12), `Price` (month mean), `yearly_avg`, `seasonal_index` (100 = yearly average) |
| `forecast_<item>.csv` | `date`, `predicted_price`, `lower_bound`, `upper_bound`, `item_name` (90 days from 28 Feb 2026; method undocumented) |
| `data_quality_report.csv` | `file`, `rows`, `date_min`, `date_max`, `unique_dates`, `districts`, `items`, `missing_price`, `low_coverage_days` |

## Archived files (`archive/`)

| File | Status |
|---|---|
| `monthly_price_changes.csv` | Cross-check only (item, month, average price, MoM %, YoY %) |
| `commodity_risk_scores.csv` | Superseded (CV-based score mixing trend and volatility) |
| `district_volatility.csv` | Superseded (pooled items of different units) |

## Workbook table: `Data_Calc` (one row per commodity x month; 72 x 38 = 2,736 rows)

| Column | Type | Description |
|---|---|---|
| item_id, Month | Input | Keys; month = first day of month |
| Key | Formula | item_id x 1,000,000 + yyyymm (used by lookups) |
| Group | Formula | Commodity group from `Dim_Item` |
| Month idx | Input | 1 (Jan 2023) to 38 (Feb 2026) |
| State avg price | Input (aggregate) | Equal-weight mean of district monthly means |
| Districts reporting | Input (aggregate) | Districts with at least 5 observations in the month |
| District dispersion (CV) | Input (aggregate) | Std / mean across districts |
| Breadth of rise | Input (aggregate) | Share of districts more than 10% above own 12M average |
| Seasonal index | Formula | Lookup from `Seasonal` |
| MoM %, YoY %, 12M avg, vs 12M avg %, Volatility (12M) | Formula | See `METHODOLOGY.md` section 3 |
| Confidence, Scored? | Formula | High / Medium / Low / No data; 1 if eligible |
| Score: momentum, volatility, deviation, YoY, dispersion, breadth, seasonal | Formula | 0 to 100 component scores |
| RISK SCORE, Class, Risk type, Spread signal | Formula | Final outputs |

## Other workbook tables

| Sheet | Grain | Notes |
|---|---|---|
| `Data_District` | District x commodity x month (31,103 rows) | District monthly mean, state mean, premium (formula), eligibility (formula) |
| `Dim_Item` | Commodity (72) | Cleaned name, unit, display label (`name [unit]`), group, months with data, districts reporting |
| `Seasonal` | Commodity x calendar month (864) | Index and lookup key |
| `Months` | Month (38) | Label, days reported, last date reported |
| `Lists` | 69 commodities | Drop-down source for the trend charts (full 38-month history only) |
| `Month_View` | Commodity (72) | All metrics for the month selected on the Dashboard; ranks |
| `Chart_Data` | Helper | Top 10, selected commodity series, class counts by group |

## Units

Prices are retail prices in Rs per the item's unit. Never average prices across items; compare items only through % changes and scores.
