/* =========================================================
   🧠 STEP 0: CREATE DATABASE
   Purpose: Create isolated environment for this project
========================================================= */

CREATE DATABASE business_performance_360;
GO

USE business_performance_360;
GO


/* =========================================================
   STEP 1: DATA EXPLORATION (UNDERSTAND RAW DATA)
   Purpose: Check structure, data quality, and anomalies
========================================================= */

-- View sample records to understand schema
SELECT TOP 10 * FROM dbo.sales;

-- Count total records for dataset size check
SELECT COUNT(*) FROM dbo.sales;

-- Identify unique states for geography validation
SELECT DISTINCT State FROM dbo.sales;

-- Check missing values in City column
SELECT * FROM dbo.sales WHERE City IS NULL;


/* =========================================================
   STEP 2: CREATE CLEAN WORKING COPY
   Purpose: Never modify raw data directly (best practice)
========================================================= */

SELECT * INTO dbo.sales_clean
FROM dbo.sales;


/* =========================================================
   STEP 3: HANDLE MISSING VALUES
   Purpose: Replace NULLs to avoid BI calculation errors
========================================================= */

UPDATE dbo.sales_clean
SET City = ISNULL(City, 'Unknown'),
    Discount = ISNULL(Discount, 0);


/* =========================================================
   STEP 4: FIX DATA INCONSISTENCIES
   Purpose: Standardize text fields for accurate grouping
========================================================= */

-- Remove leading/trailing spaces
UPDATE dbo.sales_clean
SET State = TRIM(State),
    City = TRIM(City),
    District = TRIM(District);

-- Fix spelling errors in State column
UPDATE dbo.sales_clean
SET State = 'Kerala'
WHERE LOWER(State) IN ('kerela', 'kerala ');


/* =========================================================
   STEP 5: REMOVE DUPLICATES
   Purpose: Ensure each Order_ID is unique for accurate KPIs
========================================================= */

WITH cte AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY Order_ID ORDER BY Order_ID) AS rn
    FROM dbo.sales_clean
)
DELETE FROM cte
WHERE rn > 1;


/* =========================================================
   STEP 6: FIX DATA TYPES
   Purpose: Ensure numeric calculations work correctly
========================================================= */

ALTER TABLE dbo.sales_clean ALTER COLUMN Quantity INT;
ALTER TABLE dbo.sales_clean ALTER COLUMN Price DECIMAL(10,2);
ALTER TABLE dbo.sales_clean ALTER COLUMN Discount DECIMAL(5,2);
ALTER TABLE dbo.sales_clean ALTER COLUMN Sales_Amount DECIMAL(12,2);
ALTER TABLE dbo.sales_clean ALTER COLUMN Total_Cost DECIMAL(12,2);


/* =========================================================
   STEP 7: ADD & REBUILD CORE BUSINESS KPIs
   Purpose: Create correct revenue, profit, and margin logic
========================================================= */

-- Add calculated KPI columns
ALTER TABLE dbo.sales_clean
ADD 
    Sales_Recalc DECIMAL(12,2),
    Profit_Recalc DECIMAL(12,2),
    Profit_Margin_Recalc DECIMAL(12,6);

-- Recalculate all business metrics
UPDATE dbo.sales_clean
SET 
    Sales_Recalc = Quantity * Price * (1 - Discount),

    Profit_Recalc = (Quantity * Price * (1 - Discount)) - Total_Cost,

    Profit_Margin_Recalc =
        CASE 
            WHEN (Quantity * Price * (1 - Discount)) = 0 THEN 0
            ELSE ((Quantity * Price * (1 - Discount)) - Total_Cost)
                 / (Quantity * Price * (1 - Discount))
        END;


/* =========================================================
   STEP 8: DELIVERY PERFORMANCE LOGIC
   Purpose: Identify delayed shipments for operations KPI
========================================================= */

UPDATE dbo.sales_clean
SET Delivery_Status =
    CASE 
        WHEN Delivery_Days > 7 THEN 'Delayed'
        ELSE 'On-Time'
    END;


/* =========================================================
   STEP 9: PROFIT CLASSIFICATION
   Purpose: Segment orders into profit/loss for analysis
========================================================= */

-- Add classification column
ALTER TABLE dbo.sales_clean
ADD Profit_Flag VARCHAR(10);

-- Mark profitable vs loss orders
UPDATE dbo.sales_clean
SET Profit_Flag =
    CASE 
        WHEN Profit_Recalc < 0 THEN 'Loss'
        ELSE 'Profit'
    END;


/* =========================================================
   STEP 10: DATE FEATURES ENGINEERING
   Purpose: Enable time-based analysis (Power BI ready)
========================================================= */

ALTER TABLE dbo.sales_clean
ADD 
    Year INT,
    Month INT,
    Month_Name VARCHAR(20);

UPDATE dbo.sales_clean
SET 
    Year = YEAR(Order_Date),
    Month = MONTH(Order_Date),
    Month_Name = DATENAME(MONTH, Order_Date);


/* =========================================================
   STEP 11: BUSINESS EVENT FLAGS (SEASONAL ANALYSIS)
   Purpose: Capture regional business effects (Monsoon, Onam)
========================================================= */

-- Monsoon impact in Kerala (June–July)
ALTER TABLE dbo.sales_clean
ADD Monsoon_Flag VARCHAR(10);

UPDATE dbo.sales_clean
SET Monsoon_Flag =
    CASE 
        WHEN State = 'Kerala' AND Month IN (6,7) THEN 'Yes'
        ELSE 'No'
    END;


-- Onam festival impact (Aug–Sep Kerala sales boost)
ALTER TABLE dbo.sales_clean
ADD Onam_Flag VARCHAR(10);

UPDATE dbo.sales_clean
SET Onam_Flag =
    CASE 
        WHEN State = 'Kerala' 
             AND MONTH(Order_Date) IN (8,9)
        THEN 'Yes'
        ELSE 'No'
    END;


/* =========================================================
   STEP 12: OUTLIER DETECTION
   Purpose: Identify abnormal sales values (data quality + insights)
========================================================= */

ALTER TABLE dbo.sales_clean ADD Outlier_Flag VARCHAR(10);

UPDATE dbo.sales_clean
SET Outlier_Flag =
    CASE 
        WHEN Sales_Recalc > (SELECT AVG(Sales_Recalc) * 3 FROM dbo.sales_clean)
        THEN 'Yes'
        ELSE 'No'
    END;


/* =========================================================
   STEP 13: FINAL FACT TABLE CREATION
   Purpose: Create Power BI-ready star schema fact table
========================================================= */

-- Drop if exists (safe rerun script)
IF OBJECT_ID('fact_sales_final', 'U') IS NOT NULL
    DROP TABLE fact_sales_final;

-- Final curated dataset for analytics
SELECT 
    Order_ID,
    Customer_ID,
    Product_ID,
    State,
    City,
    Order_Date,
    Quantity,
    Sales_Recalc,
    Profit_Recalc,
    Profit_Margin_Recalc,
    Delivery_Status,
    Profit_Flag,
    Monsoon_Flag,
    Onam_Flag,
    Outlier_Flag
INTO fact_sales_final
FROM dbo.sales_clean;


/* =========================================================
   STEP 14: FINAL VALIDATION
   Purpose: Ensure dataset is clean and ready for BI tools
========================================================= */

SELECT TOP 100 * FROM fact_sales_final;

-- Optional KPI check
SELECT 
    SUM(Sales_Recalc) AS Total_Revenue,
    SUM(Profit_Recalc) AS Total_Profit
FROM fact_sales_final;