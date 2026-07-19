# Marketing Intelligence Analytics Project

## How to Run
1. Download the dataset from [Maven Analytics](https://mavenanalytics.io/data-playground/marketing-campaign-results)
2. In SSMS: right-click your database → Tasks → Import Flat File → select the CSV
   (this auto-creates a table named `marketing_data`)
3. Open `sql/marketing_intelligence.sql` and run it section by section in SSMS
4. See `data/data_dictionary.csv` for column definitions and `screenshots/` for
   proof of successful execution

## 1. Business Problem

A retail marketing team runs periodic campaigns across email/direct channels but
has no systematic way to know which customers are worth targeting, which channels
convert best, or whether campaigns actually drive incremental spend rather than
just reaching customers who would have bought anyway. This project uses SQL to
segment customers, evaluate campaign performance, and produce evidence-based
targeting recommendations.

## 2. Data Source

- **Dataset:** Marketing Campaign (Jack Daoud), hosted via Maven Analytics
- **Link:** https://mavenanalytics.io/data-playground/marketing-campaign-results
- **Size:** 2,240 customers, 28 fields, single flat file
- **Scope:** Customer demographics, 2-year aggregated spend by product category,
  purchase channel counts, and responses to 6 marketing campaigns
- **Known limitation:** the dataset contains no campaign spend/cost data, so this
  project does not calculate ROI or CAC — only response rates and revenue impact,
  which the data actually supports

## 3. Data Warehouse Design

Star schema with one dimension table and two fact tables:

- **DimCustomer** — demographics (income, education, marital status, household, country)
- **FactPurchases** — 2-year aggregated spend by category, purchase channel counts
- **FactCampaignResponse** — unpivoted campaign responses (one row per customer per campaign)

*(See `docs/er_diagram.md` for the full ER diagram — renders automatically on GitHub.)*

## 4. Data Quality Assessment

| Check | Result |
|---|---|
| Total records | 2,240 |
| Duplicate customers | 0 |
| Missing income values | 24 (1.1%) |
| Negative income values | 0 |

## 5. Key Findings

**Customer segmentation (RFM):**

| Segment | Customers | Avg Spend | % of Total Revenue |
|---|---|---|---|
| Loyal Customer | 699 (31%) | ₹995.24 | 51.27% |
| Champion | 333 (15%) | ₹1,333.32 | 32.72% |
| Potential Loyalist | 665 (30%) | ₹280.60 | 13.75% |
| At Risk | 485 (22%) | ₹59.75 | 2.14% |
| Lost | 58 (3%) | ₹29.95 | 0.13% |

Champions and Loyal Customers together are only 46% of the customer base but
generate 84% of total revenue. At Risk and Lost customers (25% of the base)
contribute barely 2.3% of revenue combined.

**Campaign performance:**

| Campaign | Response Rate |
|---|---|
| Final Campaign | 14.91% |
| Campaign 4 | 7.46% |
| Campaign 5 | 7.28% |
| Campaign 3 | 7.28% |
| Campaign 1 | 6.43% |
| Campaign 2 | 1.34% |

Campaign 2 badly underperformed every other campaign (1.34% vs a 6-15% range
for the rest) — roughly 5x lower response than the next-worst campaign.

**RFM segment predicts campaign response directly:**

| Segment | Final Campaign Response Rate |
|---|---|
| Champion | 32.73% |
| Loyal Customer | 17.88% |
| Potential Loyalist | 11.88% |
| At Risk | 4.33% |
| Lost | 0.00% |

Champions respond at 7.6x the rate of At Risk customers, and Lost customers
never responded at all. RFM segment is a strong, direct predictor of who will
respond to a campaign.

**Campaign lift:**

| Group | Customers | Avg Total Spend |
|---|---|---|
| Accepted at least 1 campaign | 609 (27%) | ₹1,001.33 |
| Never accepted | 1,631 (73%) | ₹458.11 |

Customers who accepted at least one campaign spend 2.19x more on average than
those who never accepted. This suggests campaigns correlate with genuinely
higher-value customers, not just reach — though this is a correlation, not
proof campaigns caused the extra spend (Champions may simply be both more
likely to spend and more likely to respond).

**Revenue concentration (Pareto):**

843 customers — 37.63% of the customer base — account for 80% of total
revenue. This is a moderately concentrated distribution: not as extreme as a
classic 80/20 split, but still meaningfully skewed toward a minority of
high-value customers.

**Product category performance:**

| Category | Total Spend |
|---|---|
| Wines | ₹6,80,816 |
| Meat | ₹3,73,968 |
| Gold | ₹98,609 |
| Fish | ₹84,057 |
| Sweets | ₹60,621 |
| Fruits | ₹58,917 |

Wine spend nearly matches all other five categories combined, and is almost
2x Meat, the next-highest category. Wine is clearly the anchor product for
this customer base.

**Geographic distribution:**

| Country | Customers |
|---|---|
| Spain | 1,095 (49%) |
| Saudi Arabia | 337 (15%) |
| Canada | 268 (12%) |
| Australia | 160 (7%) |
| India | 148 (7%) |
| Germany | 120 (5%) |
| USA | 109 (5%) |

Spain alone accounts for nearly half the customer base. Any campaign strategy
here is effectively a Spain-first strategy by volume, even though the dataset
spans 8 countries.

## 6. Business Recommendations

1. **Protect and grow the Champion and Loyal Customer segments.** They are 46%
   of customers but 84% of revenue. Losing even a small share of this group
   would disproportionately hurt revenue — prioritize retention offers here
   over broad-based discounting.

2. **Investigate Campaign 2 before reusing its approach.** At 1.34% response,
   it performed roughly 5x worse than every other campaign. Compare its
   targeting criteria, offer, and timing against Campaign 4/5 (7%+) to find
   what went wrong.

3. **Use RFM segment as a targeting filter for future campaigns.** Champions
   respond at 32.7% vs 4.3% for At Risk and 0% for Lost — targeting Champions
   and Loyal Customers first would likely raise overall response rate
   substantially versus blasting the full base.

4. **Don't write off At Risk customers, but don't over-invest either.** They
   respond at only 4.33% and contribute just 2.14% of revenue — a low-cost
   win-back attempt is reasonable, but they shouldn't receive the same budget
   priority as Champions.

5. **The 37.63%-of-customers-drive-80%-of-revenue finding supports tiered
   service.** A dedicated approach for the top ~38% of customers by spend is
   justified given how much revenue concentration exists there.

6. **Lead with wine in cross-sell and bundle offers.** Wine spend nearly
   equals all other five categories combined — pairing lower-performing
   categories (Fruits, Sweets) with wine bundles could lift their volume.

7. **Treat Spain as the primary market, not one of eight equal markets.**
   With 49% of the customer base, campaign timing, language, and offers
   should be optimized for Spain first, with the remaining markets treated
   as secondary rather than equally weighted.

## 7. SQL Techniques Used

- Star schema design (1 dimension, 2 fact tables)
- CTEs for modular, readable queries
- Window functions: `NTILE()`, `RANK()`, `LAG()`
- RFM segmentation scoring
- Rule-based customer personas
- Pareto (80/20) revenue concentration analysis
- Reusable views and a stored procedure
- Indexing for query performance

## 8. What This Project Does NOT Do

- Does not calculate ROI or CAC (no cost data exists in the source dataset)
- Does not impute missing income (only 1.1% missing; kept as "Unknown" category)
- Customer personas are rule-based on purchase behavior, not statistically derived
- All findings are drawn directly from query output — no fabricated or illustrative figures

## 9. Tech Stack

SQL Server (SSMS), T-SQL

## 10. Screenshots

See `/screenshots` for SSMS execution proof:
- `01_category_country_breakdown.png` — product category spend + country distribution
- `02_rfm_segmentation.png` — RFM segment summary
- `03_campaign_performance.png` — campaign response rates, RFM vs response, campaign lift
- `04_pareto_analysis.png` — 80/20 revenue concentration
