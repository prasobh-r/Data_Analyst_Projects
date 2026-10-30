# Healthcare ED Throughput Optimization
### A Data-Driven Analysis of Patient Flow, Waiting Times, and Left Without Being Seen (LWBS)

## Project Overview

This project analyzes Emergency Department (ED) visit data to understand patient flow, waiting times, operational bottlenecks, and Left Without Being Seen (LWBS) patterns.

The project follows an end-to-end analytics workflow using **SQL Server, Python, statistical analysis, and Power BI**. It focuses on validating healthcare visit records, calculating timestamp-based care intervals, examining LWBS patterns, conducting statistical significance tests, and presenting operational findings through an interactive dashboard.

The analysis also highlights data-quality limitations and distinguishes between statistically observed patterns and conclusions that the available data cannot support.

## Business Problem

Emergency Departments need to manage patient arrivals, triage, physician assessments, and final dispositions efficiently. Delays at different stages of the care journey may affect patient experience and operational performance.

This project investigates the available visit records to understand:

- How patients move through different stages of the ED process.
- How long patients wait between key care stages.
- What patterns appear in LWBS visits.
- Whether observed differences in LWBS rates are statistically significant.
- How timestamp quality and missing records affect operational reporting.

## Project Objectives

1. Validate the completeness and consistency of ED visit records.
2. Analyze patient flow using timestamp-based care intervals.
3. Identify potential operational bottlenecks.
4. Examine LWBS patterns by arrival year, arrival hour, wait-time category, and triage score.
5. Apply statistical tests to evaluate observed differences.
6. Reconcile SQL analysis results with Power BI reporting.
7. Communicate findings while clearly documenting data limitations.

## Dataset Overview

The project dataset contains **200,000 ED visit records** covering the period from **January 1, 2019, to December 31, 2025**.

### Dataset Summary

| Attribute | Description |
|---|---|
| Total ED visits | 200,000 |
| Distinct patients | 49,059 |
| Arrival date range | 2019-01-01 to 2025-12-31 |
| Analysis unit | Individual visit |
| Disposition categories | Discharged, Admitted, LWBS |
| Data structure | Visit-level records |
| Repeated patient visits | A patient may have multiple visits |

### Disposition Distribution

| Disposition | Visit Count |
|---|---:|
| Discharged | 99,845 |
| Admitted | 80,283 |
| LWBS | 19,872 |
| **Total** | **200,000** |

Overall, LWBS visits represent approximately **9.94%** of all recorded visits.

### Dataset Files

| File | Purpose |
|---|---|
| `dataset/raw/Cleaned_ED_Visits.csv` | Raw project input dataset containing ED visit records. |
| `dataset/processed/ed_visits_timestamp_corrected.csv` | Processed dataset used for timestamp-based analysis and statistical validation. |
| `docs/lwbs_significance_results.csv` | Exported statistical significance test results. |
| `docs/lwbs_statistical_validation.csv` | Supporting statistical validation results. |

**Data transparency:** The original dataset source and redistribution license have not been verified. The dataset may be simulated. The analysis should therefore be interpreted as an analytical demonstration rather than evidence of actual hospital performance. Verify redistribution permission and ensure that files contain no sensitive or identifying patient information before making them publicly available.

## Technology Stack

| Technology | Application |
|---|---|
| SQL Server | Data validation, transformation, interval calculations, and analytical views |
| Python | Data analysis, statistical testing, and validation |
| Pandas | Data manipulation and analysis |
| SciPy | Statistical hypothesis testing |
| Statsmodels | Exploratory statistical modelling, including GEE |
| Jupyter Notebook | Statistical analysis and documentation |
| Power BI | Interactive dashboards, KPI reporting, and visualization |
| DAX | Measures and analytical calculations |

## Repository Structure

```text
healthcare-ed-throughput/
│
├── README.md
├── LWBS_significance_tests.ipynb
│
├── dataset/
│   ├── raw/
│   │   └── Cleaned_ED_Visits.csv
│   │
│   └── processed/
│       └── ed_visits_timestamp_corrected.csv
│
├── docs/
│   ├── lwbs_significance_results.csv
│   └── lwbs_statistical_validation.csv
│
├── report/
│   └── Healthcare_ED_Final_Analytics.pbix
│
├── screenshots/
│   ├── executive-overview.jpg
│   ├── patient-flow.jpg
│   ├── lwbs-deep-dive.jpg
│   └── data-quality-limits.jpg
│
└── sql/
    └── Healthcare_ED_Final_Analytics.sql
```

## Project Workflow

The project follows a structured analytics workflow:

1. **Data Preparation:** Load and inspect the available ED visit records.
2. **Data Validation:** Check record counts, unique visit identifiers, missing timestamps, and invalid timestamp sequences.
3. **SQL Analysis:** Build analytical views and calculate timestamp-based care intervals.
4. **Statistical Analysis:** Evaluate LWBS patterns using appropriate statistical tests.
5. **Python Validation:** Conduct independent statistical analysis and export supporting results.
6. **Power BI Development:** Build interactive dashboards using validated analytical outputs.
7. **Reconciliation:** Compare SQL results with Power BI KPI calculations.
8. **Documentation:** Record findings, limitations, and reproducibility information.

## Data Quality Assessment

Timestamp quality is important because the operational metrics depend on valid event sequences.

The validation identified the following issues:

| Data Quality Check | Records |
|---|---:|
| Missing triage timestamp | 9,909 |
| Triage timestamp before arrival | 1,947 |
| Missing doctor-seen timestamp | 10,000 |
| Disposition before doctor-seen timestamp | 920 |

### Valid Timestamp Intervals

| Care Interval | Eligible Records | Average Duration |
|---|---:|---:|
| Arrival to Triage | 188,144 | 32.04 minutes |
| Triage to Doctor | 178,729 | 66.87 minutes |
| Doctor to Disposition | 189,080 | 164.37 minutes |

The eligibility criteria differ by interval. Records with missing or invalid timestamps are excluded from the relevant interval calculation.

**Important:** The data-quality issue counts may overlap. They should not be added together to estimate the total number of affected visits.

## Statistical Analysis

The project evaluates whether observed differences in LWBS patterns are statistically significant.

The final validation uses a significance level of **5% (α = 0.05)**.

### Statistical Tests and Results

| Analysis | Sample Size | Test Statistic | df | P-value |
|---|---:|---:|---:|---:|
| Triage Score vs LWBS | 200,000 | χ² = 1.4002 | 4 | 0.844160 |
| Arrival Year vs LWBS | 200,000 | χ² = 6.4177 | 6 | 0.378063 |
| Arrival Hour vs LWBS | 200,000 | χ² = 30.6157 | 23 | 0.132529 |
| Wait-Time Band vs LWBS | 188,144 | χ² = 2.3306 | 3 | 0.506682 |
| Wait-Time Distribution: LWBS vs Non-LWBS | 188,144 | U = 1,591,636,000* | — | 0.259916 |

*The Mann–Whitney U statistic is displayed in rounded form as exported in the project documentation.*

### Statistical Interpretation

All reported p-values are greater than 0.05. Therefore, the analysis does not detect statistically significant differences in the tested relationships at the 5% significance level.

This does not prove that the groups are identical or that no relationship exists. It means the available analysis did not provide sufficient statistical evidence to reject the relevant null hypotheses.

### Exploratory Analysis

The notebook also contains exploratory analyses using Generalized Estimating Equations (GEE) and other statistical methods.

These exploratory results use different analytical eligibility rules in some cases, including the treatment of zero-minute wait values.

They are documented separately from the final validation results. The two result sets should not be treated as interchangeable.

Refer to:

- `LWBS_significance_tests.ipynb`
- `docs/lwbs_significance_results.csv`
- `docs/lwbs_statistical_validation.csv`

## Key Analytical Observations

### 1. Overall LWBS

- Total recorded visits: 200,000.
- LWBS visits: 19,872.
- Overall LWBS rate: approximately 9.94%.

### 2. Arrival-Hour Pattern

The observed LWBS rate varies across arrival hours:

- Highest observed rate: 10.54% at 11 AM.
- Lowest observed rate: 9.37% at 8 AM.
- Difference: 1.17 percentage points.

The statistical test did not detect a significant association between arrival hour and LWBS at the 5% significance level.

### 3. Wait-Time Categories

The observed LWBS rate across wait-time categories ranges from approximately 9.73% to 10.02%, a spread of 0.29 percentage points.

The statistical test did not detect a significant association between wait-time category and LWBS.

### 4. Annual Pattern

The observed annual LWBS rate ranges from approximately 9.73% to 10.22%.

The statistical test did not detect a significant association between arrival year and LWBS.

### 5. Timestamp and Classification Limitations

A notable data-quality observation is that 18,871 of the 19,872 records classified as LWBS contain a doctor-seen timestamp.

This requires further investigation into the source data's classification rules and event definitions. It is documented as a validation concern, not automatically treated as proof of incorrect classification.

## Power BI Dashboard

The Power BI report contains four analytical pages.

### 1. Executive Overview

Provides a high-level view of ED performance, including:

- Total visits
- LWBS visits and rate
- Patient disposition distribution
- Key operational indicators

![Executive Overview](screenshots/executive-overview.jpg)

### 2. Patient Flow

Examines the patient journey through the ED process and summarizes timestamp-based care intervals.

![Patient Flow](screenshots/patient-flow.jpg)

### 3. LWBS Deep Dive

Explores LWBS patterns across arrival hours, years, wait-time categories, and triage scores.

![LWBS Deep Dive](screenshots/lwbs-deep-dive.jpg)

### 4. Data Quality and Limitations

Highlights missing timestamps, invalid event sequences, data-quality concerns, and analytical limitations.

![Data Quality and Limits](screenshots/data-quality-limits.jpg)

## SQL and Power BI Reconciliation

SQL Server is used as the primary analytical layer for the timestamp-based interval calculations.

The corresponding Power BI measures and report outputs are checked against the SQL results to maintain consistency.

The reconciliation covers:

- Eligible record counts
- Average care interval durations
- LWBS counts and rates
- Analytical filtering and eligibility criteria

The objective is to ensure that the dashboard reflects the validated analytical outputs rather than independent or inconsistent calculations.

## How to Reproduce the Analysis

### Prerequisites

- Microsoft SQL Server
- SQL Server Management Studio (SSMS)
- Python 3.x
- Jupyter Notebook
- Required Python packages
- Microsoft Power BI Desktop

### Step 1: Set Up the Database

1. Create or select the SQL Server database `Healthcare_Project`.
2. Import the raw dataset from:

   `dataset/raw/Cleaned_ED_Visits.csv`

3. Ensure that the source table is available as:

   `dbo.Cleaned_ED_Visits`

4. Open and execute:

   `sql/Healthcare_ED_Final_Analytics.sql`

5. Review the generated analytical views and validation results.

### Step 2: Prepare the Processed Dataset

Follow the SQL workflow and export the required processed analytical data to:

`dataset/processed/ed_visits_timestamp_corrected.csv`

Use this same path when loading the processed dataset into the Python notebook.

### Step 3: Run the Statistical Notebook

Open:

`LWBS_significance_tests.ipynb`

Install the required Python packages if necessary:

```bash
pip install pandas scipy statsmodels numpy matplotlib seaborn jupyter
```

Run the notebook cells in sequence and review the statistical outputs.

### Step 4: Review the Statistical Results

Compare the notebook outputs with the exported CSV files in:

`docs/`

The exported results provide supporting documentation for the statistical analysis.

### Step 5: Open the Power BI Report

Open:

`report/Healthcare_ED_Final_Analytics.pbix`

If prompted, update the data-source paths to match the local dataset and database configuration.

Refresh the report and review the four dashboard pages.

## Project Limitations

The following limitations are important when interpreting the results:

1. **Dataset provenance:** The original dataset source and redistribution license have not been verified.
2. **Timestamp completeness:** Missing and invalid timestamps reduce the number of eligible records for some interval calculations.
3. **LWBS classification:** Some records classified as LWBS contain doctor-seen timestamps. The source classification logic requires further investigation.
4. **Triage interpretation:** The meaning and direction of the triage score have not been independently verified.
5. **Boarding measurement:** Arrival-to-disposition time is not a validated measure of patient boarding.
6. **Bed occupancy:** Bed occupancy cannot be calculated reliably from visit counts alone. Bed-level occupancy and capacity data would be required.
7. **Financial impact:** No financial loss or revenue impact is estimated because validated financial data is unavailable.
8. **Causality:** The statistical analysis identifies patterns and associations; it does not establish causal relationships.
9. **Statistical interpretation:** A p-value greater than 0.05 does not prove that no effect or relationship exists.

## Conclusion

This project demonstrates an end-to-end healthcare analytics workflow combining SQL Server, Python, statistical testing, and Power BI.

It focuses on patient flow, timestamp-based care intervals, LWBS patterns, statistical validation, and data-quality assessment.

Beyond dashboard development, the project emphasizes analytical reliability, SQL–Power BI reconciliation, transparent reporting, and responsible interpretation of healthcare data.

The findings provide a structured view of the available dataset while clearly identifying areas where additional source information would be required for stronger operational conclusions.

## Author

**Prasobh R.**

Data Analyst | SQL Server | Power BI | Python

- GitHub: https://github.com/prasobh-r
- LinkedIn: https://www.linkedin.com/in/prasobh04
- Portfolio: https://prasobh-r.github.io/portfolio-website/