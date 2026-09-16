/* ============================================================================
   Bank Loan Risk Intelligence Platform — REAL DATA VERSION
   02_Analysis_Queries_LendingClub.sql
   ============================================================================ */

USE BankLoanRisk_Real;
GO

/* ============================================================================
   QUERY 1 — Portfolio Overview KPIs
   ============================================================================ */
SELECT
    COUNT(*)                                            AS total_loans,
    SUM(loan_amnt)                                       AS total_exposure,
    SUM(CASE WHEN defaulted = 1 THEN loan_amnt ELSE 0 END) AS exposure_at_default,
    CAST(AVG(CAST(defaulted AS FLOAT)) AS DECIMAL(5,4))  AS portfolio_default_rate
FROM Fact_Loan;
GO

/* ============================================================================
   QUERY 2 — Vintage Analysis by Origination Month
   ============================================================================ */
SELECT
    vintage_month,
    COUNT(*)                                            AS loans_originated,
    SUM(loan_amnt)                                       AS vintage_exposure,
    CAST(AVG(CAST(defaulted AS FLOAT)) AS DECIMAL(5,4))  AS vintage_default_rate
FROM Fact_Loan
GROUP BY vintage_month
ORDER BY vintage_month;
GO

/* ============================================================================
   QUERY 3 — Your Scorecard vs. LendingClub's Own Grade
   Technique: cross-tab comparison — this is the strongest "real data" angle
   Business question: does your independently-built WOE/IV scorecard agree
   with LendingClub's own A-G grade? Where do they diverge, and why?
   (Populate model_risk_grade first via your Python scorecard notebook)
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
   QUERY 4 — Delinquency Snapshot (roll-rate proxy)
   Technique: conditional aggregation on loan_status
   Real-data limitation: LendingClub gives current status, not a full
   transition history like the synthetic version — so this is a snapshot
   of where currently-open loans sit, not a true period-over-period roll-rate.
   Document this distinction in your Key Insight section.
   ============================================================================ */
SELECT
    loan_status,
    COUNT(*)            AS loans,
    SUM(loan_amnt)        AS exposure,
    AVG(int_rate)          AS avg_interest_rate
FROM Fact_Loan
WHERE loan_status NOT IN ('Fully Paid', 'Charged Off', 'Default')
GROUP BY loan_status
ORDER BY loans DESC;
GO

/* ============================================================================
   QUERY 5 — Risk Decile by DTI (pre-model, exploratory)
   ============================================================================ */
WITH RiskDeciles AS (
    SELECT
        f.loan_id,
        f.loan_amnt,
        b.dti,
        f.defaulted,
        NTILE(10) OVER (ORDER BY b.dti DESC) AS risk_decile
    FROM Fact_Loan f
    JOIN Dim_Borrower b ON f.loan_id = b.loan_id
)
SELECT
    risk_decile,
    COUNT(*)                                            AS loans,
    SUM(loan_amnt)                                       AS exposure,
    CAST(AVG(CAST(defaulted AS FLOAT)) AS DECIMAL(5,4))  AS decile_default_rate
FROM RiskDeciles
GROUP BY risk_decile
ORDER BY risk_decile;
GO

/* ============================================================================
   QUERY 6 — Geographic Concentration
   ============================================================================ */
SELECT
    b.addr_state,
    COUNT(*)                                            AS loans,
    SUM(f.loan_amnt)                                     AS exposure,
    CAST(AVG(CAST(f.defaulted AS FLOAT)) AS DECIMAL(5,4)) AS state_default_rate
FROM Fact_Loan f
JOIN Dim_Borrower b ON f.loan_id = b.loan_id
GROUP BY b.addr_state
ORDER BY exposure DESC;
GO

/* ============================================================================
   QUERY 7 — Purpose-Level Risk & Pricing
   ============================================================================ */
SELECT
    purpose,
    COUNT(*)                                            AS loans,
    AVG(int_rate)                                         AS avg_int_rate,
    CAST(AVG(CAST(defaulted AS FLOAT)) AS DECIMAL(5,4))  AS default_rate
FROM Fact_Loan
GROUP BY purpose
ORDER BY loans DESC;
GO

/* ============================================================================
   QUERY 8 (view) — vw_PortfolioRiskSummary
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
