/* ============================================================
   HR ATTRITION ANALYTICS
   SQL SERVER ANALYSIS
   ============================================================ */


/* ============================================================
   SECTION 9.1 — DATABASE SETUP
   ============================================================ */

CREATE DATABASE HR_Attrition_Analytics;
GO

USE HR_Attrition_Analytics;
GO

SELECT DB_NAME() AS CurrentDatabase;


/* ============================================================
   SECTION 9.2 — DATA VALIDATION
   ============================================================ */


/* 1. Total records */

SELECT
    COUNT(*) AS TotalRows
FROM dbo.employee_attrition_clean;


/* 2. Row count and unique employees */

SELECT
    COUNT(*) AS TotalRows,
    COUNT(DISTINCT ID) AS UniqueEmployees
FROM dbo.employee_attrition_clean;


/* 3. Attrition distribution */

SELECT
    Attrition,
    COUNT(*) AS EmployeeCount
FROM dbo.employee_attrition_clean
GROUP BY Attrition
ORDER BY EmployeeCount DESC;


/* 4. Validate Attrition and AttritionFlag */

SELECT
    Attrition,
    AttritionFlag,
    COUNT(*) AS EmployeeCount
FROM dbo.employee_attrition_clean
GROUP BY
    Attrition,
    AttritionFlag
ORDER BY
    Attrition,
    AttritionFlag;


/* 5. Missing-value check */

SELECT
    SUM(CASE WHEN ID IS NULL THEN 1 ELSE 0 END) AS Missing_ID,
    SUM(CASE WHEN Attrition IS NULL THEN 1 ELSE 0 END) AS Missing_Attrition,
    SUM(CASE WHEN Gender IS NULL THEN 1 ELSE 0 END) AS Missing_Gender,
    SUM(CASE WHEN Sector IS NULL THEN 1 ELSE 0 END) AS Missing_Sector,
    SUM(CASE WHEN Department IS NULL THEN 1 ELSE 0 END) AS Missing_Department,
    SUM(CASE WHEN JobTitle IS NULL THEN 1 ELSE 0 END) AS Missing_JobTitle
FROM dbo.employee_attrition_clean;


/* 6. Duplicate ID check */

SELECT
    ID,
    COUNT(*) AS RecordCount
FROM dbo.employee_attrition_clean
GROUP BY ID
HAVING COUNT(*) > 1;


/* 7. Column count */

SELECT
    COUNT(*) AS ColumnCount
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'dbo'
  AND TABLE_NAME = 'employee_attrition_clean';


/* ============================================================
   SECTION 9.3 — CORE HR ATTRITION KPIs
   ============================================================ */

SELECT
    COUNT(*) AS TotalEmployees,

    SUM(
        CASE
            WHEN AttritionFlag = 0 THEN 1
            ELSE 0
        END
    ) AS ActiveEmployees,

    SUM(
        CASE
            WHEN AttritionFlag = 1 THEN 1
            ELSE 0
        END
    ) AS AttritionEmployees,

    CAST(
        100.0 *
        SUM(
            CASE
                WHEN AttritionFlag = 1 THEN 1
                ELSE 0
            END
        )
        / COUNT(*)
        AS DECIMAL(10,2)
    ) AS OverallAttritionRate

FROM dbo.employee_attrition_clean;


/* ============================================================
   SECTION 9.4 — PHYSICAL STRESS ANALYSIS
   ============================================================ */

SELECT
    CASE Physical_Stress_Score
        WHEN 0 THEN 'No'
        WHEN 1 THEN 'Sometimes'
        WHEN 2 THEN 'Yes'
    END AS PhysicalStressLevel,

    COUNT(*) AS EmployeeCount,

    SUM(CAST(AttritionFlag AS INT)) AS AttritionCount,

    CAST(
        100.0 *
        AVG(CAST(AttritionFlag AS DECIMAL(10,4)))
        AS DECIMAL(10,2)
    ) AS AttritionRate

FROM dbo.employee_attrition_clean

GROUP BY Physical_Stress_Score

ORDER BY Physical_Stress_Score;


/* ============================================================
   SECTION 9.5 — PSYCHOLOGICAL EXHAUSTION ANALYSIS
   ============================================================ */

SELECT
    CASE Psychological_Exhaustion_Score
        WHEN 0 THEN 'No'
        WHEN 1 THEN 'Sometimes'
        WHEN 2 THEN 'Yes'
    END AS PsychologicalExhaustionLevel,

    COUNT(*) AS EmployeeCount,

    SUM(CAST(AttritionFlag AS INT)) AS AttritionCount,

    CAST(
        100.0 *
        AVG(CAST(AttritionFlag AS DECIMAL(10,4)))
        AS DECIMAL(10,2)
    ) AS AttritionRate

FROM dbo.employee_attrition_clean

GROUP BY Psychological_Exhaustion_Score

ORDER BY Psychological_Exhaustion_Score;

/* ============================================================
   SECTION 9.4.1 — GENDER ATTRITION ANALYSIS
   ============================================================ */

SELECT
    Gender,

    COUNT(*) AS EmployeeCount,

    SUM(CAST(AttritionFlag AS INT)) AS AttritionCount,

    CAST(
        100.0 *
        AVG(CAST(AttritionFlag AS DECIMAL(10,4)))
        AS DECIMAL(10,2)
    ) AS AttritionRate

FROM dbo.employee_attrition_clean

GROUP BY Gender

ORDER BY AttritionRate DESC;

/* ============================================================
   SECTION 9.4.2 — AGE GROUP ATTRITION ANALYSIS
   ============================================================ */

SELECT
    CASE
        WHEN TRY_CONVERT(INT, Age) BETWEEN 21 AND 30 THEN '21 to 30'
        WHEN TRY_CONVERT(INT, Age) BETWEEN 31 AND 40 THEN '31 to 40'
        WHEN TRY_CONVERT(INT, Age) BETWEEN 41 AND 50 THEN '41 to 50'
        WHEN TRY_CONVERT(INT, Age) BETWEEN 51 AND 60 THEN '51 to 60'
    END AS AgeGroup,

    COUNT(*) AS EmployeeCount,

    SUM(CAST(AttritionFlag AS INT)) AS AttritionCount,

    CAST(
        100.0 *
        AVG(CAST(AttritionFlag AS DECIMAL(10,4)))
        AS DECIMAL(10,2)
    ) AS AttritionRate

FROM dbo.employee_attrition_clean

GROUP BY
    CASE
        WHEN TRY_CONVERT(INT, Age) BETWEEN 21 AND 30 THEN '21 to 30'
        WHEN TRY_CONVERT(INT, Age) BETWEEN 31 AND 40 THEN '31 to 40'
        WHEN TRY_CONVERT(INT, Age) BETWEEN 41 AND 50 THEN '41 to 50'
        WHEN TRY_CONVERT(INT, Age) BETWEEN 51 AND 60 THEN '51 to 60'
    END;

SELECT
    Age,
    COUNT(*) AS EmployeeCount
FROM dbo.employee_attrition_clean
GROUP BY Age
ORDER BY EmployeeCount DESC;

/* ============================================================
   SECTION 9.5.1 — YEARS OF EXPERIENCE ATTRITION ANALYSIS
   ============================================================ */

SELECT
    Years_Experience AS ExperienceGroup,

    COUNT(*) AS EmployeeCount,

    SUM(CAST(AttritionFlag AS INT)) AS AttritionCount,

    CAST(
        100.0 *
        AVG(CAST(AttritionFlag AS DECIMAL(10,4)))
        AS DECIMAL(10,2)
    ) AS AttritionRate

FROM dbo.employee_attrition_clean

GROUP BY Years_Experience

ORDER BY
    CASE Years_Experience
        WHEN 'Less than 5 years' THEN 1
        WHEN 'From 5 to 10 years' THEN 2
        WHEN 'From 11 to 15 years' THEN 3
        WHEN 'From 16 to 20 years' THEN 4
        WHEN 'From 21 to 25 years' THEN 5
        WHEN 'From 26 to 30 years' THEN 6
        WHEN 'From 31 to 35 years' THEN 7
        ELSE 8
    END;

/* ============================================================
   SECTION 9.5.2 — YEARS AT LAST ORGANIZATION
   ============================================================ */

SELECT
    Years_experience_lastorganization AS ExperienceAtLastOrganization,

    COUNT(*) AS EmployeeCount,

    SUM(CAST(AttritionFlag AS INT)) AS AttritionCount,

    CAST(
        100.0 *
        AVG(CAST(AttritionFlag AS DECIMAL(10,4)))
        AS DECIMAL(10,2)
    ) AS AttritionRate

FROM dbo.employee_attrition_clean

GROUP BY Years_experience_lastorganization

ORDER BY
    CASE Years_experience_lastorganization
        WHEN 'Less than 5 years' THEN 1
        WHEN 'From 5 to 10 years' THEN 2
        WHEN 'From 11 to 15 years' THEN 3
        WHEN 'From 16 to 20 years' THEN 4
        WHEN 'From 21 to 25 years' THEN 5
        WHEN 'From 26 to 30 years' THEN 6
        WHEN 'From 31 to 35 years' THEN 7
        ELSE 8
    END;

/* ============================================================
   SECTION 9.5.3 — SECTOR ATTRITION ANALYSIS
   ============================================================ */

SELECT
    Sector,

    COUNT(*) AS EmployeeCount,

    SUM(CAST(AttritionFlag AS INT)) AS AttritionCount,

    CAST(
        100.0 *
        AVG(CAST(AttritionFlag AS DECIMAL(10,4)))
        AS DECIMAL(10,2)
    ) AS AttritionRate

FROM dbo.employee_attrition_clean

GROUP BY Sector

ORDER BY AttritionRate DESC;

/* ============================================================
   SECTION 9.5.4 — DEPARTMENT ATTRITION ANALYSIS
   ============================================================ */

SELECT
    Department,

    COUNT(*) AS EmployeeCount,

    SUM(CAST(AttritionFlag AS INT)) AS AttritionCount,

    CAST(
        100.0 *
        AVG(CAST(AttritionFlag AS DECIMAL(10,4)))
        AS DECIMAL(10,2)
    ) AS AttritionRate

FROM dbo.employee_attrition_clean

GROUP BY Department

ORDER BY AttritionRate DESC;

/* ============================================================
   SECTION 9.5.5 — JOB TITLE ATTRITION ANALYSIS
   ============================================================ */

SELECT
    JobTitle,

    COUNT(*) AS EmployeeCount,

    SUM(CAST(AttritionFlag AS INT)) AS AttritionCount,

    CAST(
        100.0 *
        AVG(CAST(AttritionFlag AS DECIMAL(10,4)))
        AS DECIMAL(10,2)
    ) AS AttritionRate

FROM dbo.employee_attrition_clean

GROUP BY JobTitle

ORDER BY AttritionRate DESC;

/* ============================================================
   SECTION 9.6.1 — MONTHLY SALARY ATTRITION ANALYSIS
   ============================================================ */

SELECT
    MonthlySalary AS SalaryGroup,

    COUNT(*) AS EmployeeCount,

    SUM(CAST(AttritionFlag AS INT)) AS AttritionCount,

    CAST(
        100.0 *
        AVG(CAST(AttritionFlag AS DECIMAL(10,4)))
        AS DECIMAL(10,2)
    ) AS AttritionRate

FROM dbo.employee_attrition_clean

GROUP BY MonthlySalary

ORDER BY
    CASE MonthlySalary
        WHEN 'Less than 5000 SAR' THEN 1
        WHEN 'From 5000 to 10000 S.R' THEN 2
        WHEN 'From 11000 to 15000 S.R' THEN 3
        WHEN 'From 16000 to 20000 S.R' THEN 4
        WHEN 'From 21000 to 25000 S.R' THEN 5
        WHEN 'From 26000 to 30000 S.R' THEN 6
        WHEN 'S.R 31000 - and more' THEN 7
        ELSE 8
    END;

/* ============================================================
   SECTION 9.6.2 — ALLOWANCES ATTRITION ANALYSIS
   ============================================================ */

SELECT
    Allowances,

    COUNT(*) AS EmployeeCount,

    SUM(CAST(AttritionFlag AS INT)) AS AttritionCount,

    CAST(
        100.0 *
        AVG(CAST(AttritionFlag AS DECIMAL(10,4)))
        AS DECIMAL(10,2)
    ) AS AttritionRate

FROM dbo.employee_attrition_clean

GROUP BY Allowances

ORDER BY Allowances;

/* ============================================================
   SECTION 9.6.3 — BONUS ATTRITION ANALYSIS
   ============================================================ */

SELECT
    Bonus,

    COUNT(*) AS EmployeeCount,

    SUM(CAST(AttritionFlag AS INT)) AS AttritionCount,

    CAST(
        100.0 *
        AVG(CAST(AttritionFlag AS DECIMAL(10,4)))
        AS DECIMAL(10,2)
    ) AS AttritionRate

FROM dbo.employee_attrition_clean

GROUP BY Bonus

ORDER BY AttritionRate DESC;

/* ============================================================
   SECTION 9.6.4 — MEDICAL INSURANCE ATTRITION ANALYSIS
   ============================================================ */

SELECT
    MedicalInsurance,

    COUNT(*) AS EmployeeCount,

    SUM(CAST(AttritionFlag AS INT)) AS AttritionCount,

    CAST(
        100.0 *
        AVG(CAST(AttritionFlag AS DECIMAL(10,4)))
        AS DECIMAL(10,2)
    ) AS AttritionRate

FROM dbo.employee_attrition_clean

GROUP BY MedicalInsurance

ORDER BY AttritionRate DESC;

/* ============================================================
   SECTION 9.6.5 — OVERTIME ATTRITION ANALYSIS
   ============================================================ */

SELECT
    OverTime,

    COUNT(*) AS EmployeeCount,

    SUM(CAST(AttritionFlag AS INT)) AS AttritionCount,

    CAST(
        100.0 *
        AVG(CAST(AttritionFlag AS DECIMAL(10,4)))
        AS DECIMAL(10,2)
    ) AS AttritionRate

FROM dbo.employee_attrition_clean

GROUP BY OverTime

ORDER BY AttritionRate DESC;

/* ============================================================
   SECTION 9.6.6 — PAYMENT FOR OVERTIME ATTRITION ANALYSIS
   ============================================================ */

SELECT
    Payment_Overtime,

    COUNT(*) AS EmployeeCount,

    SUM(CAST(AttritionFlag AS INT)) AS AttritionCount,

    CAST(
        100.0 *
        AVG(CAST(AttritionFlag AS DECIMAL(10,4)))
        AS DECIMAL(10,2)
    ) AS AttritionRate

FROM dbo.employee_attrition_clean

GROUP BY Payment_Overtime

ORDER BY AttritionRate DESC;

/* ============================================================
   SECTION 9.6.7 — REWARDS & WAGES SATISFACTION
   ============================================================ */

SELECT
    Rewards_Wages_Satisfaction,

    COUNT(*) AS EmployeeCount,

    SUM(CAST(AttritionFlag AS INT)) AS AttritionCount,

    CAST(
        100.0 *
        AVG(CAST(AttritionFlag AS DECIMAL(10,4)))
        AS DECIMAL(10,2)
    ) AS AttritionRate

FROM dbo.employee_attrition_clean

GROUP BY Rewards_Wages_Satisfaction

ORDER BY AttritionRate DESC;


/* ============================================================
   SECTION 9.7.1 — JOB SATISFACTION ATTRITION ANALYSIS
   ============================================================ */

SELECT
    Job_Satisfaction,

    COUNT(*) AS EmployeeCount,

    SUM(CAST(AttritionFlag AS INT)) AS AttritionCount,

    CAST(
        100.0 *
        AVG(CAST(AttritionFlag AS DECIMAL(10,4)))
        AS DECIMAL(10,2)
    ) AS AttritionRate

FROM dbo.employee_attrition_clean

GROUP BY Job_Satisfaction

ORDER BY AttritionRate DESC;

/* ============================================================
   SECTION 9.7.2 — ENVIRONMENT SATISFACTION
   ============================================================ */

SELECT
    Environment_Satisfaction,

    COUNT(*) AS EmployeeCount,

    SUM(CAST(AttritionFlag AS INT)) AS AttritionCount,

    CAST(
        100.0 *
        AVG(CAST(AttritionFlag AS DECIMAL(10,4)))
        AS DECIMAL(10,2)
    ) AS AttritionRate

FROM dbo.employee_attrition_clean

GROUP BY Environment_Satisfaction

ORDER BY AttritionRate DESC;


/* ============================================================
   SECTION 9.7.3 — EMOTIONAL COMMITMENT
   ============================================================ */

SELECT
    Emotional_Commitment,

    COUNT(*) AS EmployeeCount,

    SUM(CAST(AttritionFlag AS INT)) AS AttritionCount,

    CAST(
        100.0 *
        AVG(CAST(AttritionFlag AS DECIMAL(10,4)))
        AS DECIMAL(10,2)
    ) AS AttritionRate

FROM dbo.employee_attrition_clean

GROUP BY Emotional_Commitment

ORDER BY AttritionRate DESC;

/* ============================================================
   SECTION 9.7.4 — JOB ENGAGEMENT
   ============================================================ */

SELECT
    Job_Engagement,

    COUNT(*) AS EmployeeCount,

    SUM(CAST(AttritionFlag AS INT)) AS AttritionCount,

    CAST(
        100.0 *
        AVG(CAST(AttritionFlag AS DECIMAL(10,4)))
        AS DECIMAL(10,2)
    ) AS AttritionRate

FROM dbo.employee_attrition_clean

GROUP BY Job_Engagement

ORDER BY AttritionRate DESC;

/* ============================================================
   SECTION 9.7.5 — JOB SUPPORT
   ============================================================ */

SELECT
    Job_Support,

    COUNT(*) AS EmployeeCount,

    SUM(CAST(AttritionFlag AS INT)) AS AttritionCount,

    CAST(
        100.0 *
        AVG(CAST(AttritionFlag AS DECIMAL(10,4)))
        AS DECIMAL(10,2)
    ) AS AttritionRate

FROM dbo.employee_attrition_clean

GROUP BY Job_Support

ORDER BY AttritionRate DESC;


/* ============================================================
   SECTION 9.7.6 — RECOGNITION
   ============================================================ */

SELECT
    Recognition,

    COUNT(*) AS EmployeeCount,

    SUM(CAST(AttritionFlag AS INT)) AS AttritionCount,

    CAST(
        100.0 *
        AVG(CAST(AttritionFlag AS DECIMAL(10,4)))
        AS DECIMAL(10,2)
    ) AS AttritionRate

FROM dbo.employee_attrition_clean

GROUP BY Recognition

ORDER BY AttritionRate DESC;

SELECT
    COLUMN_NAME
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'dbo'
  AND TABLE_NAME = 'employee_attrition_clean'
  AND COLUMN_NAME LIKE '%Promotion%';

SELECT
    Get_Deserved_Promotion,

    COUNT(*) AS EmployeeCount,

    SUM(CAST(AttritionFlag AS INT)) AS AttritionCount,

    CAST(
        100.0 *
        AVG(CAST(AttritionFlag AS DECIMAL(10,4)))
        AS DECIMAL(10,2)
    ) AS AttritionRate

FROM dbo.employee_attrition_clean

GROUP BY Get_Deserved_Promotion

ORDER BY AttritionRate DESC;

/* ============================================================
   SECTION 9.7.8 — WORK-LIFE BALANCE
   ============================================================ */

SELECT
    Work_Live_Balance,

    COUNT(*) AS EmployeeCount,

    SUM(CAST(AttritionFlag AS INT)) AS AttritionCount,

    CAST(
        100.0 *
        AVG(CAST(AttritionFlag AS DECIMAL(10,4)))
        AS DECIMAL(10,2)
    ) AS AttritionRate

FROM dbo.employee_attrition_clean

GROUP BY Work_Live_Balance

ORDER BY AttritionRate DESC;

/* ============================================================
   SECTION 9.7.9 — JOB STABILITY
   ============================================================ */

SELECT
    Job_Stability,

    COUNT(*) AS EmployeeCount,

    SUM(CAST(AttritionFlag AS INT)) AS AttritionCount,

    CAST(
        100.0 *
        AVG(CAST(AttritionFlag AS DECIMAL(10,4)))
        AS DECIMAL(10,2)
    ) AS AttritionRate

FROM dbo.employee_attrition_clean

GROUP BY Job_Stability

ORDER BY AttritionRate DESC;

/* ============================================================
   SECTION 9.7.10 — JOB OPPORTUNITIES
   ============================================================ */

SELECT
    Job_Opportunities,

    COUNT(*) AS EmployeeCount,

    SUM(CAST(AttritionFlag AS INT)) AS AttritionCount,

    CAST(
        100.0 *
        AVG(CAST(AttritionFlag AS DECIMAL(10,4)))
        AS DECIMAL(10,2)
    ) AS AttritionRate

FROM dbo.employee_attrition_clean

GROUP BY Job_Opportunities

ORDER BY AttritionRate DESC;

/* ============================================================
   SECTION 9.8.1 — HEALTH ISSUES
   ============================================================ */

SELECT
    Health_Issues,

    COUNT(*) AS EmployeeCount,

    SUM(CAST(AttritionFlag AS INT)) AS AttritionCount,

    CAST(
        100.0 *
        AVG(CAST(AttritionFlag AS DECIMAL(10,4)))
        AS DECIMAL(10,2)
    ) AS AttritionRate

FROM dbo.employee_attrition_clean

GROUP BY Health_Issues

ORDER BY AttritionRate DESC;

/* ============================================================
   SECTION 9.8.2 — PHYSICAL STRESS
   ============================================================ */

SELECT
    CASE Physical_Stress_Score
        WHEN 0 THEN 'No'
        WHEN 1 THEN 'Sometimes'
        WHEN 2 THEN 'Yes'
    END AS PhysicalStressLevel,

    COUNT(*) AS EmployeeCount,

    SUM(CAST(AttritionFlag AS INT)) AS AttritionCount,

    CAST(
        100.0 *
        AVG(CAST(AttritionFlag AS DECIMAL(10,4)))
        AS DECIMAL(10,2)
    ) AS AttritionRate

FROM dbo.employee_attrition_clean

GROUP BY Physical_Stress_Score

ORDER BY Physical_Stress_Score;

/* ============================================================
   SECTION 9.8.3 — PSYCHOLOGICAL EXHAUSTION
   ============================================================ */

SELECT
    CASE Psychological_Exhaustion_Score
        WHEN 0 THEN 'No'
        WHEN 1 THEN 'Sometimes'
        WHEN 2 THEN 'Yes'
    END AS PsychologicalExhaustionLevel,

    COUNT(*) AS EmployeeCount,

    SUM(CAST(AttritionFlag AS INT)) AS AttritionCount,

    CAST(
        100.0 *
        AVG(CAST(AttritionFlag AS DECIMAL(10,4)))
        AS DECIMAL(10,2)
    ) AS AttritionRate

FROM dbo.employee_attrition_clean

GROUP BY Psychological_Exhaustion_Score

ORDER BY Psychological_Exhaustion_Score;

/* ============================================================
   SECTION 9.8.4 — DISTANCE TO WORK
   ============================================================ */

SELECT
    Distance_to_work,

    COUNT(*) AS EmployeeCount,

    SUM(CAST(AttritionFlag AS INT)) AS AttritionCount,

    CAST(
        100.0 *
        AVG(CAST(AttritionFlag AS DECIMAL(10,4)))
        AS DECIMAL(10,2)
    ) AS AttritionRate

FROM dbo.employee_attrition_clean

GROUP BY Distance_to_work

ORDER BY AttritionRate DESC;

/* ============================================================
   SECTION 9.8.5 — BUSINESS TRAVEL
   ============================================================ */

SELECT
    Business_Travel,

    COUNT(*) AS EmployeeCount,

    SUM(CAST(AttritionFlag AS INT)) AS AttritionCount,

    CAST(
        100.0 *
        AVG(CAST(AttritionFlag AS DECIMAL(10,4)))
        AS DECIMAL(10,2)
    ) AS AttritionRate

FROM dbo.employee_attrition_clean

GROUP BY Business_Travel

ORDER BY AttritionRate DESC;

/* ============================================================
   SECTION 9.8.6 — PHYSICAL STRESS + PSYCHOLOGICAL EXHAUSTION
   COMBINED ATTRITION ANALYSIS
   ============================================================ */

SELECT
    CASE Physical_Stress_Score
        WHEN 0 THEN 'No'
        WHEN 1 THEN 'Sometimes'
        WHEN 2 THEN 'Yes'
    END AS PhysicalStressLevel,

    CASE Psychological_Exhaustion_Score
        WHEN 0 THEN 'No'
        WHEN 1 THEN 'Sometimes'
        WHEN 2 THEN 'Yes'
    END AS PsychologicalExhaustionLevel,

    COUNT(*) AS EmployeeCount,

    SUM(CAST(AttritionFlag AS INT)) AS AttritionCount,

    CAST(
        100.0 *
        AVG(CAST(AttritionFlag AS DECIMAL(10,4)))
        AS DECIMAL(10,2)
    ) AS AttritionRate

FROM dbo.employee_attrition_clean

GROUP BY
    Physical_Stress_Score,
    Psychological_Exhaustion_Score

ORDER BY
    Physical_Stress_Score,
    Psychological_Exhaustion_Score;


/* ============================================================
   SECTION 9.9.1 — TRAINING PROGRAMS DURING LAST THREE YEARS
   ============================================================ */

SELECT
    Training_programs_During_last_three_years,

    COUNT(*) AS EmployeeCount,

    SUM(CAST(AttritionFlag AS INT)) AS AttritionCount,

    CAST(
        100.0 *
        AVG(CAST(AttritionFlag AS DECIMAL(10,4)))
        AS DECIMAL(10,2)
    ) AS AttritionRate

FROM dbo.employee_attrition_clean

GROUP BY Training_programs_During_last_three_years

ORDER BY AttritionRate DESC;

/* ============================================================
   SECTION 9.9.2 — USEFUL TRAINING PROGRAMS
   ============================================================ */

SELECT
    Useful_Training_Programs,

    COUNT(*) AS EmployeeCount,

    SUM(CAST(AttritionFlag AS INT)) AS AttritionCount,

    CAST(
        100.0 *
        AVG(CAST(AttritionFlag AS DECIMAL(10,4)))
        AS DECIMAL(10,2)
    ) AS AttritionRate

FROM dbo.employee_attrition_clean

GROUP BY Useful_Training_Programs

ORDER BY AttritionRate DESC;

/* ============================================================
   SECTION 9.10.1 — OVERALL DATASET VALIDATION
   ============================================================ */

SELECT
    COUNT(*) AS TotalEmployees,

    COUNT(DISTINCT ID) AS UniqueEmployees,

    SUM(CASE
        WHEN AttritionFlag = 1 THEN 1
        ELSE 0
    END) AS AttritionEmployees,

    SUM(CASE
        WHEN AttritionFlag = 0 THEN 1
        ELSE 0
    END) AS ActiveEmployees,

    CAST(
        100.0 *
        SUM(CASE
            WHEN AttritionFlag = 1 THEN 1
            ELSE 0
        END) / COUNT(*)
        AS DECIMAL(10,2)
    ) AS OverallAttritionRate

FROM dbo.employee_attrition_clean;

/* ============================================================
   SECTION 9.10.2 — DUPLICATE ID VALIDATION
   ============================================================ */

SELECT
    ID,
    COUNT(*) AS RecordCount
FROM dbo.employee_attrition_clean
GROUP BY ID
HAVING COUNT(*) > 1;


/* ============================================================
   SECTION 9.10.3 — KEY MISSING VALUE VALIDATION
   ============================================================ */

SELECT
    SUM(CASE WHEN ID IS NULL THEN 1 ELSE 0 END) AS Missing_ID,

    SUM(CASE WHEN Attrition IS NULL THEN 1 ELSE 0 END)
        AS Missing_Attrition,

    SUM(CASE WHEN Gender IS NULL THEN 1 ELSE 0 END)
        AS Missing_Gender,

    SUM(CASE WHEN Sector IS NULL THEN 1 ELSE 0 END)
        AS Missing_Sector,

    SUM(CASE WHEN Department IS NULL THEN 1 ELSE 0 END)
        AS Missing_Department,

    SUM(CASE WHEN JobTitle IS NULL THEN 1 ELSE 0 END)
        AS Missing_JobTitle,

    SUM(CASE WHEN MonthlySalary IS NULL THEN 1 ELSE 0 END)
        AS Missing_MonthlySalary

FROM dbo.employee_attrition_clean;

/* ============================================================
   SECTION 9.10.4 — ATTRITION FLAG VALIDATION
   ============================================================ */

SELECT
    Attrition,
    AttritionFlag,
    COUNT(*) AS EmployeeCount
FROM dbo.employee_attrition_clean
GROUP BY
    Attrition,
    AttritionFlag
ORDER BY
    Attrition,
    AttritionFlag;

/* Job Opportunities */

SELECT
    Job_Opportunities,
    COUNT(*) AS EmployeeCount,
    SUM(CAST(AttritionFlag AS INT)) AS AttritionCount,
    CAST(
        100.0 * AVG(CAST(AttritionFlag AS DECIMAL(10,4)))
        AS DECIMAL(10,2)
    ) AS AttritionRate
FROM dbo.employee_attrition_clean
GROUP BY Job_Opportunities
ORDER BY AttritionRate DESC;

/* Job Satisfaction */

SELECT
    Job_Satisfaction,
    COUNT(*) AS EmployeeCount,
    SUM(CAST(AttritionFlag AS INT)) AS AttritionCount,
    CAST(
        100.0 * AVG(CAST(AttritionFlag AS DECIMAL(10,4)))
        AS DECIMAL(10,2)
    ) AS AttritionRate
FROM dbo.employee_attrition_clean
GROUP BY Job_Satisfaction
ORDER BY AttritionRate DESC;

/* Emotional Commitment */

SELECT
    Emotional_Commitment,
    COUNT(*) AS EmployeeCount,
    SUM(CAST(AttritionFlag AS INT)) AS AttritionCount,
    CAST(
        100.0 * AVG(CAST(AttritionFlag AS DECIMAL(10,4)))
        AS DECIMAL(10,2)
    ) AS AttritionRate
FROM dbo.employee_attrition_clean
GROUP BY Emotional_Commitment
ORDER BY AttritionRate DESC;

/* Job Engagement */

SELECT
    Job_Engagement,
    COUNT(*) AS EmployeeCount,
    SUM(CAST(AttritionFlag AS INT)) AS AttritionCount,
    CAST(
        100.0 * AVG(CAST(AttritionFlag AS DECIMAL(10,4)))
        AS DECIMAL(10,2)
    ) AS AttritionRate
FROM dbo.employee_attrition_clean
GROUP BY Job_Engagement
ORDER BY AttritionRate DESC;

/* Training Programs */

SELECT
    Training_programs_During_last_three_years,

    COUNT(*) AS EmployeeCount,

    SUM(CAST(AttritionFlag AS INT)) AS AttritionCount,

    CAST(
        100.0 *
        AVG(CAST(AttritionFlag AS DECIMAL(10,4)))
        AS DECIMAL(10,2)
    ) AS AttritionRate

FROM dbo.employee_attrition_clean

GROUP BY Training_programs_During_last_three_years

ORDER BY AttritionRate DESC;

/* ============================================================
   SECTION 9.10.7 — FINAL SQL VALIDATION SUMMARY
   ============================================================ */

SELECT
    'Total Employees' AS ValidationItem,
    CAST(COUNT(*) AS VARCHAR(50)) AS ValidationValue
FROM dbo.employee_attrition_clean

UNION ALL

SELECT
    'Unique Employees',
    CAST(COUNT(DISTINCT ID) AS VARCHAR(50))
FROM dbo.employee_attrition_clean

UNION ALL

SELECT
    'Attrition Employees',
    CAST(
        SUM(CAST(AttritionFlag AS INT))
        AS VARCHAR(50)
    )
FROM dbo.employee_attrition_clean

UNION ALL

SELECT
    'Active Employees',
    CAST(
        SUM(
            CASE
                WHEN AttritionFlag = 0 THEN 1
                ELSE 0
            END
        )
        AS VARCHAR(50)
    )
FROM dbo.employee_attrition_clean

UNION ALL

SELECT
    'Overall Attrition Rate',
    CAST(
        CAST(
            100.0 * SUM(CAST(AttritionFlag AS INT))
            / COUNT(*)
            AS DECIMAL(10,2)
        )
        AS VARCHAR(50)
    )
FROM dbo.employee_attrition_clean;