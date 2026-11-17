/* ================================================================
   STEP 3: DATA QUALITY VALIDATION  (read-only on the data tables)
   Compares dbo.marketing_data (raw) with dbo.marketing_data_cleaned
   and proves the cleaning did what the log says, and nothing else.
   Output: dbo.data_validation_results (PASS/FAIL per check)
           + a before/after summary table.
   "Expect" comments = values calculated outside SQL Server; confirm after running.
   Any FAIL must be investigated before Step 4.
   ================================================================ */

USE MarketingIntelligence;
GO

IF OBJECT_ID('dbo.data_validation_results', 'U') IS NOT NULL DROP TABLE dbo.data_validation_results;
GO

CREATE TABLE dbo.data_validation_results (
    Check_No    INT PRIMARY KEY,
    Check_Name  NVARCHAR(200),
    Expected    BIGINT,
    Actual      BIGINT,
    Result      AS (CASE WHEN Expected = Actual THEN 'PASS' ELSE 'FAIL' END)
);
GO

-- ----------------------------------------------------------------
-- PART A: VALIDATION CHECKS (all 18 should PASS)
-- ----------------------------------------------------------------
DECLARE @clean_dups INT;

SELECT @clean_dups = COUNT(*)
FROM (
    SELECT ID,
        MIN(ID) OVER (
            PARTITION BY Year_Birth, Education, Marital_Status, Income, Kidhome, Teenhome,
                         Dt_Customer, Recency, MntWines, MntFruits, MntMeatProducts,
                         MntFishProducts, MntSweetProducts, MntGoldProds, NumDealsPurchases,
                         NumWebPurchases, NumCatalogPurchases, NumStorePurchases,
                         NumWebVisitsMonth, AcceptedCmp1, AcceptedCmp2, AcceptedCmp3,
                         AcceptedCmp4, AcceptedCmp5, Response, Complain, Country) AS First_ID
    FROM dbo.marketing_data_cleaned
) t
WHERE ID <> First_ID;

INSERT INTO dbo.data_validation_results (Check_No, Check_Name, Expected, Actual)
VALUES
(1,  N'Row reconciliation: raw rows = cleaned + rejected',
     (SELECT COUNT(*) FROM dbo.marketing_data),
     (SELECT COUNT(*) FROM dbo.marketing_data_cleaned) + (SELECT COUNT(*) FROM dbo.marketing_rejected)),

(2,  N'Cleaned table: every ID is unique',
     (SELECT COUNT(*) FROM dbo.marketing_data_cleaned),
     (SELECT COUNT(DISTINCT ID) FROM dbo.marketing_data_cleaned)),

(3,  N'Cleaned table: suspected-duplicate rows remaining',
     0, @clean_dups),

(4,  N'Every rejected row has its kept twin present in the cleaned table',
     (SELECT COUNT(*) FROM dbo.marketing_rejected),
     (SELECT COUNT(*) FROM dbo.marketing_rejected r
       WHERE r.Kept_ID IN (SELECT ID FROM dbo.marketing_data_cleaned))),

(5,  N'No rejected ID also appears in the cleaned table',
     0,
     (SELECT COUNT(*) FROM dbo.marketing_rejected r
       WHERE r.ID IN (SELECT ID FROM dbo.marketing_data_cleaned))),

(6,  N'Birth years before 1920 remaining',
     0,
     (SELECT COUNT(*) FROM dbo.marketing_data_cleaned WHERE Year_Birth < 1920)),

(7,  N'NULL Year_Birth count = rows flagged in Birth_Year_Flag',
     (SELECT COUNT(*) FROM dbo.marketing_data_cleaned WHERE Birth_Year_Flag IS NOT NULL),
     (SELECT COUNT(*) FROM dbo.marketing_data_cleaned WHERE Year_Birth IS NULL)),

(8,  N'Income value 666666 remaining',
     0,
     (SELECT COUNT(*) FROM dbo.marketing_data_cleaned WHERE Income = 666666)),

(9,  N'NULL Income count = rows flagged in Income_Flag',
     (SELECT COUNT(*) FROM dbo.marketing_data_cleaned WHERE Income_Flag IS NOT NULL),
     (SELECT COUNT(*) FROM dbo.marketing_data_cleaned WHERE Income IS NULL)),

(10, N'Marital_Status values outside the allowed list',
     0,
     (SELECT COUNT(*) FROM dbo.marketing_data_cleaned
       WHERE Marital_Status NOT IN (N'Married', N'Together', N'Single', N'Divorced', N'Widow', N'Unknown'))),

(11, N'Unexpected NULLs in columns that should be complete',
     0,
     (SELECT COUNT(*) FROM dbo.marketing_data_cleaned
       WHERE ID IS NULL OR Education IS NULL OR Marital_Status IS NULL OR Kidhome IS NULL
          OR Teenhome IS NULL OR Dt_Customer IS NULL OR Recency IS NULL OR MntWines IS NULL
          OR MntFruits IS NULL OR MntMeatProducts IS NULL OR MntFishProducts IS NULL
          OR MntSweetProducts IS NULL OR MntGoldProds IS NULL OR NumDealsPurchases IS NULL
          OR NumWebPurchases IS NULL OR NumCatalogPurchases IS NULL OR NumStorePurchases IS NULL
          OR NumWebVisitsMonth IS NULL OR AcceptedCmp1 IS NULL OR AcceptedCmp2 IS NULL
          OR AcceptedCmp3 IS NULL OR AcceptedCmp4 IS NULL OR AcceptedCmp5 IS NULL
          OR Response IS NULL OR Complain IS NULL OR Country IS NULL)),

(12, N'Total spend reconciles: raw = cleaned + rejected',
     (SELECT SUM(CAST(MntWines + MntFruits + MntMeatProducts + MntFishProducts + MntSweetProducts + MntGoldProds AS BIGINT))
        FROM dbo.marketing_data),
     (SELECT SUM(CAST(MntWines + MntFruits + MntMeatProducts + MntFishProducts + MntSweetProducts + MntGoldProds AS BIGINT))
        FROM dbo.marketing_data_cleaned)
   + (SELECT SUM(CAST(MntWines + MntFruits + MntMeatProducts + MntFishProducts + MntSweetProducts + MntGoldProds AS BIGINT))
        FROM dbo.marketing_rejected)),

(13, N'Campaign acceptances reconcile: raw = cleaned + rejected',
     (SELECT SUM(CAST(AcceptedCmp1 AS BIGINT) + AcceptedCmp2 + AcceptedCmp3 + AcceptedCmp4 + AcceptedCmp5 + Response)
        FROM dbo.marketing_data),
     (SELECT SUM(CAST(AcceptedCmp1 AS BIGINT) + AcceptedCmp2 + AcceptedCmp3 + AcceptedCmp4 + AcceptedCmp5 + Response)
        FROM dbo.marketing_data_cleaned)
   + (SELECT SUM(CAST(AcceptedCmp1 AS BIGINT) + AcceptedCmp2 + AcceptedCmp3 + AcceptedCmp4 + AcceptedCmp5 + Response)
        FROM dbo.marketing_rejected)),

(14, N'Columns the rules never touch are identical to raw (rows that differ)',
     0,
     (SELECT COUNT(*)
        FROM dbo.marketing_data_cleaned c
        JOIN dbo.marketing_data m ON m.ID = c.ID
       WHERE c.Education <> m.Education OR c.Country <> m.Country OR c.Dt_Customer <> m.Dt_Customer
          OR c.Recency <> m.Recency OR c.Kidhome <> m.Kidhome OR c.Teenhome <> m.Teenhome
          OR c.MntWines <> m.MntWines OR c.MntFruits <> m.MntFruits OR c.MntMeatProducts <> m.MntMeatProducts
          OR c.MntFishProducts <> m.MntFishProducts OR c.MntSweetProducts <> m.MntSweetProducts
          OR c.MntGoldProds <> m.MntGoldProds OR c.NumDealsPurchases <> m.NumDealsPurchases
          OR c.NumWebPurchases <> m.NumWebPurchases OR c.NumCatalogPurchases <> m.NumCatalogPurchases
          OR c.NumStorePurchases <> m.NumStorePurchases OR c.NumWebVisitsMonth <> m.NumWebVisitsMonth
          OR c.AcceptedCmp1 <> m.AcceptedCmp1 OR c.AcceptedCmp2 <> m.AcceptedCmp2
          OR c.AcceptedCmp3 <> m.AcceptedCmp3 OR c.AcceptedCmp4 <> m.AcceptedCmp4
          OR c.AcceptedCmp5 <> m.AcceptedCmp5 OR c.Response <> m.Response OR c.Complain <> m.Complain)),

(15, N'Income changed only for the logged outlier (NULL-aware comparison)',
     0,
     (SELECT COUNT(*)
        FROM dbo.marketing_data_cleaned c
        JOIN dbo.marketing_data m ON m.ID = c.ID
       WHERE (m.Income <> c.Income
              OR (m.Income IS NULL     AND c.Income IS NOT NULL)
              OR (m.Income IS NOT NULL AND c.Income IS NULL))
         AND NOT (m.Income = 666666 AND c.Income IS NULL))),

(16, N'Marital_Status changed only for Alone, YOLO, Absurd (other rows that differ)',
     0,
     (SELECT COUNT(*)
        FROM dbo.marketing_data_cleaned c
        JOIN dbo.marketing_data m ON m.ID = c.ID
       WHERE c.Marital_Status <> m.Marital_Status
         AND m.Marital_Status NOT IN (N'Alone', N'YOLO', N'Absurd'))),

(17, N'The 666666 income outlier was set to NULL (kept rows with 666666 in raw vs set to NULL)',
     (SELECT COUNT(*) FROM dbo.marketing_data
       WHERE Income = 666666 AND ID IN (SELECT ID FROM dbo.marketing_data_cleaned)),
     (SELECT COUNT(*)
        FROM dbo.marketing_data_cleaned c
        JOIN dbo.marketing_data m ON m.ID = c.ID
       WHERE m.Income = 666666 AND c.Income IS NULL)),

(18, N'Year_Birth changed only for birth years before 1920 (NULL-aware comparison)',
     0,
     (SELECT COUNT(*)
        FROM dbo.marketing_data_cleaned c
        JOIN dbo.marketing_data m ON m.ID = c.ID
       WHERE m.Year_Birth <> c.Year_Birth
          OR (c.Year_Birth IS NULL AND m.Year_Birth >= 1920)));
GO

SELECT Check_No, Check_Name, Expected, Actual, Result
FROM dbo.data_validation_results
ORDER BY Check_No;
GO

-- ----------------------------------------------------------------
-- PART B: BEFORE / AFTER QUALITY SUMMARY
-- Values are formatted text so counts show no decimals and averages show 2 decimals.
-- Expect (Raw -> Cleaned):
--   Rows 2240 -> 2193 | Suspected duplicate rows 47 -> 0 | Birth years < 1920: 3 -> 0
--   NULL Income 24 -> 25 (the outlier became NULL) | Max Income 666666 -> 162397
--   Avg Income about 52247 -> about 52001 | Distinct marital labels 8 -> 6
--   Non-standard marital labels (Alone, YOLO, Absurd) 7 -> 0
--   Total spend 1356988 -> 1329690 | Avg spend/customer 605.80 -> 606.33
--   Spend with zero purchases 6 -> 6 (flagged, deliberately not changed)
-- ----------------------------------------------------------------
DECLARE @raw_dups INT, @clean_dups2 INT;

SELECT @raw_dups = COUNT(*)
FROM (
    SELECT ID,
        MIN(ID) OVER (
            PARTITION BY Year_Birth, Education, Marital_Status, Income, Kidhome, Teenhome,
                         Dt_Customer, Recency, MntWines, MntFruits, MntMeatProducts,
                         MntFishProducts, MntSweetProducts, MntGoldProds, NumDealsPurchases,
                         NumWebPurchases, NumCatalogPurchases, NumStorePurchases,
                         NumWebVisitsMonth, AcceptedCmp1, AcceptedCmp2, AcceptedCmp3,
                         AcceptedCmp4, AcceptedCmp5, Response, Complain, Country) AS First_ID
    FROM dbo.marketing_data
) t
WHERE ID <> First_ID;

SELECT @clean_dups2 = Actual FROM dbo.data_validation_results WHERE Check_No = 3;

SELECT Metric, Raw_Table, Cleaned_Table
FROM (
    SELECT 1 AS Sort_No, N'Rows' AS Metric,
           FORMAT((SELECT COUNT(*) FROM dbo.marketing_data), 'N0', 'en-US') AS Raw_Table,
           FORMAT((SELECT COUNT(*) FROM dbo.marketing_data_cleaned), 'N0', 'en-US') AS Cleaned_Table
    UNION ALL SELECT 2, N'Suspected duplicate rows (all attributes except ID)',
           FORMAT(@raw_dups, 'N0', 'en-US'), FORMAT(@clean_dups2, 'N0', 'en-US')
    UNION ALL SELECT 3, N'Birth years before 1920',
           FORMAT((SELECT COUNT(*) FROM dbo.marketing_data WHERE Year_Birth < 1920), 'N0', 'en-US'),
           FORMAT((SELECT COUNT(*) FROM dbo.marketing_data_cleaned WHERE Year_Birth < 1920), 'N0', 'en-US')
    UNION ALL SELECT 4, N'Income = NULL',
           FORMAT((SELECT COUNT(*) FROM dbo.marketing_data WHERE Income IS NULL), 'N0', 'en-US'),
           FORMAT((SELECT COUNT(*) FROM dbo.marketing_data_cleaned WHERE Income IS NULL), 'N0', 'en-US')
    UNION ALL SELECT 5, N'Maximum Income',
           FORMAT((SELECT MAX(Income) FROM dbo.marketing_data), 'N0', 'en-US'),
           FORMAT((SELECT MAX(Income) FROM dbo.marketing_data_cleaned), 'N0', 'en-US')
    UNION ALL SELECT 6, N'Average Income',
           FORMAT((SELECT AVG(CAST(Income AS DECIMAL(18,2))) FROM dbo.marketing_data), 'N2', 'en-US'),
           FORMAT((SELECT AVG(CAST(Income AS DECIMAL(18,2))) FROM dbo.marketing_data_cleaned), 'N2', 'en-US')
    UNION ALL SELECT 7, N'Distinct Marital_Status labels',
           FORMAT((SELECT COUNT(DISTINCT Marital_Status) FROM dbo.marketing_data), 'N0', 'en-US'),
           FORMAT((SELECT COUNT(DISTINCT Marital_Status) FROM dbo.marketing_data_cleaned), 'N0', 'en-US')
    UNION ALL SELECT 8, N'Non-standard marital labels (Alone, YOLO, Absurd)',
           FORMAT((SELECT COUNT(*) FROM dbo.marketing_data WHERE Marital_Status IN (N'Alone', N'YOLO', N'Absurd')), 'N0', 'en-US'),
           FORMAT((SELECT COUNT(*) FROM dbo.marketing_data_cleaned WHERE Marital_Status IN (N'Alone', N'YOLO', N'Absurd')), 'N0', 'en-US')
    UNION ALL SELECT 9, N'Total spend (currency units not stated in source)',
           FORMAT((SELECT SUM(CAST(MntWines + MntFruits + MntMeatProducts + MntFishProducts + MntSweetProducts + MntGoldProds AS BIGINT)) FROM dbo.marketing_data), 'N0', 'en-US'),
           FORMAT((SELECT SUM(CAST(MntWines + MntFruits + MntMeatProducts + MntFishProducts + MntSweetProducts + MntGoldProds AS BIGINT)) FROM dbo.marketing_data_cleaned), 'N0', 'en-US')
    UNION ALL SELECT 10, N'Average spend per customer',
           FORMAT((SELECT AVG(CAST(MntWines + MntFruits + MntMeatProducts + MntFishProducts + MntSweetProducts + MntGoldProds AS DECIMAL(18,2))) FROM dbo.marketing_data), 'N2', 'en-US'),
           FORMAT((SELECT AVG(CAST(MntWines + MntFruits + MntMeatProducts + MntFishProducts + MntSweetProducts + MntGoldProds AS DECIMAL(18,2))) FROM dbo.marketing_data_cleaned), 'N2', 'en-US')
    UNION ALL SELECT 11, N'Rows with spend but zero purchases (flagged, not changed)',
           FORMAT((SELECT COUNT(*) FROM dbo.marketing_data
             WHERE (MntWines + MntFruits + MntMeatProducts + MntFishProducts + MntSweetProducts + MntGoldProds) > 0
               AND (NumWebPurchases + NumCatalogPurchases + NumStorePurchases) = 0), 'N0', 'en-US'),
           FORMAT((SELECT COUNT(*) FROM dbo.marketing_data_cleaned WHERE Purchase_Consistency_Flag IS NOT NULL), 'N0', 'en-US')
) s
ORDER BY Sort_No;
GO
