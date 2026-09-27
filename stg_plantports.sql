select
    plant_code,
    port
from {{ source('raw', 'raw_plantports') }}
