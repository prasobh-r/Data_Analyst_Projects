/* =====================================================
PROJECT: Emergency Department Throughput Optimization
DATABASE: Healthcare_Project
DESCRIPTION: End-to-End SQL Analytics Pipeline
AUTHOR: Prasobh R (Mike)
===================================================== */

-----------------------------------------------------
-- STEP 0: DATABASE SETUP
-- This step ensures the project database is created and selected.
-----------------------------------------------------

IF DB_ID('Healthcare_Project') IS NULL
    CREATE DATABASE Healthcare_Project;
GO

USE Healthcare_Project;
GO

-----------------------------------------------------
-- STEP 1: DATA VALIDATION
-- This step checks for invalid timestamps and ensures data consistency.
-----------------------------------------------------

SELECT TOP 10 * FROM Cleaned_ED_Visits;

SELECT *
FROM Cleaned_ED_Visits
WHERE Clean_Triage < Arrival_Timestamp
   OR Clean_Doctor < Clean_Triage
   OR Clean_Disposition < Clean_Doctor;

-----------------------------------------------------
-- STEP 2: BOTTLENECK ANALYSIS
-- This identifies average delays at each stage of patient flow.
-----------------------------------------------------

CREATE OR ALTER VIEW vw_Bottleneck_Analysis AS
WITH Stage_Times AS (
    SELECT
        Visit_ID,
        Triage_Score,
        DATEDIFF(MINUTE, Arrival_Timestamp, Clean_Triage) AS Triage_Wait,
        DATEDIFF(MINUTE, Clean_Triage, Clean_Doctor) AS Doctor_Wait,
        DATEDIFF(MINUTE, Clean_Doctor, Clean_Disposition) AS Treatment_Time
    FROM Cleaned_ED_Visits
)
SELECT
    AVG(Triage_Wait) AS Avg_Triage_Wait,
    AVG(Doctor_Wait) AS Avg_Doctor_Wait,
    AVG(Treatment_Time) AS Avg_Treatment_Time
FROM Stage_Times;
GO

-----------------------------------------------------
-- STEP 3: PEAK HOURS ANALYSIS
-- This identifies busiest hours and classifies risk levels.
-----------------------------------------------------

CREATE OR ALTER VIEW vw_Peak_Hours AS
SELECT
    Hour,
    Total_Visits,
    CASE
        WHEN Busy_Rank <= 3 THEN 'High Risk'
        WHEN Busy_Rank <= 6 THEN 'Medium Risk'
        ELSE 'Low Risk'
    END AS Risk_Level
FROM (
    SELECT
        DATEPART(HOUR, Arrival_Timestamp) AS Hour,
        COUNT(*) AS Total_Visits,
        RANK() OVER (ORDER BY COUNT(*) DESC) AS Busy_Rank
    FROM Cleaned_ED_Visits
    GROUP BY DATEPART(HOUR, Arrival_Timestamp)
) t;
GO

-----------------------------------------------------
-- STEP 4: LWBS FINANCIAL IMPACT
-- This estimates revenue loss from patients leaving without being seen.
-----------------------------------------------------

CREATE OR ALTER VIEW vw_LWBS_Impact AS
SELECT
    COUNT(*) AS LWBS_Count,
    SUM(
        CASE
            WHEN Triage_Score = 1 THEN 10000
            WHEN Triage_Score = 2 THEN 7000
            ELSE 4000
        END
    ) AS Estimated_Revenue_Loss
FROM Cleaned_ED_Visits
WHERE Disposition_Type = 'LWBS';
GO

-----------------------------------------------------
-- STEP 5: STAFF IMPACT ANALYSIS
-- This evaluates how staffing levels affect patient wait times.
-----------------------------------------------------

CREATE OR ALTER VIEW vw_Staff_Impact AS
SELECT
    s.Hour_Key,
    s.Physicians_On_Duty,
    COUNT(v.Visit_ID) AS Patient_Volume,
    CAST(COUNT(v.Visit_ID) AS FLOAT) / NULLIF(s.Physicians_On_Duty,0) AS Patient_to_Doctor_Ratio,
    AVG(DATEDIFF(MINUTE, v.Arrival_Timestamp, v.Clean_Triage)) AS Avg_Triage_Wait,
    AVG(DATEDIFF(MINUTE, v.Clean_Triage, v.Clean_Doctor)) AS Avg_Doctor_Wait
FROM Cleaned_ED_Visits v
JOIN Fact_Staffing_Levels s
    ON DATEPART(HOUR, v.Arrival_Timestamp) = s.Hour_Key
GROUP BY s.Hour_Key, s.Physicians_On_Duty;
GO

-----------------------------------------------------
-- STEP 6: BED OCCUPANCY
-- This calculates hospital bed utilization rates.
-----------------------------------------------------

CREATE OR ALTER VIEW vw_Bed_Occupancy AS
SELECT
    DATEPART(HOUR, v.Arrival_Timestamp) AS Hour,
    COUNT(*) AS Active_Patients,
    r.Total_Beds,
    CAST(COUNT(*) AS FLOAT) / NULLIF(r.Total_Beds,0) * 100 AS Occupancy_Rate
FROM Cleaned_ED_Visits v
CROSS JOIN (
    SELECT SUM(Total_Capacity) AS Total_Beds
    FROM Dim_Hospital_Resources
    WHERE Resource_Type LIKE '%Bed%'
) r
GROUP BY DATEPART(HOUR, v.Arrival_Timestamp), r.Total_Beds;
GO

-----------------------------------------------------
-- STEP 7: LWBS RISK ANALYSIS
-- This evaluates how wait time impacts patient drop-off rates.
-----------------------------------------------------

CREATE OR ALTER VIEW vw_LWBS_Risk AS
SELECT
    Triage_Score,
    AVG(WAIT_TIME) AS Avg_Wait_Time,
    COUNT(*) AS Total_Patients,
    SUM(CASE WHEN Disposition_Type = 'LWBS' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS LWBS_Rate
FROM Cleaned_ED_Visits
GROUP BY Triage_Score;
GO

-----------------------------------------------------
-- STEP 8: THROUGHPUT EFFICIENCY
-- This measures how efficiently patients are processed per hour.
-----------------------------------------------------

CREATE OR ALTER VIEW vw_Throughput_Efficiency AS
SELECT
    DATEPART(HOUR, Arrival_Timestamp) AS Hour,
    COUNT(*) AS Patients_Handled,
    AVG(TOTAL_TIME) AS Avg_Total_Time,
    COUNT(*) * 60.0 / NULLIF(AVG(TOTAL_TIME),0) AS Patients_Per_Hour
FROM Cleaned_ED_Visits
GROUP BY DATEPART(HOUR, Arrival_Timestamp);
GO

-----------------------------------------------------
-- STEP 9: OVERLOAD ALERT
-- This detects abnormal spikes in patient volume.
-----------------------------------------------------

CREATE OR ALTER VIEW vw_Overload_Alert AS
WITH Hourly_Count AS (
    SELECT DATEPART(HOUR, Arrival_Timestamp) AS Hour, COUNT(*) AS cnt
    FROM Cleaned_ED_Visits
    GROUP BY DATEPART(HOUR, Arrival_Timestamp)
),
Stats AS (
    SELECT AVG(cnt) AS avg_cnt, STDEV(cnt) AS std_cnt FROM Hourly_Count
)
SELECT
    h.Hour,
    h.cnt AS Patient_Count,
    CASE
        WHEN h.cnt > s.avg_cnt + s.std_cnt THEN 'OVERLOAD'
        ELSE 'NORMAL'
    END AS Status
FROM Hourly_Count h
CROSS JOIN Stats s;
GO

-----------------------------------------------------
-- STEP 10: LENGTH OF STAY
-- This measures average and maximum patient stay duration.
-----------------------------------------------------

CREATE OR ALTER VIEW vw_Length_of_Stay AS
SELECT
    AVG(DATEDIFF(MINUTE, Arrival_Timestamp, Clean_Disposition)) AS Avg_LOS_Minutes,
    MAX(DATEDIFF(MINUTE, Arrival_Timestamp, Clean_Disposition)) AS Max_LOS_Minutes
FROM Cleaned_ED_Visits;
GO

-----------------------------------------------------
-- STEP 11: STAFFING EFFICIENCY
-- This evaluates how staff levels impact performance metrics.
-----------------------------------------------------

CREATE OR ALTER VIEW vw_Staffing_Efficiency AS
SELECT
    s.Physicians_On_Duty,
    s.Nurses_On_Duty,
    COUNT(v.Visit_ID) AS Patient_Count,
    AVG(v.WAIT_TIME) AS Avg_Wait_Time,
    CAST(COUNT(v.Visit_ID) AS FLOAT) / NULLIF(s.Physicians_On_Duty,0) AS Patient_Doctor_Ratio
FROM Cleaned_ED_Visits v
JOIN Fact_Staffing_Levels s
    ON DATEPART(HOUR, v.Arrival_Timestamp) = s.Hour_Key
GROUP BY s.Physicians_On_Duty, s.Nurses_On_Duty;
GO

-----------------------------------------------------
-- STEP 12: SHIFT PERFORMANCE
-- This compares performance across shifts and weekends.
-----------------------------------------------------

CREATE OR ALTER VIEW vw_Shift_Performance AS
SELECT
    c.Shift_Name,
    c.Is_Weekend,
    AVG(v.WAIT_TIME) AS Avg_Triage_Wait,
    AVG(v.DOCTOR_WAIT) AS Avg_Doctor_Wait,
    AVG(v.TOTAL_TIME) AS Avg_Total_Time
FROM Cleaned_ED_Visits v
JOIN Dim_Calendar_Time c
    ON CAST(v.Arrival_Timestamp AS DATE) = CAST(c.Date_Key AS DATE)
    AND DATEPART(HOUR, v.Arrival_Timestamp) = DATEPART(HOUR, c.Date_Key)
GROUP BY c.Shift_Name, c.Is_Weekend;
GO

-----------------------------------------------------
-- STEP 13: PATIENT FLOW FUNNEL
-- This tracks patient journey from arrival to treatment completion.
-----------------------------------------------------

CREATE OR ALTER VIEW vw_Patient_Flow AS
SELECT 
    COUNT(DISTINCT Patient_ID) AS Total_Patients,
    COUNT(*) AS Total_Visits,
    -- Real Triaged
    COUNT(CASE WHEN Triage_Timestamp IS NOT NULL THEN 1 END) AS Triaged,
    -- Real Doctor Seen
    COUNT(CASE WHEN Doctor_Seen_Timestamp IS NOT NULL THEN 1 END) AS Seen_By_Doctor,
    -- Drop-off
    COUNT(CASE WHEN Doctor_Seen_Timestamp IS NULL THEN 1 END) AS LWBS
FROM Cleaned_ED_Visits;
GO
-----------------------------------------------------
-- STEP 14: TESTING QUERIES
-- This validates all created views.
-----------------------------------------------------

SELECT * FROM vw_Bottleneck_Analysis;
SELECT * FROM vw_Peak_Hours ORDER BY Total_Visits DESC;
SELECT * FROM vw_LWBS_Impact;
SELECT * FROM vw_Staff_Impact ORDER BY Patient_to_Doctor_Ratio DESC;
SELECT * FROM vw_Bed_Occupancy;
SELECT * FROM vw_LWBS_Risk;
SELECT * FROM vw_Throughput_Efficiency;
SELECT * FROM vw_Overload_Alert;
SELECT * FROM vw_Length_of_Stay;
SELECT * FROM vw_Staffing_Efficiency;
SELECT * FROM vw_Shift_Performance;
SELECT * FROM vw_Patient_Flow;

-----------------------------------------------------
-- STEP 15: REALISTIC DATA SIMULATION (OPTIONAL)
-- This simulates real-world wait times for testing.
-----------------------------------------------------

UPDATE Cleaned_ED_Visits
SET WAIT_TIME =
CASE
    WHEN DATEPART(HOUR, Arrival_Timestamp) BETWEEN 8 AND 11 THEN 25 + ABS(CHECKSUM(NEWID())) % 20
    WHEN DATEPART(HOUR, Arrival_Timestamp) BETWEEN 16 AND 22 THEN 45 + ABS(CHECKSUM(NEWID())) % 30
    WHEN DATEPART(HOUR, Arrival_Timestamp) BETWEEN 0 AND 5 THEN 10 + ABS(CHECKSUM(NEWID())) % 15
    ELSE 20 + ABS(CHECKSUM(NEWID())) % 20
END;

UPDATE Cleaned_ED_Visits
SET DOCTOR_WAIT = WAIT_TIME + (10 + ABS(CHECKSUM(NEWID())) % 40);

UPDATE Cleaned_ED_Visits
SET TOTAL_TIME = WAIT_TIME + DOCTOR_WAIT + (60 + ABS(CHECKSUM(NEWID())) % 180);


