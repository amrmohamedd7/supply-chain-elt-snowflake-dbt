-- One row per historical order. Source is already clean (Snowflake's
-- loader auto-inferred good names/types from the Excel headers), so this
-- is mostly a thin pass-through with one renamed column for clarity.
select
    order_id,
    order_date,
    origin_port,
    carrier,
    tpt as transit_time_days,
    service_level,
    ship_ahead_day_count,
    ship_late_day_count,
    customer,
    product_id,
    plant_code,
    destination_port,
    unit_quantity,
    weight
from {{ source('raw', 'raw_orderlist') }}
