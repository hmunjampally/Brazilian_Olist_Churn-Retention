# Brazilian E-Commerce Customer Retention Intelligence Platform

![Databricks](https://img.shields.io/badge/Databricks-FF3621?style=flat&logo=databricks&logoColor=white)
![AWS S3](https://img.shields.io/badge/AWS_S3-569A31?style=flat&logo=amazons3&logoColor=white)
![Delta Lake](https://img.shields.io/badge/Delta_Lake-003366?style=flat&logoColor=white)
![PySpark](https://img.shields.io/badge/PySpark-E25A1C?style=flat&logo=apachespark&logoColor=white)
![Python](https://img.shields.io/badge/Python-3776AB?style=flat&logo=python&logoColor=white)
![Unity Catalog](https://img.shields.io/badge/Unity_Catalog-1a56db?style=flat&logoColor=white)

---

## The Business Question

> *"Of our 93,000+ customers, which ones are most likely to never purchase again —
> and how much revenue are we at risk of losing if we do nothing?"*

This project answers that question end-to-end: from raw CSV files in AWS S3 to a
ranked retention action list ready for a marketing team to act on today.

---

## Dashboard

![Dashboard](docs/dashboard_screenshot.png)

| Metric | Value |
|--------|-------|
| Total customers analyzed | 93,360 |
| Total platform revenue | R$15.42M |
| **Revenue at risk** | **R$6.17M** |
| Customers at risk | 37,340 |
| % of revenue at risk | ~40% |

---

## Architecture

```
AWS S3  (raw CSV files — 9 source tables)
    │
    │   spark.read.csv()  ·  read once, never again
    ▼
┌──────────────────────────────────────────────────┐
│  BRONZE  ·  brazilian.bronze.*                   │
│  9 managed Delta tables  ·  1.5M+ rows           │
│  Raw ingestion, zero transforms                  │
│  + _ingested_at  + _source_file  (lineage)       │
└──────────────────────┬───────────────────────────┘
                       │  PySpark multi-table JOIN
                       │  Date casting · Null handling
                       │  customer_unique_id dedup
                       ▼
┌──────────────────────────────────────────────────┐
│  SILVER  ·  brazilian.silver.*                   │
│  1 analytical table  ·  ~96K delivered orders    │
│  Cleaned · Joined · Typed · Validated            │
└──────────────────────┬───────────────────────────┘
                       │  RFM aggregation
                       │  ntile(5) window scoring
                       │  CASE WHEN segmentation
                       ▼
┌──────────────────────────────────────────────────┐
│  GOLD  ·  brazilian.gold.*                       │
│  5 business-ready Delta tables                   │
│  RFM scores · Segments · Revenue at risk         │
│  Ranked retention action list                    │
└──────────────────────┬───────────────────────────┘
                       │
                       ▼
              Databricks SQL Dashboard
              + sample_retention_list.csv
```

**Stack:** AWS S3 · Databricks Free Edition · Unity Catalog · Delta Lake · PySpark · Spark SQL · Python · Databricks SQL Dashboards

---

## Delta Tables Created

### Bronze — Raw Ingestion (9 tables)

| Table | Source File | Rows |
|-------|------------|------|
| `brazilian.bronze.olist_orders` | olist_orders_dataset.csv | 99,441 |
| `brazilian.bronze.olist_customers` | olist_customers_dataset.csv | 99,441 |
| `brazilian.bronze.olist_order_items` | olist_order_items_dataset.csv | 112,650 |
| `brazilian.bronze.olist_payments` | olist_order_payments_dataset.csv | 103,886 |
| `brazilian.bronze.olist_reviews` | olist_order_reviews_dataset.csv | 99,224 |
| `brazilian.bronze.olist_products` | olist_products_dataset.csv | 32,951 |
| `brazilian.bronze.olist_sellers` | olist_sellers_dataset.csv | 3,095 |
| `brazilian.bronze.olist_geolocation` | olist_geolocation_dataset.csv | 1,000,163 |
| `brazilian.bronze.olist_category_translation` | product_category_name_translation.csv | 71 |

### Silver — Cleaned Analytical Base (1 table)

| Table | Description | Rows |
|-------|-------------|------|
| `brazilian.silver.customer_orders` | Joined, cleaned, delivered orders only | ~96,000 |

### Gold — Business Output (5 tables)

| Table | Description |
|-------|-------------|
| `brazilian.gold.customer_rfm_scores` | RFM scores per customer (r/f/m score 1–5) |
| `brazilian.gold.churn_segments` | Segment label per customer |
| `brazilian.gold.segment_summary` | Aggregated KPIs per segment (6 rows) |
| `brazilian.gold.revenue_at_risk_summary` | Revenue breakdown for At-Risk + Lost |
| `brazilian.gold.retention_priority` | Ranked retention list with recommended actions |

---

## Key Technical Decisions

### 1. customer_unique_id vs customer_id
Olist generates a new `customer_id` per order — the same person placing 3 orders
gets 3 different `customer_id` values. Using `customer_id` for RFM would make
frequency always equal to 1 for every customer, collapsing the model. All analysis
uses `customer_unique_id` — the stable real-person identifier.

### 2. Snapshot date = MAX(purchase_ts), not today()
Olist data ends in late 2018. Using `today()` for recency calculation would give
every customer 2000+ days of recency, making all customers appear churned with no
differentiation. `MAX(purchase_ts)` is used as the reference point — the same
approach a data team would use running this analysis at the time the data was collected.

### 3. Delivered orders only
Cancelled and processing orders do not represent a completed purchase relationship.
Including them distorts recency and frequency. Silver layer filters to
`order_status = 'delivered'`.

### 4. RFM scoring with ntile(5)
Fixed thresholds break when data distributions shift. `ntile(5)` produces relative
scoring that always generates meaningful differentiation regardless of actual value
ranges. Recency is inverted — fewer days since purchase = higher score.

### 5. Threshold calibration for Olist's frequency distribution
~95% of Olist customers place exactly one order. Standard RFM thresholds designed
for repeat-purchase businesses produce empty segments on this dataset. Thresholds
were calibrated by inspecting the actual f_score distribution and adjusting CASE WHEN
conditions to match Olist's single-purchase-dominant profile.

---

## Key Findings

**1. R$6.17M in revenue at risk — 40% of total platform revenue**
At-Risk and Lost customers represent R$6.17M in historical lifetime value. These
customers have demonstrated spend capacity but are no longer active. Without
intervention this revenue does not return.

**2. 37,340 customers classified as disengaged**
40% of the analyzed customer base sits in At-Risk or Lost segments — an unusually
high concentration driven by Olist's single-purchase customer profile.

**3. Satisfaction scores differ across segments**
At-Risk customers average 4.17 stars vs Champions at 4.28 stars. The gap indicates
service quality is a contributing factor to disengagement. Retention messaging should
acknowledge the customer experience before leading with a discount offer.

**4. Geographic concentration creates campaign efficiency**
Revenue at risk is not evenly distributed across Brazil. The top states hold a
disproportionate share of at-risk LTV — geographic targeting improves campaign ROI
versus a blanket national send.

**5. Recovery potential score enables budget prioritization**
A composite score (monetary 50% + recency 30% + satisfaction 20%) ranks each
at-risk customer by who is most worth pursuing and most likely to respond. This
allows a fixed campaign budget to be allocated to highest-ROI customers first.

---

## Sample Output

See [`data/sample_retention_list.csv`](data/sample_retention_list.csv) for the first
50 rows of the retention priority list.

| Column | Description |
|--------|-------------|
| `customer_unique_id` | Anonymized customer identifier |
| `segment` | At-Risk or Lost |
| `lifetime_value` | Total historical spend in BRL |
| `recency_days` | Days since last purchase |
| `recommended_action` | P1 personal outreach / P2 email / P3 automated / P4 generic |
| `suggested_channel` | Email / Personal call / Email + SMS |
| `recovery_potential_score` | Composite prioritization score (1.6–5.0) |

---

## Notebooks

| Notebook | Purpose |
|----------|---------|
| [01_bronze_ingestion](notebooks/01_bronze_ingestion.ipynb) | Ingest 9 CSVs from S3 into Delta tables |
| [02_silver_cleaning_joining](notebooks/02_silver_cleaning_joining.ipynb) | Clean, join, deduplicate |
| [03_gold_Feature_Engineering](notebooks/03_gold_Feature_Engineering.ipynb) | RFM aggregation and ntile(5) scoring |
| [04_churn_risk_segmentation](notebooks/04_churn_risk_segmentation.ipynb) | Segment assignment and validation |
| [05_Revenue_Risk_Retention_Priority_List](notebooks/05_Revenue_Risk_Retention_Priority_List.ipynb) | Business output + retention list |
| [06_analysis_insights](notebooks/06_analysis_insights.ipynb) | Charts and executive summary |

---

## How to Run

**Prerequisites**
- Databricks Free Edition account
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
Olist Brazilian E-Commerce — [kaggle.com/datasets/olistbr/brazilian-ecommerce](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)

---

## What I Would Add With More Time

**Delta Live Tables (DLT)**
Replace the manual notebook chain with a declarative pipeline using Lakeflow Spark
Declarative Pipelines — built-in data quality expectations, automatic retry logic,
and pipeline lineage tracking.

**Supervised ML churn model**
Train a gradient boosting classifier using RFM features plus review scores. Track
experiments in MLflow (built into Databricks). Register the best model in the Unity
Catalog Model Registry. Moves from rule-based segmentation to probabilistic churn
probabilities.

**A/B test framework**
Measure whether retention campaigns actually work. Track reactivation rate by campaign
cohort and feed results back as ground truth labels for model retraining.

**Real-time scoring**
Move from batch scoring to session-level churn signals using Databricks Feature Store
and Model Serving.

---

## About This Project

Built to demonstrate end-to-end data engineering and analytics on a production-style
stack. Every architectural decision mirrors what data teams use in enterprise
environments — Medallion Architecture on Delta Lake is the standard at Uber, LinkedIn,
Apple, and Comcast.

**Currency:** Brazilian Real (BRL / R$)  
**Dataset period:** 2016–2018  
**Analysis reference date:** MAX(purchase_timestamp) in dataset
