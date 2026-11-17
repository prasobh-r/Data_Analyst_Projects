# ER Diagram: Marketing Star Schema

Built from `marketing_data_cleaned` by `sql/04_star_schema_and_rfm.sql`. Renders automatically on GitHub.

```mermaid
erDiagram
  DimCustomer ||--|| FactPurchases : "has one purchase snapshot"
  DimCustomer ||--o{ FactCampaignResponse : "has one row per campaign"

  DimCustomer {
    int Customer_ID PK
    int Year_Birth "NULL if implausible"
    string Education
    string Marital_Status
    int Income "NULL if missing or outlier"
    int Kidhome
    int Teenhome
    date Dt_Customer
    string Country
    int Complain
    string Birth_Year_Flag
    string Income_Flag
  }

  FactPurchases {
    int Customer_ID PK_FK
    int Recency
    int MntWines
    int MntFruits
    int MntMeatProducts
    int MntFishProducts
    int MntSweetProducts
    int MntGoldProds
    int Total_Spend
    int NumDealsPurchases
    int NumWebPurchases
    int NumCatalogPurchases
    int NumStorePurchases
    int Total_Purchases
    int NumWebVisitsMonth
    string Purchase_Consistency_Flag
  }

  FactCampaignResponse {
    int Customer_ID PK_FK
    string Campaign_Name PK
    int Accepted
  }
```

**Relationships**
- `DimCustomer` to `FactPurchases`: one-to-one. `FactPurchases` is a 2-year aggregated snapshot, one row per customer, not individual transactions.
- `DimCustomer` to `FactCampaignResponse`: one-to-many. Each customer has 6 rows, one per campaign (13,158 rows for 2,193 customers). The primary key is `(Customer_ID, Campaign_Name)`.

**Notes**
- `Total_Purchases` is web + catalog + store purchases. `NumDealsPurchases` is kept separate because the source does not say whether deal purchases overlap the channel counts.
- The flag columns record the cleaning decisions made in `sql/02_data_cleaning.sql`.
