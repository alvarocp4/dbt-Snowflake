with src_datos_perfil as (
    select
        try_to_number(src_datos_perfil.sidprospecto)                             as id_prospect,
        src_datos_perfil.srelacionadaprospectid                                  as id_prospect_related,
        collate(trim(src_datos_perfil.scampanacreacionprospecto), '')            as prospect_creation_campaing,
        collate(trim(src_datos_perfil.srscampanaoriginal), '')                   as prospect_original_campaing,
        src_datos_perfil.srefercampanaorigen                                     as prospect_related_campaing,
        collate(trim(src_datos_perfil.campania), '')                             as campaing_name,
        try_to_timestamp(src_datos_perfil.dfechacreavisita)                      as dh_visit_crea
    from {{ source('odin_staging', 'src_altitude8_reportingdatosperfil') }} src_datos_perfil
),

related_criteria as (
    select
        id_prospect_related                                                 as id_prospect,
        coalesce(prospect_creation_campaing, prospect_original_campaing)    as campana_crea_rel
    from src_datos_perfil
    where prospect_creation_campaing is not null
      and prospect_creation_campaing not in ('','SP_PbkCalls','SP_RunScript','SP_AsignMkt','SP_AsignManager','SP_AsignOthers')
      and prospect_creation_campaing not like 'SP_TC%'
      and prospect_creation_campaing not like 'SP_TS%'
      and id_prospect_related is not null
    qualify row_number() over (
        partition by id_prospect_related 
        order by dh_visit_crea
    ) = 1
),

first_criteria as (
    select
        id_prospect,
        iff(upper(prospect_creation_campaing) like '%REFERIDO%', prospect_related_campaing, prospect_creation_campaing) as crea_campaing_crit_1
    from src_datos_perfil
    where prospect_creation_campaing is not null
      and prospect_creation_campaing not in ('','SP_PbkCalls','SP_RunScript','SP_AsignMkt','SP_AsignManager','SP_AsignOthers')
      and prospect_creation_campaing not like 'SP_TC%'
      and prospect_creation_campaing not like 'SP_TS%'
      and id_prospect is not null
    qualify row_number() over (
        partition by id_prospect 
        order by dh_visit_crea
    ) = 1
),

second_criteria as (
    select
        id_prospect,
        prospect_original_campaing          as crea_campaing_crit_2
    from src_datos_perfil
    where prospect_original_campaing is not null
      and prospect_original_campaing not in ('','SP_PbkCalls','SP_RunScript','SP_AsignMkt','SP_AsignManager','SP_AsignOthers')
      and prospect_original_campaing not like 'SP_TC%'
      and prospect_original_campaing not like 'SP_TS%'
      and upper(prospect_original_campaing) not like '%REFERIDO%'
      and id_prospect is not null
    qualify row_number() over (
        partition by id_prospect 
        order by dh_visit_crea
    ) = 1
),

fourth_criteria as (
    select
        id_prospect,
        campaing_name            as crea_campaing_crit_4
    from src_datos_perfil
    where campaing_name is not null
      and campaing_name not in ('','SP_PbkCalls','SP_RunScript','SP_AsignMkt','SP_AsignManager','SP_AsignOthers')
      and campaing_name not like 'SP_TC%'
      and campaing_name not like 'SP_TS%'
      and id_prospect is not null
    qualify row_number() over (
        partition by id_prospect 
        order by dh_visit_crea desc
    ) = 1
),

agent_criteria as (
    select
        upper(src_total_agents.matricula)           as id_user,
        src_campaing.campana_altitude               as altitude_campaing
    from {{ source('odin_staging', 'src_mktv_totalagentes') }} src_total_agents
    left join {{ source('odin_staging', 'src_mktcap_campana') }} src_campaing
        on src_total_agents.campania_actual = src_campaing.campana_contactcenter
    where src_total_agents.campania_actual is not null
      and src_total_agents.ln <> '866'
    qualify row_number() over (
        partition by upper(src_total_agents.matricula) 
        order by src_total_agents.campania_actual
    ) = 1
)

select
    stg_opportunity.opportunity_number,
    stg_opportunity.id_prospect,
    coalesce(
        related_criteria.campana_crea_rel,
        first_criteria.crea_campaing_crit_1,
        second_criteria.crea_campaing_crit_2,
        src_campaing_crea.campana_crea_real,
        fourth_criteria.crea_campaing_crit_4,
        agent_criteria.altitude_campaing,
        'No Identificado'
    )           as creation_campaing
from {{ ref('stg_opportunity_current_state') }} stg_opportunity
left join related_criteria      on stg_opportunity.id_prospect = related_criteria.id_prospect
left join first_criteria        on stg_opportunity.id_prospect = first_criteria.id_prospect
left join second_criteria       on stg_opportunity.id_prospect = second_criteria.id_prospect
left join {{ source('odin_staging', 'src_mktv_campana_crea_contactcenter') }} src_campaing_crea
    on stg_opportunity.id_prospect = src_campaing_crea.id_prospecto
left join fourth_criteria       on stg_opportunity.id_prospect = fourth_criteria.id_prospect
left join agent_criteria        on upper(stg_opportunity.booker_user) = agent_criteria.id_user