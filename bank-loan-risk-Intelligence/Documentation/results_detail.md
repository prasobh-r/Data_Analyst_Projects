# Results detail and remaining limitations

Supporting detail for the [main README](../README.md). Nothing here changes the headline results; it holds the finer points that would slow down a first read.

## revol_util anomaly

The `revol_util` coefficient is positive (+0.14) where every other feature is negative. Its WOE values correlate 0.48 with the bureau score across all loans (0.46 on the training loans), so once the bureau score is in the model it adds little independent signal. Variance inflation factors are all below 1.5, so this is not severe multicollinearity. The feature is kept and flagged as unstable.

## Within-grade ranking

Within each of the seven LendingClub grades the model ranks defaults better than chance (AUC 0.57 to 0.62); grades F and G have only 188 and 71 test loans, so those two are less certain.

Inside LendingClub grade B (341 to 945 loans per cell), the default rate rises from 8.8% for model grade A to 19.9% for model grade F, with one small reversal between model grades B and C (10.4% vs 10.2%).

## Same approval share, different rankings

If the best-ranked 30%, 50% or 70% of the test loans are approved, the default rate of the approved loans is:

| Approved share | Model score | LendingClub sub-grade | Sub-grade + model |
|---:|---:|---:|---:|
| 30% | 8.4% | 7.4% | 6.9% |
| 50% | 11.0% | 9.9% | 9.6% |
| 70% | 13.6% | 13.3% | 12.8% |

The model alone is a little worse than the lender's sub-grade, and the two together are 0.3 to 0.5 percentage points better than the sub-grade alone. A "one-lever" change to underwriting will not sharpen approvals much, because no single feature dominates and the model's gain over the lender's grade is small; the useful output is a combined ranking plus an explicit cutoff.

## Other limitations

These continue the numbered list in the README (items 1 to 4 are there).

5. **Small cells.** LendingClub grades F and G have 188 and 71 test loans; purposes with fewer than 1,000 loans (for example wedding, 2 loans) are not compared.
6. **No borrower age, and no month-by-month repayment ledger.** A roll-rate or delinquency-transition analysis would need a separate, unfiltered extract of open loans.
7. **Outliers left as supplied:** 7 loans with `dti` of 999 (92 above 100), 10 loans with `annual_inc` of 1,000 or less and 47 above 1,000,000. Quantile WOE bins limit their influence. Four loans with status `Default` are counted as defaults. Details in `data_quality_notes.md`.
8. **Missing values:** `emp_title` (6.54% missing) is excluded from the model as high-cardinality free text; `emp_length` is filled with an `"Unknown"` category; 345 loans (0.23%) have no `last_pymnt_d` and all of them defaulted, consistent with defaults before any payment.
