# Data quality log

Issues found in the source files and how the workbook handles each one. The same log is on the `Data_Quality` sheet.

| # | Issue | Evidence | Treatment | Status |
|---|---|---|---|---|
| 1 | Item names embed units and have irregular spaces | Raw names such as "Rice(red)open market  Matta (Kg.)" (double spaces, unit suffixes) | Names and units cleaned in Dim_Item; display label = name [unit]; all joins use item_id | Fixed |
| 2 | Two coconut items differ only by capitalisation/unit | item 20 "Coconut without Husk" (Kg, ~Rs 53) vs item 56 "Coconut without husk" (10 Nos, ~Rs 247) | Keyed on item_id; unit shown in label (Excel PivotTables/XLOOKUP are case-insensitive and would merge them) | Fixed |
| 3 | Mixed units across items | Kg, Ltr, Dozen, 100gm, 10 Nos | Never average prices across items; use % changes and indexed comparisons only | By design |
| 4 | Uneven district coverage by item | Some items reported by 1-3 districts (e.g. Mysore Vella rice: Wayanad only; KLF Nirmal coconut oil: Kollam 35 rows, Palakkad 399) | Confidence flag (High/Medium/Low) from districts reporting; Low items excluded from ranking, not scored zero | Handled |
| 5 | Overall cell coverage about 80% | 701,948 rows vs 14 districts x 72 items x 874 dates = 880,992 possible | Monthly aggregates need >=5 daily observations per district-month | Handled |
| 6 | Source district_volatility.csv pools all items | Mean/std taken across items priced Rs 4 to Rs 570 in different units, so values (80-95%) reflect basket mix, not volatility | Not used; district view uses % premium vs state average per item | Replaced |
| 7 | Source risk score mixed trend with volatility | Coconut oil (Kera) averaged Rs 161 in 2023 and Rs 375 in 2025; its high "volatility" was a level shift | New score separates volatility, deviation vs 12M average, YoY and momentum | Replaced |
| 8 | Latest day has low coverage | 27 Feb 2026: only 6 of 14 districts reported tomato (13-14 on normal days), so the day average (Rs 21.8) is not comparable | Monthly figures use district monthly means (>=5 obs), so one thin day has little effect; days with <10 districts are dropped from the Forecast actual series | Handled |
| 9 | Feb 2026 has 21 reporting days | Feb 2025 had 22; data ends 27 Feb | Treated as a normal month; "Data through" date shown on Dashboard | Noted |
| 10 | Seasonal index rests on 3 years | Tomato July index of 171 largely reflects the 2023 spike (Q3 2023 averaged Rs 73 vs Rs 46 and Rs 41 later) | Seasonal pressure carries only 10% weight and is labelled indicative | Noted |
| 11 | Source grouping quirks | Onion small is grouped under Spices And Condiments, Onion big under Fruits And Vegetables, Carrot/Beetroot under Tubers | Source groups kept as supplied (group-level views follow them); remap in Dim_Item if needed | Noted |
| 12 | Working-day reporting pattern | No Sunday records; Saturdays appear on 119 of about 164 Saturdays; 69 Monday-Friday dates are absent (874 reporting dates in 1,152 calendar days) | Absent dates are not treated as missing data; coverage is measured against reporting dates, and monthly metrics need >=5 daily observations per district-month | Noted |
| 13 | Prices often unchanged day to day | 88.9% of daily prices equal the previous record for the same district and commodity; no single date has more than 94.5% unchanged, so no whole-day copies. The source dashboard is reported to show the last available day when data are missing, so some unchanged values may be carried forward | Cannot separate stale from genuinely unchanged prices; monthly means dampen but do not remove the effect; treat very low volatility with caution | Limitation |
| 14 | Single-day jumps | 224 daily changes above 50% (6 above 100%), mostly vegetables | Left in the data (plausible for perishables); monthly means damp their effect | Noted |
| 15 | Forecast files cover 3 items only; method undocumented | Tomato, Ladies Finger, Coconut oil (Kera); 90 days from 28 Feb 2026; Tomato forecast starts well above recent actuals | Shown as scenarios with sanity checks; backtest recommended before use | Open |
| 16 | No supply-side data | Dataset has prices only | "Supply stress" inferred from district dispersion, breadth of rise and seasonality; add arrivals/stock/rainfall as next step | Limitation |

## Source file quality report (`data/data_quality_report.csv`)

| file      |   rows | date_min   | date_max   |   unique_dates |   districts |   items |   missing_price |   low_coverage_days |
|:----------|-------:|:-----------|:-----------|---------------:|------------:|--------:|----------------:|--------------------:|
| 2023.xlsx | 220899 | 2023-01-03 | 2023-12-30 |            273 |          14 |      70 |               0 |                   0 |
| 2024.xlsx | 220689 | 2024-01-01 | 2024-12-31 |            277 |          14 |      72 |               0 |                   5 |
| 2025.xlsx | 225092 | 2025-01-01 | 2025-12-31 |            279 |          14 |      72 |               0 |                   2 |
| 2026.xlsx |  35268 | 2026-01-01 | 2026-02-27 |             45 |          14 |      72 |               0 |                   2 |

Totals: 701,948 rows, 874 reporting dates, no missing prices. The threshold used to flag a low-coverage day is not documented in the source report.
