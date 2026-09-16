# Methodology Notes — Credit Risk Techniques Used in This Project

Reference doc so you can explain these confidently in interviews. All "Your
result" lines below are filled in from the actual notebook runs — see
`woe_scorecard_artifact.json` and `model_evaluation_summary.json` for the
underlying source data.

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

**Your result:**

| Feature | IV | Strength |
|---|---|---|
| bureau_score | 0.133 | Medium |
| dti | 0.075 | Weak |
| home_ownership | 0.044 | Weak |
| loan_amnt | 0.035 | Weak |
| revol_util | 0.034 | Weak (sign-flipped in final model — see Key Insight) |
| monthly_income | 0.030 | Weak |
| inq_last_6mths | 0.025 | Weak |
| purpose | 0.021 | Weak |
| emp_length | 0.014 | Not useful — dropped |
| open_acc | 0.003 | Not useful — dropped |
| total_acc | 0.003 | Not useful — dropped |
| delinq_2yrs | 0.002 | Not useful — dropped |
| term_months | 0.000 | Not useful — dropped |

Nothing clears "Strong," and only `bureau_score` clears "Medium" — even the
single most-weighted factor in most real credit decisions doesn't dominate
here. Risk is spread thin across several weak-to-medium signals rather than
concentrated in one driver, which is exactly why real scorecards combine
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

**Your result: KS = 24.06 — Acceptable.** A real, honest result for an
8-feature scorecard that deliberately excludes LendingClub's own `int_rate`
and `grade` (leakage risk) — a materially harder task than a model that gets
to see the lender's own pricing decision.

---

## 3. Gini Coefficient

**What it is:** `Gini = 2 × AUC − 1`. Same information as AUC, rescaled to a
0–1 (or sometimes reported as a percentage) range that's the conventional way
credit risk teams report model discrimination, alongside KS.

**Your result: Gini = 0.343** (from AUC = 0.671, out-of-time test set).

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

**Your result: PSI = 0.087 — No significant population shift.** Computed
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

**Your result:** Default rate rose from **~20.8% (January 2015)** to a peak of
**27.09% (August 2016)** — a real, genuine deterioration in loan quality over
that period. The trend then appears to *decline* sharply toward 2018, but
this is an artifact of the resolved-loans-only filter, not real improvement:
loans issued closer to the 2018Q4 extract date haven't had time for all their
eventual defaults to occur yet, so recent vintages are mechanically
under-counted on default rate. **The reliable comparison window is 2015
through early 2017** — vintages after that should be read with this
right-censoring caveat in mind, and this is exactly what the shaded
annotation on the dashboard's Page 1 ("Portfolio & Trajectory") calls out
directly rather than leaving to a footnote.
