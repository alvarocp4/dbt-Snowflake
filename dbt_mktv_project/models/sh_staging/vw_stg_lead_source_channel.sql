with src_master_acds as (
    select
        cast(src_master_acds.idacd as integer)                  as id_acd,
        ltrim(rtrim(upper(src_master_acds.desacd)))             as acd_code,
        src_master_acds.nombre                                  as ds_acd,
        src_master_acds.medio                                   as source,
        src_master_acds.medio                                   as source_esp,
        src_master_acds.medio_cdm                               as source_cdm,
        src_master_acds.clasificacion_submedio                  as source_subcategory,
        src_master_acds.canal                                   as channel,
        collate(trim(src_master_acds.canal_cdm), '')            as channel_cdm,
        upper(src_master_acds.tlf)                              as phone_number,
        src_master_acds.empresa                                 as company_name,
        null                                                    as ds_business_model,
        src_master_acds.ds_tipologia_campana                    as ds_campaign_type,
        src_master_acds.fecha_inicio                            as dt_start,
        src_master_acds.fecha_fin                               as dt_end
    from {{ source('odin_staging', 'src_mktv_maestros_acds') }} src_master_acds
    where id_acd is not null
      and id_acd is not null
),

src_master_origin as (
    select distinct
        rtrim(ltrim(upper(src_master_origin.origen)))           as ds_origin,
        src_master_origin.medio                                 as source,
        src_master_origin.medio_cdm                             as source_cdm,
        src_master_origin.clasificacion_submedio                as source_subcategory,
        src_master_origin.canal                                 as channel,
        collate(trim(src_master_origin.canal_cdm), '')          as channel_cdm,
        src_master_origin.compania                              as company_name,
        null                                                    as ds_business_model,
        src_master_origin.ds_tipologia_campana                  as ds_campaign_type,
        src_master_origin.fecha_inicio                          as dt_start,
        src_master_origin.fecha_fin                             as dt_end
    from {{ source('odin_staging', 'src_mktv_maestros_origenes') }} src_master_origin
    where ds_origin is not null
      and channel  is not null
),

altitude7_inbound as (
    select
        'I'                                                                                                         as source_table,
        altitude7_inbound.idprospecto                                                                               as id_prospect,
        altitude7_inbound.idnumacd                                                                                  as id_num_acd,
        altitude7_inbound.id_easycode                                                                               as id_easy_code,
        altitude7_inbound.bi_campana                                                                                as campaign_name,
        altitude7_inbound.fentradacampana                                                                           as dh_campaign_entry,
        iff(altitude7_inbound.origeninternet = '', altitude7_inbound.desorigen, altitude7_inbound.origeninternet)   as ds_origin,
        upper(iff(src_master_acds.source_esp = 'SEGUN ORIGEN' or id_num_acd is null 
            or id_num_acd = 0, src_master_origin.source, src_master_acds.source_esp))                               as source_esp,
        upper(iff(src_master_acds.source = 'SEGUN ORIGEN' or id_num_acd is null 
            or id_num_acd = 0, src_master_origin.source_cdm, src_master_acds.source_cdm))                           as source_cdm,
        upper(iff(src_master_acds.source = 'SEGUN ORIGEN' or id_num_acd is null 
            or id_num_acd = 0, src_master_origin.source_subcategory, src_master_acds.source_subcategory))           as source_subcategory,
        upper(iff(src_master_acds.channel = 'SEGUN ORIGEN' or id_num_acd is null 
            or id_num_acd = 0, src_master_origin.channel_cdm, src_master_acds.channel_cdm))                         as channel_cdm,
        upper(iff(src_master_acds.source = 'SEGUN ORIGEN' or id_num_acd is null 
            or id_num_acd = 0, src_master_origin.company_name, src_master_acds.company_name))                       as company_name,
        upper(iff(src_master_acds.source = 'SEGUN ORIGEN' or id_num_acd is null 
            or id_num_acd = 0, src_master_origin.ds_business_model, src_master_acds.ds_business_model))             as ds_business_model,
        upper(iff(src_master_acds.source = 'SEGUN ORIGEN' or id_num_acd is null 
            or id_num_acd = 0, src_master_origin.ds_campaign_type, src_master_acds.ds_campaign_type))               as ds_campaign_type,
        altitude7_inbound.tfncontacto1                                                                              as first_phone_contact,
        altitude7_inbound.tfncontacto2                                                                              as second_phone_contact,
        altitude7_inbound.tfnpantalla                                                                               as screen_phone_number,
        case 
            when coalesce(dh_campaign_entry::varchar,'19500101') = '19500101' then altitude7_inbound.momento 
            else dh_campaign_entry 
        end                                                                                                         as third_criteria,
        cast(null as varchar)                                                                                       as last_result
    from {{ source('marketing', 'fact_altitude7_inbound') }} altitude7_inbound
    left join src_master_acds        on id_num_acd = src_master_acds.id_acd
       and date(dh_campaign_entry) >= date(src_master_acds.dt_start)
       and date(dh_campaign_entry) <= date(src_master_acds.dt_end)
    left join src_master_origin      on (iff(altitude7_inbound.origeninternet = '', altitude7_inbound.desorigen, altitude7_inbound.origeninternet)) = src_master_origin.ds_origin
       and date(dh_campaign_entry) >= date(src_master_origin.dt_start)
       and date(dh_campaign_entry) <= date(src_master_origin.dt_end)
    inner join {{ source('odin_staging', 'aux_altitude7_consultas') }} aux_altitude7
        on altitude7_inbound.bi_campana = aux_altitude7.campana and aux_altitude7.mktv = 1
),

altitude7_outbound as (
    select
        'O'                                                                                                         as source_table,
        cast(null as number)                                                                                        as id_prospect,
        src_master_acds.id_acd                                                                                      as id_num_acd,
        altitude7_outbound.id_easycode                                                                              as id_easy_code,
        altitude7_outbound.bi_campana                                                                               as campaign_name,
        altitude7_outbound.ct_visita                                                                                as dh_campaign_entry,
        altitude7_outbound.ct_origen                                                                                as ds_origin,
        upper(iff(src_master_acds.source_esp = 'SEGUN ORIGEN' or id_num_acd is null 
            or id_num_acd = 0, src_master_origin.source, src_master_acds.source_esp))                               as source_esp,
        upper(iff(src_master_acds.source = 'SEGUN ORIGEN' or id_num_acd is null 
            or id_num_acd = 0, src_master_origin.source_cdm, src_master_acds.source_cdm))                           as source_cdm,
        upper(iff(src_master_acds.source = 'SEGUN ORIGEN' or id_num_acd is null
            or id_num_acd = 0, src_master_origin.source_subcategory, src_master_acds.source_subcategory))           as source_subcategory,
        upper(iff(src_master_acds.channel = 'SEGUN ORIGEN' or id_num_acd is null 
            or id_num_acd = 0, src_master_origin.channel_cdm, src_master_acds.channel_cdm))                         as channel_cdm,
        upper(iff(src_master_acds.source = 'SEGUN ORIGEN' or id_num_acd is null
            or id_num_acd = 0, src_master_origin.company_name, src_master_acds.company_name))                       as company_name,
        upper(iff(src_master_acds.source = 'SEGUN ORIGEN' or id_num_acd is null 
            or id_num_acd = 0, src_master_origin.ds_business_model, src_master_acds.ds_business_model))             as ds_business_model,
        upper(iff(src_master_acds.source = 'SEGUN ORIGEN' or id_num_acd is null
            or id_num_acd = 0, src_master_origin.ds_campaign_type, src_master_acds.ds_campaign_type))               as ds_campaign_type,
        altitude7_outbound.ct_tfno_contacto1                                                                        as first_phone_contact, 
        altitude7_outbound.ct_tfno_contacto2                                                                        as second_phone_contact, 
        cast(null as varchar)                                                                                       as screen_phone_number,
        case 
            when coalesce(altitude7_outbound.horaprimerallamada::varchar,'19500101') = '19500101' then altitude7_outbound.moment 
            else altitude7_outbound.horaprimerallamada 
        end                                                                                                         as third_criteria,
        cast(null as varchar)                                                                                       as last_result
    from {{ source('marketing', 'fact_altitude7_outbound') }} altitude7_outbound
    left join src_master_acds        on ltrim(rtrim(upper(altitude7_outbound.ct_grupoacd))) = src_master_acds.ds_acd
       and date(altitude7_outbound.ct_visita) >= date(src_master_acds.dt_start)
       and date(altitude7_outbound.ct_visita) <= date(src_master_acds.dt_end)
    left join src_master_origin      on altitude7_outbound.ct_origen = src_master_origin.ds_origin
       and date(altitude7_outbound.ct_visita) >= date(src_master_origin.dt_start)
       and date(altitude7_outbound.ct_visita) <= date(src_master_origin.dt_end)
    inner join {{ source('odin_staging', 'aux_altitude7_consultas') }} aux_altitude7
        on altitude7_outbound.bi_campana = aux_altitude7.campana and aux_altitude7.mktv = 1
),

altitude8_totalcts as (
    select
        '8'                                                                                                            as source_table,
        altitude8_totalcts.idprospecto                                                                                 as id_prospect,
        altitude8_totalcts.idnumacd                                                                                    as id_num_acd,
        altitude8_totalcts.perfildirectorio                                                                            as id_easy_code,
        altitude8_totalcts.scampanacreacionprospecto                                                                   as campaign_name,
        altitude8_totalcts.fentradacampana                                                                             as dh_campaign_entry,
        iff(altitude8_totalcts.origeninternet = '', altitude8_totalcts.desorigen, altitude8_totalcts.origeninternet)   as ds_origin,
        upper(
            case 
                when src_master_acds2.source_esp is not null then src_master_acds2.source_esp              
                when src_master_acds.source_esp = 'SEGUN ORIGEN' or src_master_acds.id_acd is null or src_master_acds.id_acd = 0 then src_master_origin.source              
                else src_master_acds.source_esp              
            end)                                                                                                       as source_esp,
        upper(
            case 
                when src_master_acds2.source_cdm is not null then src_master_acds2.source_cdm              
                when src_master_acds.source = 'SEGUN ORIGEN' or src_master_acds.id_acd is null or src_master_acds.id_acd = 0 then src_master_origin.source_cdm              
                else src_master_acds.source_cdm              
            end)                                                                                                       as source_cdm,
        upper(
            case 
                when src_master_acds2.source_subcategory is not null then src_master_acds2.source_subcategory 
                when src_master_acds.source = 'SEGUN ORIGEN' or src_master_acds.id_acd is null or src_master_acds.id_acd = 0 then src_master_origin.source_subcategory 
                else src_master_acds.source_subcategory 
            end)                                                                                                       as source_subcategory,
        upper(
            case 
                when src_master_acds2.channel_cdm is not null then src_master_acds2.channel_cdm              
                when src_master_acds.channel = 'SEGUN ORIGEN' or src_master_acds.id_acd is null or src_master_acds.id_acd = 0 then src_master_origin.channel_cdm              
                else src_master_acds.channel_cdm              
            end)                                                                                                       as channel_cdm,
        upper(
            case 
                when src_master_acds2.company_name is not null then src_master_acds2.company_name                
                when src_master_acds.source = 'SEGUN ORIGEN' or src_master_acds.id_acd is null or src_master_acds.id_acd = 0 then src_master_origin.company_name              
                else src_master_acds.company_name
            end)                                                                                                       as company_name,
        upper(iff(src_master_acds.source = 'SEGUN ORIGEN' or id_num_acd is null 
            or id_num_acd = 0, src_master_origin.ds_business_model, src_master_acds.ds_business_model))                as ds_business_model,
        upper(
            case 
                when src_master_acds2.ds_campaign_type   is not null then src_master_acds2.ds_campaign_type   
                when src_master_acds.source    = 'SEGUN ORIGEN' or src_master_acds.id_acd is null or src_master_acds.id_acd = 0 then src_master_origin.ds_campaign_type  
                else src_master_acds.ds_campaign_type   
            end)                                                                                                       as ds_campaign_type,
        altitude8_totalcts.tfncontacto1                                                                                as first_phone_contact, 
        altitude8_totalcts.tfncontacto2                                                                                as second_phone_contact, 
        altitude8_totalcts.tfnpantalla                                                                                 as screen_phone_number,
        altitude8_totalcts.fentradacampana                                                                             as third_criteria,
        altitude8_totalcts.ultimoresult                                                                                as last_result
    from {{ source('marketing', 'fact_altitude8_reportingtotalcts') }} altitude8_totalcts
    left join src_master_acds
        on altitude8_totalcts.idnumacd = src_master_acds.id_acd
       and date(altitude8_totalcts.fentradacampana) >= date(src_master_acds.dt_start)
       and date(altitude8_totalcts.fentradacampana) <= date(src_master_acds.dt_end)
    left join src_master_acds src_master_acds2
        on src_master_acds2.phone_number is not null and src_master_acds2.phone_number <> 'X' and substr(src_master_acds2.acd_code,1,1) <> '6'
       and altitude8_totalcts.tr_num_900 = src_master_acds2.phone_number
       and altitude8_totalcts.campania = 'SP_RcvAbandoned'
       and date(altitude8_totalcts.fentradacampana) >= date(src_master_acds2.dt_start)
       and date(altitude8_totalcts.fentradacampana) <= date(src_master_acds2.dt_end)
    left join src_master_origin
        on rtrim(ltrim(upper(altitude8_totalcts.desorigen))) = src_master_origin.ds_origin
       and date(altitude8_totalcts.fentradacampana) >= date(src_master_origin.dt_start)
       and date(altitude8_totalcts.fentradacampana) <= date(src_master_origin.dt_end)
    inner join {{ source('odin_staging', 'src_mktv_campains') }} src_mktv_campains
        on altitude8_totalcts.campania = src_mktv_campains.altitude
       and src_mktv_campains.linea_de_negocio = 'Contact Center'
       and src_mktv_campains.altitude not in ('SP_AsignMkt')
       and date(altitude8_totalcts.fentradacampana) >= date(src_mktv_campains.fecha_inicio)
       and date(altitude8_totalcts.fentradacampana) <= date(src_mktv_campains.fecha_fin)
),

src_mktv_jotforms as (
    select
        'J'                                                             as source_table,
        cast(null as number)                                            as id_prospect,
        cast(null as number)                                            as id_num_acd,
        src_mktv_jotforms.perfildirectorio / 10000000000000             as id_easy_code,
        src_mktv_jotforms.descrct                                       as campaign_name,
        src_mktv_jotforms.fentradacampana                               as dh_campaign_entry,
        rtrim(ltrim(upper(src_mktv_jotforms.origeninternet)))           as ds_origin,
        upper(src_master_origin.source)                                 as source_esp,
        upper(src_master_origin.source_cdm)                             as source_cdm,
        upper(src_master_origin.source_subcategory)                     as source_subcategory,
        upper(src_master_origin.channel_cdm)                            as channel_cdm,
        upper(src_master_origin.company_name)                           as company_name,
        null                                                            as ds_business_model,
        upper(src_master_origin.ds_campaign_type)                       as ds_campaign_type,
        cast(null as varchar)                                           as first_phone_contact, 
        cast(null as varchar)                                           as second_phone_contact, 
        src_mktv_jotforms.tfnpantalla_e                                 as screen_phone_number,
        src_mktv_jotforms.fentradacampana                               as third_criteria,
        cast(null as varchar)                                           as last_result
    from {{ source('odin_staging', 'src_mktv_jotforms') }} src_mktv_jotforms
    left join src_master_origin 
        on rtrim(ltrim(upper(src_mktv_jotforms.origeninternet))) = src_master_origin.ds_origin
       and date(src_mktv_jotforms.fentradacampana) >= date(src_master_origin.dt_start)
       and date(src_mktv_jotforms.fentradacampana) <= date(src_master_origin.dt_end)
),

leads_altitude as (
    select * from altitude7_inbound
    union all
    select * from altitude7_outbound
    union all
    select * from altitude8_totalcts
    union all
    select * from src_mktv_jotforms
),

leads_altitude_filtered as (
    select distinct
        id_prospect,
        id_num_acd,
        id_easy_code,
        source_table,
        campaign_name,
        dh_campaign_entry,
        ds_origin,
        source_esp,
        source_cdm,
        source_subcategory,
        channel_cdm,
        company_name,
        ds_business_model,
        ds_campaign_type
    from leads_altitude
    where (id_num_acd is not null or (ds_origin is not null and ds_origin <> '' and ds_origin <> ' '))
      and channel_cdm not like '%RELL%'
      and coalesce(id_num_acd, 0) not in (26,117,504,532,600)
      and coalesce(try_to_number(id_easy_code::varchar), 0) <> 0
      and rtrim(ltrim(coalesce(source_cdm, ''))) <> ''
      and rtrim(ltrim(coalesce(channel_cdm, ''))) <> ''
),

stg_opportunity_acds as (
    select distinct
        stg_opportunity.opportunity_number,
        stg_opportunity.id_prospect,
        stg_opportunity.id_easy_code,
        stg_opportunity.dh_prospect_creation,
        src_master_acds.acd_code,
        src_master_acds.channel_cdm
    from {{ ref('vw_stg_opportunity_current_state') }} stg_opportunity
    left join src_master_acds
        on upper(trim(stg_opportunity.ds_acd)) = upper(trim(src_master_acds.ds_acd))
       and date(stg_opportunity.dh_prospect_creation) >= date(src_master_acds.dt_start)
       and date(stg_opportunity.dh_prospect_creation) <= date(src_master_acds.dt_end)
    where year(stg_opportunity.dh_prospect_creation) >= 2017
      and channel_cdm not like '%RELL%'
),

first_criteria as (
    select
        stg_opportunity_acds.opportunity_number,
        stg_opportunity_acds.id_prospect,
        1                       as criteria_priority,
        'CRITERIA 1'            as criteria,
        leads_altitude_filtered.source_table, 
        leads_altitude_filtered.campaign_name,
        leads_altitude_filtered.id_easy_code,
        leads_altitude_filtered.dh_campaign_entry,
        leads_altitude_filtered.id_num_acd,
        leads_altitude_filtered.ds_origin,
        leads_altitude_filtered.channel_cdm,
        leads_altitude_filtered.source_cdm,
        leads_altitude_filtered.source_esp,
        leads_altitude_filtered.source_subcategory,
        leads_altitude_filtered.company_name,
        leads_altitude_filtered.ds_business_model,
        leads_altitude_filtered.ds_campaign_type,
        stg_opportunity_acds.dh_prospect_creation
    from stg_opportunity_acds
    inner join leads_altitude_filtered
        on coalesce(try_to_number(leads_altitude_filtered.id_easy_code::varchar),0) = coalesce(try_to_number(stg_opportunity_acds.id_easy_code::varchar),0)
       and dateadd('day', 100, leads_altitude_filtered.dh_campaign_entry) >= stg_opportunity_acds.dh_prospect_creation
    where coalesce(stg_opportunity_acds.acd_code, '0') not in ('-900','66188','66419','60051','66988')
      and leads_altitude_filtered.id_easy_code is not null
      and leads_altitude_filtered.campaign_name <> 'SP_RunScript'
      and coalesce(try_to_number(leads_altitude_filtered.id_easy_code::varchar),0) <> 0
      and coalesce(leads_altitude_filtered.id_num_acd, -1) not in (26,117,504,532,600)
      and leads_altitude_filtered.channel_cdm not like '%RELL%'
      and rtrim(ltrim(coalesce(leads_altitude_filtered.channel_cdm,''))) <> ''
      and rtrim(ltrim(coalesce(leads_altitude_filtered.source_cdm,''))) <> ''
      and rtrim(ltrim(coalesce(leads_altitude_filtered.source_esp,''))) <> ''
      and rtrim(ltrim(coalesce(leads_altitude_filtered.company_name,''))) <> ''
      and rtrim(ltrim(coalesce(leads_altitude_filtered.ds_campaign_type,''))) <> ''
),

second_criteria as (
    select
        stg_opportunity_acds.opportunity_number,
        stg_opportunity_acds.id_prospect,
        2                                   as criteria_priority,
        'CRITERIA 2'                        as criteria,
        leads_altitude_filtered.source_table,
        leads_altitude_filtered.campaign_name,
        leads_altitude_filtered.id_easy_code,
        leads_altitude_filtered.dh_campaign_entry,
        leads_altitude_filtered.id_num_acd,
        leads_altitude_filtered.ds_origin,
        leads_altitude_filtered.channel_cdm,
        leads_altitude_filtered.source_cdm,
        leads_altitude_filtered.source_esp,
        leads_altitude_filtered.source_subcategory,
        leads_altitude_filtered.company_name,
        leads_altitude_filtered.ds_business_model,
        leads_altitude_filtered.ds_campaign_type,
        stg_opportunity_acds.dh_prospect_creation
    from stg_opportunity_acds
    inner join leads_altitude_filtered
        on leads_altitude_filtered.id_prospect = stg_opportunity_acds.id_prospect
    where leads_altitude_filtered.id_easy_code is not null
      and leads_altitude_filtered.campaign_name <> 'SP_RunScript'
      and not (coalesce(leads_altitude_filtered.id_num_acd, -1) in (21,26,132,10)
               and (leads_altitude_filtered.ds_origin is null or leads_altitude_filtered.ds_origin = '' or leads_altitude_filtered.ds_origin = ' '))
      and rtrim(ltrim(coalesce(leads_altitude_filtered.channel_cdm,''))) <> ''
      and rtrim(ltrim(coalesce(leads_altitude_filtered.source_cdm,''))) <> ''
      and rtrim(ltrim(coalesce(leads_altitude_filtered.source_esp,''))) <> ''
      and rtrim(ltrim(coalesce(leads_altitude_filtered.company_name,''))) <> ''
      and rtrim(ltrim(coalesce(leads_altitude_filtered.ds_campaign_type,''))) <> ''
),

/* -------------------------------------------------------------------------
   CRITERIO 3 / 4 / 5 (por telefono) -- PENDIENTE
   Bloqueado: el prospecto Yukon no expone telefono (NUM_TELF_*).
   Cuando esten disponibles, se anaden como crit3/crit4/crit5 con su
   criterio_prio = 3/4/5 y se incluyen en el union all de 'candidatos'.
   Logica legacy: match por tfnpantalla / tfncontacto1 / tfncontacto2
   contra leads (tfn*) con ventana de fecha F_CRIT3.
   ------------------------------------------------------------------------- */

unified_criteria as (
    select * from first_criteria
    union all
    select * from second_criteria
    -- union all select * from crit3
    -- union all select * from crit4
    -- union all select * from crit5
),

last_prospect_criteria as (
    select *
    from unified_criteria
    qualify row_number() over (
        partition by id_prospect
        order by criteria_priority, dh_campaign_entry
    ) = 1
)

select
    opportunity_number,
    try_to_number(id_prospect) as id_prospect,
    source_table,
    source_cdm,
    channel_cdm,
    source_esp,
    source_subcategory,
    company_name,
    ds_campaign_type,
    dh_prospect_creation,
    ds_origin,
    campaign_name,
    ds_business_model,
    dh_campaign_entry,
    criteria
from last_prospect_criteria
order by id_prospect