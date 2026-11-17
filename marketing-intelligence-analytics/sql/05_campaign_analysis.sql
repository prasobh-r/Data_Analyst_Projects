/* ================================================================
   STEP 5: CAMPAIGN & CUSTOMER ANALYSIS  (read-only)
   Input : DimCustomer, FactPurchases, FactCampaignResponse, RFM_Results (Step 4)
   Every query below feeds one finding in the README.
   Reading the results correctly:
   - "Acceptance rate" = accepted / ALL 2193 customers. The source does not say who
     was actually sent each campaign, so this is not a true conversion rate.
   - Comparisons between groups show association, not cause. There is no control group.
   - Spend is in currency units; the source does not state the currency.
   "Expect" comments = values calculated outside SQL Server; confirm after running.
   ================================================================ */

USE MarketingIntelligence;
GO

-- ----------------------------------------------------------------
-- 1. CAMPAIGN ACCEPTANCE RATES
-- Expect (accepted | % of 2193): Final 328 | 14.96, Campaign4 165 | 7.52, Campaign5 161 | 7.34,
--   Campaign3 159 | 7.25, Campaign1 142 | 6.48, Campaign2 29 | 1.32
-- ----------------------------------------------------------------
SELECT Campaign_Name,
       COUNT(*)      AS Customers,
       SUM(Accepted) AS Accepted,
       CAST(ROUND(100.0 * SUM(Accepted) / COUNT(*), 2) AS DECIMAL(18,2)) AS Acceptance_Rate_Pct
FROM dbo.FactCampaignResponse
GROUP BY Campaign_Name
ORDER BY Acceptance_Rate_Pct DESC;
GO

-- ----------------------------------------------------------------
-- 2. IS CAMPAIGN 2 REALLY WORSE THAN CAMPAIGN 1? (McNemar's paired test)
-- The same 2193 customers were measured for both campaigns, so the observations are
-- paired, not independent. A two-proportion z-test would ignore that; McNemar's test
-- uses only the customers who accepted one campaign but not the other.
-- Chi-square (continuity corrected) = (|b - c| - 1)^2 / (b + c), 1 degree of freedom.
-- Above 10.83 corresponds to p < 0.001.
-- Expect: both accepted 13, Campaign 1 only 129, Campaign 2 only 16, neither 2035,
--         chi-square 86.51
-- ----------------------------------------------------------------
WITH Pairs AS (
    SELECT c1.Customer_ID, c1.Accepted AS A1, c2.Accepted AS A2
    FROM dbo.FactCampaignResponse c1
    JOIN dbo.FactCampaignResponse c2
      ON c2.Customer_ID = c1.Customer_ID AND c2.Campaign_Name = 'Campaign2'
    WHERE c1.Campaign_Name = 'Campaign1'
),
Counts AS (
    SELECT SUM(CASE WHEN A1 = 1 AND A2 = 1 THEN 1 ELSE 0 END) AS Both_Accepted,
           SUM(CASE WHEN A1 = 1 AND A2 = 0 THEN 1 ELSE 0 END) AS Campaign1_Only,
           SUM(CASE WHEN A1 = 0 AND A2 = 1 THEN 1 ELSE 0 END) AS Campaign2_Only,
           SUM(CASE WHEN A1 = 0 AND A2 = 0 THEN 1 ELSE 0 END) AS Neither
    FROM Pairs
)
SELECT Both_Accepted, Campaign1_Only, Campaign2_Only, Neither,
       CAST(ROUND(POWER(ABS(Campaign1_Only - Campaign2_Only) - 1.0, 2)
             / (Campaign1_Only + Campaign2_Only), 2) AS DECIMAL(18,2)) AS McNemar_Chi_Square
FROM Counts;
GO

-- ----------------------------------------------------------------
-- 3. FINAL CAMPAIGN RESPONSE BY RFM SEGMENT
-- RFM and the final response are measured at the same snapshot, so read this as
-- "associated with", not "predicts".
-- Expect: Champion 329 | 112 | 34.04, Loyal 673 | 117 | 17.38, Potential 665 | 79 | 11.88,
--         At Risk 458 | 20 | 4.37, Lost 68 | 0 | 0.00
-- ----------------------------------------------------------------
SELECT r.Customer_Segment,
       COUNT(*)        AS Customers,
       SUM(f.Accepted) AS Accepted_Final,
       CAST(ROUND(100.0 * SUM(f.Accepted) / COUNT(*), 2) AS DECIMAL(18,2)) AS Acceptance_Rate_Pct
FROM dbo.RFM_Results r
JOIN dbo.FactCampaignResponse f
  ON f.Customer_ID = r.Customer_ID AND f.Campaign_Name = 'CampaignFinal'
GROUP BY r.Customer_Segment
ORDER BY CASE r.Customer_Segment
             WHEN 'Champion' THEN 1 WHEN 'Loyal Customer' THEN 2 WHEN 'Potential Loyalist' THEN 3
             WHEN 'At Risk' THEN 4 ELSE 5 END;
GO

-- ----------------------------------------------------------------
-- 4. RESPONDERS VS NON-RESPONDERS: SPEND COMPARISON (not a causal "lift")
-- Expect: accepted at least one: 597 customers, avg spend 1002.67
--         never accepted: 1596 customers, avg spend 458.08  (ratio about 2.19x)
-- ----------------------------------------------------------------
WITH Resp AS (
    SELECT Customer_ID, MAX(Accepted) AS Any_Accepted
    FROM dbo.FactCampaignResponse
    GROUP BY Customer_ID
)
SELECT CASE WHEN r.Any_Accepted = 1 THEN 'Accepted at least 1 campaign' ELSE 'Never accepted' END AS Customer_Group,
       COUNT(*) AS Customers,
       CAST(ROUND(AVG(CAST(p.Total_Spend AS DECIMAL(18,2))), 2) AS DECIMAL(18,2)) AS Avg_Spend
FROM Resp r
JOIN dbo.FactPurchases p ON p.Customer_ID = r.Customer_ID
GROUP BY r.Any_Accepted
ORDER BY r.Any_Accepted DESC;
GO

-- ----------------------------------------------------------------
-- 5. REVENUE CONCENTRATION (Pareto)
-- Counts customers from the top until the running total first reaches 80% of revenue,
-- including the customer who crosses the line.
-- Expect: 827 customers, 37.71% of the base
-- ----------------------------------------------------------------
WITH Ranked AS (
    SELECT Customer_ID, Total_Spend,
           SUM(CAST(Total_Spend AS BIGINT)) OVER (ORDER BY Total_Spend DESC, Customer_ID
                                                  ROWS UNBOUNDED PRECEDING) AS Running_Spend,
           SUM(CAST(Total_Spend AS BIGINT)) OVER () AS Grand_Total
    FROM dbo.FactPurchases
)
SELECT COUNT(*) AS Customers_To_Reach_80_Pct_Of_Revenue,
       CAST(ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM dbo.FactPurchases), 2) AS DECIMAL(18,2)) AS Pct_Of_Customers
FROM Ranked
WHERE Running_Spend - Total_Spend < 0.8 * Grand_Total;
GO

-- ----------------------------------------------------------------
-- 6. PURCHASE CHANNEL MIX (the README problem statement asks which channels matter)
-- Counts of purchases, not money: the source has no spend per channel.
-- Expect overall: Web 8982 (32.66%), Catalog 5834 (21.21%), Store 12686 (46.13%)
-- ----------------------------------------------------------------
SELECT N'Web' AS Channel, SUM(NumWebPurchases) AS Purchases,
       CAST(ROUND(100.0 * SUM(NumWebPurchases) / SUM(NumWebPurchases + NumCatalogPurchases + NumStorePurchases), 2) AS DECIMAL(18,2)) AS Pct_Of_Purchases
FROM dbo.FactPurchases
UNION ALL
SELECT N'Catalog', SUM(NumCatalogPurchases),
       CAST(ROUND(100.0 * SUM(NumCatalogPurchases) / SUM(NumWebPurchases + NumCatalogPurchases + NumStorePurchases), 2) AS DECIMAL(18,2))
FROM dbo.FactPurchases
UNION ALL
SELECT N'Store', SUM(NumStorePurchases),
       CAST(ROUND(100.0 * SUM(NumStorePurchases) / SUM(NumWebPurchases + NumCatalogPurchases + NumStorePurchases), 2) AS DECIMAL(18,2))
FROM dbo.FactPurchases;
GO

-- Channel mix by RFM segment (percent of each segment's purchases)
-- Expect Catalog %: Champion 27.3, Loyal 23.8, Potential 14.7, At Risk 8.4, Lost 3.1
--        Store %:   Champion 42.8, Loyal 44.2, Potential 48.3, At Risk 58.3, Lost 68.1
SELECT r.Customer_Segment,
       CAST(ROUND(100.0 * SUM(p.NumWebPurchases)     / SUM(p.NumWebPurchases + p.NumCatalogPurchases + p.NumStorePurchases), 1) AS DECIMAL(18,1)) AS Web_Pct,
       CAST(ROUND(100.0 * SUM(p.NumCatalogPurchases) / SUM(p.NumWebPurchases + p.NumCatalogPurchases + p.NumStorePurchases), 1) AS DECIMAL(18,1)) AS Catalog_Pct,
       CAST(ROUND(100.0 * SUM(p.NumStorePurchases)   / SUM(p.NumWebPurchases + p.NumCatalogPurchases + p.NumStorePurchases), 1) AS DECIMAL(18,1)) AS Store_Pct
FROM dbo.RFM_Results r
JOIN dbo.FactPurchases p ON p.Customer_ID = r.Customer_ID
GROUP BY r.Customer_Segment
ORDER BY CASE r.Customer_Segment
             WHEN 'Champion' THEN 1 WHEN 'Loyal Customer' THEN 2 WHEN 'Potential Loyalist' THEN 3
             WHEN 'At Risk' THEN 4 ELSE 5 END;
GO

-- ----------------------------------------------------------------
-- 7. SPEND BY PRODUCT CATEGORY
-- Expect: Wines 667006, Meat 366920, Gold 96889, Fish 82100, Sweets 59294, Fruits 57481
-- ----------------------------------------------------------------
SELECT N'Wines'  AS Category, SUM(CAST(MntWines        AS BIGINT)) AS Total_Spend FROM dbo.FactPurchases
UNION ALL SELECT N'Meat',   SUM(CAST(MntMeatProducts  AS BIGINT)) FROM dbo.FactPurchases
UNION ALL SELECT N'Gold',   SUM(CAST(MntGoldProds     AS BIGINT)) FROM dbo.FactPurchases
UNION ALL SELECT N'Fish',   SUM(CAST(MntFishProducts  AS BIGINT)) FROM dbo.FactPurchases
UNION ALL SELECT N'Sweets', SUM(CAST(MntSweetProducts AS BIGINT)) FROM dbo.FactPurchases
UNION ALL SELECT N'Fruits', SUM(CAST(MntFruits        AS BIGINT)) FROM dbo.FactPurchases
ORDER BY Total_Spend DESC;
GO

-- ----------------------------------------------------------------
-- 8. COUNTRY VIEW: DOES "SPAIN FIRST" HOLD BEYOND CUSTOMER COUNT?
-- Mexico has 3 customers, so its figures are not meaningful.
-- Expect (customers | % of spend | avg spend | final-campaign acceptance %):
--   Spain 1055 | 48.04 | 605.51 | 16.11     Saudi Arabia 335 | 15.74 | 624.91 | 15.52
--   Canada 265 | 12.65 | 634.74 | 14.34     Australia 159 | 6.71 | 560.74 | 14.47
--   India 147 | 5.88 | 532.32 | 8.84        Germany 120 | 5.63 | 624.28 | 14.17
--   USA 109 | 5.11 | 622.77 | 11.93         Mexico 3 | 0.23 | 1040.67 | 66.67
-- ----------------------------------------------------------------
SELECT d.Country,
       COUNT(*) AS Customers,
       CAST(ROUND(100.0 * SUM(p.Total_Spend) / SUM(SUM(p.Total_Spend)) OVER (), 2) AS DECIMAL(18,2)) AS Pct_Of_Spend,
       CAST(ROUND(AVG(CAST(p.Total_Spend AS DECIMAL(18,2))), 2) AS DECIMAL(18,2)) AS Avg_Spend,
       CAST(ROUND(100.0 * SUM(f.Accepted) / COUNT(*), 2) AS DECIMAL(18,2)) AS Final_Acceptance_Pct
FROM dbo.DimCustomer d
JOIN dbo.FactPurchases p ON p.Customer_ID = d.Customer_ID
JOIN dbo.FactCampaignResponse f ON f.Customer_ID = d.Customer_ID AND f.Campaign_Name = 'CampaignFinal'
GROUP BY d.Country
ORDER BY Customers DESC;
GO
