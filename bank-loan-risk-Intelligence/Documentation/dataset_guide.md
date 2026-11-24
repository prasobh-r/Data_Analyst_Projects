# Dataset Guide: LendingClub Loan Data

## Why this dataset

| Dataset | Verdict |
|---|---|
| **LendingClub accepted loans (used)** | Bank-style loan data with LendingClub's own A to G grade (used to benchmark the scorecard), issue dates for vintage analysis, and a `loan_status` field that maps directly to a default flag |
| Home Credit Default Risk | Seven relational tables; a larger build and less transparent. A possible follow-up project |
| Give Me Some Credit | One flat table with about 11 columns, too thin for vintage analysis or a benchmark against a lender's grade |

## How to get it

1. Go to Kaggle: `https://www.kaggle.com/datasets/wordsforthewise/lending-club` (all LendingClub loan data, 2007 to 2018).
2. Download `accepted_2007_to_2018Q4.csv.gz` (the accepted-loans file). The rejected-loans file is not used: those applicants were never funded, so it has almost no columns useful for scoring.
3. Unzip it to `Dataset/raw/accepted_2007_to_2018Q4.csv`.

A free Kaggle account is needed to download.

**Size:** the file has about 2.26 million rows and 151 columns (about 1.5 GB unzipped). `Python/01_load_and_clean_lendingclub.ipynb` reads only the columns it needs and reduces the data to resolved loans from 2015 onward, then to a 150,000-loan random sample (see below).

## Licence and attribution

The data is published on Kaggle under that dataset's terms; check the licence shown on the dataset page before reusing it. The raw file is not redistributed in this repository (file size, and the dataset's terms). `Dataset/raw/` is git-ignored. Credit: "LendingClub, via Kaggle (wordsforthewise/lending-club)". See `Dataset/README.md` for which derived files are kept out of the repository.

## Columns used (of 151)

`Python/01_load_and_clean_lendingclub.ipynb` selects a working subset of 29 columns. The main ones, and what they map to in the pipeline:

| Pipeline concept | LendingClub column(s) |
|---|---|
| loan id | `id` |
| borrower age | **not available**: LendingClub does not disclose it (see Data Quality Notes) |
| employment | `emp_title`, `emp_length` |
| monthly_income | `annual_inc` / 12 |
| state | `addr_state` |
| issue date, vintage | `issue_d`, parsed to a date and `vintage_month` (`YYYY-MM`) |
| loan_amount | `loan_amnt` |
| term_months | `term` (a string such as "36 months", parsed to a number) |
| interest rate | `int_rate` |
| purpose | `purpose` |
| dti_ratio | `dti` (provided directly) |
| bureau_score | average of `fico_range_low` and `fico_range_high` |
| credit utilization | `revol_util` |
| prior delinquencies | `delinq_2yrs` |
| credit inquiries | `inq_last_6mths` |
| defaulted (target) | from `loan_status`: `Charged Off` and `Default` become 1, `Fully Paid` becomes 0 |
| repayment snapshot | `last_pymnt_d`, `last_pymnt_amnt`, `total_pymnt`, `out_prncp` (coarser than a full installment history) |
| benchmark | `grade`, `sub_grade`: LendingClub's own A to G scorecard, used only to benchmark the model, not as features |

**Resolved loans only.** Loans with status `Current`, `In Grace Period` or any `Late` bucket are dropped, because they have not finished playing out and counting them as non-defaults would bias the model. The side effect (distorted recent-vintage default rates) is described in the README under Limitations.
