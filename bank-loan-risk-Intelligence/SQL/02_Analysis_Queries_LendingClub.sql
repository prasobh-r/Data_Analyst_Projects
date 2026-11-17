/* ============================================================================
   Bank Loan Risk Intelligence: SQL analysis queries
   02_Analysis_Queries_LendingClub.sql

   Run after 01_Database_Setup_LendingClub.sql and 03_Load_Model_Scores.sql.
   Data: 150,000 resolved LendingClub loans (2015 to 2018 vintages), a random
   sample. All queries use Fact_Loan and Dim_Borrower.
   "Expect" comments = values calculated from the CSVs outside SQL Server;
   confirm them after running.
   ============================================================================ */

USE BankLoanRisk_Real;
GO

/* ============================================================================
   QUERY 1: Portfolio overview KPIs
   Expect: 150000 loans, exposure 2178108050, exposure at default 505566800,
           default rate 0.2155
   ============================================================================ */
SELECT
    COUNT(*)                                             AS total_loans,
    SUM(loan_amnt)                                       AS total_exposure,
    SUM(CASE WHEN defaulted = 1 THEN loan_amnt ELSE 0 END) AS exposure_at_default,
    CAST(AVG(CAST(defaulted AS FLOAT)) AS DECIMAL(5,4))  AS portfolio_default_rate
FROM Fact_Loan;
GO

/* ============================================================================
   QUERY 2: Vintage analysis by origination month
   Only resolved loans are in the data, so recent vintages look safer than they
   are: loans issued near the end of 2018 have not had time to default yet.
   Read the trend only up to early 2017.
   Expect: first month 2015-01 default rate 0.2076, peak 2016-08 at 0.2709
   ============================================================================ */
SELECT
    vintage_month,
    COUNT(*)                                             AS loans_originated,
    SUM(loan_amnt)                                       AS vintage_exposure,
    CAST(AVG(CAST(defaulted AS FLOAT)) AS DECIMAL(5,4))  AS vintage_default_rate
FROM Fact_Loan
GROUP BY vintage_month
ORDER BY vintage_month;
GO

/* ============================================================================
   QUERY 3a: Model grade vs LendingClub grade, ALL loans
   About 90% of these loans (vintages 2015-01 to 2017-09) were used to train the
   scorecard, so this is an in-sample view. Use 3b for the out-of-time view.
   Small cells (see the loans column) are noisy: do not read a trend from them.
   ============================================================================ */
SELECT
    lc_grade,
    model_risk_grade,
    COUNT(*) AS loans,
    CAST(AVG(CAST(defaulted AS FLOAT)) AS DECIMAL(5,4)) AS actual_default_rate
FROM Fact_Loan
WHERE model_risk_grade IS NOT NULL
GROUP BY lc_grade, model_risk_grade
ORDER BY lc_grade, model_risk_grade;
GO

/* ============================================================================
   QUERY 3b: Model grade vs LendingClub grade, OUT-OF-TIME test vintages only
   The scorecard never saw these loans (2017-10 to 2018-12). This is the
   comparison to quote. If you change the train/test split in the notebook,
   change the date below to match.
   ============================================================================ */
SELECT
    lc_grade,
    model_risk_grade,
    COUNT(*) AS loans,
    CAST(AVG(CAST(defaulted AS FLOAT)) AS DECIMAL(5,4)) AS actual_default_rate
FROM Fact_Loan
WHERE model_risk_grade IS NOT NULL
  AND vintage_month >= '2017-10'
GROUP BY lc_grade, model_risk_grade
ORDER BY lc_grade, model_risk_grade;
GO

/* ============================================================================
   QUERY 4: Risk decile by DTI (pre-model, exploratory)
   loan_id is the tie-breaker so decile membership is the same on every run
   (many loans share the same DTI, and NTILE splits ties arbitrarily without it).
   Decile 1 = highest DTI.
   Expect default rate per decile, 1 to 10 (15000 loans each):
     0.3085, 0.2762, 0.2477, 0.2278, 0.2121, 0.1965, 0.1876, 0.1733, 0.1648, 0.1601
   Third-decimal differences from an earlier run are tie-ordering effects.
   ============================================================================ */
WITH RiskDeciles AS (
    SELECT
        f.loan_id,
        f.loan_amnt,
        b.dti,
        f.defaulted,
        NTILE(10) OVER (ORDER BY b.dti DESC, f.loan_id) AS risk_decile
    FROM Fact_Loan f
    JOIN Dim_Borrower b ON f.loan_id = b.loan_id
)
SELECT
    risk_decile,
    COUNT(*)                                             AS loans,
    SUM(loan_amnt)                                       AS exposure,
    CAST(AVG(CAST(defaulted AS FLOAT)) AS DECIMAL(5,4))  AS decile_default_rate
FROM RiskDeciles
GROUP BY risk_decile
ORDER BY risk_decile;
GO

/* ============================================================================
   QUERY 5: Geographic concentration
   Expect top 5 by exposure: CA 318504500 (14.62%), TX 191570700 (8.80%),
   NY 172353050 (7.91%), FL 150554600 (6.91%), IL 83533525 (3.84%).
   CA + TX + NY + FL = 38.2% of exposure. 50 states in total.
   ============================================================================ */
SELECT
    b.addr_state,
    COUNT(*)                                             AS loans,
    SUM(f.loan_amnt)                                     AS exposure,
    ROUND(100.0 * SUM(f.loan_amnt) / SUM(SUM(f.loan_amnt)) OVER (), 2) AS pct_of_exposure,
    CAST(AVG(CAST(f.defaulted AS FLOAT)) AS DECIMAL(5,4)) AS state_default_rate
FROM Fact_Loan f
JOIN Dim_Borrower b ON f.loan_id = b.loan_id
GROUP BY b.addr_state
ORDER BY exposure DESC;
GO

/* ============================================================================
   QUERY 6: Purpose-level risk and pricing
   Small categories are unreliable: wedding has 2 loans (50% default) and
   renewable_energy has 89. Compare purposes with at least 1000 loans.
   Expect: small_business 1430 loans, default 0.3510, avg rate 15.91;
           debt_consolidation 86142 loans, default 0.2273
   ============================================================================ */
SELECT
    purpose,
    COUNT(*)                                             AS loans,
    ROUND(AVG(int_rate), 2)                              AS avg_int_rate,
    CAST(AVG(CAST(defaulted AS FLOAT)) AS DECIMAL(5,4))  AS default_rate,
    CASE WHEN COUNT(*) >= 1000 THEN 'reliable' ELSE 'small sample' END AS sample_size_flag
FROM Fact_Loan
GROUP BY purpose
ORDER BY loans DESC;
GO

/* ============================================================================
   QUERY 7 (view): vw_PortfolioRiskSummary
   The flat view Power BI connects to.
   ============================================================================ */
CREATE OR ALTER VIEW vw_PortfolioRiskSummary AS
SELECT
    f.loan_id, f.issue_date, f.vintage_month, f.loan_amnt, f.term_months,
    f.int_rate, f.lc_grade, f.lc_sub_grade, f.purpose, f.loan_status, f.defaulted,
    f.model_score, f.model_risk_grade,
    b.addr_state, b.home_ownership, b.annual_inc, b.bureau_score, b.dti, b.revol_util
FROM Fact_Loan f
JOIN Dim_Borrower b ON f.loan_id = b.loan_id;
GO
