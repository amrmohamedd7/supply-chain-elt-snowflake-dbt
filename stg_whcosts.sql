-- WH holds the plant code -- renamed for consistency with the other tables
select
    wh as plant_code,
    cost_unit as cost_per_unit
from {{ source('raw', 'raw_whcosts') }}
