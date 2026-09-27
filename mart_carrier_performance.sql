{{ config(materialized='table') }}

-- One row per carrier: volume, cost, on-time performance, and how often we
-- even have a matching rate-card entry for their shipments.

with orders as (
    select * from {{ ref('int_orders_freight') }}
)

select
    carrier,
    count(*)                                                     as total_orders,
    count_if(freight_match_status = 'Matched')                   as matched_orders,
    round(100.0 * count_if(freight_match_status = 'Matched')
                / count(*), 1)                                   as match_rate_pct,
    sum(actual_shipping_cost)                                     as total_shipping_cost,
    round(avg(actual_shipping_cost), 2)                           as avg_cost_per_order,
    round(avg(order_transit_time_days), 1)                        as avg_transit_time_days,
    count_if(ship_late_day_count > 0)                             as late_shipments,
    round(100.0 * count_if(ship_late_day_count > 0)
                / count(*), 1)                                    as late_rate_pct,
    sum(weight)                                                   as total_weight_shipped
from orders
group by carrier
order by total_orders desc
