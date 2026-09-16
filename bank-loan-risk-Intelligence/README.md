# Bank Risk Intelligence

An end-to-end credit risk analytics project on real LendingClub loan data —
covering data engineering, an independently-built credit scorecard, and a
3-page Power BI decision-support dashboard with a live approval-cutoff
simulator. Built across Python, SQL Server, and Power BI.

![Portfolio & Trajectory](Images/page1_portfolio_trajectory.png)

---

## Why this project is different from a typical "beginner" loan-risk project

Most portfolio loan-risk projects stop at "trained a logistic regression, got
an AUC." This one is built around the actual vocabulary and workflow of a
credit risk analyst, on real data rather than a synthetic toy dataset:

- **Real data** — 150,000 resolved LendingClub loans (2015–2018), not a
  fabricated dataset with no external benchmark
- A **credit scorecard** built with Weight of Evidence (WOE) binning and
  Information Value (IV) — the industry-standard technique real credit risk
  teams use, not a black-box classifier
- **KS statistic, Gini coefficient, and PSI** reported alongside AUC — the
  metrics a risk committee actually expects
- **Benchmarked against a real lender's own grading** — LendingClub's A–G
  grade is used as an external check on the model, not just an internal
  train/test split
- **Out-of-time validation** — trained on 2015–2017 vintages, tested on
  2017–2018, the way a scorecard is actually validated before deployment
- **Every honest limitation documented, not hidden** — a leakage risk caught
  and removed, a sign-flipped coefficient flagged rather than deleted, an
  immature-vintage bias in the trend data called out explicitly

---

## Business Problem

A consumer lending analytics team needs to answer three questions that most
single-page projects collapse into one:

1. **What are we managing, and how has portfolio risk moved over time?**
   Understanding the book's scale and trend — including where a naive read
   of that trend would be *wrong* — before drawing any conclusions from it.
2. **Did we build a model that adds real value?** Not just "trained a
   model," but validated it out-of-time and proven it discriminates risk
   beyond what the original lender's own underwriting already captured.
3. **Where does risk concentrate, and what should we actually do about it?**
   Segmentation that flows into an actionable decision tool, not just
   descriptive charts.

This project builds a full pipeline — raw CSV → Python cleaning and
scorecard modeling → SQL Server star schema and analytical queries → a
3-page Power BI dashboard — to answer all three.

---

## Architecture

```
Raw LendingClub CSV (accepted_2007_to_2018Q4.csv, via Kaggle)
        │
        ▼
Python (pandas, scikit-learn) — cleaning, WOE/IV feature binning,
                                 logistic regression scorecard,
                                 out-of-time KS / Gini / AUC / PSI evaluation
        │
        ▼
SQL Server — star-schema database, vintage analysis, grade-benchmark
             comparison, geographic/purpose/DTI segmentation queries
        │
        ▼
Power BI — 3-page dashboard: portfolio trajectory, scorecard validation,
           segmentation + live approval-cutoff simulator
        │
        ▼
Business recommendations
```

---

## Dataset

**Real data:** [LendingClub accepted loans, 2007–2018](https://www.kaggle.com/datasets/wordsforthewise/lending-club)
(via Kaggle) — filtered to 150,000 resolved loans (Fully Paid or Charged Off)
from 2015 onward, to support a clean binary target and a tractable analysis
scope. See `Documentation/dataset_guide.md` for the full column mapping and
download steps.

| Field group | Source columns |
|---|---|
| Loan terms | `loan_amnt`, `term`, `int_rate`, `installment`, `purpose` |
| Borrower profile | `annual_inc`, `emp_length`, `home_ownership`, `addr_state`, `dti`, `revol_util` |
| Bureau-style signal | `fico_range_low/high`, `delinq_2yrs`, `inq_last_6mths`, `open_acc` |
| Ground truth | `loan_status` → `defaulted` |
| Benchmark | `grade`, `sub_grade` — LendingClub's own A–G scorecard |

**Known limitations, documented rather than hidden:**
- LendingClub doesn't disclose borrower age
- No full month-by-month repayment ledger — only current status and
  last-payment snapshot fields
- Filtering to *resolved* loans only means recent vintages (2017–2018)
  appear artificially safer than they truly are — real loans still heading
  toward default haven't resolved yet in this extract (see Key Insight)

---

## What I Built

### Python — Data Engineering & Credit Scorecard
- Cleaned and validated the real LendingClub extract — duplicate checks,
  missing-value handling, referential sanity checks
- **WOE/IV feature binning**: ranked 8 candidate features by Information
  Value, deliberately **excluding `int_rate`/`grade`/`sub_grade`** — these
  are LendingClub's own risk-based outputs, and including them would leak
  the answer rather than test an independent model
- Trained a **logistic regression scorecard** on the WOE-transformed
  features, validated **out-of-time** (train: 2015–2017 vintages, test:
  2017–2018)
- Converted output probabilities into a 300–850 style score and A–G risk
  grade using standard points-to-double-odds scaling
- Reported **AUC, KS, Gini, and PSI together** — not AUC alone
- Diagnosed a real multicollinearity-driven sign flip (`revol_util`) rather
  than silently trusting the model

### SQL Server — Portfolio Analytics Layer
Star-schema database (`Dim_Borrower`, `Fact_Loan`) with queries covering:
- Vintage analysis — default rate by origination month
- **Model grade vs. LendingClub's real grade** — a cross-tab comparison most
  portfolio projects never get to make, since most don't have a real
  lender's grading decision already attached to the data
- Geographic concentration, purpose-level risk and pricing, DTI risk
  deciles via `NTILE()`
- A reusable view (`vw_PortfolioRiskSummary`) feeding Power BI directly

See `SQL/01_Database_Setup_LendingClub.sql` and
`SQL/02_Analysis_Queries_LendingClub.sql`.

### Power BI — 3-Page Interactive Dashboard

**1. Portfolio & Trajectory** — headline KPIs (total loans, exposure,
default rate), grade mix, and the vintage default-rate trend — including a
shaded annotation flagging exactly where the visible trend stops being
trustworthy (the immature-vintage-bias effect), rather than reporting the
naive decline at face value.

![Portfolio & Trajectory](Images/page1_portfolio_trajectory.png)

**2. The Scorecard: Built, Validated, Benchmarked** — the WOE/IV feature
ranking, AUC/KS/Gini/PSI, and the centerpiece finding: a grade-comparison
matrix showing the model discriminates risk *within every single
LendingClub grade*, not just in aggregate.

![The Scorecard](Images/page2_scorecard.png)

**3. Segmentation & the Decision** — geographic, purpose, and DTI-decile
risk concentration, flowing directly into a **live What-If score-cutoff
simulator**: drag a slider and watch approval rate, approved default rate,
correctly-declined bad loans, and lost good loans update in real time,
alongside a fixed reference table and a waterfall chart showing the full
book's flow down to the approved subset.

![Segmentation & the Decision](Images/page3_segmentation_decision.png)

---

## Key Insight: Real Risk Is Spread Thin — and an Independent Model Still Adds Value on Top of a Real Lender's Own Grading

An 8-feature WOE/IV scorecard was trained on real LendingClub loans and
validated out-of-time.

**Feature strength (Information Value):**

| Feature | IV | Strength |
|---|---|---|
| bureau_score | 0.133 | Medium |
| dti | 0.075 | Weak |
| home_ownership | 0.044 | Weak |
| loan_amnt | 0.035 | Weak |
| revol_util | 0.034 | Weak |
| monthly_income | 0.030 | Weak |
| inq_last_6mths | 0.025 | Weak |
| purpose | 0.021 | Weak |

Nothing clears "Strong" — not even bureau score, the single most-weighted
factor in most real credit decisions. Risk here is spread thin across
several weak-to-medium signals rather than concentrated in one dominant
driver — a common, legitimate shape for real credit data, and why real
scorecards combine 8–15 features instead of relying on one.

**Model performance (out-of-time test set):**

| Metric | Value |
|---|---|
| AUC | 0.671 |
| Gini | 0.343 |
| KS | 24.06 (Acceptable) |
| PSI (train vs. test) | 0.087 (no significant population shift) |

**The centerpiece finding — benchmarked against a real lender's real grade:**
cross-tabbing the model's own A–G grade against LendingClub's actual grade
shows a clean, monotonic default-rate climb *within every single LendingClub
grade band*. Concretely: within LendingClub's own **Grade B**, the model's
own sub-grading spans **8.1% to 21.7%** default — a **2.7x** risk spread
hidden inside one lender grade. That's real, incremental discrimination on
top of a real lender's own underwriting — a materially stronger claim than
simply agreeing with the lender's decision.

**One anomaly, documented rather than hidden:** the `revol_util` coefficient
came out sign-flipped (positive, where every other feature was negative as
expected) — a known multicollinearity effect with `dti` and `loan_amnt`.
Retained for completeness, flagged as unstable.

**One data-honesty catch on the trend side:** the raw vintage default-rate
trend appears to *decline* sharply toward 2018 — but this is an artifact of
filtering to resolved loans only, not real improvement. Loans issued closer
to the 2018Q4 extract haven't had time for all their eventual defaults to
occur yet. The reliable comparison window is 2015 through early 2017, where
default rate genuinely rose from ~20.8% to a peak of ~27.09% (August 2016).

**Business implication:** because no single feature dominates and the model
adds real but moderate incremental value, a "one-lever fix" approach to
underwriting won't meaningfully sharpen approval decisions on its own. This
is reflected directly in the dashboard's third page: segmentation
(geography, purpose, DTI) combined with a live cutoff simulator, rather than
a single blanket threshold recommendation.

---

## Results

- **150,000** real LendingClub loans (2015–2018 vintages, resolved outcomes
  only) analyzed end-to-end from raw CSV to a risk-scored, benchmarked
  portfolio
- **21.55%** overall default rate in the analysis set (elevated relative to
  a live book, since filtering to resolved loans excludes many still-current,
  generally safer, more recent loans — a documented artifact, not an error)
- **CA, TX, NY, FL together hold ~38%** of total portfolio exposure
- **Small business loans carry a genuinely elevated 35.1% default rate** on
  a real 1,430-loan sample — the highest of any purpose category with a
  trustworthy sample size
- **DTI risk decile alone** separates default rate cleanly from 30.9%
  (riskiest) to 16.0% (safest)
- Built an independent 8-feature WOE/IV credit scorecard achieving
  **AUC 0.671 / KS 24.06** out-of-time, with a clean monotonic A–G grade
- **Benchmarked the scorecard against LendingClub's own real grade** — the
  model adds a real, quantified 2.7x risk spread within a single lender
  grade band
- **PSI of 0.087** confirms the model generalizes across the 2015–2017 →
  2017–2018 time split without meaningful population drift
- Built a live Power BI score-cutoff simulator showing the real trade-off
  between bad loans correctly declined and good loans lost at any threshold

---

## Tech Stack

Python (pandas, scikit-learn) · SQL Server (T-SQL, CTEs, window functions,
views) · Power BI (DAX, What-If parameters, conditional formatting) ·
Jupyter Notebook

---

## Repository Structure

```
Bank-Risk-Intelligence/
├── README.md
├── Dataset/
│   ├── loans_clean.csv
│   ├── loans_model_ready.csv
│   ├── loans_woe_transformed.csv
│   └── loans_scored.csv
├── Python/
│   ├── 01_load_and_clean_lendingclub.py
│   ├── 02_EDA_and_cleaning.ipynb
│   ├── 03_woe_iv_binning.ipynb
│   └── 04_scorecard_model_and_evaluation.ipynb
├── SQL/
│   ├── 01_Database_Setup_LendingClub.sql
│   └── 02_Analysis_Queries_LendingClub.sql
├── PowerBI/
│   └── Bank_Risk_Intelligence.pbix
├── Images/
│   ├── page1_portfolio_trajectory.png
│   ├── page2_scorecard.png
│   └── page3_segmentation_decision.png
└── Documentation/
    ├── methodology_notes.md      (WOE/IV, KS, Gini, PSI explained)
    ├── dataset_guide.md
    └── data_quality_notes.md
```

---

## Data Quality Notes (Transparency)

- `emp_title` (6.54% missing) excluded from the model — too high-cardinality
  free text to use as a WOE bin without NLP work outside this project's scope
- `last_pymnt_d` missing (0.22% of rows) — confirmed via cross-check to
  correspond to loans that defaulted very early, before any payment was
  recorded, rather than a data quality error
- Filtering to resolved loans only (documented above) shapes the vintage
  trend's recent-year readings — treated as a stated limitation throughout,
  not smoothed over

---

## Future Improvements

- Compare the WOE/IV scorecard against a gradient-boosted model
  (XGBoost/LightGBM) with SHAP explainability, to quantify the accuracy vs.
  interpretability trade-off explicitly
- A dedicated roll-rate / delinquency-transition page, which would require
  a separate, unfiltered extract of currently-open loans (out of scope for
  the current resolved-loans-only dataset)
- Row-level security for role-based dashboard access

---

## Credits

Dataset: LendingClub accepted loan data (2007–2018), via Kaggle
(`wordsforthewise/lending-club`). Used per Kaggle's dataset terms — raw data
is not redistributed in this repo; see `Documentation/dataset_guide.md`.
