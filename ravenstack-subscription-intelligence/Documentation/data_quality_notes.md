# Data Quality Notes

Transparency log of every data-quality issue found during this project, and how each was resolved. Documented here rather than silently fixed, since knowing *what* was wrong with the source data — and why a particular fix was chosen — is part of the analysis.

---

## 1. Mixed date formats across source files

**Issue:** `accounts.csv` stored `signup_date` as `DD-MM-YYYY`, while `subscriptions.csv`, `feature_usage.csv`, `support_tickets.csv`, and `churn_events.csv` used `YYYY-MM-DD`.

**Resolution:** Standardized all date columns to proper `datetime64` in pandas during the cleaning phase (`01_EDA_and_Cleaning.ipynb`), explicitly specifying the source format for `accounts.signup_date` to avoid silent misparsing.

---

## 2. Non-unique primary key in `Fact_Usage`

**Issue:** `usage_id` in the feature usage table contained 21 non-unique values out of 25,000 rows (~0.08%). Investigation confirmed these were **not duplicate rows** — each pair of rows sharing a `usage_id` had genuinely different `subscription_id`, `usage_date`, `feature_name`, and other values, indicating a synthetic-data ID generation artifact rather than duplicated records.

**Resolution:** Added a surrogate `IDENTITY` primary key (`usage_pk`) in SQL Server rather than forcing a non-unique business key into the primary key role, or silently dropping the affected rows.

---

## 3. Overlapping subscription date ranges

**Issue:** When calculating gap-days between consecutive subscriptions per account (via `LAG`/`LEAD` window functions), a subset of records showed **negative** `gap_days_since_last_sub` values — meaning a new subscription's `start_date` occurred before the prior subscription's `end_date`.

**Resolution:** Preserved as-is rather than artificially cleaned. Most plausibly reflects mid-cycle plan changes being processed before the prior contract formally closed out in the source system (a realistic operational pattern), or a synthetic-data generation artifact. Documented in `SQL/Analysis_Queries.sql` (Query 4 comment) rather than silently corrected.

---

## 4. Auto-created Power BI relationships requiring removal

**Issue:** Power BI's relationship autodetect created unwanted 1:1 relationships between `Dim_Account` and two independently-scoped reporting views (`vw_CustomerRanking`, `vw_SaveCampaignPrioritizer`), based purely on matching `account_id` values — even though these views were intentionally built to stand alone. This caused incorrect data blending (e.g., a KPI showing the same repeated grand-total value across every row of a table instead of per-account values).

**Resolution:** Renamed the `account_id` column to `acct_ref` in both views (`SQL/CREATE_VIEW.sql`) so Power BI's relationship autodetect no longer matches them to `Dim_Account`, and manually removed the incorrect relationships in the Power BI model.

---

## 5. Weak churn-model predictive signal

**Issue:** A logistic regression trained on behavioral/engagement features to predict churn achieved only AUC 0.581 — barely above random.

**Resolution:** Not a data quality issue in the traditional sense, but investigated with the same rigor: confirmed via correlation analysis (max |r| = 0.09) and a follow-up SQL structural-signal test that churn in this dataset is genuinely fragmented across causes rather than driven by a data or modeling error. See `notebook_markdown_snippet.md` / the corresponding markdown cell in `Python/01_EDA_and_Cleaning.ipynb` for the full write-up.
