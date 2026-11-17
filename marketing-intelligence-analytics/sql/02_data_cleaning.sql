/* ================================================================
   STEP 2: DATA CLEANING PIPELINE
   Input  : dbo.marketing_data            (raw, never modified)
   Output : dbo.marketing_data_cleaned    (analysis-ready table)
            dbo.marketing_rejected        (rows removed, with the reason)
            dbo.data_cleaning_log         (one row per rule, counts computed from the data)
   Every rule below is a documented analyst decision based on the Step 1
   profiling results. The script can be re-run: it drops and rebuilds its outputs.
   "Expect" comments = counts checked outside SQL Server; confirm them after running.
   ================================================================ */

USE MarketingIntelligence;
GO

IF OBJECT_ID('dbo.data_cleaning_log',      'U') IS NOT NULL DROP TABLE dbo.data_cleaning_log;
IF OBJECT_ID('dbo.marketing_rejected',     'U') IS NOT NULL DROP TABLE dbo.marketing_rejected;
IF OBJECT_ID('dbo.marketing_data_cleaned', 'U') IS NOT NULL DROP TABLE dbo.marketing_data_cleaned;
GO

-- ----------------------------------------------------------------
-- RULE 1: EXACT DUPLICATES
-- Records identical in all 27 attributes except ID are treated as suspected repeated
-- entries of one customer (an analyst decision; the data cannot prove it). The lowest ID is kept; the others go to
-- marketing_rejected instead of being deleted without a trace.
-- Expect: 47 rows rejected (47 groups of exactly 2)
-- ----------------------------------------------------------------
WITH Grp AS (
    SELECT *,
        MIN(ID) OVER (
            PARTITION BY Year_Birth, Education, Marital_Status, Income, Kidhome, Teenhome,
                         Dt_Customer, Recency, MntWines, MntFruits, MntMeatProducts,
                         MntFishProducts, MntSweetProducts, MntGoldProds, NumDealsPurchases,
                         NumWebPurchases, NumCatalogPurchases, NumStorePurchases,
                         NumWebVisitsMonth, AcceptedCmp1, AcceptedCmp2, AcceptedCmp3,
                         AcceptedCmp4, AcceptedCmp5, Response, Complain, Country) AS Kept_ID
    FROM dbo.marketing_data
)
SELECT *, CAST(N'Suspected duplicate of another record (all attributes except ID)' AS NVARCHAR(100)) AS Rejection_Reason
INTO dbo.marketing_rejected
FROM Grp
WHERE ID <> Kept_ID;
GO

-- ----------------------------------------------------------------
-- RULES 2-6 applied while building the cleaned table
--   2. Birth year before 1920 (3 rows)      -> Year_Birth set to NULL, row kept, flagged
--   3. Income 666666 (1 row, extreme outlier) -> Income set to NULL, row kept, flagged
--   4. Missing income (24 rows)              -> left NULL, NOT imputed, flagged
--   5. Marital_Status: Alone -> Single; YOLO and Absurd -> Unknown
--   6. Spend > 0 but zero purchases (6 rows) -> kept, flagged only
-- Rows are kept wherever possible because age and income are not used in
-- the RFM or campaign analysis, so dropping those customers would remove
-- their spending for no benefit.
-- ----------------------------------------------------------------
WITH Grp AS (
    SELECT *,
        MIN(ID) OVER (
            PARTITION BY Year_Birth, Education, Marital_Status, Income, Kidhome, Teenhome,
                         Dt_Customer, Recency, MntWines, MntFruits, MntMeatProducts,
                         MntFishProducts, MntSweetProducts, MntGoldProds, NumDealsPurchases,
                         NumWebPurchases, NumCatalogPurchases, NumStorePurchases,
                         NumWebVisitsMonth, AcceptedCmp1, AcceptedCmp2, AcceptedCmp3,
                         AcceptedCmp4, AcceptedCmp5, Response, Complain, Country) AS Kept_ID
    FROM dbo.marketing_data
)
SELECT
    ID,
    CASE WHEN Year_Birth < 1920 THEN NULL ELSE Year_Birth END AS Year_Birth,
    Education,
    CASE Marital_Status
        WHEN N'Alone'  THEN N'Single'
        WHEN N'YOLO'   THEN N'Unknown'
        WHEN N'Absurd' THEN N'Unknown'
        ELSE Marital_Status
    END AS Marital_Status,
    CASE WHEN Income = 666666 THEN NULL ELSE Income END AS Income,
    Kidhome, Teenhome, Dt_Customer, Recency,
    MntWines, MntFruits, MntMeatProducts, MntFishProducts, MntSweetProducts, MntGoldProds,
    NumDealsPurchases, NumWebPurchases, NumCatalogPurchases, NumStorePurchases, NumWebVisitsMonth,
    AcceptedCmp3, AcceptedCmp4, AcceptedCmp5, AcceptedCmp1, AcceptedCmp2, Response, Complain,
    Country,
    CAST(CASE WHEN Year_Birth < 1920 THEN N'Implausible year set to NULL' END AS NVARCHAR(60)) AS Birth_Year_Flag,
    CAST(CASE WHEN Income IS NULL     THEN N'Missing in source'
              WHEN Income = 666666    THEN N'Extreme outlier set to NULL'
         END AS NVARCHAR(60)) AS Income_Flag,
    CAST(CASE WHEN (MntWines + MntFruits + MntMeatProducts + MntFishProducts + MntSweetProducts + MntGoldProds) > 0
               AND (NumWebPurchases + NumCatalogPurchases + NumStorePurchases) = 0
              THEN N'Spend recorded with zero channel purchases'
         END AS NVARCHAR(60)) AS Purchase_Consistency_Flag
INTO dbo.marketing_data_cleaned
FROM Grp
WHERE ID = Kept_ID;
GO

ALTER TABLE dbo.marketing_data_cleaned ALTER COLUMN ID SMALLINT NOT NULL;
ALTER TABLE dbo.marketing_data_cleaned ADD CONSTRAINT PK_marketing_data_cleaned PRIMARY KEY (ID);
GO

-- ----------------------------------------------------------------
-- CLEANING LOG (counts come from the tables, not typed in by hand)
-- Expect rows affected: 47, 3, 1, 24, 3, 4, 6
-- ----------------------------------------------------------------
CREATE TABLE dbo.data_cleaning_log (
    Rule_No        INT PRIMARY KEY,
    Issue          NVARCHAR(200),
    Rows_Affected  INT,
    Action_Taken   NVARCHAR(300),
    Rationale      NVARCHAR(500)
);
GO

INSERT INTO dbo.data_cleaning_log (Rule_No, Issue, Rows_Affected, Action_Taken, Rationale)
SELECT 1, N'Suspected duplicate records (identical in all attributes except ID)', COUNT(*),
       N'Excluded from cleaned table (lowest ID kept); retained in marketing_rejected; raw table untouched',
       N'Analyst decision: identical enrolment date, recency, spending and demographics make repeated entries more likely than two real customers, but the data cannot prove it'
FROM dbo.marketing_rejected;

INSERT INTO dbo.data_cleaning_log (Rule_No, Issue, Rows_Affected, Action_Taken, Rationale)
SELECT 2, N'Birth year before 1920 (ages 114 to 121 in 2014)', COUNT(*),
       N'Year_Birth set to NULL; row kept; flagged in Birth_Year_Flag',
       N'Age is not used in the RFM or campaign analysis, so the customer spend is kept. The 1920 limit is an analyst-chosen review threshold'
FROM dbo.marketing_data_cleaned WHERE Birth_Year_Flag IS NOT NULL;

INSERT INTO dbo.data_cleaning_log (Rule_No, Issue, Rows_Affected, Action_Taken, Rationale)
SELECT 3, N'Income 666666, far above the next highest value (162397)', COUNT(*),
       N'Income set to NULL; row kept; flagged in Income_Flag',
       N'Extreme outlier that would distort income averages. The data cannot prove it is a placeholder, so the decision is logged rather than hidden'
FROM dbo.marketing_data_cleaned WHERE Income_Flag LIKE N'Extreme%';

INSERT INTO dbo.data_cleaning_log (Rule_No, Issue, Rows_Affected, Action_Taken, Rationale)
SELECT 4, N'Missing Income', COUNT(*),
       N'Left as NULL, not imputed; flagged in Income_Flag',
       N'Missingness is uneven (Australia 13 of 160 customers, 8.1%), so a single fill value could bias income analysis. Income is not used in RFM'
FROM dbo.marketing_data_cleaned WHERE Income_Flag = N'Missing in source';

INSERT INTO dbo.data_cleaning_log (Rule_No, Issue, Rows_Affected, Action_Taken, Rationale)
SELECT 5, N'Marital_Status = Alone', COUNT(*),
       N'Relabelled as Single (analyst-defined standardization)',
       N'Assumption: Alone and Single describe the same status. Original value remains in marketing_data'
FROM dbo.marketing_data m
WHERE m.Marital_Status = N'Alone' AND m.ID IN (SELECT ID FROM dbo.marketing_data_cleaned);

INSERT INTO dbo.data_cleaning_log (Rule_No, Issue, Rows_Affected, Action_Taken, Rationale)
SELECT 6, N'Marital_Status = YOLO or Absurd (not valid statuses)', COUNT(*),
       N'Relabelled as Unknown (analyst-defined standardization)',
       N'No safe way to infer the real status, so it is marked Unknown rather than guessed'
FROM dbo.marketing_data m
WHERE m.Marital_Status IN (N'YOLO', N'Absurd') AND m.ID IN (SELECT ID FROM dbo.marketing_data_cleaned);

INSERT INTO dbo.data_cleaning_log (Rule_No, Issue, Rows_Affected, Action_Taken, Rationale)
SELECT 7, N'Spend recorded but zero web, catalog and store purchases', COUNT(*),
       N'Kept; flagged in Purchase_Consistency_Flag; no values changed',
       N'Cause unknown. These rows get Frequency 0 in RFM, so Step 4 should test results with and without them'
FROM dbo.marketing_data_cleaned WHERE Purchase_Consistency_Flag IS NOT NULL;
GO

-- ----------------------------------------------------------------
-- RECONCILIATION: every raw row must be accounted for
-- Expect: Raw 2240 = Cleaned 2193 + Rejected 47, Unaccounted 0
-- ----------------------------------------------------------------
SELECT
    (SELECT COUNT(*) FROM dbo.marketing_data)         AS Raw_Rows,
    (SELECT COUNT(*) FROM dbo.marketing_data_cleaned) AS Cleaned_Rows,
    (SELECT COUNT(*) FROM dbo.marketing_rejected)     AS Rejected_Rows,
    (SELECT COUNT(*) FROM dbo.marketing_data)
      - (SELECT COUNT(*) FROM dbo.marketing_data_cleaned)
      - (SELECT COUNT(*) FROM dbo.marketing_rejected) AS Unaccounted_Rows;

SELECT Rule_No, Issue, Rows_Affected, Action_Taken FROM dbo.data_cleaning_log ORDER BY Rule_No;
GO
