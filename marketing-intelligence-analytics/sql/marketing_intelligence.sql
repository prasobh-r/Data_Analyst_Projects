/* ================================================================
   MARKETING INTELLIGENCE ANALYTICS PROJECT (LEAN VERSION)
   Dataset: Marketing Campaign (Jack Daoud / Maven Analytics)
   Platform: SQL Server (SSMS)
   ================================================================
   This is the trimmed, essentials-only version. Every query here
   maps directly to a finding in the README. Nothing redundant.
   ================================================================ */


-- ================================================================
-- SECTION 0-1: DATABASE SETUP & VERIFY IMPORT
-- ================================================================
IF DB_ID('MarketingIntelligence') IS NULL
    CREATE DATABASE MarketingIntelligence;
GO
USE MarketingIntelligence;
GO

SELECT COUNT(*) AS Total_Rows FROM marketing_data;   -- expect 2240
GO


-- ================================================================
-- SECTION 2: STAR SCHEMA
-- ================================================================
IF OBJECT_ID('FactCampaignResponse','U') IS NOT NULL DROP TABLE FactCampaignResponse;
IF OBJECT_ID('FactPurchases','U') IS NOT NULL DROP TABLE FactPurchases;
IF OBJECT_ID('DimCustomer','U') IS NOT NULL DROP TABLE DimCustomer;
GO

CREATE TABLE DimCustomer (
    Customer_ID     INT PRIMARY KEY,
    Year_Birth      INT,
    Education       VARCHAR(50),
    Marital_Status  VARCHAR(50),
    Income          DECIMAL(12,2) NULL,
    Kidhome         INT,
    Teenhome        INT,
    Dt_Customer     DATE,
    Country         VARCHAR(20),
    Complain        INT
);
GO

INSERT INTO DimCustomer
SELECT ID, Year_Birth, Education, Marital_Status, Income, Kidhome, Teenhome,
       Dt_Customer, Country, Complain
FROM marketing_data;
GO

CREATE TABLE FactPurchases (
    Customer_ID          INT PRIMARY KEY,
    Recency               INT,
    MntWines               DECIMAL(10,2),
    MntFruits               DECIMAL(10,2),
    MntMeatProducts          DECIMAL(10,2),
    MntFishProducts          DECIMAL(10,2),
    MntSweetProducts         DECIMAL(10,2),
    MntGoldProds              DECIMAL(10,2),
    Total_Spend               DECIMAL(12,2),
    NumWebPurchases            INT,
    NumCatalogPurchases        INT,
    NumStorePurchases          INT,
    Total_Purchases            INT,
    FOREIGN KEY (Customer_ID) REFERENCES DimCustomer(Customer_ID)
);
GO

INSERT INTO FactPurchases
SELECT
    ID, Recency,
    MntWines, MntFruits, MntMeatProducts, MntFishProducts, MntSweetProducts, MntGoldProds,
    (MntWines + MntFruits + MntMeatProducts + MntFishProducts + MntSweetProducts + MntGoldProds) AS Total_Spend,
    NumWebPurchases, NumCatalogPurchases, NumStorePurchases,
    (NumWebPurchases + NumCatalogPurchases + NumStorePurchases) AS Total_Purchases
FROM marketing_data;
GO

CREATE TABLE FactCampaignResponse (
    Customer_ID     INT,
    Campaign_Name   VARCHAR(20),
    Accepted        INT,
    FOREIGN KEY (Customer_ID) REFERENCES DimCustomer(Customer_ID)
);
GO

INSERT INTO FactCampaignResponse (Customer_ID, Campaign_Name, Accepted)
SELECT ID, 'Campaign1', AcceptedCmp1 FROM marketing_data
UNION ALL SELECT ID, 'Campaign2', AcceptedCmp2 FROM marketing_data
UNION ALL SELECT ID, 'Campaign3', AcceptedCmp3 FROM marketing_data
UNION ALL SELECT ID, 'Campaign4', AcceptedCmp4 FROM marketing_data
UNION ALL SELECT ID, 'Campaign5', AcceptedCmp5 FROM marketing_data
UNION ALL SELECT ID, 'CampaignFinal', Response FROM marketing_data;
GO

SELECT 'DimCustomer' AS Tbl, COUNT(*) AS Rows_ FROM DimCustomer
UNION ALL SELECT 'FactPurchases', COUNT(*) FROM FactPurchases
UNION ALL SELECT 'FactCampaignResponse', COUNT(*) FROM FactCampaignResponse;
GO


-- ================================================================
-- SECTION 3: DATA QUALITY (essential -- proves you checked the data)
-- ================================================================
SELECT
    COUNT(*) AS Total_Customers,
    COUNT(*) - COUNT(Income) AS Missing_Income_Count,
    ROUND(100.0 * (COUNT(*) - COUNT(Income)) / COUNT(*), 2) AS Missing_Income_Pct
FROM DimCustomer;
GO

SELECT Customer_ID, COUNT(*) AS Row_Count
FROM DimCustomer GROUP BY Customer_ID HAVING COUNT(*) > 1;   -- expect 0
GO

SELECT COUNT(*) AS Invalid_Age_Count FROM DimCustomer
WHERE Year_Birth < 1920 OR Year_Birth > 2010;
GO


-- ================================================================
-- SECTION 4: DESCRIPTIVE OVERVIEW (essential baseline)
-- ================================================================
SELECT
    COUNT(*) AS Total_Customers,
    AVG(Income) AS Avg_Income,
    SUM(p.Total_Spend) AS Total_Revenue,
    AVG(p.Total_Spend) AS Avg_Spend_Per_Customer
FROM DimCustomer c JOIN FactPurchases p ON c.Customer_ID = p.Customer_ID;
GO

SELECT 'Wines' AS Category, SUM(MntWines) AS Total_Spend FROM FactPurchases
UNION ALL SELECT 'Meat', SUM(MntMeatProducts) FROM FactPurchases
UNION ALL SELECT 'Fish', SUM(MntFishProducts) FROM FactPurchases
UNION ALL SELECT 'Fruits', SUM(MntFruits) FROM FactPurchases
UNION ALL SELECT 'Sweets', SUM(MntSweetProducts) FROM FactPurchases
UNION ALL SELECT 'Gold', SUM(MntGoldProds) FROM FactPurchases
ORDER BY Total_Spend DESC;
GO

SELECT Country, COUNT(*) AS Customer_Count
FROM DimCustomer GROUP BY Country ORDER BY Customer_Count DESC;
GO


-- ================================================================
-- SECTION 5: RFM SEGMENTATION (the core differentiator -- keep this,
-- it replaces the need for separate personas/quartile/CLV sections)
-- ================================================================
IF OBJECT_ID('RFM_Results','U') IS NOT NULL DROP TABLE RFM_Results;
GO

WITH RFM_Base AS (
    SELECT c.Customer_ID, p.Recency, p.Total_Purchases AS Frequency, p.Total_Spend AS Monetary
    FROM DimCustomer c JOIN FactPurchases p ON c.Customer_ID = p.Customer_ID
),
RFM_Scored AS (
    SELECT
        Customer_ID, Recency, Frequency, Monetary,
        NTILE(5) OVER (ORDER BY Recency DESC) AS R_Score,
        NTILE(5) OVER (ORDER BY Frequency ASC) AS F_Score,
        NTILE(5) OVER (ORDER BY Monetary ASC) AS M_Score
    FROM RFM_Base
)
SELECT
    Customer_ID, Recency, Frequency, Monetary, R_Score, F_Score, M_Score,
    (R_Score + F_Score + M_Score) AS RFM_Total,
    CASE
        WHEN (R_Score + F_Score + M_Score) >= 13 THEN 'Champion'
        WHEN (R_Score + F_Score + M_Score) >= 10 THEN 'Loyal Customer'
        WHEN (R_Score + F_Score + M_Score) >= 7  THEN 'Potential Loyalist'
        WHEN (R_Score + F_Score + M_Score) >= 4  THEN 'At Risk'
        ELSE 'Lost'
    END AS Customer_Segment
INTO RFM_Results
FROM RFM_Scored;
GO

SELECT
    Customer_Segment, COUNT(*) AS Customer_Count, AVG(Monetary) AS Avg_Spend,
    ROUND(100.0 * SUM(Monetary) / (SELECT SUM(Monetary) FROM RFM_Results), 2) AS Pct_Of_Total_Revenue
FROM RFM_Results
GROUP BY Customer_Segment
ORDER BY Pct_Of_Total_Revenue DESC;
GO


-- ================================================================
-- SECTION 6: CAMPAIGN PERFORMANCE & LIFT (essential business analysis)
-- ================================================================
SELECT
    Campaign_Name, COUNT(*) AS Total_Customers, SUM(Accepted) AS Total_Accepted,
    ROUND(100.0 * SUM(Accepted) / COUNT(*), 2) AS Response_Rate_Pct
FROM FactCampaignResponse
GROUP BY Campaign_Name
ORDER BY Response_Rate_Pct DESC;
GO

-- Does RFM segment predict response? (ties segmentation to business action)
SELECT
    r.Customer_Segment,
    COUNT(DISTINCT f.Customer_ID) AS Customer_Count,
    ROUND(100.0 * SUM(CASE WHEN f.Campaign_Name = 'CampaignFinal' AND f.Accepted = 1 THEN 1 ELSE 0 END)
        / COUNT(DISTINCT f.Customer_ID), 2) AS Response_Rate_Pct
FROM RFM_Results r
JOIN FactCampaignResponse f ON r.Customer_ID = f.Customer_ID
GROUP BY r.Customer_Segment
ORDER BY Response_Rate_Pct DESC;
GO

-- Campaign lift: do acceptors spend more? (real fields only)
WITH ResponderFlag AS (
    SELECT c.Customer_ID,
        CASE WHEN MAX(CASE WHEN f.Accepted = 1 THEN 1 ELSE 0 END) = 1
             THEN 'Accepted At Least 1 Campaign' ELSE 'Never Accepted' END AS Response_Behavior
    FROM DimCustomer c JOIN FactCampaignResponse f ON c.Customer_ID = f.Customer_ID
    GROUP BY c.Customer_ID
)
SELECT
    r.Response_Behavior, COUNT(*) AS Customer_Count, AVG(p.Total_Spend) AS Avg_Total_Spend
FROM ResponderFlag r JOIN FactPurchases p ON r.Customer_ID = p.Customer_ID
GROUP BY r.Response_Behavior;
GO


-- ================================================================
-- SECTION 7: PARETO ANALYSIS (essential business insight -- 80/20 rule)
-- ================================================================
WITH ParetoSplit AS (
    SELECT Customer_ID,
        100.0 * SUM(Total_Spend) OVER (ORDER BY Total_Spend DESC) / SUM(Total_Spend) OVER () AS Cumulative_Percent
    FROM FactPurchases
)
SELECT
    COUNT(*) AS Customers_Until_80_Percent,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM FactPurchases), 2) AS Pct_Of_Customers
FROM ParetoSplit
WHERE Cumulative_Percent <= 80;
GO
