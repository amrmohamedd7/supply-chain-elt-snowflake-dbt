# Supply Chain Network Cost & Capacity Analysis

**Is the shipping network operating efficiently? Where is cost visibility missing, and which warehouses are over or under capacity?**

A data-analyst case study built on a modern ELT stack — Snowflake for the warehouse, dbt for transformation and testing, Power BI for the dashboard.

## Problem

A supply-chain network's cost and capacity data lives across several disconnected reference tables (rate cards, warehouse capacities, plant-product mappings). Before any cost or efficiency question can be answered, that data has to be modeled correctly — and along the way, this project surfaced real gaps in the underlying rate documentation itself, which turned out to be one of the most important findings.

## Data

- Source: [Supply Chain Logistics Problem Dataset](https://brunel.figshare.com/articles/dataset/Supply_Chain_Logistics_Problem_Dataset/7558679), Kalganova & Dzalbs, Brunel University London, CC-BY-4.0
- **7 relational tables**: OrderList (9,215 orders), FreightRates (1,540 rate-card entries), WhCosts, WhCapacities, ProductsPerPlant, VmiCustomers, PlantPorts (19–2,036 rows each)
- 3 carriers, 19 plants
- **Confirmed data characteristic**: every order shares a single `order_date` — this is a one-point-in-time planning snapshot (the dataset's original purpose was a supply-chain network optimization problem), not a time series. This reshaped how capacity metrics are interpreted throughout.

## Method

| Stage | Tool |
|---|---|
| Raw ingestion (7 tables loaded as-is, untransformed) | Snowflake |
| Staging (renaming, type fixes, documented exceptions) | dbt (7 models) |
| Intermediate (order-to-freight-rate matching, cost calculation) | dbt (1 model) |
| Marts (carrier performance, warehouse operations) | dbt (2 models, materialized as tables) |
| Schema tests (uniqueness, referential integrity, accepted values) | dbt (25 tests) |
| Dashboard | Power BI, connected live to Snowflake |

**Deliberate ELT design**: raw tables were loaded into Snowflake exactly as extracted, including known messiness (e.g., a column named `Daily Capacity ` with a trailing space). All cleaning happened afterward in dbt's staging layer as tested, version-controlled SQL — not in Python before upload. This is the core methodological difference from the other two projects in this portfolio, and it's what dbt is actually for.

## Key findings

**1. Nearly a quarter of all orders have no matching freight rate.** 2,224 of 9,215 orders (24.1%) couldn't be matched to a rate-card entry:
- **854 orders (9.3%)**: the carrier/route combination doesn't exist in the rate card at all
- **1,370 orders (14.9%)**: the route exists, but the shipment's weight falls outside every available weight band for it

**2. The gap is concentrated in specific carriers, not spread evenly:**

| Carrier | Share of volume | Rate-card match rate |
|---|---|---|
| V444_0 | 68.0% | 100% |
| V444_1 | 22.8% | 34.7% |
| V44_3 | 9.3% | **0%** |

**V44_3 has zero documented freight rates for any of its 854 shipments** — a real financial-control gap, not a data artifact (confirmed: this carrier's order count exactly equals the "route not in rate card" total). **V444_1's unmatched orders (1,370) exactly equal the "weight out of band" total** — its rate card exists but doesn't cover the full range of shipment weights actually used.

**3. The under-documented carrier may be the better one.** V444_1 shows a lower late-shipment rate (0.4% vs. 2.9% for V444_0) and faster average transit (1.1 vs. 2 days) — but two-thirds of its cost is invisible in the current data, making a full cost-benefit comparison impossible without fixing the rate card first.

**4. Warehouse assignment is badly imbalanced.** Since this is a single-batch snapshot, "capacity utilization" is better read as "backlog days at capacity" — how many days of stated daily capacity the current order batch would take to clear:

| Plant | Backlog | |
|---|---|---|
| PLANT03 | **8.4 days** | Primary bottleneck |
| PLANT08 | **7.3 days** | Bottleneck despite being a small plant |
| PLANT12 | 1.4 days | Slightly over |
| PLANT16, PLANT13, PLANT04 | < 0.4 days | Large spare capacity |
| **12 of 19 plants** | **0 orders** | No orders assigned in this batch at all |

The network's problem isn't total capacity — it's distribution. Two plants are heavily overloaded while 12 sit completely idle in this batch.

## Data-quality issues found and how they were handled

- **`RAW_VMICUSTOMERS`** loaded with its header row treated as data (Snowflake auto-named the columns `C1`/`C2`). Fixed by renaming in the dbt staging model rather than re-loading, with the reason documented inline.
- **`CND9`** (a plant code in ProductsPerPlant) has no matching row in WhCapacities and doesn't follow the `PLANTxx` naming convention used everywhere else — a genuine source-data gap. The relevant dbt test was downgraded to a warning (not silenced) so the build doesn't fail on a known, documented case.
- **Join fanout risk**: matching orders to freight rates could multiply rows if a route/carrier had more than one applicable rate. Handled with a `qualify row_number()` dedup, and verified afterward that `order_id` stayed unique and equal to the source row count (9,215).

## Recommendations

1. **Formalize freight-rate documentation for carrier V44_3 immediately.** 9.3% of shipping volume currently has zero cost visibility in the system — this should be treated as a financial-control gap, not just a data nicety.
2. **Expand the FreightRates weight bands for V444_1.** Only a third of its shipments have a matching rate. Given this carrier already shows better on-time performance and faster transit, closing this gap could reveal it's worth shifting more volume toward it.
3. **Rebalance order-to-plant assignment.** PLANT03 and PLANT08 carry backlogs equal to 7–8+ days of daily capacity while 12 of 19 plants have none. Reallocating even a portion of PLANT03's load toward underused plants (PLANT16, PLANT13, PLANT04) would directly relieve the network's biggest bottleneck.
4. **Treat every "daily" metric in this analysis as a batch snapshot, not a recurring rate**, when using it for planning — a genuine characteristic of this data, not a caveat to bury in a footnote.

## Limitations

- This is a single-point-in-time snapshot (one `order_date` value), not a time series — no trend, seasonality, or true daily-rate analysis is possible from it.
- The source dataset was designed for a network optimization (Linear Programming) problem; this project repurposes it for descriptive/diagnostic BI rather than solving the original routing-optimization question.
- 24.1% of orders have no cost estimate, so **every "total shipping cost" figure in this analysis is an undercount** — most severely for V44_3 (100% of its cost is missing) and V444_1 (65% missing). A dollar-value business-impact estimate (as in the companion healthcare project) isn't credible here until this gap is closed.
- `CND9`'s missing capacity data means it's silently excluded from any capacity-based analysis.
- Passing dbt tests confirms structural integrity (uniqueness, valid categories, referential integrity) — it does not confirm the underlying rate card itself is complete or correct.

## Repository structure

```
snowflake/
  00_snowflake_setup.sql
dbt/
  models/staging/            -- 7 models + sources.yml + tests
  models/intermediate/       -- int_orders_freight + tests
  models/marts/               -- mart_carrier_performance, mart_warehouse_operations + tests
  dbt_project.yml
python/
  00_inspect_files_sc.py     -- initial file/sheet inspection
  01_inspect_export_sc.py    -- raw export for Snowflake (no cleaning, by design)
dashboard/
  supply_chain_dashboard.pbix
images/
  dbt_lineage_graph.png      -- from dbt docs
README.md
```

## Tools

Snowflake · dbt · Python (pandas) · Power BI

---

### For a resume / CV

> Built an end-to-end ELT pipeline (Snowflake + dbt) modeling 7 relational supply-chain tables through staging, intermediate, and mart layers with 25 automated schema tests. Uncovered a 24% freight-rate documentation gap — including one carrier representing 9.3% of shipping volume with zero cost visibility — and identified a warehouse-assignment imbalance where one plant carried an 8.4-day order backlog while 12 of 19 plants had no orders assigned. Delivered findings via a Power BI dashboard connected live to Snowflake.
