select
    carrier,
    orig_port_cd as origin_port,
    dest_port_cd as destination_port,
    minm_wgh_qty as min_weight_qty,
    max_wgh_qty as max_weight_qty,
    svc_cd as service_code,
    minimum_cost,
    rate,
    mode_dsc as transport_mode,
    tpt_day_cnt as transit_time_days,
    carrier_type
from {{ source('raw', 'raw_freightrates') }}
