USE RavenStack_SubscriptionIntelligence;
GO

-- View 1: Cohort Retention
CREATE VIEW vw_CohortRetention AS
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
GROUP BY cb.cohort_month, cs.total_accounts;
GO

-- View 2: Customer Ranking
-- NOTE: account_id renamed to acct_ref so Power BI does NOT auto-create
-- a relationship back to Dim_Account -- this view is self-contained and
-- is meant to stand alone as a reporting table (same pattern as
-- vw_CohortRetention, vw_RevenueByIndustry, vw_ChurnSignal).
CREATE VIEW vw_CustomerRanking AS
SELECT 
    account_id AS acct_ref,
    plan_tier,
    risk_tier,
    revenue_at_risk,
    RANK() OVER (PARTITION BY risk_tier ORDER BY revenue_at_risk DESC) AS rank_within_tier,
    ROW_NUMBER() OVER (ORDER BY revenue_at_risk DESC) AS overall_rank,
    NTILE(4) OVER (ORDER BY mrr_amount DESC) AS revenue_quartile
FROM Dim_Account
WHERE is_active = 1;
GO

-- View 3: Save Campaign Prioritizer
-- NOTE: account_id renamed to acct_ref for the same reason as above.
CREATE VIEW vw_SaveCampaignPrioritizer AS
SELECT 
    account_id AS acct_ref,
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
    AND revenue_at_risk > 0;
GO

-- View 4: Revenue by Industry (for funnel/industry breakdown visual)
CREATE VIEW vw_RevenueByIndustry AS
SELECT 
    industry,
    COUNT(*) AS total_signups,
    SUM(CASE WHEN churn_flag = 1 THEN 1 ELSE 0 END) AS churned,
    ROUND(100.0 * SUM(CASE WHEN churn_flag = 1 THEN 1 ELSE 0 END) / COUNT(*), 1) AS churn_rate_pct,
    SUM(revenue_at_risk) AS total_revenue_at_risk
FROM Dim_Account
GROUP BY industry;
GO

-- View 5: Structural Churn Signal
CREATE VIEW vw_ChurnSignal AS
SELECT 
    preceding_upgrade_flag,
    preceding_downgrade_flag,
    COUNT(*) AS churn_events,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_all_churns
FROM Fact_Churn
GROUP BY preceding_upgrade_flag, preceding_downgrade_flag;
GO


SELECT TABLE_NAME FROM INFORMATION_SCHEMA.VIEWS;