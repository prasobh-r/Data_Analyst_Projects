# Data Dictionary

Documents the real dataset as it actually flows through this project — from
the cleaned LendingClub extract, through the Python-only intermediate files,
to the SQL Server tables that power the dashboard. See
`Documentation/dataset_guide.md` for the raw-to-clean column mapping and
`Documentation/data_quality_notes.md` for missingness and known limitations.

---

## Dataset/loans_clean.csv (150,000 rows)

Output of `Python/00_load_and_clean_lendingclub.py`. The master cleaned file —
every other file in `Dataset/` derives from this one.

| Column | Type | Description |
|---|---|---|
| id | string | LendingClub's own loan identifier |
| issue_d | date | Loan origination date |
| vintage_month | string | `YYYY-MM`, derived from `issue_d` |
| loan_amnt | float | Original loan amount |
| term_months | int | Loan term: 36 or 60 |
| int_rate | float | Annual interest rate (%) — **excluded from modeling**, see below |
| installment | float | Scheduled monthly payment |
| grade | string | LendingClub's own risk grade, A–G — **excluded from modeling**, kept as benchmark |
| sub_grade | string | LendingClub's finer-grained grade (e.g. B3) — excluded from modeling |
| emp_title | string | Free-text employer name — excluded from modeling (high cardinality) |
| emp_length | string | Years employed, or `"Unknown"` if missing |
| home_ownership | string | RENT / MORTGAGE / OWN / ANY |
| annual_inc | float | Self-reported annual income |
| monthly_income | float | Derived: `annual_inc / 12` |
| verification_status | string | Whether income was verified by LendingClub |
| purpose | string | Stated loan purpose (13 categories) |
| addr_state | string | Borrower's US state (2-letter code) |
| dti | float | Debt-to-income ratio, as provided directly by LendingClub |
| delinq_2yrs | int | Number of delinquencies in the past 2 years |
| bureau_score | float | Derived: average of `fico_range_low`/`fico_range_high` |
| inq_last_6mths | int | Hard credit inquiries in the last 6 months |
| open_acc | int | Number of open credit lines |
| revol_bal | float | Total revolving credit balance |
| revol_util | float | Revolving line utilization (%) |
| total_acc | int | Total number of credit lines ever opened |
| loan_status | string | Raw LendingClub status — filtered to `Fully Paid`/`Charged Off`/`Default` only |
| defaulted | int | Target variable: 1 if `Charged Off`/`Default`, 0 if `Fully Paid` |
| last_pymnt_d | date | Date of last payment received (0.22% missing — see data quality notes) |
| last_pymnt_amnt | float | Amount of last payment |
| total_pymnt | float | Total amount paid to date |
| out_prncp | float | Outstanding principal remaining |

---

## Python-only intermediate files (never loaded into SQL Server)

| File | Produced by | Contents |
|---|---|---|
| `loans_model_ready.csv` | `02_EDA_and_cleaning.ipynb` | Subset of `loans_clean.csv` columns selected for modeling, plus `id`/`vintage_month`/`grade` retained for reference |
| `loans_woe_transformed.csv` | `03_woe_iv_binning.ipynb` | `id`, `defaulted`, and 8 `*_woe` columns (WOE-transformed versions of the selected features) |
| `loans_scored.csv` | `04_scorecard_model_and_evaluation.ipynb` | `id`, `model_score` (300–850), `model_risk_grade` (A–G) — the only file re-imported into SQL Server, to populate `Fact_Loan` |

---

## SQL Server: Dim_Borrower

Attributes describing the borrower, not the loan. One row per `loan_id`.

| Column | Type | Description |
|---|---|---|
| loan_id | VARCHAR(20) | Primary key, matches LendingClub's `id` |
| emp_title | VARCHAR(200) | Nullable free-text employer |
| emp_length | VARCHAR(20) | |
| home_ownership | VARCHAR(20) | |
| annual_inc | DECIMAL(14,2) | |
| monthly_income | DECIMAL(12,2) | |
| verification_status | VARCHAR(30) | |
| addr_state | CHAR(2) | |
| bureau_score | DECIMAL(6,1) | |
| dti | DECIMAL(6,2) | |
| delinq_2yrs | INT | |
| inq_last_6mths | INT | |
| open_acc | INT | |
| revol_bal | DECIMAL(14,2) | |
| revol_util | DECIMAL(5,2) | |
| total_acc | INT | |

## SQL Server: Fact_Loan

One row per loan. `model_score`/`model_risk_grade` start `NULL` and are
populated from `loans_scored.csv` after the Python scorecard notebook runs.

| Column | Type | Description |
|---|---|---|
| loan_id | VARCHAR(20) | Primary key, references `Dim_Borrower(loan_id)` |
| issue_date | DATE | |
| vintage_month | CHAR(7) | `YYYY-MM` |
| loan_amnt | DECIMAL(12,2) | |
| term_months | INT | |
| int_rate | DECIMAL(5,2) | Kept in the warehouse for reference/pricing queries; excluded from the model itself |
| installment | DECIMAL(10,2) | |
| lc_grade | CHAR(1) | LendingClub's own A–G grade |
| lc_sub_grade | VARCHAR(3) | |
| purpose | VARCHAR(30) | |
| loan_status | VARCHAR(30) | |
| defaulted | BIT | |
| last_pymnt_date | DATE | Nullable |
| last_pymnt_amnt | DECIMAL(12,2) | Nullable |
| total_pymnt | DECIMAL(14,2) | |
| out_prncp | DECIMAL(12,2) | |
| model_score | INT | Nullable until populated — this project's independent 300–850 score |
| model_risk_grade | CHAR(1) | Nullable until populated — this project's independent A–G grade |

## SQL Server: vw_PortfolioRiskSummary (view)

Joins `Fact_Loan` and `Dim_Borrower` into the single flat view Power BI
connects to directly. Columns: `loan_id`, `issue_date`, `vintage_month`,
`loan_amnt`, `term_months`, `int_rate`, `lc_grade`, `lc_sub_grade`, `purpose`,
`loan_status`, `defaulted`, `model_score`, `model_risk_grade`, `addr_state`,
`home_ownership`, `annual_inc`, `bureau_score`, `dti`, `revol_util`.

---

## Power BI–only tables (not in SQL Server)

Built directly inside the `.pbix` file to support the What-If score-cutoff
simulator on Page 3 — see `Documentation/powerbi_storytelling_guide.md`.

| Table | Type | Purpose |
|---|---|---|
| `Score Cutoff` | What-If Parameter (300–850, step 10) | Drives the live slider and the 5 KPI cards |
| `Cutoff Range` | Calculated table (`GENERATESERIES(300, 850, 10)`) | A second, independent copy of the same range, used only by the fixed reference table and the `*_CURVE` measures — deliberately kept unrelated to `Score Cutoff` in the data model so the reference table stays fixed regardless of slider position |
| `Decision Flow` | Manually entered (3 rows) | Category labels (`Total Loans`, `Bad Loans Declined`, `Good Loans Lost`) driving the Waterfall chart |
| `Outcome Type` | Manually entered (2 rows) | Category labels (`Bad Loans Declined`, `Good Loans Lost`) driving the live 2-bar comparison chart |
