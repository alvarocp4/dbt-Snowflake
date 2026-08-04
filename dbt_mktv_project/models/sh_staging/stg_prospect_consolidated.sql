with base as (
    select * from {{ ref('stg_opportunity_current_state') }}
),

attrs_cc as (
    select
        id_prospect,
        actual_cost_center,
        previous_cost_center,
        is_tlvanu_flg,
        is_due_to_opp_flg
        -- cost_center ya viene en base (lo toma de stg_cost_center)
    from {{ ref('stg_cost_center') }}
),

medio_canal as (
    select
        id_prospect,
        source_cdm,
        channel_cdm,
        source_esp,
        source_subcategory,
        company_name,
        ds_camapaign_type,
        ds_origin,
        campaign_name,
        criterio                    as criterio_medio_canal,
        ds_business_model,
    from {{ ref('stg_lead_medio_canal') }}
),

campana_crea as (
    select
        id_prospect,
        campaign_creation
    from {{ ref('stg_campaign_crea') }}
),

foto as (
    select
        id_prospect,
        entra_foto,
        fecha_foto,
        entra_foto_online,
        fecha_foto_online,
        est_hist_prospecto_cierre,
        abrvrecurso_his
    from {{ ref('stg_foto_crea_criteria') }}
)

select
    b.*,
    b.assigned_user,
    ac.actual_cost_center,
    ac.previous_cost_center,
    ac.is_tlvanu_flg,
    ac.is_due_to_opp_flg,
    mc.source_cdm,
    mc.channel_cdm,
    mc.source_esp,
    mc.source_subcategory,
    mc.company_name,
    mc.ds_camapaign_type,
    mc.ds_origin,
    mc.campaign_name,
    mc.criterio_medio_canal,
    mc.ds_business_model,
    cr.campaign_creation,
    f.entra_foto                        as is_foto_criteria,
    f.fecha_foto                        as dh_foto_criteria,
    f.entra_foto_online                 as is_foto_criteria_online,
    f.fecha_foto_online                 as dh_foto_criteria_online,
    f.est_hist_prospecto_cierre         as prospect_status_closing_hist,
    f.abrvrecurso_his                   as abreviation_his
from base b
left join attrs_cc     ac on ac.id_prospect = b.id_prospect
left join medio_canal  mc on mc.id_prospect = b.id_prospect
left join campana_crea cr on cr.id_prospect = b.id_prospect
left join foto         f  on f.id_prospect  = b.id_prospect