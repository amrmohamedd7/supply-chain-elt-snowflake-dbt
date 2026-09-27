-- NOTE: this table loaded with its header row treated as data, so Snowflake
-- named the columns generically (c1, c2) instead of the real header names.
-- Fixing the names here rather than re-loading the raw table.
select
    c1 as plant_code,
    c2 as customer
from {{ source('raw', 'raw_vmicustomers') }}
