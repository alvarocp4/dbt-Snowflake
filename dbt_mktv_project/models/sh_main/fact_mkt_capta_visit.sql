-- =============================================================================
-- fact_mktv_visitas
-- foto diaria, 1 fila/prospecto.
-- Ensamblaje minimo: passthrough del spine (ya trae identidad + salida de los 5 modelos).
-- Merge por id_prospecto; watermark = ssfultmodifica (MAX event_datetime del estado).
-- =============================================================================

with spine as (
    select * from {{ ref('stg_prospect_consolidated') }}
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
    ownership_channel,
    ownership_subchannel,
    segment,
    segment_subtype,
    zip_code,
    current_alarm_system,
    booker_user,
    assigned_user,
    allocator_user,
    cost_center,
    dh_visit_appointment,
    dh_end_construction,
    installation_code,
    dh_installation,
    ds_origin,
    ds_acd,
    grupo_ln,
    status_name,
    dh_status,
    closing_reason,
    dh_closing,
    source_cdm,
    channel_cdm,
    source_esp,
    source_subcategory,
    company_name,
    ds_camapaign_type,
    campaign_name,
    campaign_creation,
    ds_business_model,
    is_foto_criteria,
    dh_foto_criteria,
    is_foto_criteria_online,
    dh_foto_criteria_online,
    prospect_status_closing_hist,
    abreviation_his,
    {{load_metadata()}}
from spine
{% if is_incremental() %}
where dh_last_modification > (
    select coalesce(max(dh_last_modification), '1900-01-01'::timestamp_ntz)
    from {{ this }}
)
{% endif %}