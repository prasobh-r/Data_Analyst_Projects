# ER Diagram — Marketing Intelligence Star Schema

```mermaid
erDiagram
  DimCustomer ||--|| FactPurchases : has
  DimCustomer ||--o{ FactCampaignResponse : "responds to"

  DimCustomer {
    int Customer_ID PK
    int Year_Birth
    string Education
    string Marital_Status
    decimal Income
    int Kidhome
    int Teenhome
    date Dt_Customer
    string Country
    int Complain
  }

  FactPurchases {
    int Customer_ID PK_FK
    int Recency
    decimal MntWines
    decimal MntFruits
    decimal MntMeatProducts
    decimal MntFishProducts
    decimal MntSweetProducts
    decimal MntGoldProds
    decimal Total_Spend
    int NumWebPurchases
    int NumCatalogPurchases
    int NumStorePurchases
    int Total_Purchases
  }

  FactCampaignResponse {
    int Customer_ID FK
    string Campaign_Name
    int Accepted
  }
```

**Relationships:**
- `DimCustomer` to `FactPurchases`: one-to-one (each customer has one aggregated purchase record)
- `DimCustomer` to `FactCampaignResponse`: one-to-many (each customer has 6 rows, one per campaign)
