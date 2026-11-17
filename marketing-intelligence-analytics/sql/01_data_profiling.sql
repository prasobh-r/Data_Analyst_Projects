/* ================================================================
   STEP 1: RAW DATA PROFILING  (read-only, changes nothing)
   Table : dbo.marketing_data  (imported via SSMS "Import Flat File")
   Rule  : never UPDATE or DELETE marketing_data. It stays as the raw source.
   Run each section separately and screenshot the results.
   "Expect" comments = what the CSV showed when checked outside SQL Server.
   If your result differs, investigate before moving to Step 2.
   ================================================================ */

USE MarketingIntelligence;
GO

-- ----------------------------------------------------------------
-- 1. COLUMN NAMES AND DATA TYPES
-- Look for: odd characters in the first column (the CSV starts with a
-- hidden BOM character before "ID") and spaces in the Income column name
-- (the CSV header is " Income "). If a name is wrong, fix it once with:
--   EXEC sp_rename 'dbo.marketing_data.[<bad name>]', 'Income', 'COLUMN';
-- Also check Dt_Customer: is it date or varchar?
-- ----------------------------------------------------------------
SELECT ORDINAL_POSITION, COLUMN_NAME, DATA_TYPE, IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'marketing_data'
ORDER BY ORDINAL_POSITION;
GO

-- ----------------------------------------------------------------
-- 2. ROW COUNT AND ID UNIQUENESS
-- Expect: 2240 rows, 2240 non-null IDs, 2240 distinct IDs, 0 NULL IDs, 0 duplicate ID rows
-- ----------------------------------------------------------------
SELECT
    COUNT(*)                                        AS Total_Rows,
    COUNT(ID)                                       AS Non_Null_IDs,
    COUNT(DISTINCT ID)                              AS Distinct_IDs,
    SUM(CASE WHEN ID IS NULL THEN 1 ELSE 0 END)     AS Null_IDs,
    COUNT(ID) - COUNT(DISTINCT ID)                  AS Duplicate_ID_Rows
FROM dbo.marketing_data;
GO

-- ----------------------------------------------------------------
-- 3. NULL COUNT FOR EVERY COLUMN (built automatically from the column list)
-- Expect: only Income has NULLs (24). Requires SQL Server 2017 or later.
-- ----------------------------------------------------------------
DECLARE @sql NVARCHAR(MAX);

SELECT @sql = STRING_AGG(
    CAST(N'SELECT N''' + REPLACE(COLUMN_NAME, '''', '''''') + N''' AS Column_Name, '
       + N'COUNT(*) - COUNT(' + QUOTENAME(COLUMN_NAME) + N') AS Null_Count '
       + N'FROM dbo.marketing_data' AS NVARCHAR(MAX)),
    N' UNION ALL ')
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'marketing_data';

SET @sql = N'SELECT * FROM (' + @sql + N') t ORDER BY Null_Count DESC, Column_Name;';
EXEC sp_executesql @sql;
GO

-- ----------------------------------------------------------------
-- 4. DUPLICATES BY CONTENT (same customer details, different ID)
-- The ID-only check (section 2) cannot see these.
-- Expect: 47 extra rows (e.g. IDs 455 and 7592 are identical apart from ID)
-- Precondition: Section 2 must show 0 NULL IDs. A NULL ID would be skipped by the
-- (ID <> First_ID) test below, so the extra-row count is only trusted if that holds.
-- ----------------------------------------------------------------
IF OBJECT_ID('tempdb..#Dup') IS NOT NULL DROP TABLE #Dup;

SELECT ID, Year_Birth, Income, Dt_Customer, Country,
    MIN(ID) OVER (
        PARTITION BY Year_Birth, Education, Marital_Status, Income, Kidhome, Teenhome,
                     Dt_Customer, Recency, MntWines, MntFruits, MntMeatProducts,
                     MntFishProducts, MntSweetProducts, MntGoldProds, NumDealsPurchases,
                     NumWebPurchases, NumCatalogPurchases, NumStorePurchases,
                     NumWebVisitsMonth, AcceptedCmp1, AcceptedCmp2, AcceptedCmp3,
                     AcceptedCmp4, AcceptedCmp5, Response, Complain, Country) AS First_ID
INTO #Dup
FROM dbo.marketing_data;

-- 4a. how many extra rows
SELECT COUNT(*) AS Extra_Duplicate_Rows FROM #Dup WHERE ID <> First_ID;

-- 4b. the duplicate groups themselves (evidence to screenshot)
SELECT First_ID AS Representative_ID, COUNT(*) AS Rows_In_Group,
       STRING_AGG(CAST(ID AS VARCHAR(20)), ', ') AS IDs_In_Group
FROM #Dup
GROUP BY First_ID
HAVING COUNT(*) > 1
ORDER BY Rows_In_Group DESC, First_ID;
GO

-- ----------------------------------------------------------------
-- 5. IMPLAUSIBLE BIRTH YEARS
-- The thresholds below are analyst-chosen review limits, not rules of the dataset.
-- Expect: 3 rows. 1893 and 1899 = Extreme Age Outlier, 1900 = Unusual Age - Review.
-- (age measured at 2014, the last year in Dt_Customer)
-- ----------------------------------------------------------------
SELECT ID, Year_Birth, 2014 - Year_Birth AS Age_In_2014,
    CASE
        WHEN Year_Birth < 1900 THEN 'Extreme Age Outlier'
        WHEN Year_Birth < 1940 THEN 'Unusual Age - Review'
        ELSE 'Future Birth Year'
    END AS Data_Quality_Flag
FROM dbo.marketing_data
WHERE Year_Birth < 1940 OR Year_Birth > 2014
ORDER BY Year_Birth;
GO

-- ----------------------------------------------------------------
-- 6. INCOME: RANGE, TOP VALUES, ZERO OR NEGATIVE
-- Expect: max 666666, far above the next highest (162397). Treat as an extreme
--         outlier to investigate; the data alone cannot prove it is a placeholder.
--         0 zero/negative values
-- ----------------------------------------------------------------
SELECT MIN(Income) AS Min_Income, MAX(Income) AS Max_Income,
       CAST(AVG(CAST(Income AS DECIMAL(18,2))) AS DECIMAL(18,2)) AS Avg_Income,
       SUM(CASE WHEN Income <= 0 THEN 1 ELSE 0 END) AS Zero_Or_Negative
FROM dbo.marketing_data;

SELECT TOP 5 ID, Income FROM dbo.marketing_data ORDER BY Income DESC;
GO

-- ----------------------------------------------------------------
-- 7. CATEGORY VALUES (spot inconsistent or invalid labels)
-- Expect Marital_Status: Alone (3), YOLO (2), Absurd (2) look invalid
-- Expect Education: "2n Cycle" is a valid label (equivalent to Master), not an error
-- Expect Country: Mexico appears only 3 times
-- ----------------------------------------------------------------
SELECT Marital_Status, COUNT(*) AS Customers FROM dbo.marketing_data GROUP BY Marital_Status ORDER BY Customers DESC;
SELECT Education,      COUNT(*) AS Customers FROM dbo.marketing_data GROUP BY Education      ORDER BY Customers DESC;
SELECT Country,        COUNT(*) AS Customers FROM dbo.marketing_data GROUP BY Country        ORDER BY Customers DESC;
GO

-- ----------------------------------------------------------------
-- 8. DATES
-- The CSV stores dates as yyyy-mm-dd (ISO), which TRY_CONVERT reads by default.
-- Do NOT add style 105 (dd-mm-yyyy): it would flag every row as unreadable.
-- Expect: 0 unreadable dates; range 2012-07-30 to 2014-06-29
-- ----------------------------------------------------------------
SELECT
    SUM(CASE WHEN Dt_Customer IS NOT NULL AND TRY_CONVERT(DATE, Dt_Customer) IS NULL THEN 1 ELSE 0 END) AS Unreadable_Dates,
    MIN(TRY_CONVERT(DATE, Dt_Customer)) AS Earliest,
    MAX(TRY_CONVERT(DATE, Dt_Customer)) AS Latest
FROM dbo.marketing_data;
GO

-- ----------------------------------------------------------------
-- 9. NUMERIC SANITY: NEGATIVES, NULL FLAGS, FLAGS THAT ARE NOT 0/1
-- Expect: 0 negatives; 0 rows with NULL flags; 0 rows with invalid flags
-- (NOT IN skips NULLs, so NULL flags are counted separately.)
-- ----------------------------------------------------------------
SELECT COUNT(*) AS Rows_With_Negative_Values
FROM dbo.marketing_data
WHERE Recency < 0 OR MntWines < 0 OR MntFruits < 0 OR MntMeatProducts < 0
   OR MntFishProducts < 0 OR MntSweetProducts < 0 OR MntGoldProds < 0
   OR NumDealsPurchases < 0 OR NumWebPurchases < 0 OR NumCatalogPurchases < 0
   OR NumStorePurchases < 0 OR NumWebVisitsMonth < 0 OR Kidhome < 0 OR Teenhome < 0;

SELECT
    SUM(CASE WHEN AcceptedCmp1 IS NULL OR AcceptedCmp2 IS NULL OR AcceptedCmp3 IS NULL
              OR AcceptedCmp4 IS NULL OR AcceptedCmp5 IS NULL OR Response IS NULL
              OR Complain IS NULL THEN 1 ELSE 0 END) AS Rows_With_Null_Flags,
    SUM(CASE WHEN (AcceptedCmp1 IS NOT NULL AND AcceptedCmp1 NOT IN (0,1))
              OR (AcceptedCmp2 IS NOT NULL AND AcceptedCmp2 NOT IN (0,1))
              OR (AcceptedCmp3 IS NOT NULL AND AcceptedCmp3 NOT IN (0,1))
              OR (AcceptedCmp4 IS NOT NULL AND AcceptedCmp4 NOT IN (0,1))
              OR (AcceptedCmp5 IS NOT NULL AND AcceptedCmp5 NOT IN (0,1))
              OR (Response IS NOT NULL AND Response NOT IN (0,1))
              OR (Complain IS NOT NULL AND Complain NOT IN (0,1)) THEN 1 ELSE 0 END) AS Rows_With_Invalid_Flags
FROM dbo.marketing_data;
GO

-- ----------------------------------------------------------------
-- 10. LOGICAL CONSISTENCY: SPENT MONEY BUT ZERO PURCHASES
-- Expect: 6 rows
-- ----------------------------------------------------------------
-- COALESCE here only keeps the diagnostic from skipping rows; it is NOT a cleaning rule.
SELECT ID, NumWebPurchases, NumCatalogPurchases, NumStorePurchases,
       COALESCE(MntWines,0) + COALESCE(MntFruits,0) + COALESCE(MntMeatProducts,0)
     + COALESCE(MntFishProducts,0) + COALESCE(MntSweetProducts,0) + COALESCE(MntGoldProds,0) AS Total_Spend
FROM dbo.marketing_data
WHERE COALESCE(MntWines,0) + COALESCE(MntFruits,0) + COALESCE(MntMeatProducts,0)
    + COALESCE(MntFishProducts,0) + COALESCE(MntSweetProducts,0) + COALESCE(MntGoldProds,0) > 0
  AND COALESCE(NumWebPurchases,0) + COALESCE(NumCatalogPurchases,0) + COALESCE(NumStorePurchases,0) = 0;
GO

-- ----------------------------------------------------------------
-- 11. IS MISSING INCOME RANDOM?
-- Verified in SQL Server: Australia 13 of 160 (8.1%), Germany 4 of 120 (3.3%), USA 2 of 109 (1.8%);
-- all other countries under 1%. Germany and USA counts are tiny, so judge them with care.
-- Checked outside SQL Server: Australia vs all other countries, Fisher's exact p about 1e-9 (13/160 vs 11/2080),
-- so missingness is not random across countries. It shows the pattern, not the cause.
-- ----------------------------------------------------------------
SELECT Country,
       COUNT(*) AS Customers,
       SUM(CASE WHEN Income IS NULL THEN 1 ELSE 0 END) AS Missing_Income,
       CAST(ROUND(100.0 * SUM(CASE WHEN Income IS NULL THEN 1 ELSE 0 END) / COUNT(*), 2) AS DECIMAL(18,2)) AS Missing_Pct
FROM dbo.marketing_data
GROUP BY Country
ORDER BY Missing_Pct DESC;
GO
