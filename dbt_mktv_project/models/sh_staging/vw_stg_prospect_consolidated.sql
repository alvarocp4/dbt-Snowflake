with stg_opportunity as (
    select * from {{ ref('vw_stg_opportunity_current_state') }}
),

stg_cost_center as (
    select
        id_prospect,
        actual_cost_center,
        previous_cost_center,
        is_tlvanu_flg,
        is_due_to_opp_flg
    from {{ ref('vw_stg_cost_center') }}
),

stg_lead_source_channel as (
    select
        id_prospect,
        source_cdm,
        channel_cdm,
        source_esp,
        source_subcategory,
        company_name,
        ds_campaign_type,
        ds_origin,
        campaign_name,
        criteria,
        ds_business_model
    from {{ ref('vw_stg_lead_source_channel') }}
),

stg_campaign_crea as (
    select
        id_prospect,
        campaign_creation
    from {{ ref('vw_stg_campaign_crea') }}
),

stg_foto_crea_criteria as (
    select
        id_prospect,
        is_foto,
        dh_foto,
        is_foto_online,
        dh_foto_online,
        closing_reason,
        ds_acd
    from {{ ref('vw_stg_foto_crea_criteria') }}
)

select
    stg_opportunity.*,
    stg_cost_center.actual_cost_center,
    stg_cost_center.previous_cost_center,
    stg_cost_center.is_tlvanu_flg,
    stg_cost_center.is_due_to_opp_flg,
    stg_lead_source_channel.source_cdm,
    stg_lead_source_channel.channel_cdm,
    stg_lead_source_channel.source_esp,
    stg_lead_source_channel.source_subcategory,
    stg_lead_source_channel.company_name,
    stg_lead_source_channel.ds_campaign_type,
    stg_lead_source_channel.ds_origin               as ds_origin_lead,
    stg_lead_source_channel.campaign_name,
    stg_lead_source_channel.criteria,
    stg_lead_source_channel.ds_business_model,
    stg_campaign_crea.campaign_creation,
    stg_foto_crea_criteria.is_foto                  as is_foto_criteria,
    stg_foto_crea_criteria.dh_foto                  as dh_foto_criteria,
    stg_foto_crea_criteria.is_foto_online           as is_foto_criteria_online,
    stg_foto_crea_criteria.dh_foto_online           as dh_foto_criteria_online,
    stg_foto_crea_criteria.closing_reason           as prospect_status_closing_hist,
    stg_foto_crea_criteria.ds_acd                   as abreviation_his
from stg_opportunity
left join stg_cost_center               on stg_cost_center.id_prospect = stg_opportunity.id_prospect
left join stg_lead_source_channel       on stg_lead_source_channel.id_prospect = stg_opportunity.id_prospect
left join stg_campaign_crea             on stg_campaign_crea.id_prospect = stg_opportunity.id_prospect
left join stg_foto_crea_criteria        on stg_foto_crea_criteria.id_prospect  = stg_opportunity.id_prospect