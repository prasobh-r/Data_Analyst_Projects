-- =============================================
-- RavenStack Subscription Intelligence Platform
-- Database & Schema Setup
-- =============================================

IF DB_ID('RavenStack_SubscriptionIntelligence') IS NULL
    CREATE DATABASE RavenStack_SubscriptionIntelligence;
GO

USE RavenStack_SubscriptionIntelligence;
GO

-- -------------------------------------------------------------------
-- Step 1: Rename auto-imported tables to a clean naming convention
-- (Tables were created via SSMS Import Wizard using source file names)
-- -------------------------------------------------------------------
EXEC sp_rename 'dim_fact_master_account', 'Dim_Account';
EXEC sp_rename 'fact_subscription', 'Fact_Subscription';
EXEC sp_rename 'fact_usage', 'Fact_Usage';
EXEC sp_rename 'fact_support', 'Fact_Support';
EXEC sp_rename 'fact_churn', 'Fact_Churn';
GO

-- -------------------------------------------------------------------
-- Step 2: Fix data types that were too narrow for safe headroom
-- (Import Wizard auto-inferred smallint/tinyint on some numeric columns)
-- -------------------------------------------------------------------
ALTER TABLE Dim_Account ALTER COLUMN mrr_amount INT;
ALTER TABLE Dim_Account ALTER COLUMN total_usage_events INT;
ALTER TABLE Dim_Account ALTER COLUMN total_errors INT;
ALTER TABLE Dim_Account ALTER COLUMN distinct_features_used INT;
GO

-- -------------------------------------------------------------------
-- Step 3: Primary keys
-- -------------------------------------------------------------------
ALTER TABLE Dim_Account ADD CONSTRAINT PK_Dim_Account PRIMARY KEY (account_id);
ALTER TABLE Fact_Subscription ADD CONSTRAINT PK_Fact_Subscription PRIMARY KEY (subscription_id);

-- Fact_Usage.usage_id had 21 non-unique values (source data artifact: ~0.08% ID collision
-- in the synthetic generator). Resolved using a surrogate identity key instead of forcing
-- a non-unique business key into the primary key role.
ALTER TABLE Fact_Usage ADD usage_pk INT IDENTITY(1,1);
ALTER TABLE Fact_Usage ADD CONSTRAINT PK_Fact_Usage PRIMARY KEY (usage_pk);

ALTER TABLE Fact_Support ADD CONSTRAINT PK_Fact_Support PRIMARY KEY (ticket_id);
ALTER TABLE Fact_Churn ADD CONSTRAINT PK_Fact_Churn PRIMARY KEY (churn_event_id);
GO

-- -------------------------------------------------------------------
-- Step 4: Foreign keys linking fact tables back to Dim_Account
-- -------------------------------------------------------------------
ALTER TABLE Fact_Subscription ADD CONSTRAINT FK_Subscription_Account 
    FOREIGN KEY (account_id) REFERENCES Dim_Account(account_id);

ALTER TABLE Fact_Support ADD CONSTRAINT FK_Support_Account 
    FOREIGN KEY (account_id) REFERENCES Dim_Account(account_id);

ALTER TABLE Fact_Churn ADD CONSTRAINT FK_Churn_Account 
    FOREIGN KEY (account_id) REFERENCES Dim_Account(account_id);
GO

-- =============================================
-- Verification
-- =============================================
SELECT 'Dim_Account' AS TableName, COUNT(*) AS [RowCount] FROM Dim_Account
UNION ALL
SELECT 'Fact_Subscription', COUNT(*) FROM Fact_Subscription
UNION ALL
SELECT 'Fact_Usage', COUNT(*) FROM Fact_Usage
UNION ALL
SELECT 'Fact_Support', COUNT(*) FROM Fact_Support
UNION ALL
SELECT 'Fact_Churn', COUNT(*) FROM Fact_Churn;
