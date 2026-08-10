with src_data_profile as (
    select
        try_to_number(src_data_profile.sidprospecto)                             as id_prospect,
        src_data_profile.srelacionadaprospectid                                  as id_prospect_related,
        collate(trim(src_data_profile.scampanacreacionprospecto), '')            as prospect_creation_campaign,
        collate(trim(src_data_profile.srscampanaoriginal), '')                   as prospect_original_campaign,
        src_data_profile.srefercampanaorigen                                     as prospect_related_campaign,
        collate(trim(src_data_profile.campania), '')                             as campaign_name,
        try_to_timestamp(src_data_profile.dfechacreavisita)                      as dh_visit_crea
    from {{ source('odin_staging', 'src_altitude8_reportingdatosperfil') }} src_data_profile
),

related_criteria as (
    select
        id_prospect_related                                                 as id_prospect,
        coalesce(prospect_creation_campaign, prospect_original_campaign)    as campaign_crea_related,
        dh_visit_crea
    from src_data_profile
    where prospect_creation_campaign is not null
      and prospect_creation_campaign not in ('','SP_PbkCalls','SP_RunScript','SP_AsignMkt','SP_AsignManager','SP_AsignOthers')
      and prospect_creation_campaign not like 'SP_TC%'
      and prospect_creation_campaign not like 'SP_TS%'
      and id_prospect_related is not null
    qualify row_number() over (
        partition by id_prospect_related 
        order by dh_visit_crea
    ) = 1
),

first_criteria as (
    select
        id_prospect,
        iff(upper(prospect_creation_campaign) like '%REFERIDO%', prospect_related_campaign, prospect_creation_campaign)     as campaign_crea_crit_1,
        dh_visit_crea
    from src_data_profile
    where prospect_creation_campaign is not null
      and prospect_creation_campaign not in ('','SP_PbkCalls','SP_RunScript','SP_AsignMkt','SP_AsignManager','SP_AsignOthers')
      and prospect_creation_campaign not like 'SP_TC%'
      and prospect_creation_campaign not like 'SP_TS%'
      and id_prospect is not null
    qualify row_number() over (
        partition by id_prospect 
        order by dh_visit_crea
    ) = 1
),

second_criteria as (
    select
        id_prospect,
        prospect_original_campaign          as campaign_crea_crit_2,
        dh_visit_crea
    from src_data_profile
    where prospect_original_campaign is not null
      and prospect_original_campaign not in ('','SP_PbkCalls','SP_RunScript','SP_AsignMkt','SP_AsignManager','SP_AsignOthers')
      and prospect_original_campaign not like 'SP_TC%'
      and prospect_original_campaign not like 'SP_TS%'
      and upper(prospect_original_campaign) not like '%REFERIDO%'
      and id_prospect is not null
    qualify row_number() over (
        partition by id_prospect 
        order by dh_visit_crea
    ) = 1
),

-- thrith_criteria as (

-- )

fourth_criteria as (
    select
        id_prospect,
        campaign_name            as campaign_crea_crit_4,
        dh_visit_crea
    from src_data_profile
    where campaign_name is not null
      and campaign_name not in ('','SP_PbkCalls','SP_RunScript','SP_AsignMkt','SP_AsignManager','SP_AsignOthers')
      and campaign_name not like 'SP_TC%'
      and campaign_name not like 'SP_TS%'
      and id_prospect is not null
    qualify row_number() over (
        partition by id_prospect 
        order by dh_visit_crea desc
    ) = 1
),

agent_criteria as (
    select
        upper(src_total_agents.matricula)           as id_user,
        src_campaign.campana_altitude               as campaign_altitude
    from {{ source('odin_staging', 'src_mktv_totalagentes') }} src_total_agents
    left join {{ source('odin_staging', 'src_mktcap_campana') }} src_campaign
        on src_total_agents.campania_actual = src_campaign.campana_contactcenter
    where src_total_agents.campania_actual is not null
      and src_total_agents.ln <> '866'
    qualify row_number() over (
        partition by upper(src_total_agents.matricula) 
        order by src_total_agents.campania_actual
    ) = 1
),

calculated_fields as (
    select
        stg_opportunity.opportunity_number,
        stg_opportunity.id_prospect,
        coalesce(
            related_criteria.campaign_crea_related,
            first_criteria.campaign_crea_crit_1,
            second_criteria.campaign_crea_crit_2,
            src_campaign_crea.campana_crea_real,
            fourth_criteria.campaign_crea_crit_4,
            agent_criteria.campaign_altitude,
            'No Identificado'
        )           as campaign_creation,
        coalesce (
            related_criteria.dh_visit_crea,
            first_criteria.dh_visit_crea,
            second_criteria.dh_visit_crea,
            fourth_criteria.dh_visit_crea,
            null
        )           as dh_visit_crea
    from {{ ref('vw_stg_opportunity_current_state') }} stg_opportunity
    left join related_criteria       on stg_opportunity.id_prospect = related_criteria.id_prospect
    left join first_criteria         on stg_opportunity.id_prospect = first_criteria.id_prospect
    left join second_criteria        on stg_opportunity.id_prospect = second_criteria.id_prospect
    left join fourth_criteria        on stg_opportunity.id_prospect = fourth_criteria.id_prospect
    left join agent_criteria         on upper(stg_opportunity.booker_user) = agent_criteria.id_user
    left join {{ source('odin_staging', 'src_mktv_campana_crea_contactcenter') }} src_campaign_crea
        on stg_opportunity.id_prospect = src_campaign_crea.id_prospecto
)

select
    opportunity_number,
    id_prospect,
    campaign_creation,
    dh_visit_crea
from calculated_fields