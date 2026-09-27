-- One row per order, matched to the freight-rate entry that applies to its
-- carrier + route + weight, with the actual cost calculated.
--
-- NOTE on the join: a route/carrier can have more than one rate-card row
-- (e.g. different service levels), so this join could multiply rows if we
-- don't pick one. The `qualify` clause below keeps only the CHEAPEST
-- matching rate per order -- an assumption, not a fact confirmed from real
-- data yet. Check: does removing `qualify` change the row count? If order
-- rows multiply, this dedup is doing real work; if not, routes+carrier
-- already uniquely determine the rate here.

with orders as (
    select * from {{ ref('stg_orderlist') }}
),

rates as (
    select * from {{ ref('stg_freightrates') }}
),

route_check as (
    -- Precomputed once, so the case logic below doesn't repeat the same
    -- correlated subqueries per row.
    select
        o.order_id,
        max(case when r.carrier is not null then 1 else 0 end) as route_exists,
        max(case when o.weight between r.min_weight_qty and r.max_weight_qty then 1 else 0 end) as weight_in_band
    from orders o
    left join rates r
        on  o.carrier          = r.carrier
        and o.origin_port      = r.origin_port
        and o.destination_port = r.destination_port
    group by o.order_id
),

joined as (
    select
        o.order_id,
        o.order_date,
        o.carrier,
        o.origin_port,
        o.destination_port,
        o.plant_code,
        o.customer,
        o.product_id,
        o.weight,
        o.unit_quantity,
        o.transit_time_days as order_transit_time_days,
        o.ship_ahead_day_count,
        o.ship_late_day_count,
        r.rate,
        r.minimum_cost,
        r.transport_mode,
        greatest(r.minimum_cost, r.rate * o.weight) as actual_shipping_cost,
        case
            when rc.route_exists = 0 then 'Route not in rate card'
            when rc.weight_in_band = 0 then 'Weight out of band'
            else 'Matched'
        end as freight_match_status
    from orders o
    left join route_check rc on o.order_id = rc.order_id
    left join rates r
        on  o.carrier          = r.carrier
        and o.origin_port      = r.origin_port
        and o.destination_port = r.destination_port
        and o.weight between r.min_weight_qty and r.max_weight_qty
    qualify row_number() over (
        partition by o.order_id
        order by greatest(r.minimum_cost, r.rate * o.weight) asc
    ) = 1
)

select * from joined
