# Methodology

## 1. Scope and design choice

The dataset contains **prices only**. The workbook therefore measures **upward price pressure** and uses three proxies for supply stress (district dispersion, breadth of rise, seasonality). It is an early-warning indicator for monthly MIS review, not a shortage forecast.

Risk is defined from the consumer / procurement side: only price **rises** score. Price falls do not add risk, though they appear in the "largest monthly falls" list.

## 2. From daily prices to monthly metrics

1. **District-month mean.** For each commodity and district, the mean of daily prices in the month. A district-month needs at least **5 daily observations** to count.
2. **State average** = equal-weight mean of the district monthly means for districts reporting that commodity. (A plain average over daily rows would weight districts by how often they report.) The result matches the earlier `monthly_price_changes.csv` closely: median difference 0.02%, 95th percentile 0.23%, maximum 4.7% (for commodities reported by only 2 districts).
3. **Districts reporting** = number of districts counted in step 2.
4. **District dispersion** = coefficient of variation (std / mean) of the district monthly means; defined when at least 3 districts report.
5. **Breadth of rise** = share of reporting districts whose monthly mean is more than 10% above their own trailing-12-month average (prior 12 months, at least 6 months of history); defined when at least 3 districts have history.

The aggregation is done once in Python (`scripts/01_prepare_monthly.py`) because formulas cannot practically run over 700K rows. Everything after this step is a live Excel formula.

## 3. Metrics computed by Excel formulas (`Data_Calc`)

| Metric | Definition |
|---|---|
| MoM % | State average / previous month - 1 |
| YoY % | State average / same month last year - 1 |
| 12M average (prior) | Mean of the previous 12 monthly state averages (needs at least 8) |
| vs 12M average % | State average / 12M average - 1 |
| Volatility (12M) | Sample std deviation of the last 12 monthly MoM changes (needs at least 8) |
| Seasonal index | From `data/seasonal_index.csv` for the commodity and calendar month |
| Confidence | High: at least 10 districts; Medium: at least 5; Low: fewer (thresholds on `Assumptions`) |

**Scored?** requires at least 12 months of history (month index 13 or later, so Jan 2024 onward), valid MoM, deviation and volatility, and High or Medium confidence.

## 4. Risk score

Each component is converted to 0 to 100 with a cap, then combined with weights:

`component score = MIN(1, MAX(0, value / cap)) x 100` (volatility, dispersion and breadth are never negative)

| Component | Value used | Weight | Cap |
|---|---|---|---|
| Momentum | MoM % (rises only) | 20% | 15% |
| Volatility | 12M std of MoM | 15% | 15% |
| Deviation | vs 12M average % (rises only) | 20% | 30% |
| YoY | YoY % (rises only) | 15% | 60% |
| Dispersion | District CV | 10% | 25% |
| Breadth | Breadth of rise | 10% | 50% |
| Seasonal | (Seasonal index - 100) | 10% | 25 points |

`Risk score = sum(weight x component score) / sum(weights)`. Missing dispersion, breadth or seasonal values contribute 0.

**Class:** Red at 65 or above, Amber at 40 or above, otherwise Green.
**Risk type** (first match): *Sustained surge* (YoY at least 40% and price at least 10% above its 12M average), *Short-term spike* (MoM at least 20%), *Volatile* (volatility at least 12%), otherwise *Stable*.
**Spread signal:** *Statewide* (breadth at least 50%), *Regional* (at least 20%), otherwise *Isolated/none*.

## 5. Calibration history (transparency)

- **Caps** were set near the upper percentiles of the 2024 to Feb 2026 distribution: momentum 15% (about the 95th percentile of MoM rises), deviation 30% (about the 95th), volatility 15% (about the 90th), dispersion 25% and YoY 60% (above the 95th), seasonal 25 points (about the 99th). Percentiles are approximate and were taken on the first scoring sample.
- **First version** had six components without YoY and scored coconut oil only Amber at its peak (+143% YoY), because the rise was steady rather than volatile. A YoY component was added, weights were rebalanced, and the Red threshold was set at 65 so that Red remains a small, reviewable list (0 to 10 commodities per month).
- These are judgement calls. The weights, caps and thresholds are inputs on the `Assumptions` sheet so reviewers can test sensitivity.

## 6. Why the original risk table was replaced

`archive/commodity_risk_scores.csv` ranked commodities by coefficient of variation over the whole period, which mixes long-run trend with volatility (coconut oil's level shift from about Rs 161 in 2023 to Rs 375 in 2025 registered as "volatility"). `archive/district_volatility.csv` pooled all 72 commodities, priced from Rs 4 to Rs 570 in different units, so its percentages reflect each district's commodity mix rather than volatility. Both were replaced (see `DATA_QUALITY_LOG.md`).

## 7. District view

Premium = district monthly mean / state average - 1, averaged over commodities in a group (only commodities with at least the Medium number of districts reporting). Positive = the district is pricier than the state average.

## 8. Validation

- `scripts/risk_score.py` re-implements the full scoring in pandas. For all 1,560 scored commodity-months, the risk score differs from the Excel result by at most 2e-13, and class, risk type and spread signal match exactly.
- For Feb 2026, 112 District_View cells (district x group premiums and district averages), 96 Group_Heatmap cells and the Watchlist Top 15 order match independent pandas calculations.
- Selecting a different month and commodity (Aug 2025, Coconut oil) reproduced the pandas top-5 ranking.
- The workbook recalculates in LibreOffice with 0 errors across about 120,000 formulas.
- Not done: a backtest of the supplied forecasts (the files hold only future predictions, so a backtest would require refitting a model on a training cut-off), and an out-of-sample test of whether high scores precede price spikes. Both are recommended next steps.
