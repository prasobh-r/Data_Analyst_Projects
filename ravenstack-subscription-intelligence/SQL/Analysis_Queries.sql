-- =============================================
-- RavenStack Subscription Intelligence Platform
-- Advanced SQL Analysis Queries
-- Run Database_Setup.sql first.
-- =============================================

USE RavenStack_SubscriptionIntelligence;
GO


-- =============================================
-- Query 1: Monthly Cohort Retention
-- CTEs + conditional aggregation
-- Shows, for each signup month, how many accounts are still active.
-- =============================================
WITH CohortBase AS (
    SELECT 
        account_id,
        cohort_month,
        signup_date,
        is_active,
        DATEDIFF(MONTH, signup_date, 
            COALESCE((SELECT MAX(end_date) FROM Fact_Subscription 
                      WHERE Fact_Subscription.account_id = Dim_Account.account_id), 
                      '2024-12-31')
        ) AS months_since_signup
    FROM Dim_Account
),
CohortSize AS (
    SELECT cohort_month, COUNT(*) AS total_accounts
    FROM Dim_Account
    GROUP BY cohort_month
)
SELECT 
    cb.cohort_month,
    cs.total_accounts,
    SUM(CASE WHEN cb.is_active = 1 THEN 1 ELSE 0 END) AS still_active,
    ROUND(100.0 * SUM(CASE WHEN cb.is_active = 1 THEN 1 ELSE 0 END) / cs.total_accounts, 1) AS retention_pct
FROM CohortBase cb
JOIN CohortSize cs ON cb.cohort_month = cs.cohort_month
GROUP BY cb.cohort_month, cs.total_accounts
ORDER BY cb.cohort_month;


-- =============================================
-- Query 2: Customer Ranking with Window Functions
-- RANK, ROW_NUMBER, NTILE
-- Ranks active accounts by revenue-at-risk within each risk tier,
-- and buckets accounts into revenue quartiles.
-- =============================================
SELECT 
    account_id,
    plan_tier,
    risk_tier,
    revenue_at_risk,
    RANK() OVER (PARTITION BY risk_tier ORDER BY revenue_at_risk DESC) AS rank_within_tier,
    ROW_NUMBER() OVER (ORDER BY revenue_at_risk DESC) AS overall_rank,
    NTILE(4) OVER (ORDER BY mrr_amount DESC) AS revenue_quartile
FROM Dim_Account
WHERE is_active = 1
ORDER BY revenue_at_risk DESC;


-- =============================================
-- Query 3: Save Campaign Prioritizer
-- CASE-based business logic
-- Ranks at-risk active accounts by revenue impact and recommends
-- a specific retention action per account.
-- =============================================
SELECT 
    account_id,
    account_name,
    industry,
    plan_tier,
    mrr_amount,
    health_score,
    risk_tier,
    revenue_at_risk,
    total_tickets,
    escalation_rate,
    renewal_probability,
    CASE 
        WHEN escalation_rate > 0.2 THEN 'Escalate to CS Manager'
        WHEN avg_satisfaction_score < 3 THEN 'Support Recovery Outreach'
        WHEN distinct_features_used < 10 THEN 'Feature Adoption Nudge'
        WHEN total_tickets = 0 AND health_score < 40 THEN 'Proactive Check-in (Silent Risk)'
        ELSE 'Standard Retention Outreach'
    END AS recommended_action
FROM Dim_Account
WHERE is_active = 1
    AND risk_tier IN ('High Risk', 'Medium Risk')
    AND revenue_at_risk > 0
ORDER BY revenue_at_risk DESC;


-- =============================================
-- Query 4: Subscription Funnel
-- Signup -> Converted -> Renewed -> Upgraded -> Churned
-- The headline funnel-stage query for the Power BI funnel visual.
-- =============================================
WITH FunnelBase AS (
    SELECT 
        a.account_id,
        a.is_trial,
        a.is_active,
        a.churn_flag,
        CASE WHEN EXISTS (
            SELECT 1 FROM Fact_Subscription s 
            WHERE s.account_id = a.account_id AND s.upgrade_flag = 1
        ) THEN 1 ELSE 0 END AS has_upgraded,
        CASE WHEN (
            SELECT COUNT(*) FROM Fact_Subscription s WHERE s.account_id = a.account_id
        ) > 1 THEN 1 ELSE 0 END AS has_renewed
    FROM Dim_Account a
)
SELECT 
    COUNT(*) AS total_signups,
    SUM(CASE WHEN is_trial = 0 OR is_active = 1 THEN 1 ELSE 0 END) AS converted_from_trial,
    SUM(has_renewed) AS renewed_at_least_once,
    SUM(has_upgraded) AS upgraded_at_least_once,
    SUM(CASE WHEN churn_flag = 1 THEN 1 ELSE 0 END) AS churned,
    ROUND(100.0 * SUM(has_renewed) / COUNT(*), 1) AS renewal_rate_pct,
    ROUND(100.0 * SUM(CASE WHEN churn_flag = 1 THEN 1 ELSE 0 END) / COUNT(*), 1) AS churn_rate_pct
FROM FunnelBase;


-- =============================================
-- Query 5: Revenue at Each Funnel Stage (with Industry Breakdown)
-- Quantifies MRR associated with accounts at each funnel stage,
-- and MRR lost specifically at the churn stage -- the headline
-- "dollars lost" number for the case study. Also segments churn
-- rate by industry to show which verticals leak the most.
-- =============================================
WITH FunnelRevenue AS (
    SELECT 
        a.account_id,
        a.industry,
        a.mrr_amount,
        a.is_active,
        a.churn_flag,
        CASE WHEN (
            SELECT COUNT(*) FROM Fact_Subscription s WHERE s.account_id = a.account_id
        ) > 1 THEN 1 ELSE 0 END AS has_renewed
    FROM Dim_Account a
)
-- Part A: revenue by overall funnel stage
SELECT 
    'Total Signups' AS funnel_stage, COUNT(*) AS accounts, SUM(mrr_amount) AS total_mrr
FROM FunnelRevenue
UNION ALL
SELECT 'Converted (Active)', COUNT(*), SUM(mrr_amount) 
FROM FunnelRevenue WHERE is_active = 1
UNION ALL
SELECT 'Renewed at Least Once', COUNT(*), SUM(mrr_amount) 
FROM FunnelRevenue WHERE has_renewed = 1
UNION ALL
SELECT 'Churned (Revenue Lost)', COUNT(*), SUM(mrr_amount) 
FROM FunnelRevenue WHERE churn_flag = 1;

-- Part B: churn rate and revenue-at-risk by industry segment
SELECT 
    industry,
    COUNT(*) AS total_signups,
    SUM(CASE WHEN churn_flag = 1 THEN 1 ELSE 0 END) AS churned,
    ROUND(100.0 * SUM(CASE WHEN churn_flag = 1 THEN 1 ELSE 0 END) / COUNT(*), 1) AS churn_rate_pct,
    SUM(revenue_at_risk) AS total_revenue_at_risk
FROM Dim_Account
GROUP BY industry
ORDER BY churn_rate_pct DESC;


-- =============================================
-- Query 6: Structural Churn Signal — Plan Change Before Churn
-- Tests whether upgrades/downgrades preceding churn are a stronger,
-- more specific signal than the day-to-day usage/support behavior
-- tested in the Python phase (which showed weak correlation, AUC 0.58).
-- Closes the analytical loop from Phase 1.
-- =============================================
SELECT 
    preceding_upgrade_flag,
    preceding_downgrade_flag,
    COUNT(*) AS churn_events,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_all_churns
FROM Fact_Churn
GROUP BY preceding_upgrade_flag, preceding_downgrade_flag
ORDER BY churn_events DESC;
