/* ============================================================================
   Bank Loan Risk Intelligence: load model scores into Fact_Loan
   03_Load_Model_Scores.sql

   Run after 01_Database_Setup_LendingClub.sql and after notebook 04 has
   written Dataset/loans_scored.csv (columns: id, model_score, model_risk_grade).
   Query 3a/3b in 02_Analysis_Queries_LendingClub.sql need these columns.

   Step 1: in SSMS, right-click the BankLoanRisk_Real database, Tasks,
           Import Flat File, choose loans_scored.csv, name the table
           stg_loans_scored.
           (If you retrain the model later: DROP TABLE stg_loans_scored first,
           then import the new file again.)
   Step 2: run this script.
   "Expect" comments = values calculated outside SQL Server; confirm them.
   ============================================================================ */

USE BankLoanRisk_Real;
GO

-- Expect: 150000 staged rows, 150000 distinct ids
SELECT COUNT(*) AS staged_rows, COUNT(DISTINCT id) AS distinct_ids
FROM stg_loans_scored;
GO

UPDATE f
SET f.model_score      = s.model_score,
    f.model_risk_grade = CAST(s.model_risk_grade AS CHAR(1))
FROM Fact_Loan f
JOIN stg_loans_scored s
  ON f.loan_id = CAST(s.id AS VARCHAR(20));
GO   -- Expect: 150000 rows affected

-- Reconciliation. Expect: 150000 loans, 0 missing scores, 0 missing grades
SELECT COUNT(*) AS loans,
       SUM(CASE WHEN model_score      IS NULL THEN 1 ELSE 0 END) AS missing_score,
       SUM(CASE WHEN model_risk_grade IS NULL THEN 1 ELSE 0 END) AS missing_grade
FROM Fact_Loan;
GO

-- Score range and grade distribution
-- Expect (corrected notebooks): scores 453 to 591, not 300 to 850, and grades A to G all present
-- (loans per grade A 12305, B 18812, C 22398, D 27240, E 30179, F 24346, G 14720).
SELECT MIN(model_score) AS min_score, MAX(model_score) AS max_score FROM Fact_Loan;

SELECT model_risk_grade, COUNT(*) AS loans,
       CAST(AVG(CAST(defaulted AS FLOAT)) AS DECIMAL(5,4)) AS default_rate
FROM Fact_Loan
GROUP BY model_risk_grade
ORDER BY model_risk_grade;
GO
