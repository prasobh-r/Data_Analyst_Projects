# Methodology Notes — Credit Risk Techniques Used in This Project

Reference doc so you can explain these confidently in interviews. All "Your
result" lines below are filled in from the actual notebook runs — see
`woe_scorecard_artifact.json` and `model_evaluation_summary.json` for the
underlying source data.

---

## Revision note

An independent review of the first version of this project found four problems.
All four were fixed and the notebooks re-run; the numbers below are from the
corrected run.

1. **WOE bins were fitted on all 150,000 loans, including the test period.**
   They are now fitted on the training vintages only. On the same features this
   moved the test AUC from 0.6713 to 0.6682.
2. **`term_months` was dropped by a binning bug.** Quantile binning collapsed
   a two-valued feature (36 or 60 months) into one bin, giving IV = 0.000. As a
   category its IV is 0.178, the highest of any feature (60-month loans
   default at 34.9% against 17.5%).
3. **The grade comparison was in-sample.** The earlier "8.1% to 21.7% inside
   Grade B" figure used all loans, about 90% of which trained the model, and
   was not monotonic in the smaller grades. The comparison now uses the
   out-of-time test loans only, with cell counts, and adds an AUC comparison of
   the lender's grade alone against grade plus model score.
4. **The `revol_util` explanation was not supported.** Its WOE values
   correlate 0.48 with the bureau score, not with `dti` or `loan_amnt`, and
   all variance inflation factors are below 1.5.

---

## 1. WOE (Weight of Evidence) & IV (Information Value)

**What it is:** For a categorical or binned continuous variable, WOE measures
how much a given bin separates "good" (non-default) from "bad" (default)
accounts, on a log-odds scale:

```
WOE = ln( % of good accounts in this bin / % of bad accounts in this bin )
```

IV sums the WOE across all bins of a feature, weighted by the difference in
distribution, into a single score of that feature's overall predictive power:

```
IV = Σ (% good − % bad) × WOE
```

**Rule-of-thumb IV interpretation** (standard credit-industry bands):
| IV | Predictive power |
|---|---|
| < 0.02 | Not useful |
| 0.02–0.1 | Weak |
| 0.1–0.3 | Medium |
| 0.3–0.5 | Strong |
| > 0.5 | Suspiciously strong — check for leakage |

**Why banks use this instead of just feeding raw features into a model:**
WOE binning handles non-linear relationships and outliers automatically, and
the resulting scorecard is fully auditable — a regulator or risk committee can
see exactly why an applicant's score is what it is, bin by bin. This
interpretability requirement is a real, defining constraint in credit risk
modeling that plain black-box models don't satisfy.

**Your result** (fitted on the training vintages only):

| Feature | IV | Strength |
|---|---|---|
| term_months | 0.178 | Medium |
| bureau_score | 0.137 | Medium |
| dti | 0.076 | Weak |
| home_ownership | 0.040 | Weak |
| monthly_income | 0.030 | Weak |
| loan_amnt | 0.030 | Weak |
| revol_util | 0.030 | Weak (positive coefficient in the final model, see README) |
| inq_last_6mths | 0.025 | Weak |
| purpose | 0.0199 | Not useful (just under the 0.02 cut-off) — dropped |
| emp_length | 0.012 | Not useful — dropped |
| open_acc | 0.005 | Not useful — dropped |
| total_acc | 0.002 | Not useful — dropped |
| delinq_2yrs | 0.002 | Not useful — dropped |

Nothing clears "Strong", and only `term_months` and `bureau_score` clear
"Medium". Risk is spread thin across several weak-to-medium signals rather
than concentrated in one driver, which is exactly why real scorecards combine
8–15 features instead of relying on one.

---

## 2. KS Statistic (Kolmogorov–Smirnov)

**What it is:** The maximum separation between the cumulative distribution of
scores for "good" accounts and "bad" accounts. Plot cumulative % of goods and
cumulative % of bads against score bands — KS is the largest vertical gap
between the two curves.

**Rule-of-thumb interpretation:**
| KS | Model quality |
|---|---|
| < 20 | Poor |
| 20–40 | Acceptable |
| 40–60 | Good |
| 60–75 | Very strong |
| > 75 | Check for leakage |

**Why it matters more than accuracy here:** the portfolio is imbalanced
(far more good loans than defaults), so accuracy is meaningless — a model that
predicts "never defaults" would still be ~78% accurate. KS (like AUC) is
threshold-independent and imbalance-robust.

**Your result: KS = 25.80 — Acceptable.** A real, honest result for an
8-feature scorecard that deliberately excludes LendingClub's own `int_rate`
and `grade` (leakage risk) — a materially harder task than a model that gets
to see the lender's own pricing decision.

---

## 3. Gini Coefficient

**What it is:** `Gini = 2 × AUC − 1`. Same information as AUC, rescaled to a
0–1 (or sometimes reported as a percentage) range that's the conventional way
credit risk teams report model discrimination, alongside KS.

**Your result: Gini = 0.353** (from AUC = 0.677, out-of-time test set).

---

## 4. Population Stability Index (PSI)

**What it is:** A model-monitoring metric that compares the distribution of
scores (or a key feature) between the population the model was built on and a
more recent population, to detect drift.

```
PSI = Σ (% actual − % expected) × ln(% actual / % expected)
```

**Rule-of-thumb interpretation:**
| PSI | Interpretation |
|---|---|
| < 0.1 | No significant shift |
| 0.1–0.25 | Moderate shift — investigate |
| > 0.25 | Major shift — model likely needs retraining |

**Why it matters:** a scorecard that scored well at build time can silently
degrade as the applicant population changes (economic conditions, marketing
channel mix, etc.). PSI is the standard early-warning check risk teams run
periodically — this is the difference between "built a model" and "operates a
model in production."

**Your result: PSI = 0.047 — No significant population shift.** Computed
comparing the train population (2015-01 to 2017-09 vintages, 21.88% default
rate) against the out-of-time test population (2017-10 to 2018-12 vintages,
18.57% default rate). The lower test-set default rate is consistent with —
and additional evidence for — the immature-vintage bias documented in the
Vintage Analysis section below, since the test window skews toward the more
recent, artificially-lower-default cohorts.

---

## 5. Roll-Rate Analysis

**What it is:** A transition matrix showing what % of accounts in one
delinquency bucket move to another bucket in the next period (e.g., what % of
30dpd accounts "cure" back to current vs. roll forward to 60dpd vs. stay at
30dpd).

**Why it matters:** it's the standard way collections teams decide staffing
and strategy — if cure rates from 30dpd are high, light-touch reminders make
sense; if they're low, earlier and more aggressive intervention pays off.

**Your result: not available with this dataset, and documented as such rather
than faked.** Query 4 in `SQL/02_Analysis_Queries_LendingClub.sql` returns
zero rows against the real data — by design, not by error. The modeling
dataset was deliberately filtered to fully-resolved loans only (`Fully Paid`,
`Charged Off`, `Default`) to support a clean binary target, which means no
loan in `Fact_Loan` is ever in an intermediate delinquency state (`Late`,
`In Grace Period`) to build a transition matrix from. A true roll-rate
analysis would require a separate, unfiltered extract of currently-open
loans — noted as a Future Improvement rather than forced with unsuitable data.

---

## 6. Vintage Analysis

**What it is:** Grouping loans by origination month (vintage) and tracking
their default rate over loan age, to separate "this cohort of loans is
inherently riskier" from "defaults are just accumulating over time across all
cohorts."

**Your result:** The reported default rate moves from **~20.8% (January 2015)**
to **27.09% (August 2016)**, then falls sharply toward 2018. Neither movement
can be taken at face value, because the data holds resolved loans only
(Fully Paid or Charged Off) and that filter distorts the trend in two ways:

- Loans still being repaid are excluded, and they are mostly good loans, so the
  default rate of 2016–2017 vintages is pushed **up**. Splitting by term shows
  it: 36-month loans default at 15% to 16% through 2016 Q1 (fully resolved by
  the end of 2018), then jump to 22% in 2016 Q2, while 60-month loans show no
  such jump.
- The newest vintages have not had time to default yet, so 2018 rates are pushed
  **down** (2.2% in 2018 Q4).

**Only the 2015 to 2016 Q1 vintages are fully seasoned**, at a stable ~20%.
After that, real change in loan quality cannot be separated from the filter.
A fixed-horizon measure (for example, default within 12 months of origination)
would avoid the problem, but needs default dates that this extract does not
contain. Page 1 of the dashboard shows the 36-month and 60-month trends and a
"how to read this page" note for this reason.
