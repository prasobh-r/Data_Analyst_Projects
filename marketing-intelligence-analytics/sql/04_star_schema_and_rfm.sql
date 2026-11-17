/* ================================================================
   STEP 4: STAR SCHEMA + RFM SEGMENTATION  (built from the CLEANED table)
   Input : dbo.marketing_data_cleaned  (2193 rows, validated in Step 3)
   Output: DimCustomer, FactPurchases, FactCampaignResponse,
           RFM_Results, RFM_Results_Excl_Flagged (sensitivity version)
   The script drops and rebuilds its own outputs, so it can be re-run.
   "Expect" comments = values calculated outside SQL Server; confirm after running.
   ================================================================ */

USE MarketingIntelligence;
GO

IF OBJECT_ID('dbo.RFM_Results_Excl_Flagged', 'U') IS NOT NULL DROP TABLE dbo.RFM_Results_Excl_Flagged;
IF OBJECT_ID('dbo.RFM_Results',              'U') IS NOT NULL DROP TABLE dbo.RFM_Results;
IF OBJECT_ID('dbo.FactCampaignResponse',     'U') IS NOT NULL DROP TABLE dbo.FactCampaignResponse;
IF OBJECT_ID('dbo.FactPurchases',            'U') IS NOT NULL DROP TABLE dbo.FactPurchases;
IF OBJECT_ID('dbo.DimCustomer',              'U') IS NOT NULL DROP TABLE dbo.DimCustomer;
GO

-- ================================================================
-- PART A: STAR SCHEMA
-- ================================================================
CREATE TABLE dbo.DimCustomer (
    Customer_ID      INT PRIMARY KEY,
    Year_Birth       INT NULL,
    Education        NVARCHAR(50),
    Marital_Status   NVARCHAR(50),
    Income           INT NULL,
    Kidhome          INT,
    Teenhome         INT,
    Dt_Customer      DATE,
    Country          NVARCHAR(50),
    Complain         INT,
    Birth_Year_Flag  NVARCHAR(60) NULL,
    Income_Flag      NVARCHAR(60) NULL
);
GO

INSERT INTO dbo.DimCustomer
SELECT ID, Year_Birth, Education, Marital_Status, Income, Kidhome, Teenhome,
       Dt_Customer, Country, CAST(Complain AS INT), Birth_Year_Flag, Income_Flag
FROM dbo.marketing_data_cleaned;
GO

-- FactPurchases holds one row per customer: a 2-year aggregated purchase snapshot,
-- not individual transactions.
-- Total_Purchases = web + catalog + store only. NumDealsPurchases is kept as its own
-- column because the source does not say whether deal purchases overlap the channel counts.
CREATE TABLE dbo.FactPurchases (
    Customer_ID                INT PRIMARY KEY,
    Recency                    INT,
    MntWines                   INT,
    MntFruits                  INT,
    MntMeatProducts            INT,
    MntFishProducts            INT,
    MntSweetProducts           INT,
    MntGoldProds               INT,
    Total_Spend                INT,
    NumDealsPurchases          INT,
    NumWebPurchases            INT,
    NumCatalogPurchases        INT,
    NumStorePurchases          INT,
    Total_Purchases            INT,
    NumWebVisitsMonth          INT,
    Purchase_Consistency_Flag  NVARCHAR(60) NULL,
    FOREIGN KEY (Customer_ID) REFERENCES dbo.DimCustomer(Customer_ID)
);
GO

INSERT INTO dbo.FactPurchases
SELECT ID, Recency, MntWines, MntFruits, MntMeatProducts, MntFishProducts, MntSweetProducts, MntGoldProds,
       MntWines + MntFruits + MntMeatProducts + MntFishProducts + MntSweetProducts + MntGoldProds,
       NumDealsPurchases, NumWebPurchases, NumCatalogPurchases, NumStorePurchases,
       NumWebPurchases + NumCatalogPurchases + NumStorePurchases,
       NumWebVisitsMonth, Purchase_Consistency_Flag
FROM dbo.marketing_data_cleaned;
GO

-- One row per customer per campaign (6 campaigns). Composite primary key.
-- The source does not say which customers were actually sent each campaign,
-- so Accepted = 1 means "accepted", and rates later are shares of ALL customers.
CREATE TABLE dbo.FactCampaignResponse (
    Customer_ID    INT,
    Campaign_Name  VARCHAR(20),
    Accepted       INT,
    PRIMARY KEY (Customer_ID, Campaign_Name),
    FOREIGN KEY (Customer_ID) REFERENCES dbo.DimCustomer(Customer_ID)
);
GO

INSERT INTO dbo.FactCampaignResponse (Customer_ID, Campaign_Name, Accepted)
SELECT c.ID, v.Campaign_Name, v.Accepted
FROM dbo.marketing_data_cleaned c
CROSS APPLY (VALUES
    ('Campaign1',     CAST(c.AcceptedCmp1 AS INT)),
    ('Campaign2',     CAST(c.AcceptedCmp2 AS INT)),
    ('Campaign3',     CAST(c.AcceptedCmp3 AS INT)),
    ('Campaign4',     CAST(c.AcceptedCmp4 AS INT)),
    ('Campaign5',     CAST(c.AcceptedCmp5 AS INT)),
    ('CampaignFinal', CAST(c.Response     AS INT))
) v (Campaign_Name, Accepted);
GO

-- Expect: DimCustomer 2193, FactPurchases 2193, FactCampaignResponse 13158 (2193 x 6)
SELECT 'DimCustomer' AS Table_Name, COUNT(*) AS Row_Count FROM dbo.DimCustomer
UNION ALL SELECT 'FactPurchases', COUNT(*) FROM dbo.FactPurchases
UNION ALL SELECT 'FactCampaignResponse', COUNT(*) FROM dbo.FactCampaignResponse;
GO

-- ================================================================
-- PART B: RFM SEGMENTATION
-- NTILE needs a deterministic tie-breaker. Frequency has only a few dozen distinct
-- values, so many customers tie; without Customer_ID in ORDER BY, SQL Server may split
-- tied customers into different scores differently on each run.
-- Score direction: Recency DESC so the most recent buyers get the highest R score.
-- Segment cut-offs on the 3-15 total are analyst-chosen, not statistical.
-- ================================================================
WITH RFM_Base AS (
    SELECT Customer_ID, Recency, Total_Purchases AS Frequency, Total_Spend AS Monetary
    FROM dbo.FactPurchases
),
RFM_Scored AS (
    SELECT Customer_ID, Recency, Frequency, Monetary,
        NTILE(5) OVER (ORDER BY Recency   DESC, Customer_ID) AS R_Score,
        NTILE(5) OVER (ORDER BY Frequency ASC,  Customer_ID) AS F_Score,
        NTILE(5) OVER (ORDER BY Monetary  ASC,  Customer_ID) AS M_Score
    FROM RFM_Base
)
SELECT Customer_ID, Recency, Frequency, Monetary, R_Score, F_Score, M_Score,
       R_Score + F_Score + M_Score AS RFM_Total,
       CASE
           WHEN R_Score + F_Score + M_Score >= 13 THEN 'Champion'
           WHEN R_Score + F_Score + M_Score >= 10 THEN 'Loyal Customer'
           WHEN R_Score + F_Score + M_Score >= 7  THEN 'Potential Loyalist'
           WHEN R_Score + F_Score + M_Score >= 4  THEN 'At Risk'
           ELSE 'Lost'
       END AS Customer_Segment
INTO dbo.RFM_Results
FROM RFM_Scored;
GO

-- Segment summary
-- Expect (customers | avg spend | % of revenue):
--   Champion 329 | 1336.20 | 33.06     Loyal Customer 673 | 991.25 | 50.17
--   Potential Loyalist 665 | 289.35 | 14.47     At Risk 458 | 61.88 | 2.13     Lost 68 | 32.47 | 0.17
-- Champion + Loyal together: 45.7% of customers, 83.2% of revenue
SELECT
    Customer_Segment,
    COUNT(*) AS Customer_Count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS Pct_Of_Customers,
    ROUND(AVG(CAST(Monetary AS DECIMAL(18,2))), 2) AS Avg_Spend,
    ROUND(100.0 * SUM(Monetary) / SUM(SUM(Monetary)) OVER (), 2) AS Pct_Of_Revenue
FROM dbo.RFM_Results
GROUP BY Customer_Segment
ORDER BY CASE Customer_Segment
             WHEN 'Champion' THEN 1 WHEN 'Loyal Customer' THEN 2 WHEN 'Potential Loyalist' THEN 3
             WHEN 'At Risk' THEN 4 ELSE 5 END;
GO

-- ================================================================
-- PART C: SENSITIVITY CHECK
-- The 6 customers flagged in Step 2 (spend recorded, zero purchases) get Frequency 0.
-- Re-run the segmentation without them and compare.
-- Expect: 2187 customers; Champion and Loyal rows unchanged (329 / 673),
--         small shifts only in Potential Loyalist (658), At Risk (460), Lost (67).
-- ================================================================
WITH RFM_Base AS (
    SELECT Customer_ID, Recency, Total_Purchases AS Frequency, Total_Spend AS Monetary
    FROM dbo.FactPurchases
    WHERE Purchase_Consistency_Flag IS NULL
),
RFM_Scored AS (
    SELECT Customer_ID, Recency, Frequency, Monetary,
        NTILE(5) OVER (ORDER BY Recency   DESC, Customer_ID) AS R_Score,
        NTILE(5) OVER (ORDER BY Frequency ASC,  Customer_ID) AS F_Score,
        NTILE(5) OVER (ORDER BY Monetary  ASC,  Customer_ID) AS M_Score
    FROM RFM_Base
)
SELECT Customer_ID, Recency, Frequency, Monetary, R_Score, F_Score, M_Score,
       R_Score + F_Score + M_Score AS RFM_Total,
       CASE
           WHEN R_Score + F_Score + M_Score >= 13 THEN 'Champion'
           WHEN R_Score + F_Score + M_Score >= 10 THEN 'Loyal Customer'
           WHEN R_Score + F_Score + M_Score >= 7  THEN 'Potential Loyalist'
           WHEN R_Score + F_Score + M_Score >= 4  THEN 'At Risk'
           ELSE 'Lost'
       END AS Customer_Segment
INTO dbo.RFM_Results_Excl_Flagged
FROM RFM_Scored;
GO

SELECT
    a.Customer_Segment,
    a.Customers_All, b.Customers_Excl_Flagged,
    a.Pct_Revenue_All, b.Pct_Revenue_Excl_Flagged
FROM (
    SELECT Customer_Segment, COUNT(*) AS Customers_All,
           ROUND(100.0 * SUM(Monetary) / SUM(SUM(Monetary)) OVER (), 2) AS Pct_Revenue_All
    FROM dbo.RFM_Results GROUP BY Customer_Segment
) a
JOIN (
    SELECT Customer_Segment, COUNT(*) AS Customers_Excl_Flagged,
           ROUND(100.0 * SUM(Monetary) / SUM(SUM(Monetary)) OVER (), 2) AS Pct_Revenue_Excl_Flagged
    FROM dbo.RFM_Results_Excl_Flagged GROUP BY Customer_Segment
) b ON a.Customer_Segment = b.Customer_Segment
ORDER BY CASE a.Customer_Segment
             WHEN 'Champion' THEN 1 WHEN 'Loyal Customer' THEN 2 WHEN 'Potential Loyalist' THEN 3
             WHEN 'At Risk' THEN 4 ELSE 5 END;
GO
