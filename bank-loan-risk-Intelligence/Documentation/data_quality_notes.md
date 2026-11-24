# Data Quality Notes (Transparency)

This project treats data quality issues as findings to document, not problems
to silently smooth over. Every item below was surfaced by the pipeline itself
and handled deliberately — the goal is that a reader can trust the numbers in
the README precisely *because* the rough edges are visible here.

---

## Missingness in the raw LendingClub extract

Printed by `Python/01_load_and_clean_lendingclub.ipynb` for the filtered loans
(resolved, 2015+ vintages) before the 150,000-loan sample is drawn and before
any filling. The sample itself shows 6.54% missing `emp_title`, 6.45%
`"Unknown"` `emp_length` and 0.23% missing `last_pymnt_d` (345 loans).

| Column | % Missing | Handling |
|---|---|---|
| `emp_title` | 6.54% | Excluded from the model entirely — high-cardinality free text, not usable as a WOE bin without NLP work outside this project's scope |
| `emp_length` | 6.45% | Filled as `"Unknown"` category — kept as a legitimate bin rather than dropped, since "employer didn't report length" may itself carry signal |
| `last_pymnt_d` | 0.22% (0.23% in the sample) | **Investigated, not assumed.** Cross-checked in `02_EDA_and_cleaning.ipynb`: rows missing this field show a **100% default rate**, confirming they represent loans that defaulted before any payment was ever recorded — not a random data gap |
| `revol_util` | 0.06% | Filled with the column median |
| `dti` | under 0.005% | Filled with the column median |

---

## Structural / referential checks

- **Zero duplicate `loan_id` values** across all 150,000 rows
- **`term_months`** confirmed to contain only the two valid LendingClub values
  (36, 60) — no malformed entries
- No non-positive `loan_amnt` or `monthly_income` values survived the cleaning
  filters

---

## Outliers and values left as supplied

Counted in `Dataset/loans_clean.csv` (150,000 loans). None were removed or
capped; the quantile-based WOE bins put extreme values in the first or last
bin, which limits their influence on the scorecard.

| Item | Count | Note |
|---|---|---|
| `dti` of 999 | 7 loans | Placeholder-like value in the source (maximum is 999) |
| `dti` above 100 | 92 loans | Includes the 7 above |
| `annual_inc` of 1,000 or less | 10 loans | Minimum is 1 |
| `annual_inc` above 1,000,000 | 47 loans | Maximum is 9,500,000 |
| `loan_status` = `Default` | 4 loans | Counted as defaults with the 32,315 `Charged Off` loans (32,319 in total) |

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
  real portfolio improvement — see the README's Limitations section and the
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
  regression (+0.14, where every other feature was negative as expected). Its
  WOE values correlate 0.48 with the bureau score across all loans (0.46 on the
  training loans), so it is partly redundant
  once the bureau score is in the model; variance inflation factors are all
  below 1.5, so this is not severe multicollinearity. Kept in the model for
  completeness, flagged as unstable rather than silently trusted or quietly
  dropped.
- **WOE bins are fitted on the training vintages only** (2015-01 to 2017-09),
  so no test-period outcome influences the scorecard. The first version of the
  project fitted them on all loans; see the revision note in
  `methodology_notes.md`.
- **Out-of-time train/test default rates differ** (21.88% train vs. 18.57%
  test) — consistent with, and additional evidence for, the immature-vintage
  bias documented above, since the test set skews toward the more recent,
  artificially-lower-default vintages.

---

## What this means for reading the results

The figures in the README were produced after the checks above, and the model
figures come from the out-of-time test set. Three cautions apply when reading
them:

- The test set (2017-10 to 2018-12) is the most immature part of the data, so
  its default rate is lower than the training rate.
- The grade-by-grade comparison for LendingClub grades F and G rests on few
  loans (188 and 71 in the test set).
- The 21.55% overall default rate reflects a resolved-loans-only sample and is
  higher than a live book would show.

See the revision note in `methodology_notes.md` for corrections made to the
first version of the analysis.
