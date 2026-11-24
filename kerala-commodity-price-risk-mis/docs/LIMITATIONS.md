# Limitations

The full list. The four that matter most for reading the results are also in the [main README](../README.md#limitations).

1. **Price data only.** No market arrivals, stock, rainfall or import data, so supply stress is inferred from price-based proxies.
2. **Possible carried-forward prices.** 89.0% of daily prices equal the previous record for the same district and commodity (no single date exceeds 94.5%, so there are no whole-day copies). Retail prices are sticky, but if the source repeats the last available day, some values may be stale; this cannot be separated from genuinely unchanged prices. Monthly means dampen the effect.
3. **Uneven coverage.** Some commodities are reported by few districts; 12 of 72 are excluded in Feb 2026. Commodity coverage also changes slightly between years (70 to 72).
4. **Analyst-defined weights, caps and thresholds**, calibrated on 2024 to Feb 2026 data. Test sensitivity before operational use.
5. **Short seasonal history** (3 years): for example, tomato's July peak is largely driven by 2023.
6. **Forecasts are indicative scenarios.** They cover only Tomato, Ladies Finger and Coconut oil (Kera), their method is undocumented and they have not been backtested (the files hold only future values). Tomato's forecast starts 24.4% above its last 30 observations.
7. **The risk score is not a proven predictor.** The backtest is in-sample (weights were calibrated on the same period) and shows little ability to time rises within a commodity or to rank commodities month by month.
8. **Monthly aggregates in the workbook** for speed; a full 700K-row Power Pivot model must be built separately (see the `Model_Guide` sheet). Drop-downs replace slicers.
9. Source commodity groups are kept as supplied (for example, onion small sits under Spices and Condiments).
