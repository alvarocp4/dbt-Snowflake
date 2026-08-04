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
        src_master_acds.ds_tipologia_campana                    as ds_camapaign_type,
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
        src_master_origin.ds_tipologia_campana                  as ds_camapaign_type,
        src_master_origin.fecha_inicio                          as dt_start,
        src_master_origin.fecha_fin                             as dt_end
    from {{ source('odin_staging', 'src_mktv_maestros_origenes') }} src_master_origin
    where ds_origin is not null
      and channel  is not null
),

inbound as (
    select
        'I'                                                                                                         as io,
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
            or id_num_acd = 0, src_master_origin.company_name, src_master_acds.company_name))                       as ds_business_model,
        upper(iff(src_master_acds.source = 'SEGUN ORIGEN' or id_num_acd is null 
            or id_num_acd = 0, src_master_origin.ds_camapaign_type, src_master_acds.ds_camapaign_type))             as ds_camapaign_type,
        altitude7_inbound.tfncontacto1                                                                              as first_phone_contact,
        altitude7_inbound.tfncontacto2                                                                              as second_phone_contact,
        altitude7_inbound.tfnpantalla                                                                               as screen_phone_number,
        case 
            when coalesce(dh_campaign_entry::varchar,'19500101') = '19500101' then altitude7_inbound.momento 
            else dh_campaign_entry 
        end                                                                                                         as third_criteria,
        cast(null as varchar)                                                                                       as last_result
    from {{ source('marketing', 'fact_altitude7_inbound') }} altitude7_inbound
    left join src_master_acds       on id_num_acd = src_master_acds.id_acd
       and date(dh_campaign_entry) >= date(src_master_acds.dt_start)
       and date(dh_campaign_entry) <= date(src_master_acds.dt_end)
    left join src_master_origin     on (iff(altitude7_inbound.origeninternet = '', altitude7_inbound.desorigen, altitude7_inbound.origeninternet)) = src_master_origin.ds_origin
       and date(dh_campaign_entry) >= date(src_master_origin.dt_start)
       and date(dh_campaign_entry) <= date(src_master_origin.dt_end)
    inner join {{ source('odin_staging', 'aux_altitude7_consultas') }} aux_altitude7
        on altitude7_inbound.bi_campana = aux_altitude7.campana and aux_altitude7.mktv = 1
),

outbound as (
    select
        'O'                                                                                                         as io,
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
            or id_num_acd = 0, src_master_origin.company_name, src_master_acds.company_name))                       as ds_business_model,
        upper(iff(src_master_acds.source = 'SEGUN ORIGEN' or id_num_acd is null
            or id_num_acd = 0, src_master_origin.ds_camapaign_type, src_master_acds.ds_camapaign_type))             as ds_camapaign_type,
        altitude7_outbound.ct_tfno_contacto1                                                                        as first_phone_contact, 
        altitude7_outbound.ct_tfno_contacto2                                                                        as second_phone_contact, 
        cast(null as varchar)                                                                                       as screen_phone_number,
        case 
            when coalesce(altitude7_outbound.horaprimerallamada::varchar,'19500101') = '19500101' then altitude7_outbound.moment 
            else altitude7_outbound.horaprimerallamada 
        end                                                                                                         as third_criteria,
        cast(null as varchar)                                                                                       as last_result
    from {{ source('marketing', 'fact_altitude7_outbound') }} altitude7_outbound
    left join src_master_acds       on ltrim(rtrim(upper(altitude7_outbound.ct_grupoacd))) = src_master_acds.ds_acd
       and date(altitude7_outbound.ct_visita) >= date(src_master_acds.dt_start)
       and date(altitude7_outbound.ct_visita) <= date(src_master_acds.dt_end)
    left join src_master_origin     on altitude7_outbound.ct_origen = src_master_origin.ds_origin
       and date(altitude7_outbound.ct_visita) >= date(src_master_origin.dt_start)
       and date(altitude7_outbound.ct_visita) <= date(src_master_origin.dt_end)
    inner join {{ source('odin_staging', 'aux_altitude7_consultas') }} aux_altitude7
        on altitude7_outbound.bi_campana = aux_altitude7.campana and aux_altitude7.mktv = 1
),

a8 as (
    select
        '8'                                                                                                            as io,
        altitude8_totalcts.idprospecto                                                                                 as id_prospect,
        altitude8_totalcts.idnumacd                                                                                    as id_num_acd,
        altitude8_totalcts.perfildirectorio                                                                            as id_easy_code,
        altitude8_totalcts.scampanacreacionprospecto                                                                   as campaign_name,
        altitude8_totalcts.fentradacampana                                                                             as dh_campaign_entry,
        iff(altitude8_totalcts.origeninternet = '', altitude8_totalcts.desorigen, altitude8_totalcts.origeninternet)   as ds_origin,
        upper(
            case 
                when b2.source_esp is not null then b2.source_esp              
                when b.source_esp = 'SEGUN ORIGEN' or b.id_acd is null or b.id_acd = 0 then src_master_origin.source              
                else b.source_esp              
            end)                                                                                                       as source_esp,
        upper(
            case 
                when b2.source_cdm is not null then b2.source_cdm              
                when b.source = 'SEGUN ORIGEN' or b.id_acd is null or b.id_acd = 0 then src_master_origin.source_cdm              
                else b.source_cdm              
            end)                                                                                                       as source_cdm,
        upper(
            case 
                when b2.source_subcategory is not null then b2.source_subcategory 
                when b.source = 'SEGUN ORIGEN' or b.id_acd is null or b.id_acd = 0 then src_master_origin.source_subcategory 
                else b.source_subcategory 
            end)                                                                                                       as source_subcategory,
        upper(
            case 
                when b2.channel_cdm is not null then b2.channel_cdm              
                when b.channel = 'SEGUN ORIGEN' or b.id_acd is null or b.id_acd = 0 then src_master_origin.channel_cdm              
                else b.channel_cdm              
            end)                                                                                                       as channel_cdm,
        upper(
            case 
                when b2.company_name is not null then b2.company_name                
                when b.source = 'SEGUN ORIGEN' or b.id_acd is null or b.id_acd = 0 then src_master_origin.company_name              
                else b.company_name
            end)                                                                                                       as company_name,
        upper(iff(b.source = 'SEGUN ORIGEN' or id_num_acd is null 
            or id_num_acd = 0, src_master_origin.company_name, b.company_name))                                        as ds_business_model,
        upper(
            case 
                when b2.ds_camapaign_type   is not null then b2.ds_camapaign_type   
                when b.source    = 'SEGUN ORIGEN' or b.id_acd is null or b.id_acd = 0 then src_master_origin.ds_camapaign_type  
                else b.ds_camapaign_type   
            end)                                                                                                       as ds_camapaign_type,
        altitude8_totalcts.tfncontacto1                                                                                as first_phone_contact, 
        altitude8_totalcts.tfncontacto2                                                                                as second_phone_contact, 
        altitude8_totalcts.tfnpantalla                                                                                 as screen_phone_number,
        altitude8_totalcts.fentradacampana                                                                             as third_criteria,
        altitude8_totalcts.ultimoresult                                                                                as last_result
    from {{ source('marketing', 'fact_altitude8_reportingtotalcts') }} altitude8_totalcts
    left join src_master_acds b
        on altitude8_totalcts.idnumacd = b.id_acd
       and date(altitude8_totalcts.fentradacampana) >= date(b.dt_start)
       and date(altitude8_totalcts.fentradacampana) <= date(b.dt_end)
    left join src_master_acds b2
        on b2.phone_number is not null and b2.phone_number <> 'X' and substr(b2.acd_code,1,1) <> '6'
       and altitude8_totalcts.tr_num_900 = b2.phone_number
       and altitude8_totalcts.campania = 'SP_RcvAbandoned'
       and date(altitude8_totalcts.fentradacampana) >= date(b2.dt_start)
       and date(altitude8_totalcts.fentradacampana) <= date(b2.dt_end)
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

jotforms as (
    select
        'J'                                                             as io,
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
        upper(src_master_origin.ds_camapaign_type)                      as ds_camapaign_type,
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
    select * from inbound
    union all
    select * from outbound
    union all
    select * from a8
    union all
    select * from jotforms
),

leads_mc as (
    select distinct
        io,
        id_prospect,
        id_num_acd,
        id_easy_code,
        campaign_name,
        dh_campaign_entry,
        ds_origin,
        source_esp,
        source_cdm,
        source_subcategory,
        channel_cdm,
        company_name,
        ds_business_model,
        ds_camapaign_type
    from leads_altitude
    where (id_num_acd is not null or (ds_origin is not null and ds_origin <> '' and ds_origin <> ' '))
      and channel_cdm not like '%RELL%'
      and coalesce(id_num_acd, 0) not in (26,117,504,532,600)
      and coalesce(try_to_number(id_easy_code::varchar), 0) <> 0
      and rtrim(ltrim(coalesce(source_cdm, ''))) <> ''
      and rtrim(ltrim(coalesce(channel_cdm, ''))) <> ''
),

visitas as (
    select distinct
        stg_opportunity.opportunity_number,
        stg_opportunity.id_prospect,
        stg_opportunity.id_easy_code,
        stg_opportunity.dh_prospect_creation,
        src_master_acds.acd_code,
        src_master_acds.channel_cdm
    from {{ ref('stg_opportunity_current_state') }} stg_opportunity
    left join src_master_acds
        on upper(trim(stg_opportunity.ds_acd)) = upper(trim(src_master_acds.ds_acd))
       and date(stg_opportunity.dh_prospect_creation) >= date(src_master_acds.dt_start)
       and date(stg_opportunity.dh_prospect_creation) <= date(src_master_acds.dt_end)
    where year(stg_opportunity.dh_prospect_creation) >= 2017
      and channel_cdm not like '%RELL%'
),

crit1 as (
    select
        d.opportunity_number,
        d.id_prospect,
        1                                   as criterio_prio,
        'CRITERIO 1'                        as criterio,
        a.io, 
        a.campaign_name, 
        a.id_easy_code, 
        a.dh_campaign_entry, 
        a.id_num_acd, 
        a.ds_origin,
        a.channel_cdm, 
        a.source_cdm, 
        a.source_esp, 
        a.source_subcategory, 
        a.company_name,
        a.ds_business_model,
        a.ds_camapaign_type,
        d.dh_prospect_creation
    from visitas d
    inner join leads_mc a
        on coalesce(try_to_number(a.id_easy_code::varchar),0) = coalesce(try_to_number(d.id_easy_code::varchar),0)
       and dateadd('day', 100, a.dh_campaign_entry) >= d.dh_prospect_creation
    where coalesce(d.acd_code, '0') not in ('-900','66188','66419','60051','66988')
      and a.id_easy_code is not null
      and a.campaign_name <> 'SP_RunScript'
      and coalesce(try_to_number(a.id_easy_code::varchar),0) <> 0
      and coalesce(a.id_num_acd, -1) not in (26,117,504,532,600)
      and a.channel_cdm not like '%RELL%'
      and rtrim(ltrim(coalesce(a.channel_cdm,''))) <> ''
      and rtrim(ltrim(coalesce(a.source_cdm,''))) <> ''
      and rtrim(ltrim(coalesce(a.source_esp,''))) <> ''
      and rtrim(ltrim(coalesce(a.company_name,''))) <> ''
      and rtrim(ltrim(coalesce(a.ds_camapaign_type,''))) <> ''
),

crit2 as (
    select
        d.opportunity_number,
        d.id_prospect,
        2                                   as criterio_prio,
        'CRITERIO 2'                        as criterio,
        a.io, 
        a.campaign_name, 
        a.id_easy_code, 
        a.dh_campaign_entry, 
        a.id_num_acd, 
        a.ds_origin,
        a.channel_cdm, 
        a.source_cdm, 
        a.source_esp, 
        a.source_subcategory, 
        a.company_name,
        a.ds_business_model, 
        a.ds_camapaign_type,
        d.dh_prospect_creation
    from visitas d
    inner join leads_mc a
        on a.id_prospect = d.id_prospect
    where a.id_easy_code is not null
      and a.campaign_name <> 'SP_RunScript'
      and not (coalesce(a.id_num_acd, -1) in (21,26,132,10)
               and (a.ds_origin is null or a.ds_origin = '' or a.ds_origin = ' '))
      and rtrim(ltrim(coalesce(a.channel_cdm,''))) <> ''
      and rtrim(ltrim(coalesce(a.source_cdm,''))) <> ''
      and rtrim(ltrim(coalesce(a.source_esp,''))) <> ''
      and rtrim(ltrim(coalesce(a.company_name,''))) <> ''
      and rtrim(ltrim(coalesce(a.ds_camapaign_type,''))) <> ''
),

/* -------------------------------------------------------------------------
   CRITERIO 3 / 4 / 5 (por telefono) -- PENDIENTE
   Bloqueado: el prospecto Yukon no expone telefono (NUM_TELF_*).
   Cuando esten disponibles, se anaden como crit3/crit4/crit5 con su
   criterio_prio = 3/4/5 y se incluyen en el union all de 'candidatos'.
   Logica legacy: match por tfnpantalla / tfncontacto1 / tfncontacto2
   contra leads (tfn*) con ventana de fecha F_CRIT3.
   ------------------------------------------------------------------------- */

candidatos as (
    select * from crit1
    union all
    select * from crit2
    -- union all select * from crit3
    -- union all select * from crit4
    -- union all select * from crit5
),

-- pick unico por prospecto: menor prioridad de criterio, luego mas antiguo -----
picked as (
    select *
    from candidatos
    qualify row_number() over (
        partition by id_prospect
        order by criterio_prio, dh_campaign_entry
    ) = 1
)

select
    opportunity_number,
    try_to_number(id_prospect) as id_prospect,
    source_cdm,
    channel_cdm,
    source_esp,
    source_subcategory,
    company_name,
    ds_camapaign_type,
    dh_prospect_creation,
    ds_origin,
    campaign_name,
    ds_business_model,
    io,
    dh_campaign_entry,
    criterio
from picked
order by id_prospect