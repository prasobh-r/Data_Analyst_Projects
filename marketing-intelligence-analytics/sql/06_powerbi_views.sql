/* ================================================================
   STEP 6: VIEWS FOR THE POWER BI DASHBOARD  (read-only on the data tables)
   Input : DimCustomer, FactPurchases, FactCampaignResponse, RFM_Results (Step 4)
   Output: dbo.vw_Customer_Segment   one row per customer (2193)
           dbo.vw_Campaign_Response  one row per customer per campaign (13158)
   Power BI connects to these two views and relates them on Customer_ID.
   Segment names and order match the README (Champion ... Lost).
   "Expect" comments = values calculated outside SQL Server; confirm after running.
   ================================================================ */

USE MarketingIntelligence;
GO

IF OBJECT_ID('dbo.vw_Campaign_Response', 'V') IS NOT NULL DROP VIEW dbo.vw_Campaign_Response;
IF OBJECT_ID('dbo.vw_Customer_Segment',  'V') IS NOT NULL DROP VIEW dbo.vw_Customer_Segment;
GO

-- One row per customer: attributes, RFM segment, spend, channel counts and campaign flags.
CREATE VIEW dbo.vw_Customer_Segment AS
SELECT
    d.Customer_ID,
    d.Country,
    d.Education,
    d.Marital_Status,
    r.Customer_Segment,
    CASE r.Customer_Segment
        WHEN 'Champion'           THEN 1
        WHEN 'Loyal Customer'     THEN 2
        WHEN 'Potential Loyalist' THEN 3
        WHEN 'At Risk'            THEN 4
        ELSE 5
    END AS Segment_Order,
    r.R_Score, r.F_Score, r.M_Score,
    p.Total_Spend,
    p.Total_Purchases,
    p.NumWebPurchases,
    p.NumCatalogPurchases,
    p.NumStorePurchases,
    f.Accepted_Final,
    f.Campaigns_Accepted,
    CASE WHEN f.Campaigns_Accepted > 0 THEN 1 ELSE 0 END AS Accepted_Any
FROM dbo.DimCustomer d
JOIN dbo.RFM_Results   r ON r.Customer_ID = d.Customer_ID
JOIN dbo.FactPurchases p ON p.Customer_ID = d.Customer_ID
JOIN (
    SELECT Customer_ID,
           MAX(CASE WHEN Campaign_Name = 'CampaignFinal' THEN Accepted END) AS Accepted_Final,
           SUM(Accepted) AS Campaigns_Accepted
    FROM dbo.FactCampaignResponse
    GROUP BY Customer_ID
) f ON f.Customer_ID = d.Customer_ID;
GO

-- One row per customer per campaign, with a display name and a chronological order.
CREATE VIEW dbo.vw_Campaign_Response AS
SELECT
    Customer_ID,
    Campaign_Name,
    CASE Campaign_Name
        WHEN 'Campaign1'     THEN 'Campaign 1'
        WHEN 'Campaign2'     THEN 'Campaign 2'
        WHEN 'Campaign3'     THEN 'Campaign 3'
        WHEN 'Campaign4'     THEN 'Campaign 4'
        WHEN 'Campaign5'     THEN 'Campaign 5'
        WHEN 'CampaignFinal' THEN 'Final'
    END AS Campaign_Label,
    CASE Campaign_Name
        WHEN 'Campaign1' THEN 1 WHEN 'Campaign2' THEN 2 WHEN 'Campaign3' THEN 3
        WHEN 'Campaign4' THEN 4 WHEN 'Campaign5' THEN 5 ELSE 6
    END AS Campaign_Order,
    Accepted
FROM dbo.FactCampaignResponse;
GO

-- ----------------------------------------------------------------
-- CHECKS (compare with the README)
-- Expect: 2193 customers; segment counts 329 / 673 / 665 / 458 / 68
-- ----------------------------------------------------------------
SELECT Customer_Segment, COUNT(*) AS Customers, SUM(Total_Spend) AS Spend, SUM(Accepted_Final) AS Accepted_Final
FROM dbo.vw_Customer_Segment
GROUP BY Customer_Segment, Segment_Order
ORDER BY Segment_Order;
GO

-- Expect: Campaign 1 = 142, Campaign 2 = 29, Final = 328 (13158 rows in total)
SELECT Campaign_Label, COUNT(*) AS Customers, SUM(Accepted) AS Accepted
FROM dbo.vw_Campaign_Response
GROUP BY Campaign_Label, Campaign_Order
ORDER BY Campaign_Order;
GO
