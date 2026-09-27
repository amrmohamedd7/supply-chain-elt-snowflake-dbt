{{ config(materialized='table') }}

-- One row per plant: daily capacity, storage cost, and the current order
-- backlog. NOTE: every order in stg_orderlist shares the same order_date
-- (confirmed: only 1 distinct date in the whole table) -- this dataset is
-- a single-point-in-time snapshot, not a time series. So "utilization"
-- here is NOT a daily rate; it's how many days of stated daily capacity
-- the current backlog would take to clear.

with capacities as (
    select * from {{ ref('stg_whcapacities') }}
),

costs as (
    select * from {{ ref('stg_whcosts') }}
),

plant_activity as (
    select
        plant_code,
        count(*) as total_orders,
        sum(unit_quantity) as total_units_shipped
    from {{ ref('stg_orderlist') }}
    group by plant_code
)

select
    c.plant_code,
    c.daily_capacity,
    co.cost_per_unit,
    coalesce(pa.total_orders, 0) as total_orders,
    round(pa.total_orders / nullif(c.daily_capacity, 0), 1) as backlog_days_at_capacity,
    coalesce(pa.total_units_shipped, 0) as total_units_shipped
from capacities c
left join costs co          on c.plant_code = co.plant_code
left join plant_activity pa on c.plant_code = pa.plant_code
order by backlog_days_at_capacity desc nulls last
