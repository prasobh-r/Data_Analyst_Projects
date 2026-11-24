# Bank Loan Risk Intelligence

An end-to-end credit risk analytics project on LendingClub loan data: data engineering in Python, an independently built WOE/IV credit scorecard validated out-of-time, a SQL Server analytics layer, and a 3-page Power BI dashboard with a live approval-cutoff simulator.

![Portfolio & Trajectory](Images/page1_portfolio_trajectory.jpg)

## At a glance

| | |
|---|---|
| **Data** | 150,000 resolved LendingClub loans, 2015 to 2018 (random sample, seed 42); 21.55% defaulted |
| **Model** | Logistic regression on 8 WOE-binned features; LendingClub's own `int_rate`, `grade` and `sub_grade` are excluded (leakage) |
| **Validation** | Trained on 2015-01 to 2017-09 vintages (134,913 loans), tested on 2017-10 to 2018-12 (15,087 loans): **AUC 0.677, Gini 0.353, KS 25.8, PSI 0.047** |
| **Against the lender's grade** | Alone, the model ranks defaults slightly worse than LendingClub's grade (AUC 0.677 vs 0.681). Adding it to the grade lifts AUC to **0.701 (+0.020)** |
| **Decision view** | On the test loans, a score cutoff of 530 approves 54.9% of loans with an 11.7% default rate, against 18.6% overall |
| **Stack** | Python (pandas, scikit-learn), SQL Server (T-SQL), Power BI (DAX, What-If parameters) |

**Contents:** [Business problem](#business-problem) · [Architecture](#architecture) · [Dataset](#dataset) · [What I built](#what-i-built) · [Results](#results) · [Limitations](#limitations) · [How to reproduce](#how-to-reproduce) · [Repository structure](#repository-structure) · [Future improvements](#future-improvements) · [Author and credits](#author-and-credits)

## Business problem

A consumer lending analytics team needs to answer three questions that single-page projects tend to collapse into one:

1. **What are we managing, and how has portfolio risk moved over time?** The book's scale and trend, including where a naive read of that trend would be wrong.
2. **Does a new model add value?** Validated out-of-time, and tested against what the original lender's own underwriting already captures.
3. **Where does risk concentrate, and what should we do about it?** Segmentation that feeds an actionable decision tool.

The project builds one pipeline to answer all three: raw CSV, Python cleaning and scorecard modeling, SQL Server star schema and queries, and a 3-page Power BI dashboard.

## Architecture

```
Raw LendingClub CSV (accepted_2007_to_2018Q4.csv, via Kaggle)
        │
        ▼
Python (pandas, scikit-learn): cleaning, WOE/IV feature binning,
                               logistic regression scorecard,
                               out-of-time KS / Gini / AUC / PSI evaluation
        │
        ▼
SQL Server: star-schema database, vintage analysis, grade-benchmark
            comparison, geographic / purpose / DTI segmentation queries
        │
        ▼
Power BI: 3-page dashboard (portfolio trajectory, scorecard validation,
          segmentation + approval-cutoff simulator)
```

## Dataset

[LendingClub accepted loans, 2007 to 2018](https://www.kaggle.com/datasets/wordsforthewise/lending-club) (via Kaggle), filtered to resolved loans (`Fully Paid`, `Charged Off` or `Default`) from 2015 onward so the target is clean, then a random sample of 150,000 loans (seed 42). Download steps and the full column mapping are in `Documentation/dataset_guide.md`.

| Field group | Source columns |
|---|---|
| Loan terms | `loan_amnt`, `term`, `int_rate`, `installment`, `purpose` |
| Borrower profile | `annual_inc`, `emp_length`, `home_ownership`, `addr_state`, `dti`, `revol_util` |
| Bureau-style signal | `fico_range_low/high`, `delinq_2yrs`, `inq_last_6mths`, `open_acc` |
| Target | `loan_status` becomes `defaulted` (`Charged Off` and `Default` = 1, `Fully Paid` = 0) |
| Benchmark | `grade`, `sub_grade`: LendingClub's own A to G scorecard |

The filter to resolved loans shapes the vintage trend and the default rate; see [Limitations](#limitations).

## What I built

**Design choices**

- **Leakage excluded.** `int_rate`, `grade` and `sub_grade` are LendingClub's own risk-based outputs. Using them would re-derive the lender's answer instead of testing an independent model.
- **Out-of-time validation.** Train on the first 70% of origination months, test on the rest. WOE bins, IV and the score grade cut-offs are fitted on the training vintages only.
- **Benchmark against the lender.** LendingClub's A to G grade is an external check, not just an internal train/test split.
- **Metrics a risk committee uses.** KS, Gini and PSI alongside AUC.

### Python: data engineering and credit scorecard

- Cleaned the raw extract (`01`, `02`): duplicate and range checks, missing-value handling, EDA.
- **WOE/IV binning** (`03`): ranked 13 candidate features by Information Value and kept the 8 with IV of at least 0.02.
- **Logistic regression scorecard** (`04`) on the WOE-transformed features. Probabilities are converted to a points-to-double-odds score (base score 600 at 50:1 good-to-bad odds, 20 points to double the odds). The observed score range is 453 to 591, not a full 300 to 850 spread.
- **Model grades A to G** are percentile bands of the training score distribution: G is the lowest-scoring 10%, then F 15%, E 20%, D 20%, C 15%, B 12%, and A the top 8%. They rank risk; they are not calibrated default probabilities.
- Tested whether the model adds anything beyond LendingClub's own grade: AUC of the grade alone against grade plus model score, on the test vintages.

### SQL Server: portfolio analytics layer

A star schema (`Dim_Borrower`, `Fact_Loan`) with queries for:

- Vintage analysis: default rate by origination month.
- **Model grade vs LendingClub grade**: a cross-tab with loan counts per cell, for all loans (about 90% were used for training, so in-sample) and for the out-of-time test vintages only.
- Geographic concentration, purpose-level risk and pricing, and DTI risk deciles via `NTILE()` with a deterministic tie-breaker.
- A reusable view (`vw_PortfolioRiskSummary`) that feeds Power BI.

Scripts: `SQL/01_Database_Setup_LendingClub.sql` (schema), `SQL/03_Load_Model_Scores.sql` (loads the scorecard output), `SQL/02_Analysis_Queries_LendingClub.sql` (queries).

### Power BI: 3-page interactive dashboard

**1. Portfolio & Trajectory** (shown at the top): headline KPIs, loan mix and default rate by LendingClub grade, and default rate by origination quarter split into 36-month and 60-month loans. The split shows where the resolved-loans-only filter starts to distort the trend, and a "how to read this page" note says which vintages can be compared.

**2. The Scorecard: Built, Validated, Benchmarked**: WOE/IV feature ranking, AUC / KS / Gini / PSI, and a matrix of LendingClub grade against model grade on the out-of-time loans. Cells with fewer than 100 loans are masked.

![The Scorecard](Images/page2_scorecard.jpg)

**3. Segmentation & the Decision**: geographic, purpose and DTI-decile risk concentration, and a **score-cutoff simulator**: move the slider to see approval rate, approved default rate, bad loans declined and good loans lost. The data-split filter switches between all loans, training loans and the out-of-time test loans; select `test` to see loans the model never saw.

![Segmentation & the Decision](Images/page3_segmentation_decision.jpg)

## Results

### Scorecard

Thirteen candidate features were ranked by Information Value on the training vintages. Eight cleared IV of 0.02:

| Feature | IV | Strength |
|---|---|---|
| term_months | 0.178 | Medium |
| bureau_score | 0.137 | Medium |
| dti | 0.076 | Weak |
| home_ownership | 0.040 | Weak |
| monthly_income | 0.030 | Weak |
| loan_amnt | 0.030 | Weak |
| revol_util | 0.030 | Weak |
| inq_last_6mths | 0.025 | Weak |

Nothing clears "Strong". Loan term and bureau score are the only "Medium" signals: across all 150,000 loans, 60-month loans default at 34.9% against 17.5% for 36-month loans. Risk is spread over several weak-to-medium signals rather than one dominant driver. `purpose` (IV 0.0199) fell just below the cut-off and was not used.

**Out-of-time performance** (15,087 test loans):

| Metric | Value |
|---|---|
| AUC | 0.677 |
| Gini | 0.353 |
| KS | 25.8 (20 to 40 is "acceptable" on the usual rule of thumb) |
| PSI (train vs test) | 0.047 (below 0.1: no significant population shift) |

Across the test loans, model grades A to G default at 5.9%, 9.8%, 13.4%, 18.3%, 23.0%, 28.9% and 38.4%.

**One anomaly:** the `revol_util` coefficient is positive (+0.14) where every other feature is negative. Its WOE values correlate 0.48 with the bureau score across all loans (0.46 on the training loans), so once the bureau score is in the model it adds little independent signal. Variance inflation factors are all below 1.5, so this is not severe multicollinearity. The feature is kept and flagged as unstable.

### Benchmark against LendingClub's own grade

Same out-of-time loans:

| Predictor | AUC |
|---|---|
| Model score alone | 0.677 |
| LendingClub grade alone (A to G) | 0.681 |
| LendingClub sub-grade alone (35 levels) | 0.688 |
| Grade + model score | 0.701 (+0.020) |
| Sub-grade + model score | 0.702 (+0.014) |

On its own the model ranks defaults slightly worse than the lender's grade, which reflects the lender's own underwriting. Adding the model to the grade raises AUC by 0.020 (0.014 against the sub-grade): a small amount of information the grade does not already capture.

Within each of the seven LendingClub grades the model ranks defaults better than chance (AUC 0.57 to 0.62); grades F and G have only 188 and 71 test loans, so those two are less certain. Inside LendingClub grade B (341 to 945 loans per cell), the default rate rises from 8.8% for model grade A to 19.9% for model grade F, with one small reversal between model grades B and C (10.4% vs 10.2%).

### Decision view: score cutoff on the test loans

Approve loans scoring at or above the cutoff. Test vintages only (15,087 loans, 2,802 of them defaults, 18.6% default rate), so the scorecard has never seen these loans. Produced by `Python/04_scorecard_model_and_evaluation.ipynb`.

| Cutoff | Approval rate | Default rate of approved loans | Bad loans declined (of 2,802) | Good loans lost |
|---:|---:|---:|---:|---:|
| 500 | 92.6% | 16.9% | 441 | 678 |
| 510 | 84.6% | 15.6% | 805 | 1,519 |
| 520 | 71.9% | 13.9% | 1,295 | 2,949 |
| 530 | 54.9% | 11.7% | 1,832 | 4,968 |
| 540 | 36.2% | 9.1% | 2,307 | 7,323 |
| 550 | 21.5% | 6.9% | 2,578 | 9,272 |
| 560 | 11.1% | 5.1% | 2,716 | 10,694 |

Raising the cutoff lowers the default rate of approved loans, and every step costs good loans. Where to stop is a business decision about margin and volume that this data cannot settle (it has no revenue or loss-given-default). The dashboard's simulator shows the same trade-off.

**Same approval rate, different rankings.** If the best-ranked 30%, 50% or 70% of the test loans are approved, the default rate of the approved loans is:

| Approved share | Model score | LendingClub sub-grade | Sub-grade + model |
|---:|---:|---:|---:|
| 30% | 8.4% | 7.4% | 6.9% |
| 50% | 11.0% | 9.9% | 9.6% |
| 70% | 13.6% | 13.3% | 12.8% |

The model alone is a little worse than the lender's sub-grade, and the two together are 0.3 to 0.5 percentage points better than the sub-grade alone. A "one-lever" change to underwriting will not sharpen approvals much, because no single feature dominates and the model's gain over the lender's grade is small; the useful output is a combined ranking plus an explicit cutoff.

### Portfolio findings

- **$2.18bn** exposure across 150,000 loans; **$506M** of it is exposure at default (21.55% default rate).
- **CA, TX, NY and FL hold 38.2%** of exposure.
- **Small business loans default at 35.1%** (1,430 loans), the highest of any purpose with at least 1,000 loans.
- **DTI deciles** separate default cleanly, from about 31% in the riskiest decile to 16% in the safest (SQL query 4 gives 30.85% and 16.01%).
- Default rates by LendingClub grade run from 6.1% (A) to 53.7% (G).

## Limitations

1. **Resolved loans only.** Loans still being repaid are left out, and they are mostly good loans, so 2016 to 2017 default rates are pushed up. The newest vintages have not had time to default, so 2018 rates are pushed down. Splitting by term shows the first effect: 36-month loans default at about 15% to 16% through 2016 Q1 (the last quarter whose 36-month loans are fully resolved), then at 22.1% in 2016 Q2, while 60-month loans show no such jump. Only the 2015 to 2016 Q1 vintages are fully seasoned (about 20%). After that, a real change in loan quality cannot be separated from the filter with this data, and the 2018 Q4 default rate of 2.2% is an artifact. The out-of-time test set is the most immature part of the data, which is why its default rate (18.6%) is below the training rate (21.9%).
2. **The 21.55% default rate is not a live-book rate.** It comes from a resolved-only sample.
3. **Modest model performance** (AUC 0.677), with one unstable coefficient (`revol_util`). The model improves on the lender's grade only slightly, and SQL queries over all loans (3a, and the dashboard with the filter on `All`) are in-sample for about 90% of loans; use the test vintages for any claim.
4. **Small cells.** LendingClub grades F and G have 188 and 71 test loans; purposes with fewer than 1,000 loans (for example wedding, 2 loans) are not compared.
5. **No borrower age, and no month-by-month repayment ledger.** A roll-rate or delinquency-transition analysis would need a separate, unfiltered extract of open loans.
6. **Outliers left as supplied:** 7 loans with `dti` of 999 (92 above 100), 10 loans with `annual_inc` of 1,000 or less and 47 above 1,000,000. Quantile WOE bins limit their influence. Four loans with status `Default` are counted as defaults. Details in `Documentation/data_quality_notes.md`.
7. **Missing values:** `emp_title` (6.54% missing) is excluded from the model as high-cardinality free text; `emp_length` is filled with an `"Unknown"` category; 345 loans (0.23%) have no `last_pymnt_d` and all of them defaulted, consistent with defaults before any payment.
8. **No pricing or loss data**, so the cutoff table cannot say which cutoff is most profitable.

## How to reproduce

Python 3.13 with the packages in `requirements.txt` was used for the checked runs.

1. `pip install -r requirements.txt`, then download the raw LendingClub file from Kaggle to `Dataset/raw/accepted_2007_to_2018Q4.csv` (see `Documentation/dataset_guide.md`).
2. Run the notebooks in `Python/` in order, from the `Python/` folder: `01` (needs the raw file), `02`, `03`, `04`. All paths are relative to the repository root. They write the CSVs in `Dataset/` (see `Dataset/README.md`) and two JSON summaries in `Documentation/`.
3. In SQL Server: create the database (first statement of `SQL/01_Database_Setup_LendingClub.sql`), import `Dataset/loans_clean.csv` as `stg_loans_clean`, run the rest of that script, import `Dataset/loans_scored.csv` as `stg_loans_scored`, run `SQL/03_Load_Model_Scores.sql`, then run `SQL/02_Analysis_Queries_LendingClub.sql`. The "Expect" comments in the SQL files give the values to compare against.
4. Open `PowerBI/Bank_Risk_Intelligence.pbix`. To refresh it against your own database, update the SQL Server data source in Power BI (Transform data, Data source settings). Screenshots of all three pages are in `Images/`.

## Repository structure

```
bank-loan-risk-Intelligence/
│
├── README.md
├── requirements.txt
├── .gitignore
│
├── Dataset/                          # generated CSVs are git-ignored
│   └── README.md                     # what each file is and how to regenerate it
│
├── Python/
│   ├── 01_load_and_clean_lendingclub.ipynb
│   ├── 02_EDA_and_cleaning.ipynb
│   ├── 03_woe_iv_binning.ipynb
│   └── 04_scorecard_model_and_evaluation.ipynb
│
├── SQL/
│   ├── 01_Database_Setup_LendingClub.sql
│   ├── 02_Analysis_Queries_LendingClub.sql
│   └── 03_Load_Model_Scores.sql
│
├── PowerBI/
│   └── Bank_Risk_Intelligence.pbix
│
├── Images/
│   ├── page1_portfolio_trajectory.jpg
│   ├── page2_scorecard.jpg
│   └── page3_segmentation_decision.jpg
│
└── Documentation/
    ├── dataset_guide.md
    ├── data_dictionary.md
    ├── data_quality_notes.md
    ├── methodology_notes.md
    ├── woe_scorecard_artifact.json
    └── model_evaluation_summary.json
```

## Future improvements

- Compare the WOE/IV scorecard with a gradient-boosted model (XGBoost or LightGBM) and SHAP explanations, to quantify the accuracy vs interpretability trade-off.
- A roll-rate / delinquency-transition page, which needs a separate unfiltered extract of currently-open loans.
- Add loss-given-default and pricing assumptions so the cutoff can be chosen on expected profit.
- Row-level security for role-based dashboard access.

## Author and credits

Prasobh R.

Dataset: LendingClub accepted loan data (2007 to 2018), via Kaggle (`wordsforthewise/lending-club`). Check the licence on the dataset page before reuse. The raw data is not redistributed in this repository; see `Documentation/dataset_guide.md`.
