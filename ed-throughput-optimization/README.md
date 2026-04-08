
# 🚑 Emergency Department Throughput Optimization & Patient Flow Intelligence

---

## 📌 Project Overview

Emergency Departments (ED) are one of the most critical and high-pressure units in a hospital. Managing unpredictable patient inflow, limited resources, and time-sensitive care makes operational efficiency a major challenge.

This project leverages **data analytics and business intelligence** to identify bottlenecks in ED operations and provide **actionable insights** to improve patient flow, reduce waiting time, and minimize LWBS (Left Without Being Seen).

---

## 🎯 Problem Statement

A metropolitan hospital is experiencing:

* ⏱️ Long patient waiting times
* 🚶 High LWBS (patients leaving without treatment)
* 👨‍⚕️ Staff overload and inefficiency

### 🔍 Key Question:

**Is the delay caused by staffing shortages or bed capacity constraints?**

---

## 🧠 Solution Approach

This project follows a complete **end-to-end analytics pipeline**:

1. **Data Generation & Simulation (Python)**
2. **Data Cleaning & Transformation (SQL Server)**
3. **Data Modeling (Star Schema)**
4. **Data Visualization (Power BI Dashboard)**
5. **Business Insights & Recommendations**

---

## 🏗️ Data Architecture

A **Star Schema Model** was implemented:

### 🔹 Fact Tables

* `Fact_ED_Visits` → Patient journey (arrival → triage → doctor → discharge)
* `Fact_Staffing_Levels` → Hourly staff availability

### 🔹 Dimension Tables

* `Dim_Patients` → Demographics
* `Dim_Calendar_Time` → Time intelligence (hour, shift, weekend)
* `Dim_Hospital_Resources` → Bed and facility capacity

---

## ⚙️ Tech Stack

| Tool           | Purpose                                  |
| -------------- | ---------------------------------------- |
| 🐍 Python      | Data generation & simulation             |
| 🗄️ SQL Server | Data cleaning, transformation, analytics |
| 📊 Power BI    | Dashboard & visualization                |
| 📑 Excel       | Preprocessing                            |

---

## 📊 Dashboard Preview

### 🔹 Executive Overview

![Dashboard Overview](https://github.com/prasobh-r/Data_Analyst_Projects/blob/main/ed-throughput-optimization/images/ED_Dashboard.jpg)

---

## 📈 Key Metrics

* Average Wait Time
* Door-to-Doctor Time
* Bed Occupancy (%)
* Patient Throughput
* LWBS (%)
* Revenue Loss due to LWBS

---

## 🔍 Key Insights

* 📌 Peak congestion occurs during **evening hours**
* 🛏️ **Bed availability**, not physician shortage, is the primary bottleneck
* 📊 Patient demand frequently exceeds capacity
* ⚠️ LWBS increases significantly with higher wait times
* 🧑‍⚕️ Staffing is not aligned with peak demand

---

## 🚨 Intelligent Features (Dashboard Highlights)

* 🚨 **Dynamic LWBS Alert System**
* 🔄 **Patient Flow Funnel Analysis**
* 📉 **Hourly Throughput & Capacity Stress Tracking**
* 🔥 **24-Hour Risk Heatmap**
* 📊 **Staffing vs Wait Time Correlation (Scatter Plot)**
* 💡 **Data-Driven Recommendations Panel**

---

## 💡 Business Recommendations

* Optimize staffing schedules during peak hours
* Improve bed allocation and discharge efficiency
* Implement real-time ED monitoring dashboards
* Enhance triage prioritization
* Apply predictive analytics for demand forecasting

---

## 📁 Project Structure

```
ED-Throughput-Optimization/
│
├── data/                # Sample datasets
├── sql/                 # SQL analytics pipeline
├── powerbi/             # Power BI dashboard (.pbix)
├── images/              # Dashboard screenshots
├── docs/                # Project report
└── README.md
```

---

## 🧪 Data Engineering Highlights

* Simulated **200K+ ED visits**
* Introduced real-world data challenges:

  * Missing values
  * Duplicate records
  * Invalid timestamps
  * Outliers
* Cleaned and validated data using SQL pipelines

---

## 📌 How to Use

1. Open the Power BI file (`.pbix`)
2. Load sample dataset or connect to SQL Server
3. Use slicers (Shift, Gender, Age Group)
4. Explore insights and alerts
