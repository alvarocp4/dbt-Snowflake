with spine as (
    select * from {{ ref('vw_stg_prospect_consolidated') }}
)

select
    id_opportunity,
    opportunity_number,
    id_prospect,
    id_unique_intender,
    id_easy_code,
    prospect_status,
    dh_prospect_creation,
    dh_last_modification,
    cost_center,
    dh_visit_appointment,
    dh_end_construction,
    dh_installation,
    grupo_ln,
    dh_status,
    dh_closing,
    source_cdm,
    channel_cdm,
    source_esp,
    source_subcategory,
    is_foto_criteria,
    dh_foto_criteria,
    is_foto_criteria_online,
    dh_foto_criteria_online,
    prospect_status_closing_hist,
    abreviation_his,
    {{load_metadata()}}
from spine s
{% if is_incremental() %}
where s.dh_last_modification > (
    select coalesce(max(dh_last_modification), '1900-01-01'::timestamp_ntz)
    from {{ this }}
)

{% endif %}