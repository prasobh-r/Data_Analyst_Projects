
/* ============================================================
   PROJECT: Healthcare ED Throughput Optimization
   DATABASE: Healthcare_Project

   PURPOSE:
   1. Verify source data
   2. Summarize data quality
   3. Calculate observed timestamp-based intervals
   4. Analyze overall and annual LWBS rates
   5. Analyze LWBS by arrival hour
   6. Analyze LWBS by observed triage-wait band
   7. Analyze LWBS by triage score and wait band
   8. Summarize patient flow
   9. Reconcile SQL results for Power BI

   IMPORTANT:
   - Source visit rows are not modified.
   - Raw timestamps are used for observed intervals.
   - Stored duration fields are not trusted as observed KPIs.
   - No causal claims about waiting time and LWBS.
   - Bed occupancy, staffing impact and revenue loss
     are not calculated by this script.
   ============================================================ */

USE Healthcare_Project;
GO

/* ============================================================
   STEP 1: VERIFY SOURCE TABLE
   ============================================================ */

IF OBJECT_ID(N'dbo.Cleaned_ED_Visits', N'U') IS NULL
BEGIN
    THROW 50001,
        'Required table dbo.Cleaned_ED_Visits was not found.',
        1;
END;
GO

SELECT
    COUNT_BIG(*) AS Total_Rows,
    COUNT(DISTINCT Visit_ID) AS Distinct_Visit_IDs,
    COUNT(DISTINCT Patient_ID) AS Distinct_Patients,
    MIN(Arrival_Timestamp) AS First_Arrival,
    MAX(Arrival_Timestamp) AS Last_Arrival
FROM dbo.Cleaned_ED_Visits;
GO

/* ============================================================
   STEP 2: DATA QUALITY SUMMARY VIEW
   ============================================================ */

CREATE OR ALTER VIEW dbo.vw_Data_Quality_Summary
AS
SELECT
    COUNT_BIG(*) AS Total_Visit_Rows,
    COUNT(DISTINCT Visit_ID) AS Distinct_Visit_IDs,

    SUM(CASE WHEN Visit_ID IS NULL
        THEN 1 ELSE 0 END) AS Missing_Visit_ID,

    SUM(CASE WHEN Patient_ID IS NULL
        THEN 1 ELSE 0 END) AS Missing_Patient_ID,

    SUM(CASE WHEN Arrival_Timestamp IS NULL
        THEN 1 ELSE 0 END) AS Missing_Arrival_Timestamp,

    SUM(CASE WHEN Triage_Timestamp IS NULL
        THEN 1 ELSE 0 END) AS Missing_Raw_Triage,

    SUM(CASE
        WHEN Arrival_Timestamp IS NOT NULL
         AND Triage_Timestamp IS NOT NULL
         AND Triage_Timestamp < Arrival_Timestamp
        THEN 1 ELSE 0
    END) AS Triage_Before_Arrival,

    SUM(CASE WHEN Doctor_Seen_Timestamp IS NULL
        THEN 1 ELSE 0 END) AS Missing_Raw_Doctor,

    SUM(CASE
        WHEN Triage_Timestamp IS NOT NULL
         AND Doctor_Seen_Timestamp IS NOT NULL
         AND Doctor_Seen_Timestamp < Triage_Timestamp
        THEN 1 ELSE 0
    END) AS Doctor_Before_Triage,

    SUM(CASE
        WHEN Doctor_Seen_Timestamp IS NOT NULL
         AND Disposition_Timestamp IS NOT NULL
         AND Disposition_Timestamp < Doctor_Seen_Timestamp
        THEN 1 ELSE 0
    END) AS Disposition_Before_Doctor,

    SUM(CASE WHEN Disposition_Timestamp IS NULL
        THEN 1 ELSE 0 END) AS Missing_Disposition_Timestamp,

    SUM(CASE WHEN Disposition_Type IS NULL
        THEN 1 ELSE 0 END) AS Missing_Disposition_Type,

    SUM(CASE WHEN Triage_Score IS NULL
        THEN 1 ELSE 0 END) AS Missing_Triage_Score,

    SUM(CASE WHEN Disposition_Type = 'LWBS'
        THEN 1 ELSE 0 END) AS LWBS_Visits

FROM dbo.Cleaned_ED_Visits;
GO

/* ============================================================
   STEP 3: OBSERVED VISIT INTERVALS VIEW

   Triage wait:
       Arrival -> Triage
       Requires valid chronological order.

   Triage to doctor:
       Triage -> Doctor
       Requires valid Arrival -> Triage -> Doctor order.

   Doctor to disposition:
       Doctor -> Disposition
       Requires valid chronological order for these two events.

   Arrival to disposition:
       Arrival -> Disposition
       Requires valid chronological order for these two events.

   Invalid intervals return NULL, not zero.
   ============================================================ */

CREATE OR ALTER VIEW dbo.vw_Observed_Visit_Intervals
AS
SELECT
    Visit_ID,
    Patient_ID,
    Arrival_Timestamp,
    Triage_Timestamp,
    Doctor_Seen_Timestamp,
    Disposition_Timestamp,
    Disposition_Type,
    Triage_Score,

    CASE
        WHEN Arrival_Timestamp IS NOT NULL
         AND Triage_Timestamp IS NOT NULL
         AND Triage_Timestamp >= Arrival_Timestamp
        THEN DATEDIFF_BIG(
            SECOND,
            Arrival_Timestamp,
            Triage_Timestamp
        ) / 60.0
    END AS Observed_Triage_Wait_Minutes,

    CASE
        WHEN Arrival_Timestamp IS NOT NULL
         AND Triage_Timestamp IS NOT NULL
         AND Doctor_Seen_Timestamp IS NOT NULL
         AND Triage_Timestamp >= Arrival_Timestamp
         AND Doctor_Seen_Timestamp >= Triage_Timestamp
        THEN DATEDIFF_BIG(
            SECOND,
            Triage_Timestamp,
            Doctor_Seen_Timestamp
        ) / 60.0
    END AS Observed_Triage_To_Doctor_Minutes,

    CASE
        WHEN Doctor_Seen_Timestamp IS NOT NULL
         AND Disposition_Timestamp IS NOT NULL
         AND Disposition_Timestamp >= Doctor_Seen_Timestamp
        THEN DATEDIFF_BIG(
            SECOND,
            Doctor_Seen_Timestamp,
            Disposition_Timestamp
        ) / 60.0
    END AS Observed_Doctor_To_Disposition_Minutes,

    CASE
        WHEN Arrival_Timestamp IS NOT NULL
         AND Disposition_Timestamp IS NOT NULL
         AND Disposition_Timestamp >= Arrival_Timestamp
        THEN DATEDIFF_BIG(
            SECOND,
            Arrival_Timestamp,
            Disposition_Timestamp
        ) / 60.0
    END AS Observed_Arrival_To_Disposition_Minutes,

    CASE
        WHEN Triage_Timestamp IS NULL THEN 1 ELSE 0
    END AS Missing_Raw_Triage_Flag,

    CASE
        WHEN Arrival_Timestamp IS NOT NULL
         AND Triage_Timestamp IS NOT NULL
         AND Triage_Timestamp < Arrival_Timestamp
        THEN 1 ELSE 0
    END AS Triage_Before_Arrival_Flag,

    CASE
        WHEN Doctor_Seen_Timestamp IS NULL THEN 1 ELSE 0
    END AS Missing_Raw_Doctor_Flag,

    CASE
        WHEN Triage_Timestamp IS NOT NULL
         AND Doctor_Seen_Timestamp IS NOT NULL
         AND Doctor_Seen_Timestamp < Triage_Timestamp
        THEN 1 ELSE 0
    END AS Doctor_Before_Triage_Flag,

    CASE
        WHEN Doctor_Seen_Timestamp IS NOT NULL
         AND Disposition_Timestamp IS NOT NULL
         AND Disposition_Timestamp < Doctor_Seen_Timestamp
        THEN 1 ELSE 0
    END AS Disposition_Before_Doctor_Flag

FROM dbo.Cleaned_ED_Visits;
GO

/* ============================================================
   STEP 4: OVERALL LWBS SUMMARY
   Denominator: all source visit rows.
   ============================================================ */

CREATE OR ALTER VIEW dbo.vw_LWBS_Impact
AS
SELECT
    COUNT_BIG(*) AS Total_Visits,

    SUM(CASE
        WHEN Disposition_Type = 'LWBS' THEN 1 ELSE 0
    END) AS LWBS_Count,

    CAST(
        100.0 * SUM(CASE
            WHEN Disposition_Type = 'LWBS' THEN 1 ELSE 0
        END) / NULLIF(COUNT_BIG(*), 0)
        AS DECIMAL(8,2)
    ) AS LWBS_Rate_Percent

FROM dbo.Cleaned_ED_Visits;
GO

/* ============================================================
   STEP 5: LWBS BY ARRIVAL YEAR
   ============================================================ */

CREATE OR ALTER VIEW dbo.vw_LWBS_By_Year
AS
SELECT
    YEAR(Arrival_Timestamp) AS Arrival_Year,
    COUNT_BIG(*) AS Total_Visits,

    SUM(CASE
        WHEN Disposition_Type = 'LWBS' THEN 1 ELSE 0
    END) AS LWBS_Visits,

    CAST(
        100.0 * SUM(CASE
            WHEN Disposition_Type = 'LWBS' THEN 1 ELSE 0
        END) / NULLIF(COUNT_BIG(*), 0)
        AS DECIMAL(8,2)
    ) AS LWBS_Rate_Percent

FROM dbo.Cleaned_ED_Visits
WHERE Arrival_Timestamp IS NOT NULL
GROUP BY YEAR(Arrival_Timestamp);
GO

/* ============================================================
   STEP 6: LWBS BY ARRIVAL HOUR
   Pooled historical observations across all years.
   Not a live or typical-day demand measure.
   ============================================================ */

CREATE OR ALTER VIEW dbo.vw_LWBS_By_Arrival_Hour
AS
SELECT
    DATEPART(HOUR, Arrival_Timestamp) AS Arrival_Hour,
    COUNT_BIG(*) AS Total_Visits,

    SUM(CASE
        WHEN Disposition_Type = 'LWBS' THEN 1 ELSE 0
    END) AS LWBS_Visits,

    CAST(
        100.0 * SUM(CASE
            WHEN Disposition_Type = 'LWBS' THEN 1 ELSE 0
        END) / NULLIF(COUNT_BIG(*), 0)
        AS DECIMAL(8,2)
    ) AS LWBS_Rate_Percent

FROM dbo.Cleaned_ED_Visits
WHERE Arrival_Timestamp IS NOT NULL
GROUP BY DATEPART(HOUR, Arrival_Timestamp);
GO

/* ============================================================
   STEP 7: LWBS BY OBSERVED TRIAGE-WAIT BAND
   Invalid or missing triage intervals are excluded.
   ============================================================ */

CREATE OR ALTER VIEW dbo.vw_LWBS_By_Wait_Band
AS
WITH WaitGroups AS
(
    SELECT
        Visit_ID,
        Disposition_Type,
        Observed_Triage_Wait_Minutes,

        CASE
            WHEN Observed_Triage_Wait_Minutes < 15
                THEN 'Under 15 min'
            WHEN Observed_Triage_Wait_Minutes < 30
                THEN '15-29 min'
            WHEN Observed_Triage_Wait_Minutes < 45
                THEN '30-44 min'
            WHEN Observed_Triage_Wait_Minutes < 60
                THEN '45-59 min'
            ELSE '60+ min'
        END AS Wait_Band,

        CASE
            WHEN Observed_Triage_Wait_Minutes < 15 THEN 1
            WHEN Observed_Triage_Wait_Minutes < 30 THEN 2
            WHEN Observed_Triage_Wait_Minutes < 45 THEN 3
            WHEN Observed_Triage_Wait_Minutes < 60 THEN 4
            ELSE 5
        END AS Wait_Band_Order

    FROM dbo.vw_Observed_Visit_Intervals
    WHERE Observed_Triage_Wait_Minutes IS NOT NULL
)
SELECT
    Wait_Band,
    Wait_Band_Order,
    COUNT_BIG(*) AS Total_Visits,

    SUM(CASE
        WHEN Disposition_Type = 'LWBS' THEN 1 ELSE 0
    END) AS LWBS_Visits,

    CAST(
        100.0 * SUM(CASE
            WHEN Disposition_Type = 'LWBS' THEN 1 ELSE 0
        END) / NULLIF(COUNT_BIG(*), 0)
        AS DECIMAL(8,2)
    ) AS LWBS_Rate_Percent,

    CAST(
        AVG(Observed_Triage_Wait_Minutes)
        AS DECIMAL(10,2)
    ) AS Avg_Observed_Wait_Minutes

FROM WaitGroups
GROUP BY Wait_Band, Wait_Band_Order;
GO

/* ============================================================
   STEP 8: LWBS BY TRIAGE SCORE AND WAIT BAND
   Triage-score meaning must be verified before interpretation.
   ============================================================ */

CREATE OR ALTER VIEW dbo.vw_LWBS_By_Score_And_Wait_Band
AS
WITH WaitGroups AS
(
    SELECT
        Triage_Score,
        Disposition_Type,
        Observed_Triage_Wait_Minutes,

        CASE
            WHEN Observed_Triage_Wait_Minutes < 15
                THEN 'Under 15 min'
            WHEN Observed_Triage_Wait_Minutes < 30
                THEN '15-29 min'
            WHEN Observed_Triage_Wait_Minutes < 45
                THEN '30-44 min'
            WHEN Observed_Triage_Wait_Minutes < 60
                THEN '45-59 min'
            ELSE '60+ min'
        END AS Wait_Band,

        CASE
            WHEN Observed_Triage_Wait_Minutes < 15 THEN 1
            WHEN Observed_Triage_Wait_Minutes < 30 THEN 2
            WHEN Observed_Triage_Wait_Minutes < 45 THEN 3
            WHEN Observed_Triage_Wait_Minutes < 60 THEN 4
            ELSE 5
        END AS Wait_Band_Order

    FROM dbo.vw_Observed_Visit_Intervals
    WHERE Observed_Triage_Wait_Minutes IS NOT NULL
      AND Triage_Score IS NOT NULL
)
SELECT
    Triage_Score,
    Wait_Band,
    Wait_Band_Order,
    COUNT_BIG(*) AS Total_Visits,

    SUM(CASE
        WHEN Disposition_Type = 'LWBS' THEN 1 ELSE 0
    END) AS LWBS_Visits,

    CAST(
        100.0 * SUM(CASE
            WHEN Disposition_Type = 'LWBS' THEN 1 ELSE 0
        END) / NULLIF(COUNT_BIG(*), 0)
        AS DECIMAL(8,2)
    ) AS LWBS_Rate_Percent

FROM WaitGroups
GROUP BY
    Triage_Score,
    Wait_Band,
    Wait_Band_Order;
GO

/* ============================================================
   STEP 9: PATIENT-FLOW SUMMARY
   ============================================================ */

CREATE OR ALTER VIEW dbo.vw_Patient_Flow_Summary
AS
SELECT
    COUNT_BIG(*) AS Total_Visit_Rows,

    COUNT(DISTINCT Patient_ID) AS Distinct_Patients,

    SUM(CASE
        WHEN Triage_Timestamp IS NOT NULL
        THEN 1 ELSE 0
    END) AS Visits_With_Raw_Triage,

    COUNT(Observed_Triage_Wait_Minutes)
        AS Visits_With_Valid_Triage_Interval,

    COUNT(Observed_Triage_To_Doctor_Minutes)
        AS Visits_With_Valid_Triage_To_Doctor_Interval,

    COUNT(Observed_Doctor_To_Disposition_Minutes)
        AS Visits_With_Valid_Doctor_To_Disposition_Interval,

    COUNT(Observed_Arrival_To_Disposition_Minutes)
        AS Visits_With_Valid_Arrival_To_Disposition_Interval,

    SUM(CASE
        WHEN Doctor_Seen_Timestamp IS NOT NULL
        THEN 1 ELSE 0
    END) AS Visits_With_Raw_Doctor_Timestamp,

    SUM(CASE
        WHEN Disposition_Type = 'LWBS'
        THEN 1 ELSE 0
    END) AS LWBS_Visits,

    SUM(CASE
        WHEN Doctor_Seen_Timestamp IS NULL
         AND (Disposition_Type IS NULL
              OR Disposition_Type <> 'LWBS')
        THEN 1 ELSE 0
    END) AS Missing_Doctor_Timestamp_Not_Labeled_LWBS

FROM dbo.vw_Observed_Visit_Intervals;
GO

/* ============================================================
   STEP 10: RUN REPORTING VIEWS
   ============================================================ */

SELECT * FROM dbo.vw_Data_Quality_Summary;
GO

SELECT * FROM dbo.vw_Observed_Visit_Intervals;
GO

SELECT * FROM dbo.vw_LWBS_Impact;
GO

SELECT * FROM dbo.vw_Patient_Flow_Summary;
GO

SELECT *
FROM dbo.vw_LWBS_By_Year
ORDER BY Arrival_Year;
GO

SELECT *
FROM dbo.vw_LWBS_By_Arrival_Hour
ORDER BY Arrival_Hour;
GO

SELECT *
FROM dbo.vw_LWBS_By_Wait_Band
ORDER BY Wait_Band_Order;
GO

SELECT *
FROM dbo.vw_LWBS_By_Score_And_Wait_Band
ORDER BY Triage_Score, Wait_Band_Order;
GO

/* ============================================================
   STEP 11: SOURCE AND LWBS RECONCILIATION
   ============================================================ */

SELECT
    COUNT_BIG(*) AS Source_Rows,
    COUNT(DISTINCT Visit_ID) AS Distinct_Visit_IDs
FROM dbo.Cleaned_ED_Visits;
GO

SELECT
    (
        SELECT COUNT_BIG(*)
        FROM dbo.Cleaned_ED_Visits
        WHERE Disposition_Type = 'LWBS'
    ) AS Source_LWBS_Count,

    (
        SELECT LWBS_Count
        FROM dbo.vw_LWBS_Impact
    ) AS View_LWBS_Count;
GO

/* ============================================================
   STEP 12: RAW ARRIVAL-TO-DISPOSITION DATA QUALITY
   ============================================================ */

SELECT
    SUM(CASE
        WHEN Arrival_Timestamp IS NOT NULL
         AND Disposition_Timestamp IS NOT NULL
         AND Disposition_Timestamp >= Arrival_Timestamp
        THEN 1 ELSE 0
    END) AS Valid_Raw_Arrival_To_Disposition,

    SUM(CASE
        WHEN Arrival_Timestamp IS NOT NULL
         AND Disposition_Timestamp IS NOT NULL
         AND Disposition_Timestamp < Arrival_Timestamp
        THEN 1 ELSE 0
    END) AS Invalid_Raw_Arrival_To_Disposition,

    SUM(CASE
        WHEN Arrival_Timestamp IS NULL
          OR Disposition_Timestamp IS NULL
        THEN 1 ELSE 0
    END) AS Incomplete_Raw_Arrival_To_Disposition

FROM dbo.Cleaned_ED_Visits;
GO

/* ============================================================
   STEP 13: CHECK DUPLICATE VISIT IDS
   Expected: zero rows if Visit_ID is unique.
   ============================================================ */

SELECT
    Visit_ID,
    COUNT_BIG(*) AS Occurrences
FROM dbo.Cleaned_ED_Visits
GROUP BY Visit_ID
HAVING COUNT_BIG(*) > 1;
GO

/* ============================================================
   STEP 14: WAIT-BAND RECONCILIATION
   Counts should match valid observed triage intervals.
   ============================================================ */

SELECT
    SUM(Total_Visits) AS Total_Visits_In_Wait_Bands,
    SUM(LWBS_Visits) AS Total_LWBS_In_Wait_Bands
FROM dbo.vw_LWBS_By_Wait_Band;
GO

SELECT
    COUNT(Observed_Triage_Wait_Minutes)
        AS Valid_Triage_Intervals,

    SUM(CASE
        WHEN Disposition_Type = 'LWBS'
        THEN 1 ELSE 0
    END) AS LWBS_Among_Valid_Triage_Intervals

FROM dbo.vw_Observed_Visit_Intervals
WHERE Observed_Triage_Wait_Minutes IS NOT NULL;
GO

/* ============================================================
   STEP 15: TRIAGE-SCORE / WAIT-BAND RECONCILIATION
   Score groups exclude visits with missing triage score.
   ============================================================ */

SELECT
    SUM(Total_Visits) AS Total_Visits,
    SUM(LWBS_Visits) AS Total_LWBS
FROM dbo.vw_LWBS_By_Score_And_Wait_Band;
GO

SELECT
    COUNT(Observed_Triage_Wait_Minutes)
        AS Valid_Triage_Intervals_With_Score,

    SUM(CASE
        WHEN Disposition_Type = 'LWBS'
        THEN 1 ELSE 0
    END) AS LWBS_Among_Valid_Intervals_With_Score

FROM dbo.vw_Observed_Visit_Intervals
WHERE Observed_Triage_Wait_Minutes IS NOT NULL
  AND Triage_Score IS NOT NULL;
GO

/* ============================================================
   STEP 16: INTERVAL COUNTS AND AVERAGES
   Compare these values with Power BI measures that use
   identical timestamp eligibility rules.
   ============================================================ */

SELECT
    COUNT(Observed_Triage_Wait_Minutes) AS n_triage,

    CAST(
        AVG(Observed_Triage_Wait_Minutes)
        AS DECIMAL(10,2)
    ) AS avg_triage,

    COUNT(Observed_Triage_To_Doctor_Minutes) AS n_t2d,

    CAST(
        AVG(Observed_Triage_To_Doctor_Minutes)
        AS DECIMAL(10,2)
    ) AS avg_t2d,

    COUNT(Observed_Doctor_To_Disposition_Minutes) AS n_d2d,

    CAST(
        AVG(Observed_Doctor_To_Disposition_Minutes)
        AS DECIMAL(10,2)
    ) AS avg_d2d,

    COUNT(Observed_Arrival_To_Disposition_Minutes) AS n_a2d,

    CAST(
        AVG(Observed_Arrival_To_Disposition_Minutes)
        AS DECIMAL(10,2)
    ) AS avg_a2d

FROM dbo.vw_Observed_Visit_Intervals;
GO

/* ============================================================
   STEP 17: INTERVAL ELIGIBILITY COUNTS
   Useful for investigating differences between intervals.
   ============================================================ */

SELECT
    COUNT_BIG(*) AS Total_Source_Rows,

    SUM(CASE
        WHEN Observed_Triage_Wait_Minutes IS NULL
        THEN 1 ELSE 0
    END) AS Invalid_Or_Missing_Triage_Interval,

    SUM(CASE
        WHEN Observed_Triage_To_Doctor_Minutes IS NULL
        THEN 1 ELSE 0
    END) AS Invalid_Or_Missing_Triage_To_Doctor_Interval,

    SUM(CASE
        WHEN Observed_Doctor_To_Disposition_Minutes IS NULL
        THEN 1 ELSE 0
    END) AS Invalid_Or_Missing_Doctor_To_Disposition_Interval,

    SUM(CASE
        WHEN Observed_Arrival_To_Disposition_Minutes IS NULL
        THEN 1 ELSE 0
    END) AS Invalid_Or_Missing_Arrival_To_Disposition_Interval

FROM dbo.vw_Observed_Visit_Intervals;
GO
