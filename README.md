# BingePlay Product & Business Analytics (SQL)

An exploratory data analysis and product metrics project built on the **BingePlay** streaming platform database. Using MySQL, this repository answers 12 core business and user-behavior questions across revenue, growth, engagement, and churn.

## Database Schema

The `bingeplay` relational database models user activity and subscriptions across five core tables:

* **`users`** — User demographics, signup dates, cities, age groups, and referral channels.
* **`subscriptions`** — Subscription tiers (`Basic`, `Premium`, `Family`), monthly pricing (INR), status, and start/end dates.
* **`shows`** — Catalog metadata including category, language, release year, IMDb rating, `is_original` flag, and minimum required plan.
* **`watch_sessions`** — Playback logs tracking watch duration, device platform, completion flags, and session dates (including guest/anonymous sessions).
* **`ratings`** — User star ratings (1–5) and rating dates across titles.

## Analysis Overview

The queries in the `.sql` script are structured across three progressive tiers:

* **Tier 1: Core Metrics & Foundations (Q1–Q5)**
  * Active Monthly Recurring Revenue (MRR) calculation accounting for open-ended subscriptions.
  * Month-over-month signup growth momentum (Jan–Jun 2024).
  * Device engagement and completion rate breakdown (excluding anonymous sessions).
  * Star rating distribution and positive sentiment share (4 & 5 stars).
  * BingePlay Originals vs. Acquired content performance comparison.

* **Tier 2: Multi-Table Joins & Cohort Logic (Q6–Q10)**
  * Single-day binge-watching detection per show in Q2 2024.
  * Unactivated Q1 user cohort identification using `NOT EXISTS` anti-joins.
  * Plan under-utilization analysis (Premium/Family subscribers watching only Basic-tier content).
  * January Basic-to-Premium/Family upgrade conversion tracking and time-to-upgrade metrics.
  * Cliffhanger comeback analysis via self-joins (incomplete sessions resumed within 1–7 days).

* **Tier 3: Advanced Window Functions & Retention (Q11–Q12)**
  * Consecutive 4+ week viewing streaks using the Gaps-and-Islands (`ROW_NUMBER()`) technique.
  * Churn risk detection identifying users with a $\ge 50\%$ drop in watch time from May to June 2024.

## Tech Stack

* **Database:** MySQL
* **Client:** MySQL Workbench (or any standard MySQL CLI/GUI client)

## How to Run Locally

1. **Set up the MySQL Database:**
   * Open MySQL Workbench and execute `bingeplay_setup.sql` to create the `bingeplay` schema and populate all five tables.

2. **Run the Analysis Queries:**
   * Open `bingeplay_analysis.sql` (or your named `.sql` file) in a new query tab.
   * Ensure the `bingeplay` schema is selected (`USE bingeplay;`), then execute individual queries or the full script to view the result sets.