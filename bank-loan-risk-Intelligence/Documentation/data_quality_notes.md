# Data Quality Notes (Transparency)

This project treats data quality issues as findings to document, not problems
to silently smooth over. Every item below was surfaced by the pipeline itself
and handled deliberately — the goal is that a reader can trust the numbers in
the README precisely *because* the rough edges are visible here.

---

## Missingness in the raw LendingClub extract

Printed directly by `Python/00_load_and_clean_lendingclub.py` on the 150,000-row
cleaned extract:

| Column | % Missing | Handling |
|---|---|---|
| `emp_title` | 6.54% | Excluded from the model entirely — high-cardinality free text, not usable as a WOE bin without NLP work outside this project's scope |
| `emp_length` | 6.45% | Filled as `"Unknown"` category — kept as a legitimate bin rather than dropped, since "employer didn't report length" may itself carry signal |
| `last_pymnt_d` | 0.22% | **Investigated, not assumed.** Cross-checked in `02_EDA_and_cleaning.ipynb`: rows missing this field show a **100% default rate**, confirming they represent loans that defaulted before any payment was ever recorded — not a random data gap |
| `revol_util` | 0.06% | Filled with the column median |
| `dti` | 0.00% | No missing values — already complete in the source extract |

---

## Structural / referential checks

- **Zero duplicate `loan_id` values** across all 150,000 rows
- **`term_months`** confirmed to contain only the two valid LendingClub values
  (36, 60) — no malformed entries
- No non-positive `loan_amnt` or `monthly_income` values survived the cleaning
  filters

---

## Known dataset limitations (by design, not oversight)

- **No borrower age.** LendingClub does not disclose this field at all — not a
  cleaning gap, a genuine absence in the source data. Documented in
  `Documentation/dataset_guide.md`.
- **No full month-by-month repayment ledger.** Only `last_pymnt_d`,
  `last_pymnt_amnt`, `total_pymnt`, and `out_prncp` are available — coarser
  than an installment-by-installment history. This is why a true roll-rate /
  delinquency-transition analysis isn't included (see Future Improvements);
  building one would require a separate, unfiltered extract of currently-open
  loans.
- **Resolved-loans-only filtering shapes the vintage trend's recent years.**
  Restricting to `Fully Paid`/`Charged Off`/`Default` (needed for a clean
  binary target) means loans issued close to the 2018Q4 extract date haven't
  had time for all their eventual defaults to occur yet. The vintage
  default-rate trend's apparent decline after mid-2016 is this artifact, not
  real portfolio improvement — see the README's Key Insight section and the
  dashboard's shaded annotation on Page 1.

---

## Model-side data honesty

- **`int_rate`, `grade`, and `sub_grade` were deliberately excluded** from the
  WOE/IV feature set. These are LendingClub's own risk-based outputs — an
  independent scorecard trained on them would partly just be re-deriving the
  lender's own grade rather than testing a genuinely separate model. Excluding
  them was a leakage-prevention decision made *before* training, not a
  post-hoc fix.
- **`revol_util`'s coefficient came out sign-flipped** in the final logistic
  regression (positive, where every other feature was negative as expected).
  Diagnosed as a multicollinearity effect with `dti` and `loan_amnt` — it had
  the weakest Information Value (0.034) of the retained features. Kept in the
  model for completeness, flagged as unstable rather than silently trusted or
  quietly dropped.
- **Out-of-time train/test default rates differ** (21.88% train vs. 18.57%
  test) — consistent with, and additional evidence for, the immature-vintage
  bias documented above, since the test set skews toward the more recent,
  artificially-lower-default vintages.

---

## What this means for reading the results

Every number in this README's Results and Key Insight sections was produced
*after* the checks above — the 21.55% overall default rate, the AUC/KS/Gini/PSI
figures, and the vintage trend all already account for the limitations listed
here. Nothing below is a caveat undermining those numbers; it's the record of
how they were arrived at honestly.
