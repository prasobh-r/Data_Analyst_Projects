/* ============================================================================
   Bank Loan Risk Intelligence Platform — REAL DATA VERSION
   01_Database_Setup_LendingClub.sql

   Builds a star schema from Dataset/loans_clean.csv (produced by
   Python/00_load_and_clean_lendingclub.py). Unlike the synthetic version,
   LendingClub is naturally closer to one wide table, so this schema splits
   it into a Dim_Applicant-style attribute dimension and a Fact_Loan table
   rather than 5 separate source tables.

   Import: SSMS "Import Flat File" on loans_clean.csv into stg_loans_clean,
   then run this script.
   ============================================================================ */

CREATE DATABASE BankLoanRisk_Real;
GO
USE BankLoanRisk_Real;
GO

/* ----------------------------------------------------------------------
   Dim_Borrower — attributes that describe the borrower, not the loan
   ---------------------------------------------------------------------- */
CREATE TABLE Dim_Borrower (
    loan_id                 VARCHAR(20) PRIMARY KEY,   -- LendingClub's 'id' — one loan per borrower record here
    emp_title               VARCHAR(200) NULL,
    emp_length              VARCHAR(20),
    home_ownership          VARCHAR(20),
    annual_inc              DECIMAL(14,2),
    monthly_income          DECIMAL(12,2),
    verification_status     VARCHAR(30),
    addr_state              CHAR(2),
    bureau_score            DECIMAL(6,1),        -- avg of fico_range_low/high
    dti                     DECIMAL(6,2),
    delinq_2yrs             INT,
    inq_last_6mths          INT,
    open_acc                INT,
    revol_bal               DECIMAL(14,2),
    revol_util              DECIMAL(5,2),
    total_acc               INT
);
GO

/* ----------------------------------------------------------------------
   Fact_Loan — one row per loan
   ---------------------------------------------------------------------- */
CREATE TABLE Fact_Loan (
    loan_id             VARCHAR(20) PRIMARY KEY REFERENCES Dim_Borrower(loan_id),
    issue_date          DATE,
    vintage_month        CHAR(7),
    loan_amnt           DECIMAL(12,2),
    term_months         INT,
    int_rate            DECIMAL(5,2),
    installment         DECIMAL(10,2),
    lc_grade            CHAR(1),          -- LendingClub's own grade, A-G
    lc_sub_grade        VARCHAR(3),
    purpose             VARCHAR(30),
    loan_status         VARCHAR(30),
    defaulted           BIT,
    last_pymnt_date     DATE NULL,
    last_pymnt_amnt     DECIMAL(12,2) NULL,
    total_pymnt         DECIMAL(14,2),
    out_prncp           DECIMAL(12,2),
    -- populate after your own WOE/IV scorecard notebook:
    model_score         INT NULL,
    model_risk_grade    CHAR(1) NULL
);
GO

/* ----------------------------------------------------------------------
   Load from staging
   ---------------------------------------------------------------------- */
INSERT INTO Dim_Borrower (loan_id, emp_title, emp_length, home_ownership,
                           annual_inc, monthly_income, verification_status,
                           addr_state, bureau_score, dti, delinq_2yrs,
                           inq_last_6mths, open_acc, revol_bal, revol_util, total_acc)
SELECT id, emp_title, emp_length, home_ownership, annual_inc, monthly_income,
       verification_status, addr_state, bureau_score, dti, delinq_2yrs,
       inq_last_6mths, open_acc, revol_bal, revol_util, total_acc
FROM stg_loans_clean;
GO

INSERT INTO Fact_Loan (loan_id, issue_date, vintage_month, loan_amnt, term_months,
                        int_rate, installment, lc_grade, lc_sub_grade, purpose,
                        loan_status, defaulted, last_pymnt_date, last_pymnt_amnt,
                        total_pymnt, out_prncp)
SELECT id, issue_d, vintage_month, loan_amnt, term_months, int_rate, installment,
       grade, sub_grade, purpose, loan_status, defaulted, last_pymnt_d,
       last_pymnt_amnt, total_pymnt, out_prncp
FROM stg_loans_clean;
GO

CREATE INDEX IX_Loan_Vintage ON Fact_Loan(vintage_month);
CREATE INDEX IX_Loan_Grade ON Fact_Loan(lc_grade);
CREATE INDEX IX_Loan_State ON Dim_Borrower(addr_state);
GO

/* ----------------------------------------------------------------------
   Note on roll-rate / delinquency analysis with real data:
   LendingClub does not give a full installment-by-installment payment
   history (unlike the synthetic version's Fact_Repayment table). Instead,
   use loan_status directly for a coarser but still real delinquency signal:
   'Late (16-30 days)', 'Late (31-120 days)', 'In Grace Period', 'Current',
   'Charged Off', 'Default'. Query 4 in 02_Analysis_Queries_LendingClub.sql
   adapts the roll-rate concept to this reality rather than pretending you
   have data you don't — document this as a real dataset limitation.
   ---------------------------------------------------------------------- */
