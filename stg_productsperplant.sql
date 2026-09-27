select
    plant_code,
    product_id
from {{ source('raw', 'raw_productsperplant') }}
