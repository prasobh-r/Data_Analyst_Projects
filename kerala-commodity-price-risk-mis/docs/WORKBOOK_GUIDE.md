# Workbook guide

`Kerala_Commodity_Price_Risk_MIS.xlsx` has 17 sheets and about 120,000 formulas. The workbook holds monthly aggregates so it stays fast; the daily table stays in `data/`.

## Using the dashboard

1. Choose a month in **C4** (Jan 2024 to Feb 2026; earlier months lack the 12 months of history needed for scoring).
2. Choose a commodity in **G4** for the two trend charts (commodities with the full 38-month history).
3. Red and Amber counts, the highest-risk commodity, the largest monthly rise, the statewide-spread count and the average score update for the selected month.
4. The Top 10 table, the charts and the commentary are formula-driven. The analyst notes at the bottom are static text for Feb 2026.

## Sheets

| Sheet | Purpose |
|---|---|
| `Dashboard` | Month and commodity selectors, KPI cards, Top 10 alerts, four charts, auto commentary, analyst notes |
| `Watchlist` | Top 15 exception report with suggested actions; five largest rises and falls |
| `Group_Heatmap` | 12-month risk heatmap by commodity group and for the current Top 15 |
| `District_View` | District price premium vs the state average by commodity group |
| `Forecast` | Supplied 90-day forecasts for three commodities with sanity checks (not backtested) |
| `Assumptions` | Scoring weights, caps and thresholds (blue input cells) |
| `Month_View`, `Chart_Data` | Helper sheets driven by the selected month |
| `Data_Calc` | Commodity x month table (2,736 rows): source aggregates plus live formulas for every metric and the risk score |
| `Data_District` | District x commodity x month prices (31,103 rows) |
| `Dim_Item`, `Seasonal`, `Months`, `Lists` | Reference tables |
| `Data_Quality` | Issue log and source-file quality report |
| `Model_Guide` | Steps and DAX measures to rebuild the full Power Pivot model |
| `README` | In-workbook documentation |

Colour conventions: blue text on yellow = inputs you can change; blue headers = source data; teal headers = formulas.
