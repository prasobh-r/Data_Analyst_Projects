# Dataset Guide — LendingClub Loan Data (Real Data)

## Why LendingClub over the other candidates

| Dataset | Verdict |
|---|---|
| **LendingClub** | ✅ Chosen — real bank-style loan data, already has A–G grades (so you can validate your own scorecard against LendingClub's real one), real issue dates for vintage analysis, real loan_status field (Fully Paid / Charged Off / Late) that maps directly to a default flag and delinquency buckets |
| Home Credit Default Risk | More advanced (7 relational tables) but heavier lift and less transparent — good stretch goal later, not the right first real-data project |
| Give Me Some Credit | Single flat table, only ~11 columns — too thin to support vintage/roll-rate/collections analysis |

## How to get it

1. Go to **Kaggle**: `https://www.kaggle.com/datasets/wordsforthewise/lending-club` (this is the
   most complete, most-referenced version — "All Lending Club loan data," 2007–2018)
2. You'll need a free Kaggle account to download. Download `accepted_2007_to_2018Q4.csv.gz`
   (the accepted-loans file — ignore the rejected-loans file, it has almost no useful columns
   for scoring since those applicants were never funded)
3. Unzip it into `Dataset/raw/accepted_2007_to_2018Q4.csv`

**Heads-up on size:** this file is ~2.26 million rows and 151 columns (~1.5GB unzipped). For a
portfolio project you do not need all of it — `Python/00_load_and_clean_lendingclub.py` filters
down to a manageable, more recent, fully-resolved subset (see below). If Kaggle's download is
slow or you want something smaller to start with, `adarshsng/lending-club-loan-data-csv` (2007–2015)
or `panchammahto/lendingclub-dataset-full-2007-to-2018` are lighter alternatives with mostly the
same columns.

## License / attribution note

LendingClub's data is published under Kaggle's dataset terms — it's freely usable for personal/
portfolio projects, but do **not** redistribute the raw CSV in your own GitHub repo (file size and
ToS both argue against it). Instead:
- Add `Dataset/raw/` to `.gitignore`
- Keep only your *cleaned, filtered, feature-engineered* output CSV in the repo (a few thousand–
  hundred thousand rows is fine to commit, or better, keep even that out and just document how to
  regenerate it)
- Credit "LendingClub, via Kaggle (wordsforthewise/lending-club)" in your README Credits section

## Columns you actually need (of 151)

`00_load_and_clean_lendingclub.py` selects a working subset. The key ones and what they map to
in your existing pipeline design:

| Your pipeline concept | LendingClub column(s) |
|---|---|
| applicant_id | generate one (`id` column exists but has gaps/nulls in places) |
| age | **not available** — LendingClub doesn't disclose borrower age. Drop age from this version, note it in Data Quality Notes as a real-world limitation (this is realistic — bureau data often excludes protected-class-adjacent fields) |
| employment_type / emp_length | `emp_title`, `emp_length` |
| monthly_income | `annual_inc` / 12 |
| state | `addr_state` |
| application/issue date | `issue_d` |
| loan_amount | `loan_amnt` |
| term_months | `term` (string like "36 months" — parse to int) |
| interest_rate_pct | `int_rate` |
| purpose | `purpose` |
| dti_ratio | `dti` — **already provided directly**, no need to derive it yourself |
| bureau_score | `fico_range_low` / `fico_range_high` (average them) |
| credit_utilization_pct | `revol_util` |
| prior_delinquencies | `delinq_2yrs` |
| credit_inquiries | `inq_last_6mths` |
| defaulted (target) | derived from `loan_status`: `Charged Off` / `Default` → 1, `Fully Paid` → 0. **Drop rows where loan_status is `Current`, `In Grace Period`, or any `Late` bucket** for the scorecard training set — those loans haven't resolved yet, so including them as "not default" would bias the model (a real, common credit-modeling pitfall worth calling out in your Key Insight section) |
| delinquency bucket history | `loan_status` values `Late (16-30 days)` / `Late (31-120 days)` give you a real (if coarse) proxy for roll-rate analysis on currently-open loans |
| repayment history | `last_pymnt_d`, `last_pymnt_amnt`, `total_pymnt`, `out_prncp` — coarser than a full installment-by-installment table, but real |
| existing scorecard to benchmark against | `grade`, `sub_grade` — LendingClub's own A–G grade. **This is a gift**: you can compare your own WOE/IV scorecard's grade assignment against theirs and discuss where you agree/disagree in your Key Insight section, which is a much stronger narrative than modeling in a vacuum |
