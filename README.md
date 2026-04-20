**Stack:** AWS S3 · Databricks Free Edition · Unity Catalog ·
Delta Lake · PySpark · Spark SQL · Databricks SQL Dashboards

---

## Delta Tables Created

### Bronze — Raw Ingestion (9 tables)

| Table | Source File | Rows |
|-------|------------|------|
| brazilian.bronze.olist_orders | olist_orders_dataset.csv | 99,441 |
| brazilian.bronze.olist_customers | olist_customers_dataset.csv | 99,441 |
| brazilian.bronze.olist_order_items | olist_order_items_dataset.csv | 112,650 |
| brazilian.bronze.olist_payments | olist_order_payments_dataset.csv | 103,886 |
| brazilian.bronze.olist_reviews | olist_order_reviews_dataset.csv | 99,224 |
| brazilian.bronze.olist_products | olist_products_dataset.csv | 32,951 |
| brazilian.bronze.olist_sellers | olist_sellers_dataset.csv | 3,095 |
| brazilian.bronze.olist_geolocation | olist_geolocation_dataset.csv | 1,000,163 |
| brazilian.bronze.olist_category_translation | product_category_name_translation.csv | 71 |

### Silver — Cleaned Analytical Base (1 table)

| Table | Description | Rows |
|-------|-------------|------|
| brazilian.silver.customer_orders | Joined, cleaned, delivered orders only | ~96,000 |

### Gold — Business Output (5 tables)

| Table | Description |
|-------|-------------|
| brazilian.gold.customer_rfm_scores | RFM scores per customer (r/f/m score 1-5) |
| brazilian.gold.churn_segments | Segment label per customer |
| brazilian.gold.segment_summary | Aggregated KPIs per segment (6 rows) |
| brazilian.gold.revenue_at_risk_summary | Revenue breakdown for At-Risk + Lost |
| brazilian.gold.retention_priority | Ranked retention list with recommended actions |

---

## Key Technical Decisions

### 1. customer_unique_id vs customer_id
Olist generates a new `customer_id` per order — the same person
placing 3 orders gets 3 different `customer_id` values. Using
`customer_id` for RFM would make frequency always equal to 1 for
every customer, collapsing the model. All analysis uses
`customer_unique_id` which is the stable real-person identifier.

### 2. Snapshot date = MAX(purchase_ts), not today()
Olist data ends in late 2018. Using `today()` for recency
calculation would give every customer 2000+ days of recency,
making all customers appear churned with no differentiation.
`MAX(purchase_ts)` is used as the reference point — the same
approach a data team would use if running this analysis at
the time the data was collected.

### 3. Delivered orders only
Cancelled and processing orders do not represent a completed
purchase relationship. Including them distorts recency and
frequency — a customer who ordered and cancelled has no purchase
signal. Silver layer filters to `order_status = 'delivered'`.

### 4. RFM scoring with ntile(5)
Fixed thresholds (e.g. "recency < 30 days = score 5") break
when data distributions shift. `ntile(5)` produces relative
scoring that always generates meaningful differentiation regardless
of the actual value ranges. Recency scoring is inverted —
fewer days since purchase = higher score.

### 5. Threshold calibration for Olist's frequency distribution
Olist has an unusual characteristic: ~95% of customers place
exactly one order. Standard RFM thresholds designed for
subscription or repeat-purchase businesses produce empty segments
on this dataset. Thresholds were calibrated by inspecting the
actual f_score distribution and adjusting CASE WHEN conditions
to match Olist's single-purchase-dominant profile.

---

## Key Findings

**1. R$6.17M in revenue at risk — 40% of total platform revenue**
At-Risk and Lost customers represent R$6.17M in historical
lifetime value. These customers have demonstrated spend capacity
but are no longer active. Without intervention this revenue
does not return.

**2. 37,340 customers classified as disengaged**
40% of the analyzed customer base sits in At-Risk or Lost
segments — an unusually high concentration driven by Olist's
single-purchase customer profile.

**3. Satisfaction scores show a gap across segments**
At-Risk customers average 4.17 stars vs Champions at 4.28 stars.
While the gap is modest, it indicates that service quality is
a contributing factor to disengagement — not purely purchase
frequency. Retention messaging should acknowledge the customer
experience before leading with a discount offer.

**4. Geographic concentration creates campaign efficiency**
Revenue at risk is not evenly distributed across Brazil.
The top states hold a disproportionate share of at-risk LTV —
geographic targeting improves campaign ROI versus a
blanket national send.

**5. Recovery potential score enables budget prioritization**
A composite score (monetary 50% + recency 30% + satisfaction 20%)
ranks each at-risk customer by who is most worth pursuing and
most likely to respond. This allows a fixed campaign budget to
be allocated to highest-ROI customers first.

---

## Sample Output

See [`data/sample_retention_list.csv`](data/sample_retention_list.csv)
for the first 50 rows of the retention priority list.

| Column | Description |
|--------|-------------|
| customer_unique_id | Anonymized customer identifier |
| segment | At-Risk or Lost |
| lifetime_value | Total historical spend in BRL |
| recency_days | Days since last purchase |
| recommended_action | P1 personal outreach / P2 email / P3 automated / P4 generic |
| suggested_channel | Email / Personal call / Email+SMS |
| recovery_potential_score | Composite prioritization score (1.6–5.0) |

---

## Notebooks

| Notebook | Purpose |
|----------|---------|
| [01_bronze_ingestion](notebooks/01_bronze_ingestion.ipynb) | Ingest 9 CSVs from S3 to Delta |
| [02_silver_cleaning](notebooks/02_silver_cleaning.ipynb) | Clean, join, deduplicate |
| [03_rfm_features](notebooks/03_rfm_features.ipynb) | RFM aggregation and scoring |
| [04_churn_segments](notebooks/04_churn_segments.ipynb) | Segment assignment |
| [05_revenue_at_risk](notebooks/05_revenue_at_risk.ipynb) | Business output + retention list |
| [06_analysis_insights](notebooks/06_analysis_insights.ipynb) | Charts + executive summary |

---

## How to Run

**Prerequisites**
- Databricks Free Edition account (community.cloud.databricks.com)
- AWS S3 bucket with Olist CSV files
- S3 external location configured in Unity Catalog

**Steps**
1. Clone this repo
2. Upload notebooks to your Databricks workspace
3. Create catalog and schemas:
```sql
CREATE CATALOG IF NOT EXISTS brazilian;
CREATE SCHEMA IF NOT EXISTS brazilian.bronze;
CREATE SCHEMA IF NOT EXISTS brazilian.silver;
CREATE SCHEMA IF NOT EXISTS brazilian.gold;
```
4. Configure S3 external location in Databricks Catalog UI
5. Run notebooks 01 through 06 in order
6. Build SQL Dashboard using queries in `docs/dashboard_queries.sql`

**Dataset**
Olist Brazilian E-Commerce — available on Kaggle:
[kaggle.com/datasets/olistbr/brazilian-ecommerce](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)

---

## What I Would Add With More Time

**Delta Live Tables (DLT)**
Replace the manual notebook chain with a declarative pipeline
using Lakeflow Spark Declarative Pipelines. DLT adds built-in
data quality expectations, automatic retry logic, and pipeline
lineage tracking — the production-grade evolution of notebook
chaining.

**Supervised ML churn model**
Use the RFM features plus review scores to train a gradient
boosting classifier. Track experiments in MLflow (built into
Databricks). Register the best model in the Unity Catalog Model
Registry. This moves from rule-based segmentation to probabilistic
churn probabilities — every customer gets a score rather than
a binary segment label.

**A/B test framework**
Measure whether the retention campaigns actually work. Track
reactivation rate by campaign cohort and feed results back as
ground truth labels for model retraining. This closes the loop
from prediction to measured business impact.

**Real-time scoring**
Move from batch scoring to session-level churn signals using
Databricks Feature Store and Model Serving. A customer showing
browse-without-purchase behavior in a live session could trigger
an immediate retention offer.

---

## About This Project

Built to demonstrate end-to-end data engineering and analytics
on a production-style stack. Every architectural decision mirrors
what data teams use in enterprise environments — Medallion
Architecture on Delta Lake is the standard at companies including
Uber, LinkedIn, Apple, and Comcast.

Currency: Brazilian Real (BRL / R$)
Dataset period: 2016–2018
Analysis reference date: MAX(purchase_timestamp) in dataset
