select
    plant_id as plant_code,
    daily_capacity
from {{ source('raw', 'raw_whcapacities') }}
